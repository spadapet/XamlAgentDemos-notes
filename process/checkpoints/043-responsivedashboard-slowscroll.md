<overview>
The goal is to autonomously test all 17 XAML Diagnostics demo apps in the Visual Studio fastmain Exp hive (`C:\vs\fastmain`, `devenv.exe /rootsuffix Exp`). For each demo:
- Drive Copilot Chat with a realistic prompt that gives no hints, then send feedback follow-ups.
- Save the transcript, events and diff to the notes repo.
- Grade the result against the hidden DEMO.md answer key.
- Fix the XAML agent tools (`Diagnostics.dll`) and the skill (SKILL.md), then rebuild and redeploy.

The user's standing requests:
- Log every test run and every fix in `Q:\source\XamlAgentDemos-notes\TestPass.md`.
- Find blocked or unexpected states (for example a paused debugger, a minimized window) and explain them clearly to the agent, including how to recover.
- Keep improving the follow-up questions.
- Complete all the remaining demos.

Autopilot is the default in VS. The harness auto-clicks "Allow" permission prompts.
</overview>

<history>
1. Earlier segments:
   - Passed: GhostClicks, LostWindows, A11ySweep, BugRepro, CrispPixels, DesignPolish A/B, GermanReady, PrecedenceWars (run2 5/5), HotReloadDoctor (run1 3/3 diagnosis).
   - Fixes from those runs:
     - DEBUGGER_PAUSED handling.
     - Capture warnings: paused debugger, off-screen window, pixel-identical to the previous capture (SHA256 per window).
     - apply_hot_reload returns `noNewActivity` and a `note`.
     - Local-precedence advice text.
     - get_element_styles hint that inactive triggers aren't listed.
     - Skill steps 5 and 6, and the "Don't pause the debugger" paragraph.
     - Harness: Approve-PendingPermission.

2. This segment:
   - **hotReloadOnSave:** added `applyMode` to GetOptions. Values are `disabled`, `onSaveOnly…` and `asYouType…`. Built, deployed, and logged the HotReloadDoctor run1 row plus findings 37–40.
   - **ResponsiveDashboard run1:** aborted because SendKeys failed. The RDP session stopped rendering (CopyFromScreen "handle is invalid", no foreground window). I polled; rendering came back after ~810 s. Logged as a harness abort.
   - **ResponsiveDashboard run2:**
     - Fixed 5/5 layout areas.
     - It treated "px" as physical pixels (853/683/533 DIPs at 150% scaling) and said so.
     - At the end the window was **minimized**; the cause is unknown and nothing was in dialogs.log. The capture returned a 91×28 image with a misleading off-screen warning, and the model finished anyway.
     - The harness follow-up failed: Ctrl+A was typed as a literal character. I resent the follow-up with `-ResumeDir` plus a targeted question; the model admitted the oversight.
     - Fixes:
       - New error code `WINDOW_MINIMIZED`: capture now throws it with recovery steps.
       - The capture description says the image is the client area.
       - list_windows returns a `note` on units (bounds are physical pixels including the frame; Width = bounds.width / dpiScale; −32000 means minimized).
       - Skill step 7: window sizing, units, and restoring the window.
       - Harness: Send-ChatPrompt retries 4 times.
     - Built, deployed, and logged findings 41–43.
   - **SlowScroll run1:**
     - Fixed 3/3 causes. First render went from 12.6 s to 0.7 s; realized items from 3000 to 45.
     - But it combined all the fixes into one edit, although the user asked for the improvement after each change.
     - It also built a copy into `bin\Verification` and launched extra app instances to measure startup.
     - CPU profiling (`collect_trace_from_app`) failed with "Cannot find session for document"; that's the profiler team's tool.
     - A targeted follow-up got the model to admit both deviations.
     - Fixes:
       - New skill section "Slow lists, scrolling or startup": count realized containers, check bounds for infinite height, the 4 virtualization killers, one change at a time, and restart the debug session for startup.
       - find_elements: `totalMatches` keeps counting past maxResults, and a `hint` explains a zero-result type search (it matches a substring of the element's own class, not base classes).
       - The tool description mentions `totalMatches`.
       - Harness follow-up question 7: "did you meet every explicit requirement?"
     - Built, deployed, and logged findings 44–46.
     - I deleted the `bin\Verification` folder.
   - **SlowScroll run2** (to validate the new guidance): **finished. I was analyzing it when the context was compacted.** What it showed:
     - It did one change at a time, measuring after each: CanContentScroll left 3000 realized items, grouping left 3000, the bounded viewport gave 45. `totalMatches` worked.
     - It restarted the debug session itself with `debugger_launch`; first render was 1,077 ms. Before that it asked `ask_question` (the user wasn't available).
     - It checked realized items again after the restart.
     - 6 failed calls:
       - `xaml_explain_property_value` returned PROPERTY_NOT_FOUND for unset attached properties (VirtualizingPanel.IsVirtualizingWhenGrouping/ScrollUnit), twice.
       - One TAP_TIMEOUT right after a hot reload.
       - collect_trace_from_app failed (profiler).
       - get_output_window_logs failed with a wrong paneId.
     - Feedback point 2: `xaml_interact setValue` on a ScrollBar reported the *old* value ("Value is now 0" after setting 30000). It reads the value back before the change takes effect.
     - It added `VirtualizingPanel.ScrollUnit="Pixel"`.
</history>

<work_done>
Repo `Q:\src\VS_xaml`: all edits are uncommitted, **built and deployed** (the latest deploy includes the SlowScroll fixes).

`src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`:
- GetOptions (~406): `applyMode` added.
- FindElementsAsync (~542–608): `totalMatches`; keeps counting past truncation; zero-result type `hint`. The file is UTF-8 **without BOM**, matching HEAD.
- ListWindowsAsync (~1814): returns a `note` with the units explanation.
- CaptureImageAsync (~1887): throws `WINDOW_MINIMIZED`; the description mentions the client area.
- Earlier changes: lastCaptureHashes, IsSameAsLastCapture, apply_hot_reload `noNewActivity`/`note`, Local advice, get_element_styles hint, GetDebuggerState returns "unknown" off the UI thread, DEBUGGER_PAUSED message.

Other repo files:
- `XamlAgentException.cs`: `WindowMinimized = "WINDOW_MINIMIZED"`.
- `XamlDiagnosticsFunctionProvider.cs:88`: find_elements description mentions `totalMatches`.
- `skills\xaml-diagnostics\SKILL.md`:
  - new "### Slow lists, scrolling or startup" section (~112–118);
  - "Reproduce a problem" step 7 (window sizing, units, restoring);
  - earlier steps 5 and 6 and the paused-debugger paragraph.

Harness (`$h`):
- Run-Demo.ps1: follow-up question 7 added.
- Harness.psm1: Send-ChatPrompt retry loop (~63–71).

TestPass.md has rows through SlowScroll run1 and findings through #46. **The SlowScroll run2 row isn't logged yet.**

Demo status:
- [x] ResponsiveDashboard (run2)
- [x] SlowScroll (run1; run2 not yet graded or logged)
- [ ] StyleMaze
- [ ] TemplateDetective
- [ ] PixelPerfect
- [ ] Optional reruns: BindingStorm, ThemeBreaker, VanishingSave
</work_done>

<technical_details>
- **Build:**
  ```
  cd Q:\src\VS_xaml; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diagbuild.txt
  ```
  Then check the file for "0 Error(s)".
- **Deploy:** `& "$h\Redeploy.ps1"` closes VS, deploys elevated, verifies the redirect and relaunches Exp.
  - `$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`
  - The redirect `0.0.0.0-10.0.0.14 → 10.0.0.0` in `C:\vs\fastmain\Common7\IDE\devenv.exe.config` stays until PR 807376 lands.
- **Run a demo:** use `Start-Process pwsh` with `$h\Run-Demo.ps1 -Name $X -Prompt "<from prompts.json>" -Tag runN`, redirecting output to `$n\$X-runN.out/.err`, then `.WaitForExit()` with initial_wait 600.
  - Resume an existing chat session: `-ResumeDir <sessionDir> -FollowUps "<q>"`, optionally with `-NoFollowUp`. Resuming doesn't reset the repo, and it overwrites transcript.md, events.jsonl and fix.diff with the current state.
  - Session dirs: `%LOCALAPPDATA%\Microsoft\VisualStudio\CopilotCli\session-state\<id>`.
- **Analysis:** pair `tool.execution_start` and `tool.execution_complete` by toolCallId. Results are in `data.result.content`, errors in `data.error`. Render with render.js.
- **Rendering check:** `Drawing.Graphics.CopyFromScreen` throws "handle is invalid" when RDP is minimized or the session is locked; SendKeys then fails and the foreground window is 0. Poll until it recovers.
- **Writing files:** TestPass.md with `[IO.File]::WriteAllLines` (UTF-8, no BOM). Keep XamlAgentService.cs without a BOM and with CRLF line endings.
- **Tool behavior:**
  - find_elements `type` is a case-insensitive substring of the element's own class name; base classes don't match.
  - explain_property_value returns PROPERTY_NOT_FOUND for attached properties that have no value. The hint says so, but the model still tries — it could return the default value instead.
  - xaml_interact setValue on a RangeValue reports the stale previous value.
- **Debugger modes:** 1 = design, 2 = break, 3 = run. Use DTE from powershell.exe.
- **Git:** never push, rebase or amend; finish with a single new local commit, offered to the user.
- **Unresolved:**
  - Why the ResponsiveDashboard window got minimized.
  - The profiler tool `collect_trace_from_app` fails ("Cannot find session") — another team's issue.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - The main tool implementation; see the line numbers above.
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - Tool descriptions and parameters (find_elements at ~87).
- `...\AgentTools\XamlAgentException.cs`
  - Error codes.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`
  - Agent guidance: recipes at ~49–125, the Slow lists section at ~112, the paused-debugger paragraph.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`
  - Results table and findings 1–46.
- `Q:\source\XamlAgentDemos-notes\test-runs\<Demo>\<runN>\`
  - Saved runs (events.jsonl, transcript.md, fix.diff, runner.log, dialogs.log).
- `Q:\source\XamlAgentDemos-notes\src\<Demo>\DEMO.md`
  - Answer keys.
- Harness: `$h\Run-Demo.ps1`, `Harness.psm1`, `Redeploy.ps1`, `prompts.json`, `render.js`.
</important_files>

<next_steps>
Immediate:
1. Finish grading SlowScroll run2 by reading the follow-up answers in its transcript.md, including question 7. Log the run2 row: it validated the one-change-at-a-time and debug-restart guidance.
2. Possible fixes:
   - `xaml_interact setValue` should report the new value: wait a moment or re-read after the dispatcher runs.
   - `explain_property_value` on an unset attached property should return the default value (source Default) instead of PROPERTY_NOT_FOUND.
   - Maybe a skill note: hot reload can briefly cause a TAP_TIMEOUT; retry.
3. Build, redeploy, and log the findings (#47 and up).

Then run the remaining demos, each followed by grading, follow-ups, fixes and logging:
- StyleMaze, TemplateDetective, PixelPerfect (its prompt references `src\PixelPerfect\design\mockup.png`).
- Optionally rerun BindingStorm, ThemeBreaker, VanishingSave.
- Consider a targeted DEBUGGER_PAUSED test via a pre-script.

At the end:
- Write the final summary in TestPass.md.
- Stop KeepAwake (PID 77596).
- Remind the user to re-enable UAC, that the redirect patch is temporary until PR 807376, and about RDP minimizing (`RemoteDesktop_SuppressWhenMinimized=2`).
- Offer a single new local commit (no push or amend).
- Ask about updating skills (writing-skills).
- If rendering drops: poll for up to ~15 min; if it doesn't come back, finish the notes and call task_complete explaining the blocker.
</next_steps>