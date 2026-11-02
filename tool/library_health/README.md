# frost_ui library health gate

Keeps an agent from piling things into the library just to finish a feature. Existing violations go into the list, which from then on only shrinks.

There is no human confirmation step here: a person does not read the code an agent writes, so one more click of "sure" means nothing. The gate fails a list that grows, and an independent review agent that cannot see the implementer's reasons then decides.

## Command

```bash
dart tool/check_library_health.dart [--root <dir>] [--base <commit>] [--prune] [--init]
```

| Argument | Effect |
|---|---|
| `--root <dir>` | The repository root to check; defaults to the repository this tool lives in |
| `--base <commit>` | Prints the changes relative to this commit (see "Report") and checks whether a list has grown (see "Growth"). When `<dir>` really is not a git repository, both are skipped without error; any other git error (broken configuration, no git, a commit that does not resolve) exits with code 2 |
| `--prune` | Shrinks only: deletes list entries that no longer exist, lowers counts and constructor parameters, then judges as usual. It never adds anything |
| `--init` | Generates both lists from the current code. It refuses if either file already exists (exit code 2) and writes nothing. On success the exit code is 0 |

Exit codes: 0 pass; 1 violations, stale entries or growth; 2 usage error or unable to check.

Cases of exit code 2: bad arguments; `frost_ui.dart` does not exist; `check_tokens` fails to run. It is also 2 when either list is missing and `--init` is not given: when both are missing it says to run `--init`, and when only one is missing it says to restore it from git.

Each problem is one line in the form `<rule> <file>:<line> <scope> <detail>: <guidance>`; for `public-api` the form is `public-api <file>:<line> <kind> <name>: <guidance>`; a stale entry is `stale <rule> <file> <scope> <detail>: run --prune`; the form of growth is under "Growth". The last line is `library health: <N> violations, <M> stale, <G> growth`.

`guidance` states only the correct way to do it and **must not mention the allowlist or public_api files or ask for an exemption**: an agent takes whatever path the error message makes cheapest.

## Files

- `tool/check_library_health.dart`: the entry point, using only `dart:` and no packages. When `package_config.json` is missing it first runs `dart pub get` in `tool/library_health/`, then starts `bin/check.dart`, passing arguments and the exit code through.
- The entry point may cache a kernel to start faster. The cache key is the content hash of `bin/`, `lib/` and `pubspec.yaml` plus `Platform.version`, not modification times; when the key does not match it rebuilds, and when the rebuild fails it starts directly with `--packages`.
- `tool/library_health/`: a standalone pure Dart package that depends on `analyzer`.
- `tool/library_health/allowlist.txt` and `public_api.txt`: the two lists, under `<root>/tool/library_health/`.
- `tool/check_library_health_test.dart`: the test, black-box, with `--root` pointing at a temporary directory.

## Code that is checked

The Dart files under `<root>/packages/frost_ui/lib/` and `<root>/packages/frost_data/lib/`, excluding tests. When `frost_data` does not exist only `frost_ui` is checked. `lib/*.dart` are the public entries (`frost_ui.dart`, the sub-entries `media.dart`, `social.dart` and `desktop.dart`, and `frost_data.dart`), and the `public-api` rule follows exports starting from every entry. The other rules check `lib/src/**` of both packages. Moving code into `frost_data` does not escape any rule.

A file under `lib/` that is neither an entry nor inside `src/` is reported by `layers` as `unknown directory`, so code cannot be placed outside the scanned scope.

Files are parsed into an AST with `parseString` from `package:analyzer`, with no type resolution (fast, and no Flutter package configuration needed), and with no regular expressions. Content in comments and strings does not count. A file that cannot be parsed is reported as a `parse` violation and cannot go into a list. When there is a parse error, neither `--init` nor `--prune` writes any file: `--init` exits with 2, and `--prune` reports violations as usual and exits with 1. A `[reference]` in a doc comment is also a comment and does not count.

## Rules

`scope` is a named declaration: in a method it is `ClassName.methodName`, in a class's field initializers and constructors it is `ClassName`, in a top-level function it is the function name, a local function counts as the method it is in, and when there is none it is `-`. `file` is relative to `lib/src`, with forward slashes. Lines of `frost_data` are written `frost_data:<path relative to its lib/src>`, for example `frost_data:list_source.dart`, and its entry is written `frost_data:../frost_data.dart`.

### public-api

Lists every public symbol exported by all entries: it follows `part`, re-exports and every branch of a conditional export (when two branches declare a symbol of the same name, each side gets its own line); `show` takes only the listed names, `hide` excludes the listed names; names beginning with `_` do not count.

| kind | name | Description |
|---|---|---|
| `class`, `enum`, `mixin`, `typedef`, `extension`, `func`, `var` | symbol name | Top-level declarations. A class alias `class A = B with C` and an extension type count as `class`, a top-level getter or setter counts as `func`, and an unnamed extension is skipped |
| `ctor` | `ClassName.new` or `ClassName.named` | Explicit constructors, primary constructors and extension type constructors. `detail` is the public parameter names, sorted and comma-separated with no spaces, for example `label,onTap` |
| `member` | `ClassName.memberName` | Public methods, getters, setters and fields (including `static`) of classes, mixins and extension types. Those with `@override` do not count. Enum values count too, with `ClassName` being the enum name |
| `ext` | `ExtensionName.memberName` | Public methods and getters of an extension |
| `reexport` | symbol name, or the package URI when there is no `show` | Exports content of another package |

`detail` is `-` except for `ctor`. `file` is relative to `lib/src`; outside `src` it is written `../x.dart`; for `reexport` it is the file that exports it.

Violation: present in reality but not in the list; or a `ctor` whose `detail` has more parameters than the list.
Stale: in the list but not in reality; or a `ctor` whose `detail` has fewer parameters than the list (then `--prune` lowers it). Renaming a parameter counts as both more and fewer, and is a violation. Moving a symbol to another file counts as one addition and one stale entry.

### layers

| Layer | Directories |
|---|---|
| 0 | `foundation` |
| 1 | `primitives`, `motion`, `surface` |
| 2 | `controls`, `display`, `feedback`, `lists`, `overlays`, `layout`, `media` |
| 3 | `navigation`, `social` |

`frost_data` is above all layers and uses `frost_ui` through its public entries. Every `import` or `export` of a file other than a `frost_ui` entry (`package:frost_ui/src/...`) counts once, and `detail` is `frost_ui:<path relative to frost_ui's lib/src>`, so symbols that were un-exported are equally governed in this package. Its files are not divided into directories and do not report `unknown directory`, unless a file is neither an entry nor inside `src`. Its `src` files must not import its own entry. No file of `frost_ui` (entries included) may import or export `frost_data`; this is reported as a violation, with `detail` carrying the `frost_data:` prefix.

Violation: an `import`, `export` or `part` of a directory with a higher layer number; or a file in `lib/src` importing any public entry (`lib/*.dart`), because that would reach every layer. The same layer is allowed. `scope` is always `-`, and `detail` is the imported file relative to `lib/src`. Imports of the form `package:frost_ui/...` are resolved and checked the same way. Other directories and files placed directly in `lib/src` are reported as violations with `detail` written `unknown directory`, and their imports are no longer checked separately.

### framework

The library does not take over framework behavior for the whole app. Each of the following counts once, and `detail` is the name given here:

| detail | Match |
|---|---|
| `highlightStrategy=` | Assignment to a property named `highlightStrategy` |
| `addEarlyKeyEventHandler`, `addLateKeyEventHandler`, `hitTestInView`, `visitAncestorElements`, `visitChildElements` | Any reference to that name, including method calls and tear-offs |
| `HardwareKeyboard.addHandler` | An `addHandler` call whose target text contains `HardwareKeyboard` |
| `pointerRouter` | An `addRoute`, `addGlobalRoute` or `add` call whose target text contains `pointerRouter` |
| `MediaQuery.size` | A `copyWith` call with the named argument `size` whose target text contains `MediaQuery` or `mediaQuery`, or whose target is an identifier named `data`; and `MediaQueryData(...)` with the named argument `size` |
| `MaterialScrollBehavior` | A class whose `extends` is `MaterialScrollBehavior` |
| `hitTest` | A `hitTest` method with `@override` in a class. `hitTestChildren` and `hitTestSelf` do not count |

### basis

Components do not decide by platform name or window size. It checks the files under `lib/src` other than `foundation/` (`frost_data` has no such exception), and `detail` is the name given here. Forms with an import prefix (`m.MediaQuery.sizeOf`) count too.

| detail | Match |
|---|---|
| `defaultTargetPlatform` | This identifier |
| `kIsWeb` | This identifier |
| `TargetPlatform` | `TargetPlatform.x`, and the dot shorthands `.android`, `.iOS`, `.linux`, `.macOS`, `.windows`, `.fuchsia` |
| `Platform.is` | `Platform.isX` |
| `Platform.operatingSystem` | This property |
| `.platform` | A property read named `platform`, or reading `platform` in an object pattern (`ThemeData(:final platform)`) |
| `FrostSizeClass` | A `FrostSizeClass.of` call |
| `MediaQuery.size` | A `MediaQuery.sizeOf` or `maybeSizeOf` call, or `MediaQuery.of(...).size`, `MediaQuery.maybeOf(...)?.size`, `MediaQuery.maybeOf(...)!.size`, also counting when wrapped in extra parentheses |
| `MediaQuery.orientation` | A `MediaQuery.orientationOf` or `maybeOrientationOf` call |
| `physicalSize` | A property read named `physicalSize` |

### child-type

Layout is not decided by the type of a child component. First collect the component classes from all files: those whose `extends` is `StatelessWidget`, `StatefulWidget`, `InheritedWidget`, `ProxyWidget`, `InheritedNotifier`, `AnimatedWidget`, `ImplicitlyAnimatedWidget`, or ends in `RenderObjectWidget`, or that inherit from an already collected component class. A class beginning with `_` is valid only in the file that declares it, and private classes of the same name in different files do not affect each other. A class alias `class A = ComponentBase with M` counts too. The following are violations, with `detail` being the class name:

- `x is ComponentClass`, `x is! ComponentClass`, `x as ComponentClass`
- `case ComponentClass()`, `case ComponentClass _` (switch statements, switch expressions and if-case all count). Only these branch tests count; a destructuring such as `final ComponentClass(:a) = widget;` does not
- `whereType<ComponentClass>()`

In addition, any read of `.runtimeType` counts: when the other side of `==` or `!=` is a component class, `detail` is the class name; otherwise `detail` is `runtimeType`.

`is`, `as` and `case` on sealed data types (which are not component classes) do not count.

### silent

A missing environment must not be silent.

| detail | Match |
|---|---|
| `maybeOf-fallback` | The expression on the left of `??` contains a call named `maybeOf`, `getInheritedWidgetOfExactType`, `dependOnInheritedWidgetOfExactType`, `findAncestorWidgetOfExactType`, `findAncestorStateOfType`, `findRootAncestorStateOfType` or `findAncestorRenderObjectOfType` |
| `catch` | A `catch` clause (`on X {}` counts too) whose body has no `rethrow`, no `throw`, and no call named `reportError` or `completeError`; and a `catchError` call whose function literal argument likewise has none of these |

### tokens

Runs `tool/check_tokens.dart --report` of this tool's repository with `<root>` as the working directory, and parses each line of the form `packages/frost_ui/lib/src/<file>:<line>: <category>: ...` and the same format for `packages/frost_data/lib/src/...`. Counts by `file` and `category`, with `scope` always `-` and `detail` being `category`.

## Lists

`allowlist.txt`, tab-separated, lines beginning with `#` are comments, sorted by field:

```
<rule>	<file>	<scope>	<detail>	<count>	<reason>
```

Judgment: when the actual count of the same `rule`, `file`, `scope` and `detail` exceeds `count`, each extra one is reported as a violation; when it is below `count` or absent in reality it is reported as stale. An empty `reason` is reported as a violation with `rule` written `allowlist`. With no entries every actual occurrence is a violation. A malformed or duplicate line is also reported as a violation, with `rule` written `allowlist`.

`public_api.txt`, tab-separated, lines beginning with `#` are comments, sorted by field:

```
<kind>	<name>	<file>	<detail>	<source>
```

An empty `source` is reported as a violation, with `rule` written `public-api`.

`--init` writes both `reason` and `source` as `baseline-20261102`.

## Growth

With `--base`, the two lists are compared with the versions in `<base>`. When the tree of `<base>` really has no such file (the gate was just introduced), this item is skipped. A git error is not the same as a missing file: when reading fails the exit code is 2.

Each of the following is one growth, one line each, exit code 1:

```
growth allowlist <rule> <file> <scope> <detail> +<n>: <guidance>
growth public-api <kind> <name> <file> <detail>: <guidance>
```

- `allowlist.txt`: a new entry (`+n` is its `count`), or an existing entry whose `count` becomes larger (`+n` is the difference).
- `public_api.txt`: a new entry, or a `ctor` whose `detail` gained parameters.

Exception: when `reason` (`source`) is `reviewed:<YYYYMMDD>:<review conclusion>` and differs from the value of that line in `<base>`, it does not count as growth. `<YYYYMMDD>` is a valid date of 8 digits, and the conclusion must not be empty. This means an independent review has seen this growth. When `<base>` already has the same value, that review was of an earlier growth, and this one still counts as growth.

`guidance` says: stop and report this growth, do not get around it yourself. Deleting a list and running `--init`, or rolling a list back, both show up as growth when compared with `<base>`.

## Review

When growth appears, the planner starts an independent review agent and gives it only the added lines, the relevant code and this spec, without the implementer's report and reasons.

- Pass: write a `reason` beginning with `reviewed:`.
- Fail: send it back for the code to be changed.

When a public component is to be added, the reviewer judges by the component admission rule: if it can be assembled from existing components and only one app wants it, it fails.

## Report

Does not affect the judgment, and is printed every time:

- Files over 800 lines (strictly greater) and constructors with more than 15 public parameters (strictly greater) are only listed and **do not fail**. A hard limit gets bypassed by splitting files and configuration objects.
- With `--base`: the net added lines of `lib/src`, plus one more line for the net added lines of its `lib/src` when `frost_data` exists; and the added and removed lines of the two lists relative to base, including changes not yet tracked by git.

## Known limits

These are covered by independent review and by how the numbers move from version to version; the tool does not stop them:

- **Deliberate circumvention:** forging `reviewed:`, forging the kernel cache, changing the checker or `check_tokens.dart`. This guards against shortcuts, not against deliberate attack; all of it is visible in the commit history.
- **Moving a rule's target:** moving a call into a local variable (`final kb = HardwareKeyboard.instance`), writing a utility function in `foundation/` to get around `basis`, a `typedef` alias, reading a value into a local variable and then using `??`.
- **Type tests on framework components:** there is no type resolution, so `x is Text` is not seen.
- **Scope of `tokens`:** decided by `check_tokens.dart`; constants and some forms of writing are not counted.
- **Moving within the same key:** removing one violation and adding another with the same key leaves the total unchanged, and the gate cannot see it. The keys of `tokens` and `layers` are the widest.

## Details

- A field initialized through a `this.x` parameter is not counted separately as a `member` only when it appears in some public constructor that has a `ctor` line, because it is already in `detail`; a public field initialized only by a private constructor or an enum constructor counts as a `member`. Primary constructor fields and the representation field of an extension type likewise do not count. Enum methods and fields also count as `member`.
- `affected_tests.dart` resolves `<base>` to a full commit id before passing it to the gate, so the Windows shell does not eat the `^` in `HEAD^`. When deciding whether base has the gate files, a git error counts as failure.
- When `--base` cannot be resolved to a commit inside a git repository, the exit code is 2 and the growth check is not skipped.
- A `catchError` with no function literal argument counts as `catch`, because it cannot be seen to handle the error.
- Lines whose `rule` is `contract` are known failures of the contract tests, whose spec is in `packages/frost_ui/test/contract/README.md`. Case IDs of `frost_data` carry the `frost_data:` prefix. The gate does not count them against code and does not report them stale, `--prune` leaves them alone, and the contract tests judge them; adding such a line also counts as growth.
