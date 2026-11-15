<overview>
The goal is to test all 17 XAML Diagnostics demo apps autonomously in the Visual Studio fastmain Exp hive (`C:\vs\fastmain`, `devenv.exe /rootsuffix Exp`).

For each demo:
- Drive Copilot Chat with a realistic prompt that doesn't hint at the answer, then send a feedback follow-up.
- Save the transcript, events and diff to the notes repo.
- Grade the result against the hidden DEMO.md answer key.
- Fix the XAML agent tools and the skill, then rebuild and redeploy.

The user wants:
- Every test run and every fix logged in the notes repo (`Q:\source\XamlAgentDemos-notes`), with session logs saved there.
- Blocked states (for example a paused debugger) found and explained to the agent clearly, including how to recover.
- The follow-up questions kept improving.
- All remaining demos completed.

The user enabled Autopilot by default in VS and increased their machine's sleep time. They asked whether the harness can click "Allow" on Copilot permission prompts automatically; it now can.
</overview>

<history>
1. Earlier segments:
   - Passed: GhostClicks, LostWindows, A11ySweep, BugRepro, CrispPixels, DesignPolish A/B, GermanReady run2 (6/6).
   - PrecedenceWars run1 fixed 5/5 in source but left the debugger paused.
   - Added the DEBUGGER_PAUSED handling, the off-screen capture warning and the structural hot reload hint.
2. This segment, before the user returned:
   - `GetDebuggerState` now returns "unknown" when called off the UI thread.
   - The capture description warns when the debugger is paused.
   - Added the skill steps 5, 6 and the "Don't pause the debugger" paragraph.
   - Stopped the stuck runner (shell 617), stopped the paused debugger through DTE, reset the demo repo, built and redeployed.
   - Updated TestPass.md: GermanReady run2 row, PrecedenceWars run1 row, findings 31–34, RDP rendering harness note.
   - Rendering was down because the RDP client was minimized, so I ended with task_complete explaining the blocker.
3. The user said to keep going (sleep time increased, Autopilot is now the default, log everything, find blocked states, improve the follow-up questions).
   - Rendering was OK again.
   - Run-Demo.ps1:
     - The follow-up now asks 6 questions: helpful tools; failed or misleading calls; blocked or unexpected states and recovery; what was verified another way; live vs. source verification; the single best improvement.
     - Logs the debugger mode at the end of the run.
   - PrecedenceWars run2: 5/5. It again used a debugger sub-agent: pause, evaluate `SyncCatalog()`, set a breakpoint. The reason is that IsBusy is set in the constructor, which the UI can't re-run. This time it continued, removed the breakpoint and completed. The mode at the end was 3 (running).
4. The user reported the debugger "Allow" side-effects prompt appearing despite "Autopilot (Allow all)" and asked me to auto-click it.
   - `Approve-PendingPermission` in Harness.psm1 now finds any element with InvokePattern named "Allow this time" or "Allow" that is enabled and on-screen.
     - It invokes it, falling back to a mouse click.
     - It logs `PERMISSION '<name>' :: <prompt texts>` to the run's dialogs.log.
   - It's called on every 10 s poll (it used to run only after 60 s quiet).
   - Not yet verified on a live prompt.
5. Tool and skill fixes from run2:
   - get_element_styles hint: inactive triggers aren't listed; read the style source at `location`; a local value beats a trigger.
   - Skill step 5: get_element_styles doesn't show inactive triggers.
   - Skill step 6: for code that only runs once (constructor or Loaded), say a restart is the real check; use the debugger only if the user wants live proof.
   - Skill paused paragraph rewritten:
     - causes: user, sub-agent, breakpoint, exception;
     - recover with `debugger_continue` or ask the user to press F5;
     - remove any breakpoints you set;
     - the debugger "Allow" prompt can appear even in Autopilot.
   - DEBUGGER_PAUSED error message lists the causes (breakpoint, exception, step, debugger_pause) and says to remove breakpoints.
   - Built successfully, logged in TestPass.md (run2 row, findings 35 and 36, harness approval note) and redeployed.
6. HotReloadDoctor:
   - The pre script failed at first: `TextDocument.ReplacePattern` has an out parameter that PowerShell's COM binder can't pass. I switched to EditPoint GetText, string Replace, Delete and Insert; all 3 edits then worked.
   - run1 diagnosed 3/3 correctly in 41 s with no source changes (correct for a diagnosis task):
     - the Loaded handler overrides the title color;
     - the handler picks CompactTipTemplate;
     - Skin.xaml is loose content read once from the output folder.
   - Feedback:
     - apply_hot_reload `applied:true` with an empty log was ambiguous.
     - "Local" doesn't distinguish XAML from code.
     - The second screenshot looked "tiny": both captures were byte-identical (same sha256 assetId), so the CLI deduplicated it into a reference.
     - The model misread `hotReloadOnSave:false` as "Hot Reload on Save is disabled".
   - Fixes made (not yet built):
     - Capture hash comparison per window (`lastCaptureHashes` ConcurrentDictionary plus `IsSameAsLastCapture` with SHA256); the description notes a pixel-identical image.
     - apply_hot_reload adds `noNewActivity` and a `note` when nothing new was logged (edits likely already applied; XAML loaded by the app itself and code overrides aren't hot reloaded; check the live value).
     - The Local precedence advice explains that XAML and code both produce Local values and to search code-behind by x:Name.
   - Was investigating `hotReloadOnSave` (`XamlAgentService.cs` ~409, GetOptions). It maps to `IsHotReloadOnSaveEnabled`, which comes from the unified setting `OptionNames.ApplyOnSave` and is used by UpdateScheduler.cs:65: true means apply only on save, false (the default) means apply as you type. The plan is to clarify this (rename or add an explanatory field).
</history>

<work_done>
Repo `Q:\src\VS_xaml` (uncommitted). The edits since the last build are **NOT built yet**: capture hash, apply_hot_reload `noNewActivity`/`note`, Local advice.

**`src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`**
- Field `lastCaptureHashes` (~line 53).
- GetDebuggerState returns "unknown" off the UI thread (~187).
- DEBUGGER_PAUSED message (~219).
- GetOptions (~406).
- Local precedence advice (~896).
- get_element_styles inactive-trigger hint (~983).
- apply_hot_reload `nothingNew`, `noNewActivity` and `note` (~1683).
- Capture: paused warning, unchanged note, IsSameAsLastCapture (~1877–1909).

**`...\AgentTools\skills\xaml-diagnostics\SKILL.md`**
- "Reproduce a problem" steps 5 and 6.
- Paused-debugger paragraph (~lines 120–123).

**Earlier this segment (built and deployed):** XamlAgentImaging off-screen check, XamlAgentException DEBUGGER_PAUSED.

**Harness** (`$h`)
- Run-Demo.ps1: new follow-up text and debugger mode logging.
- Harness.psm1: Approve-PendingPermission rewritten.
- pre-HotReloadDoctor.ps1: EditPoint approach, works.

**Notes:** TestPass.md has rows through PrecedenceWars run2 and findings through #36. The HotReloadDoctor run1 row and findings are **not yet added**.

**Test runs saved** under `Q:\source\XamlAgentDemos-notes\test-runs\`: PrecedenceWars\run2, HotReloadDoctor\run1 (events.jsonl, transcript.md, fix.diff, status.txt, runner.log, vs-final.png).

**Demo status**
- [x] GermanReady
- [x] PrecedenceWars (run2 5/5)
- [x] HotReloadDoctor (3/3 diagnosis)
- [ ] PixelPerfect, ResponsiveDashboard, SlowScroll, StyleMaze, TemplateDetective
- [ ] Optionally BindingStorm, ThemeBreaker, VanishingSave reruns
</work_done>

<technical_details>
- **Build:** `cd Q:\src\VS_xaml; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diagbuild.txt`. Check for "Build succeeded" and "0 Error(s)".
- **Deploy:** `& "$h\Redeploy.ps1"` (closes VS, deploys elevated, verifies the redirect, relaunches Exp).
  - `$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`
  - The redirect `<bindingRedirect oldVersion="0.0.0.0-10.0.0.14" newVersion="10.0.0.0" />` in `C:\vs\fastmain\Common7\IDE\devenv.exe.config` stays until PR 807376 lands.
- **Run a demo:**
  ```
  $n='Q:\source\XamlAgentDemos-notes\test-runs'
  $p=(Get-Content "$h\prompts.json" -Raw|ConvertFrom-Json).$X
  Start-Process pwsh -PassThru -ArgumentList @('-NoProfile','-File',"$h\Run-Demo.ps1",'-Name',$X,'-Prompt',"`"$p`"",'-Tag','runN') -RedirectStandardOutput "$n\$X-runN.out" -RedirectStandardError "$n\$X-runN.err" -WindowStyle Hidden
  ```
  Then `.WaitForExit()` with initial_wait 600.
  - `pre-<Demo>.ps1 $appPid` runs automatically.
  - prompts.json holds all the prompts; PixelPerfect references `src\PixelPerfect\design\mockup.png`.
- **Rendering check:** `Drawing.Graphics.CopyFromScreen`. It fails ("handle is invalid") when the RDP client is minimized. LogonUI is a false lock signal under RDP.
- **Events:**
  - Read results with `tool.execution_start`/`tool.execution_complete` by toolCallId; results are in `data.result.content`, images in `binaryResultsForLlm` (assetId sha256, so identical images are deduplicated).
  - Render with `node "$h\render.js" events.jsonl transcript.md`.
- **DTE:**
  - Debugger modes: 1 = design, 2 = break, 3 = run.
  - Run DTE calls from `powershell.exe` (Windows PowerShell): `Marshal.GetActiveObject` isn't available in pwsh. The harness uses Rot.cs.
  - In pwsh, `TextDocument.ReplacePattern` fails (out parameter); use EditPoint.
- **`hotReloadOnSave` option:** true means apply only on save; false (default) means apply as you type. The model misreads it.
- **TAP property sources** only include active value sources; inactive triggers aren't reported (a TAP extension is needed — open item).
- **Debugger evaluation:** the "Allow" side-effects prompt isn't covered by Autopilot (Allow all), which may be a product follow-up.
- **WPF quirks:** reset/ClearValue removes XAML attribute values; hot reload re-applies only the XAML that changed; IsMouseOver can't be simulated.
- **File writing:** write TestPass.md as UTF-8 without BOM with `[IO.File]::WriteAllLines`. Use the edit tool for CRLF source files.
- **Git:** per user memory, never push, rebase or amend; finish with a single new local commit.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Main tool implementation; all of the changes listed above, at the line numbers given.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`
  - Agent guidance; the "Reproduce a problem" steps and the paused-debugger paragraph (~112–125).
- `...\AgentTools\XamlAgentImaging.cs`, `XamlAgentException.cs`
  - Capture helpers and error codes.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`
  - Results table, findings 1–36 and harness notes.
- Harness files in `$h`:
  - Run-Demo.ps1, Harness.psm1 (Approve-PendingPermission ~161, Wait-TurnDone ~129), Redeploy.ps1, prompts.json, pre-HotReloadDoctor.ps1, render.js.
- Answer keys: `Q:\source\XamlAgentDemos-notes\src\<Demo>\DEMO.md`.
</important_files>

<next_steps>
Immediate:
1. Clarify `hotReloadOnSave` in GetOptions (~409), for example add `hotReloadApplyMode = options.IsHotReloadOnSaveEnabled ? "onSaveOnly" : "asYouType"` or a comment field, and possibly a skill note.
2. Build. Fix any compile errors: `using SHA256` with a using declaration is C# 8+; the ConcurrentDictionary is fully qualified.
3. Redeploy.
4. Log in TestPass.md:
   - HotReloadDoctor run1 row: 3/3 diagnosis, 41 s, no source changes; the pre script now uses EditPoint.
   - Finding #37: identical captures are deduplicated, so the model thought the image was tiny; fixed with the hash note.
   - Finding #38: apply_hot_reload `applied:true` with an empty log was ambiguous; fixed with `noNewActivity`/`note`.
   - Finding #39: Local doesn't distinguish XAML from code; advice text added.
   - Finding #40: `hotReloadOnSave` was misread.
   - Harness note: the ReplacePattern quirk.

Then run the remaining demos, each followed by grading, fixes and logging:
- ResponsiveDashboard, SlowScroll, StyleMaze, TemplateDetective, PixelPerfect.
- Check dialogs.log for PERMISSION entries to confirm the auto-Allow works.
- Consider a targeted DEBUGGER_PAUSED test: pause the debugger with a pre-script, then prompt, and check that the agent recovers using `debugger_continue`.

At the end:
- Write the final summary in TestPass.md.
- Stop KeepAwake (PID 77596, if it's still running).
- Remind the user to re-enable UAC, that the redirect patch is temporary until PR 807376, and about RDP minimizing (`RemoteDesktop_SuppressWhenMinimized=2`).
- Offer a single new local commit (no push or amend).
- Ask about updating skills (writing-skills).
- If rendering drops again, finish the builds and notes, then call task_complete explaining the blocker.
</next_steps>