# Claude Code PreToolUse hook for the Bash and PowerShell tools: blocks
# whole-suite runs (`flutter test` or `dart test` without a test file) so
# routine checks go through tool/affected_tests.dart, which
# prints only failures and a summary. Apps use this same script by its absolute
# path in their .claude/settings.json rather than a copy.
# Exit code 2 blocks the call and returns the message to the session.
try {
    $command = ([Console]::In.ReadToEnd() | ConvertFrom-Json).tool_input.command
} catch {
    exit 0
}
if (-not $command) { exit 0 }

$reason = $null
# Quoted text is data (commit messages, echo), not a command that runs, except
# a quoted test file, which still names what runs.
$keepTestFile = {
    param($match)
    if ($match.Groups[1].Value -match '_test\.dart(:\d+)?$') { $match.Groups[1].Value -replace '\s', '_' } else { '""' }
}
# A heredoc body (a commit message, a file being written) is data too.
$unheredoc = [regex]::Replace($command, "(?s)<<-?\s*['""]?(\w+)['""]?[^\n]*\n.*?\n\s*\1\s*(\n|$)", "`n")
$unquoted = [regex]::Replace($unheredoc, '"([^"]*)"', $keepTestFile)
$unquoted = [regex]::Replace($unquoted, "'([^']*)'", $keepTestFile)
foreach ($segment in $unquoted -split '&&|\|\||[;|\r\n]') {
    $words = @($segment.Trim() -split '\s+' | Where-Object { $_ })
    for ($i = 1; $i -lt $words.Count; $i++) {
        if ($words[$i] -ne 'test' -or $words[$i - 1] -notmatch '(^|[/\\])(flutter|dart)(\.bat|\.exe)?$') { continue }
        $arguments = @($words | Select-Object -Skip ($i + 1))
        $files = @($arguments | Where-Object { $_ -match '_test\.dart(:\d+)?$' })
        if ($files.Count -eq 0 -and $arguments -notcontains '-h' -and $arguments -notcontains '--help') {
            $reason = "'$($segment.Trim())' runs a whole test suite"
        }
    }
    if ($reason) { break }
}
if (-not $reason) { exit 0 }

$tool = ((Resolve-Path (Join-Path $PSScriptRoot '..\affected_tests.dart')).Path) -replace '\\', '/'
[Console]::Error.WriteLine(@"
Blocked: $reason. A full run happens only when the owner asks for one.
- Run the checks this change needs, from the repository root:
    dart $tool <base> --repo . --run
  It prints only failures and one summary line per package. In frost_ui, add
  --consumer <app directory> for the apps that use the change, and
  --dependents when the change alters a default every caller sees.
- Or run named test files: flutter test test/x_test.dart
- When the owner asks for a full run:
    dart $tool --all --repo . --run
"@)
exit 2
