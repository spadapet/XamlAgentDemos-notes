<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` tools in Diagnostics.dll;
- TAP messages for WPF, WinUI/UWP and MAUI;
- a built-in skill, SKILL.md.

The tools are tested autonomously in the fastmain Exp hive. A harness drives WPF demo apps through the Copilot Chat window, and every run is logged in a notes repo.

The current request has five parts:
- add list inputs to the tools;
- fold four status tools into `xaml_get_status`;
- don't merge the binding or accessibility tools yet;
- bring WinUI, UWP and MAUI up to the WPF functionality;
- update the test apps and re-run the tests.

Earlier requests are folded into it: improvements based on run feedback, and a fix for an assert dialog. Autopilot mode is on: decide without asking, verify, then call task_complete.
</overview>

<history>
1. Earlier segments:
   - planned and implemented the tools, the skill and the test harness;
   - ran all 17 demos;
   - added list inputs and folded the status tools into `xaml_get_status`;
   - implemented the new TAP messages in UwpTap and MauiTap (compile-checked only);
   - fixed the assert: "Change-Document scope not disposed" in DesignerUndoService (the fix calls `Abandon()` before `Detach`);
   - made many feedback fixes (#85–94);
   - VanishingSave and StyleMaze final runs were clean;
   - A11ySweep run-final2 found an `apply_hot_reload` summary bug: it ignored .NET errors. Fixed with `codeStatus` and `codeHotReloadErrors`;
   - BindingStorm run-final2: 10/10.
   - PrecedenceWars run-final2: 5/5, but `codeStatus=noOutput` was premature and the IsEnabled coercion explanation didn't name the ancestor.

2. This segment, quick fixes from the PrecedenceWars feedback:
   - **Code hot reload wait:**
     - The wait now looks for an outcome line, using new `IsCodeHotReloadLine` (non-blank, not `[XAML]`) and `IsCodeHotReloadOutcome` (error, "applied"+"success", "No changes", "restart").
     - It waits up to 20 s, or 8 s if the pane stays silent, and breaks after output has been stable for 1 s.
     - New `codeStatus` value `inProgress`.
     - `GetCodeHotReloadErrors` ignores `[XAML]` lines and "Exited with" lines; `GetCodeHotReloadWarnings` ignores `[XAML]` lines.
     - `noOutput` text explains the 8 s and includes the new `earlierCodeHotReloadResult`, the last outcome line before the call (for code applied on save).
     - The "applied" text now says code that already ran (startup, Loaded handlers, failed operations) isn't re-run.
   - **Root-cause off-by-one:** `ReadHotReloadPaneLines` split text ending in a newline, which left a trailing `""`, so `Skip(paneLinesBefore)` dropped the first new line. It now uses `TrimEnd('\r','\n')` before splitting.
   - **IsEnabled coercion:** new `ExplainDisabledAncestorAsync`.
     - It walks up to 20 ancestors via `element.Parent` (type `Microsoft.VisualStudio.DesignTools.RuntimeHost.Live.ILiveNodeWithChildren`).
     - It requests each ancestor's properties and finds the first non-overridden IsEnabled whose evaluated value is "False" and whose source isn't Coercion.
     - It compares `EvaluatedValue` when present, because `Value` holds the binding text for bound values.
     - It names the ancestor's type, x:Name, id and levels up; otherwise it points at the command's CanExecute.
     - It's called from ExplainPropertyValueAsync when the winner is Coercion, the property is IsEnabled, the evaluated value is False, and there's no objectPath.
   - New unit test `IsCodeHotReloadOutcome_IgnoresProgressAndXamlLines`, using `[Test]` (not `[Fact]`). Tests: 14/14 pass.
   - copilot-tools.md documents `codeStatus`, `codeHotReloadErrors`, the wait behavior and the IsEnabled ancestor walk.
   - **PrecedenceWars run-final3:** 5/5. The IsEnabled note correctly pointed at CanExecute, but the off-by-one was still present (`noOutput`/`inProgress`).
   - **run-final4**, after the off-by-one fix: all 3 code applies reported `codeStatus=applied`, verified. The agent reported that the ancestor walk missed the parent's `IsEnabled="{Binding IsIdle}"`. Fixed with the EvaluatedValue comparison, plus the "applied" stale-state text.
   - TestPass.md: run-final2, run-final3 and run-final4 rows replaced the old "not run" row; findings #95–101 added after #94.
   - **run-final5** (latest build, with the EvaluatedValue fix and the "applied" text) just finished: 0 failed calls, 4 explain calls, 2 apply calls. Not yet inspected.
</history>

<work_done>
All changes are uncommitted in `Q:\src\VS_xaml`: about 23 files from the whole request, plus this segment's edits.

This segment's edits:
- `XamlAgentService.cs`:
  - ExplainDisabledAncestorAsync, about lines 1495–1530;
  - the IsEnabled hook in ExplainPropertyValueAsync, about line 1702;
  - the ApplyHotReloadAsync wait loop and codeStatus, about lines 2510–2640;
  - the helpers, about lines 2640–2700;
  - ReadHotReloadPaneLines trimming, about line 2710.
- `XamlAgentToolsTests.cs`: the new test.
- `copilot-tools.md`, about line 79.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`: rows and findings #95–101.

Status:
- [x] Diagnostics builds with 0 warnings and 0 errors. Unit tests 14/14 pass. The final build is deployed to fastmain Exp (hash matches, System.Drawing redirect patched to 10.0.0.0).
- [x] run-final2 for A11ySweep (13/13), BindingStorm (10/10) and PrecedenceWars (5/5). run-final3 and run-final4 for PrecedenceWars (5/5).
- [ ] Inspect run-final5 at `Q:\source\XamlAgentDemos-notes\test-runs\PrecedenceWars\run-final5\`: does the IsEnabled note now name the bound ancestor, and are the codeStatus results right? Then log a row in TestPass.md.
- [ ] Stop KeepAwake (`stop_powershell keepawake2`).
- [ ] Call task_complete.
</work_done>

<technical_details>
- **Build** (from `Q:\src\VS_xaml`; set `[Environment]::CurrentDirectory` too):
  ```
  . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diag.txt
  ```
  The unit test project is `src\Xaml\Diagnostics\Test\Unit\Unit.csproj`.
- **Unit tests:**
  ```
  Q:\src\VS_xaml\out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\DesignTools.Tests.Unit.XamlDiagnostics.exe -class "*XamlAgentToolsTests"
  ```
  Tests use the `[Test]` attribute.
- **Harness** (`$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`):
  - Redeploy: `& "$h\Redeploy.ps1"`, then wait about 75 s.
  - Run a demo: `& "$h\Run-Demo.ps1" -Name X -Tag T` (about 6 min).
  - Run artifacts: events.jsonl, transcript.md, fix.diff, dialogs.log, runner.log.
- **Reading events.jsonl:**
  - `tool.execution_start` gives `data.toolName`, `data.toolCallId` and `data.arguments`;
  - `tool.execution_complete` gives `data.result.content`, a JSON string;
  - the `task_complete` arguments' `summary` holds the final answer and the feedback answers.
- **.NET Hot Reload pane:**
  - Pane GUID: 7BD3920C-C53C-40ED-8D79-4D2F601BEFB0.
  - It also contains `[XAML] Connected...` lines and benign `⚠ WinFormsMetadataUpdateHandler` warnings in WPF apps.
  - The success line is "Code changes were successfully applied."
  - Code edits are often applied on save, before `apply_hot_reload` is called.
- For bound properties, `TapPropertyValue.Value` holds the binding text and `EvaluatedValue` holds the actual value.
- x:Name fields keep their compiled type during hot reload.
- The harness clicks "Disable" on Hot Reload dialogs.
- **Writing files:**
  - TestPass.md: write with `[IO.File]::WriteAllLines`.
  - The edit tool fuzzy-matches, so verify each result.
- Git: never push, rebase or amend. Offer a single local commit only.
- Skill examples must use generic names, not demo names.
- **Open ideas, not implemented:**
  - label binding failures as currentlyFailing;
  - hover simulation;
  - tighter nameFilter matching;
  - a `why_not_visible` diagnostic;
  - a style audit.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Implementation of all tools. This segment changed the hot reload code wait and status, pane reading, and the IsEnabled ancestor explanation (line ranges are in work_done).
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - Tool definitions.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\skills\xaml-diagnostics\SKILL.md`
  - Skill content, including the x:Name type and codeStatus guidance.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs`
  - 14 unit tests.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Documentation\copilot-tools.md`
  - Tool docs, updated around line 79.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`
  - Results table (rows around line 59) and findings up to #101.
</important_files>

<next_steps>
1. Inspect run-final5 with the same events.jsonl parsing:
   - in `xaml_explain_property_value` results, look for an "IsEnabled is False because ancestor ..." note;
   - check `codeStatus` on each apply_hot_reload call;
   - read the task_complete feedback and fix.diff.

   If the ancestor note is still missing, investigate: is `element.Parent` null, or is the property name or source different? Then fix, rebuild, test and redeploy.
2. Add a run-final5 row to TestPass.md, and update #98 if verified.
3. Stop KeepAwake: `stop_powershell keepawake2`.
4. Call task_complete with a full summary covering:
   - tool consolidation: list inputs and `xaml_get_status`; the binding and accessibility tools stay separate;
   - platform parity: UwpTap and MauiTap, compile-checked only;
   - the assert fix;
   - feedback fixes #85–101, including codeStatus, the pane off-by-one fix and the IsEnabled ancestor walk;
   - verification:
     - build: 0 warnings, 0 errors;
     - 14 unit tests;
     - reruns: VanishingSave 4/4, StyleMaze 8/8, A11ySweep 13/13, BindingStorm 10/10, PrecedenceWars 5/5 (final2 through final5);
   - open ideas;
   - repo state: uncommitted; offer a single local commit;
   - reminders: PR 807376 for the redirect, re-enable UAC;
   - ask whether to update skills via writing-skills.
</next_steps>