# Claude Code SessionStart hook for app sessions: lists the unticked
# "App follow-up" items that frost_ui requests leave for the app the session
# runs in. The requests live in docs/requests/ beside this tool; the app is the
# repository folder's name, matched against each item's leading app name, or
# the request's `app:` when the item names none. Prints nothing when nothing
# is pending or the folder is not an app.
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
try {
    $cwd = ([Console]::In.ReadToEnd() | ConvertFrom-Json).cwd
} catch {
    $cwd = $null
}
if (-not $cwd) { $cwd = (Get-Location).Path }

$requests = Join-Path $PSScriptRoot '..\..\docs\requests'
if (-not (Test-Path $requests)) { exit 0 }

# A worktree reports the main checkout through its common git directory.
$root = $cwd
$common = git -C $cwd rev-parse --path-format=absolute --git-common-dir 2>$null
if ($LASTEXITCODE -eq 0 -and $common) { $root = Split-Path $common -Parent }
function Normalize([string]$name) { ($name.ToLowerInvariant() -replace '[^a-z0-9]', '') }
$app = Normalize (Split-Path $root -Leaf)
if (-not $app -or $app -eq 'frostui') { exit 0 }
# A repository folder may carry an `_app` suffix the app name does not.
function IsApp([string]$name) {
    $n = Normalize $name
    $n -and ($app -eq $n -or $app -eq "${n}app")
}

$followUp = '^##\s+(App follow-up|App \u4FA7\u540E\u7EED)\s*$'
$pending = foreach ($file in Get-ChildItem $requests -Filter '*-*.md') {
    $lines = Get-Content $file.FullName -Encoding UTF8
    $owner = ($lines | Where-Object { $_ -match '^app:\s*(.+)$' } | Select-Object -First 1) -replace '^app:\s*', ''
    $status = ($lines | Where-Object { $_ -match '^status:\s*(\S+)' } | Select-Object -First 1) -replace '^status:\s*', ''
    $inSection = $false
    foreach ($line in $lines) {
        if ($line -match '^##\s') { $inSection = $line -match $followUp; continue }
        if (-not $inSection -or $line -notmatch '^\s*-\s*\[\s\]\s*(.+)$') { continue }
        $item = $Matches[1]
        # An item may open with one app name or a list of them before its colon.
        $named = if ($item -match '^([A-Za-z][\w.\-]*(\s*[,\u3001/]\s*[A-Za-z][\w.\-]*)*)\s*[:\uFF1A]') { @($Matches[1] -split '\s*[,\u3001/]\s*') } else { @() }
        if (($named.Count -and @($named | Where-Object { IsApp $_ }).Count) -or (-not $named.Count -and (IsApp $owner))) {
            "- $($file.BaseName) ($status): $item"
        }
    }
}
if (-not $pending) { exit 0 }
@(
    'frost_ui requests leave these follow-ups for this app. Do each one, then tick it in its request file under ../frost_ui/docs/requests/:'
    $pending
) -join "`n"
