<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio. They are `xaml_*` tools in Diagnostics.dll, backed by TAP messages for WPF, UwpTap (WinUI/UWP) and MauiTap, plus a built-in skill (SKILL.md). Everything is tested autonomously in the fastmain Exp hive: a harness drives the WPF demo apps through Copilot Chat, and every run is logged in the notes repo (`Q:\source\XamlAgentDemos-notes`).

Autopilot is on: decide without asking, verify the work, then call task_complete.

The current request has two parts:
1. Make sure all process information (design, writing tools, debugging, building, testing, iterating) is archived in the notes repo, for a later full report.
2. Recommend the best existing demo project for a team demo: wow factor, short, and a nice visual result in both the app and the chat pane.
</overview>

<history>
1. **Earlier segments (see checkpoints):**
   - Planned and implemented the tools, the skill and the harness.
   - Ran all 17 demos and fixed findings #1–110.
   - Consolidated the tools (`xaml_get_status`, list inputs) and brought UwpTap/MauiTap to parity.
   - Added hover, the nameFilter matcher, `xaml_explain_visibility` and `xaml_audit_styles`.
   - Made the accessibility check use the Accessibility Checker pane's shared view model (#110).

2. **User asked about the accessibility checker:** does it show source file/line/column, what happens on Stop, and what happens if a check is already running?
   - **Source info:** answered yes (file, line, column). Verified live: MainWindow.xaml 52:22, and so on.
   - **Fixes:**
     - new `CANCELED` error code;
     - the tool joins an in-progress run instead of clearing it;
     - the view model has `RunCompletedTask` and an ownership-checked `finally`;
     - no `Logger.Fail` on cancel;
     - the pane's RunAsync doesn't clear entries mid-run.
   - **Docs:** updated the tool description, copilot-tools.md and SKILL.md.
   - **Tests:** added the component test `AccessibilityChecker_CancelAndConcurrentRun`. It compiles but couldn't run: the x86 .NET 10 test host fails with "Failed to create CoreCLR 0x80070057".
   - Built with 0 warnings/errors; 19 unit tests pass; redeployed.
   - **Live runs:**
     - cancel-check: the agent got CANCELED and didn't rerun.
     - rerun-after-cancel: 8 issues with columns.
     - already-running: couldn't be timed live.
   - Logged finding #111 and committed the notes repo (f08ec9e). Called task_complete.

3. **Current request** (archive the process and recommend a demo):
   - A draft answer was produced. It claimed commit `4811f79` added `process\`, containing:
     - Journal.md (9 phases);
     - checkpoints\ (62 summaries plus index.md);
     - plan.md;
     - session-transcript.md and session-events.zip;
     - harness\;
     - analysis\ (feedback.md, log-mining scripts, deploy log, redirect scripts).
   - It also said README.md now links to the journal, and recommended **VanishingSave**, with **GhostClicks** as backup and **BindingStorm** as a finale.
   - A critic flagged that the archive contents weren't evidenced; only Journal.md creation was recorded.
   - Verification so far:
     - The notes repo log shows `4811f79 Add process logs: journal, checkpoints, plan, session transcript, harness, analysis` on top of f08ec9e.
     - The working tree is clean, and a `process` directory exists at the repo root.
     - The listing of `process\` contents hadn't been printed yet when compaction happened (the Test-Path branch output wasn't shown).
</history>

<work_done>
**Notes repo** (`Q:\source\XamlAgentDemos-notes`):
- HEAD is 4811f79; the tree is clean.
- Top level: design-source, process, src, test-runs, README.md, Render-Mockup.ps1, TestPass.md, XamlDiagnosticsToolsSession.md.
- **The contents of `process\` still need verifying** (`Get-ChildItem process -Recurse`, `git show --stat 4811f79`).

**VS repo** (`Q:\src\VS_xaml`), uncommitted. Changes this segment, on top of about 23 earlier files:
- XamlAgentException.cs: added `Canceled = "CANCELED"`.
- XamlAgentService.cs:
  - RunAccessibilityCheckAsync now joins a running check, registers cancellation, and throws CANCELED.
  - Added the `lastAccessibilityRunJoined` field.
  - The results now include `note` and `running`.
- AccessibilityIssuesViewModel.cs:
  - `runCompleted` TCS and the `RunCompletedTask` property;
  - an already-running call no longer clobbers LastRunError;
  - local CTS ownership in `finally`;
  - ThrowIfCancellationRequested after the scan loop;
  - no `Logger.Fail` on cancel.
- AccessibilityIssuesToolWindow.cs: RunAsync skips if a run is in progress.
- XamlDiagnosticsFunctionProvider.cs: run-check description.
- copilot-tools.md line 42 and SKILL.md "Fix accessibility issues" step 1.
- Test\Component\AccessibilityChecker\AccessibilityCheckerTests.cs: new test.

**Harness additions:** Watch-A11yStop.ps1 and Watch-A11yRun.ps1 in the session `files\harness`.
</work_done>

<technical_details>
**Build** (from `Q:\src\VS_xaml`):
```
cd Q:\src\VS_xaml; [Environment]::CurrentDirectory='Q:\src\VS_xaml'; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diag.txt
```
- Unit tests: `out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\DesignTools.Tests.Unit.XamlDiagnostics.exe -class "*XamlAgentToolsTests"` (19 pass).
- Component tests (net10 x86) fail to host locally with CoreCLR 0x80070057, both via the exe and via vstest. The TPA list contains System.Private.CoreLib twice; the cause is unresolved. DTLTest.bat `component_vdiag` is the canonical runner.

**Harness** (`$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`):
- Redeploy.ps1: compare the deployed DLL hash with out\binaries\x86chk.
- `Run-Demo.ps1 -Name X -Tag T [-NoFollowUp -KeepRunning -Prompt -FollowUps]`.
- Results go to `test-runs\<Name>\<Tag>` (transcript.md, events.jsonl, runner.log, fix.diff and so on).

**Notes and git rules:**
- Write TestPass.md with `[IO.File]::WriteAllLines`.
- Never push, rebase or amend; use a single local commit.
- The edit tool often reports "closest matching lines"; always check the result.

**Demo facts** (from TestPass runs):
- VanishingSave: 2–2.5 min, 0 failed calls, 4 stacked causes. Uses explain_visibility, hit-test and screenshots.
- GhostClicks: about 1.2–1.5 min, an invisible-overlay hit-test.
- BindingStorm: 10/10 failures fixed, up to 11 images, 2.6–5 min.

**Reminders for the user:** re-enable UAC; PR 807376 fixes the System.Drawing.Common redirect (the Exp devenv.exe.config is patched manually to 10.0.0.0).
</technical_details>

<important_files>
- `Q:\source\XamlAgentDemos-notes\process\`: the archive claimed in commit 4811f79 (Journal.md, checkpoints, plan.md, session-transcript.md, session-events.zip, harness, analysis). Contents not yet verified.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`: the run table and findings #1–111 (#111 is at about line 190).
- `Q:\source\XamlAgentDemos-notes\README.md`: should link to process\Journal.md.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`: accessibility section at about lines 4040–4200.
- `...\AccessibilityChecker\ToolWindow\AccessibilityIssuesViewModel.cs`: run, cancel and RunCompletedTask logic.
- Session folder `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\`: checkpoints\ (index.md), plan.md, files\harness. These are the source material for the archive.
</important_files>

<next_steps>
1. Verify the archive:
   - Run `Get-ChildItem Q:\source\XamlAgentDemos-notes\process -Recurse` and `git -C Q:\source\XamlAgentDemos-notes show --stat 4811f79`.
   - If anything is missing, copy it from the session folder: checkpoints\*.md and index.md, plan.md, harness\*, the session events.jsonl rendered to a transcript (zip the raw events), and analysis/feedback files.
   - Make sure Journal.md links to the copied files and README links to Journal.md.
   - Also include this segment's findings (#110, #111 and the component-test hosting issue) in the journal.
   - Scan for secrets, then make a single new local commit (no push).
2. Report accurately what is in `process\`, citing the verified file listing and the commit hash.
3. Give the demo recommendation:
   - VanishingSave as the winner, with its prompt "Where's my Save button? It should be in the footer.", 2–2.5 min, 4 stacked causes, before/after screenshots in chat;
   - GhostClicks as the fast backup;
   - BindingStorm as the longer finale.
   - Add the reminders (UAC; PR 807376).
4. Call task_complete with that answer.
</next_steps>