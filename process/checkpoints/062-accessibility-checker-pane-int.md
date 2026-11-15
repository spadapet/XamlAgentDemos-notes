<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio. These are `xaml_*` tools in Diagnostics.dll, backed by TAP messages for WPF, UwpTap (WinUI/UWP) and MauiTap, plus a built-in skill (SKILL.md). Everything is tested autonomously in the fastmain Exp hive: a harness drives the WPF demo apps through Copilot Chat, and every run is logged in the notes repo.

Autopilot is on: decide without asking, verify the work, then call task_complete.

The current request asks three questions about `xaml_run_accessibility_check`:
- Do its results include the source XAML file and line/column?
- What happens when the user cancels the check with the pane's stop button?
- What happens if a check is already running when the tool tries to start one?
</overview>

<history>
1. **Earlier segments:**
   - Planned and implemented the tools, the skill and the harness.
   - Ran all 17 demos and fixed issues from their feedback (findings #1–109).
   - Consolidated the tools: list inputs and `xaml_get_status`.
   - Brought UwpTap and MauiTap to parity with WPF.
   - Implemented: hover/unhover, the nameFilter matcher, `xaml_explain_visibility`, `xaml_audit_styles`, `#Name` addressing, the 16 KB output budget, DataContext drill-down, and binding status fields.
   - Fixed the r9 findings:
     - mixed nameFilter;
     - NormalizeVisibility;
     - the grid-cell check;
     - per-group item errors;
     - `applied` false when code hot reload fails, plus `xamlApplied`.
   - Verified in r10, logged in TestPass.md, and committed to the notes repo (5165fe4). Called task_complete.

2. **User asked:** does `xaml_run_accessibility_check` update the Accessibility Checker pane?
   - The answer was no: the tool used a private `AccessibilityIssuesViewModel`.
   - Fixed it with a new `GetAccessibilityViewModelAsync(host, showPane, ct)`:
     - loads XamlDiagnosticsPackage and calls `package.FindToolWindow(typeof(AccessibilityIssuesToolWindow), 0, create: true)`;
     - uses `window.ViewModel`, and calls `frame.ShowNoActivate()` when showPane is true;
     - falls back to the private view model on any exception except OperationCanceledException.
   - The run uses `showPane: true`. `GetAccessibilityResultsAsync` now checks only `lastAccessibilityRun` and reads entries from the shared view model (`showPane: false`).
   - Build: 0 warnings, 0 errors. Redeployed (hash matched).
   - Ran A11ySweep with tag pane-check:
     - The tool returned 8 NameNotNull issues with line numbers.
     - The pane was on screen and showed rows with File and Line. Only 5 of 8 rows were visible through UI Automation, likely because the table virtualizes rows.
   - Updated copilot-tools.md line 42.
   - Logged finding #110 and committed to the notes repo (ae77e32). Called task_complete.

3. **Current request** (the three questions above). Investigation so far, in AccessibilityIssuesViewModel.cs:
   - **Source info:**
     - After the scan, `RequestSourceInfo` posts `MapAccessibilityErrorsRequest` to the TAP.
     - The response handler sets `issue.ElementInfo.SourceInfo` and raises `SourceInfoReceived`.
     - The tool waits up to 5 s for that event. Its output has `file` (resolved through `ScanData.SourceNavigator.GetFilePath`, or else `SourceInfo.FileName`), `line` and `column`.
     - The pane-check run showed lines (52, 55, …), so source info works for WPF. Column is included in the output; whether it was nonzero wasn't checked.
   - **Cancel:**
     - The pane's CancelCommand calls `viewModel.Cancel()`, which runs `SetCancelRun(null)` and cancels the token.
     - `RunOnProcessesAsync` catches the exception and sets `LastRunError = "The accessibility check was canceled."`.
     - The tool then sets `lastAccessibilityRun = null` and throws XamlAgentException NotAvailable with that message.
     - Partial entries may remain in the pane. `Logger.Fail` is called on all exceptions, including cancellation; in a chk build that could assert (not verified).
   - **Already running:**
     - `RunOnProcessesAsync` returns immediately with `LastRunError = "An accessibility check is already running."`.
     - Problem: the tool calls `viewModel.ClearEntries()` before `RunAsync`. With the shared view model, that wipes the in-progress run's entries.
     - The tool then throws NotAvailable with that message and gives no guidance to wait or retry.
   - No code changes have been made yet for this request.
</history>

<work_done>
**Uncommitted changes in `Q:\src\VS_xaml`** (on top of about 23 earlier uncommitted files). In `XamlAgentService.cs`, the accessibility section is around lines 4039–4160:
- `RunAccessibilityCheckAsync` uses the shared view model.
- New `GetAccessibilityViewModelAsync` (around line 4087).
- `GetAccessibilityResultsAsync` reads the shared view model.

**Notes repo** is committed through ae77e32. The demo repo was reset, and KeepAwake was stopped earlier.

**Status:**
- [x] Accessibility pane sharing: implemented, built and verified live.
- [ ] Answer the three questions; probably fix the already-running and cancel handling.
</work_done>

<technical_details>
**Planned fix for the current request:**
- In RunAccessibilityCheckAsync, before ClearEntries: if `viewModel.Running`, don't clear. Instead, wait for Running to become false (PropertyChanged on `Running`, with a timeout of about 60 s), then return those results and note that the check was started by the user from the pane. Alternatively, return a clear "already running, wait" error.
- On cancel: return a clear canceled result. It should say the user stopped the check, whether partial entries are shown, and that the agent shouldn't rerun without asking.
- Consider adding `column` verification.
- Add an `AccessibilityIssuesViewModel.Running` check. `Running` is a public property (`cancelRun != null`) and raises PropertyChanged.

**AccessibilityIssuesViewModel API:**
- `Entries` (ObservableCollection<TableEntryAdapter>)
- `Running`
- `LastRunError` (null on success)
- `ClearEntries()`, `RunAsync()`, `Cancel()`
- `SourceInfoReceived` event

**AccessibilityIssuesToolWindow:**
- `RunAsync()` calls ClearEntries and then `ViewModel.RunAsync`.
- `Run()` is fire-and-forget.
- Its controller wires the Run and Cancel toolbar commands.

**Build** (from `Q:\src\VS_xaml`):
```
cd Q:\src\VS_xaml; [Environment]::CurrentDirectory='Q:\src\VS_xaml'; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diag.txt
```
- Then grep the output for errors and warnings.
- Unit project: `src\Xaml\Diagnostics\Test\Unit\Unit.csproj`.
- Run the tests with `out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\DesignTools.Tests.Unit.XamlDiagnostics.exe -class "*XamlAgentToolsTests"` (19 tests pass).

**Harness** (`$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`):
- `& "$h\Redeploy.ps1"`:
  - If quit fails with RPC_E_CALL_REJECTED, just retry.
  - Afterwards, compare the deployed DLL hash in `C:\vs\fastmain\Common7\IDE\CommonExtensions\Microsoft\XamlDiagnostics\` with the newest DLL in out\binaries\x86chk.
- `& "$h\Run-Demo.ps1" -Name X -Tag T [-NoFollowUp -KeepRunning -Prompt "..."]`
- Harness.psm1 provides Get-VsRoot (UI Automation), Stop-Demo, Reset-Demos and Save-VsScreenshot.
- The pane is found by UI Automation name 'Accessibility Checker'; its rows are DataItems.

**Quirks:**
- The edit tool often reports "closest matching lines"; always check the result.
- Write TestPass.md with `[IO.File]::WriteAllLines`.
- Never push, rebase or amend; offer a single local commit only.

**Reminders for the user:** re-enable UAC; PR 807376 fixes the System.Drawing redirect.

**Future-work list:**
- an old→new ID map after hot reload;
- multi-step `xaml_interact`;
- a sweep-views helper;
- a contrast check;
- CanExecute reporting;
- popup capture.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Implementation of all the tools.
  - The accessibility section starts at about line 4039: RunAccessibilityCheckAsync at about 4042, GetAccessibilityViewModelAsync at about 4087, and GetAccessibilityResultsAsync at about 4117 (its output includes file, line and column).
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AccessibilityChecker\ToolWindow\AccessibilityIssuesViewModel.cs`
  - Run, Cancel and Running logic (read-only so far):
    - RunAsync: about line 101
    - RequestSourceInfo: about line 115
    - RunOnProcessesAsync: about line 318; the already-running check at about 322
    - Cancel: about line 383
- `...\AccessibilityChecker\ToolWindow\AccessibilityIssuesToolWindow.cs` and `AccessibilityIssuesController.cs`
  - How the pane runs and cancels a check (controller lines 76–102).
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - Tool descriptions. xaml_run_accessibility_check is at about line 434; it may need wording about cancel and already-running.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Documentation\copilot-tools.md` (line 42) and `...\skills\xaml-diagnostics\SKILL.md`
  - Docs to update.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`
  - Test log; the next finding is #111.
</important_files>

<next_steps>
1. Answer the user:
   - **Source info:** yes. The output has file, line and column from the TAP's MapAccessibilityErrors response, waiting up to 5 s.
   - **Cancel:** currently the tool throws NotAvailable "The accessibility check was canceled.", and partial entries stay in the pane.
   - **Already running:** currently the tool clears the running check's entries, then throws "already running". That's a bug.
2. Fix RunAccessibilityCheckAsync:
   - If `viewModel.Running`, don't call ClearEntries. Wait for completion (PropertyChanged on Running, with a timeout), then return the results with a note.
   - Make the canceled result clear: the user stopped it, so don't rerun without asking.
   - Possibly update the tool description and SKILL.md.
3. Build, redeploy, and optionally run a quick live test.
4. Log finding #111 in TestPass.md and commit to the notes repo.
5. Call task_complete with the answers and a summary of the changes.
</next_steps>