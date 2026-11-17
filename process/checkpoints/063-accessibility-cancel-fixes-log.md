<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` tools in Diagnostics.dll, backed by TAP messages for WPF, UwpTap (WinUI/UWP) and MauiTap;
- a built-in skill (SKILL.md).

The tools are tested autonomously in the fastmain Exp hive. A harness drives the WPF demo apps (in `Q:\source\XamlAgentDemos`) through Copilot Chat, and every run is logged in the notes repo `Q:\source\XamlAgentDemos-notes`. Autopilot is on: decide without asking, verify the work, then call task_complete.

The current request has two parts:
1. Make sure all useful information about the process (design, writing tools, building, debugging, testing, iterating) is saved in the notes repo. The user will later ask for a full report from the beginning.
2. Recommend which demo project is the clear winner for a team demo. It needs "wow" factor (something that's impossible or very hard without the tools), it shouldn't take long, and it should give a nice visual result in both the app and the chat pane.
</overview>

<history>
1. **Earlier segments** (details in session checkpoints 001–062):
   - Planned and implemented the tools, the skill, the TAP messages for all platforms, and the demo apps.
   - Built the harness, ran all 17 demos, and iterated on their feedback (findings #1–110).
   - Consolidated the tools: list inputs and `xaml_get_status`.
   - Added: hover, the nameFilter matcher, `xaml_explain_visibility`, `xaml_audit_styles`, and integration with the Accessibility Checker pane.

2. **User asked** about the accessibility check: does it show source file and line/column, what happens on Stop/cancel, and what happens if a check is already running.
   - **Source info:** yes. Output has file, line and column (verified live, e.g. MainWindow.xaml 52:22).
   - **Fixes:**
     - New `CANCELED` error code, with a hint to ask the user before rerunning.
     - The tool joins a check that's already running (waits up to 2 min and adds a `note` to the results) instead of clearing it.
     - Chat cancellation cancels only a scan the tool started.
     - View model: added `RunCompletedTask`; the `finally` checks it still owns the run; an "already running" call no longer overwrites `LastRunError`; a scan that finishes after Stop is still reported as canceled; no `Logger.Fail` on cancel.
     - The pane's RunAsync no longer clears entries mid-run.
     - Added component test `AccessibilityChecker_CancelAndConcurrentRun`. It compiles but couldn't run locally: the x86 .NET 10 testhost fails with "Failed to create CoreCLR 0x80070057". TPA had System.Private.CoreLib twice; unresolved.
   - Build: 0 warnings, 0 errors; 19 unit tests pass; redeployed and hashes matched.
   - Live runs logged:
     - `cancel-check`: the agent got CANCELED and didn't rerun.
     - `rerun-after-cancel`: 8 issues, each with file, line and column.
     - `already-running`: couldn't be timed, because the agent called the check in parallel with get_status and the scan takes about 1 s.
   - Finding #111 logged in TestPass.md; notes commit f08ec9e. Called task_complete.

3. **Current request** (logging plus demo pick). Started an inventory:
   - **Notes repo has:**
     - `README.md`, `TestPass.md` (60 KB; findings and run table)
     - `XamlDiagnosticsToolsSession.md` (3.2 MB; an earlier session log export)
     - `design-source/`, `src/`, `Render-Mockup.ps1`
     - `test-runs/<Demo>/<tag>/` for all 17 demos (runner.log, transcript.md, events.jsonl, fix.diff, status.txt, vs-final.png)
   - **Session folder has, but the notes repo doesn't yet:**
     - checkpoints 001–062 plus index.md (a detailed history of design and implementation)
     - plan.md
     - `files/`:
       - harness scripts: Harness.psm1, Run-Demo.ps1, Run-Batch.ps1, Redeploy.ps1, KeepAwake.ps1, Watch-A11yStop.ps1, Watch-A11yRun.ps1, prompts.json, render.js, summarize scripts, pre-*.ps1
       - feedback.md (53 KB), calls.jsonl (5.7 MB)
       - analysis js scripts
       - deploy.log, Patch-DrawingRedirect.ps1, Restore-DevenvConfig.ps1, demo-baseline.xml
       - XamlAgentDemos-original.git
</history>

<work_done>
Uncommitted code in `Q:\src\VS_xaml` (on top of about 23 earlier uncommitted feature files):
- `XamlAgentService.cs`:
  - `RunAccessibilityCheckAsync` rewritten (around lines 4042–4123).
  - Added field `lastAccessibilityRunJoined`.
  - Results now include `note` and `running`.
- `XamlAgentException.cs`: added `Canceled = "CANCELED"`.
- `AccessibilityIssuesViewModel.cs`: added `runCompleted` and `RunCompletedTask`; reworked RunOnProcessesAsync's catch and finally blocks.
- `AccessibilityIssuesToolWindow.cs`: RunAsync skips the run if one is already in progress.
- `XamlDiagnosticsFunctionProvider.cs` (around line 435): updated the tool description.
- `copilot-tools.md` (line 42) and `SKILL.md` (line 128): docs updated.
- `Test\Component\AccessibilityChecker\AccessibilityCheckerTests.cs`: new test added.

Notes repo is committed through f08ec9e. The demo repo is clean.

Current task status:
- [ ] Copy the process logs into the notes repo:
  - checkpoints and index
  - plan.md
  - the harness scripts
  - feedback.md, calls.jsonl (maybe), analysis scripts, deploy and redirect scripts
  - possibly a chronological "Process/Journal.md" summarizing design → implementation → deploy → harness → test iterations → findings
  - Then commit.
- [ ] Recommend a demo app.
</work_done>

<technical_details>
**Build:**
```
cd Q:\src\VS_xaml; [Environment]::CurrentDirectory='Q:\src\VS_xaml'; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diag.txt
```
- The output DLL is in `out\binaries\x86chk\bin\netsdk\Xaml\Diagnostics\net472\`.

**Unit tests:**
```
out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\DesignTools.Tests.Unit.XamlDiagnostics.exe -class "*XamlAgentToolsTests"
```
- 19 tests pass.
- Component tests (net10 x86) don't start locally because of the CoreCLR error.
- The canonical runner is `src\Xaml\Designer\Tools\DTLTest.bat component_vdiag`.

**Harness** is at `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`:
- `Redeploy.ps1`: after it runs, check that the deployed DLL hash matches the build output.
- `Run-Demo.ps1 -Name X -Tag T [-NoFollowUp -KeepRunning -Prompt -FollowUps]`.
- Copilot session logs are in `%LOCALAPPDATA%\Microsoft\VisualStudio\CopilotCli\session-state`.

**Exp devenv.exe.config:** System.Drawing.Common needs a manual redirect to 10.0.0.0; PR 807376 is the real fix.

**Quirks and rules:**
- The edit tool often reports "closest matching lines"; always check the result (it once dropped a test header).
- Write TestPass.md with `[IO.File]::WriteAllLines`.
- Never push, rebase or amend. Offer only a single local commit for VS repo changes. The notes repo gets regular commits.

**Demo candidates** (for the recommendation; check them against transcripts and TestPass.md):
- **BindingStorm** (r9: 10/10 binding failures fixed across 4 tabs plus a dialog, 8 images; visual and wow, but long).
- **GhostClicks** (hit-test reveals an invisible overlay blocking clicks; hard without tools).
- **VanishingSave** (explain_visibility finds a Save button collapsed by a binding converter).
- **A11ySweep** (fast; about 1 min; issues have file and line, and the pane updates).
- **ThemeBreaker**, **DesignPolish**, **PixelPerfect**, **CrispPixels** (visual).
- **PrecedenceWars** (value precedence).
- **StyleMaze** (style audit).
- **HotReloadDoctor**, **LostWindows** (off-screen window), **TemplateDetective**, **ResponsiveDashboard**, **SlowScroll**, **GermanReady**, **BugRepro**.

Pick using runtime (runner.log timestamps), visual before/after (vs-final.png, captures) and how unique the tools are. Likely candidates are GhostClicks or VanishingSave (short, runtime-only root cause, clear visual fix) or BindingStorm (most impressive but longer). Verify durations before recommending.

**Reminders for the user:** re-enable UAC; PR 807376.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`: implementation of all the tools. The accessibility section starts around line 4040.
- `...\AccessibilityChecker\ToolWindow\AccessibilityIssuesViewModel.cs`: run, cancel and ownership logic (around lines 45–85 and 320–406).
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`: tool descriptions.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md` and `src\Xaml\Diagnostics\Documentation\copilot-tools.md`: docs.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`: run table (around line 72) and findings #1–111 (#111 at about line 190). The next finding is #112.
- `Q:\source\XamlAgentDemos-notes\test-runs\*`: per-run artifacts.
- Session folder `checkpoints\001–062` plus `index.md`, `plan.md`, and `files\` (harness, feedback.md): the source for the process logs that need copying into the notes repo.
</important_files>

<next_steps>
1. Copy the process artifacts into the notes repo:
   - `process/checkpoints/` (all of 001–062 plus index.md)
   - `process/plan.md`
   - `harness/` (all scripts, including the Watch-A11y* scripts)
   - `analysis/` (feedback.md, the js analysis scripts, deploy.log, Patch-DrawingRedirect.ps1, Restore-DevenvConfig.ps1)
   - Consider calls.jsonl (5.7 MB) too.
2. Add `process/Journal.md`, a chronological overview covering:
   - phases: research, plan, implementation of each platform TAP, function provider and skill, deployment issues (missing tools in CLI sessions, threading, System.Drawing redirect), demo apps, the harness, test passes, consolidation, feedback fixes, accessibility pane;
   - key commands (build, test, redeploy, harness);
   - lessons learned.
   Point it to the checkpoints, TestPass.md and test-runs. Also update README.md to index these.
3. Commit the notes repo (no push).
4. Evaluate the demo candidates (runtime from runner.log, outcomes in TestPass.md, visuals), then recommend one, with a backup and a suggested prompt.
5. Call task_complete with the summary and the recommendation.
</next_steps>