<overview>
The goal is to autonomously test all 17 XAML Diagnostics demo apps in the Visual Studio fastmain Exp hive (`C:\vs\fastmain`, `devenv.exe /rootsuffix Exp`). For each demo:
- Drive Copilot Chat with a realistic prompt that gives no hints, then send feedback follow-ups.
- Save the transcript and logs to the notes repo.
- Grade the result against the hidden DEMO.md answer key.
- Fix the XAML agent tools (`Diagnostics.dll`, WpfTap) and the skill (SKILL.md), then rebuild and redeploy.

The user's standing requests:
- Log every test run and every fix in `Q:\source\XamlAgentDemos-notes\TestPass.md`.
- Find blocked or unexpected states (especially a paused debugger) and tell the agent clearly how to recover (unpause).
- Keep improving the follow-up questions.
- Complete all the testing.

Autopilot is the default in VS. The harness auto-allows permission prompts and ignores asserts.
</overview>

<history>
1. Earlier segments:
   - All 17 demos have now run at least once. Passed: GhostClicks, LostWindows, A11ySweep, BugRepro, CrispPixels, DesignPolish, GermanReady, PrecedenceWars, HotReloadDoctor, ResponsiveDashboard, SlowScroll, StyleMaze (4/5 twice), TemplateDetective.
   - Earlier runs of BindingStorm, ThemeBreaker and VanishingSave were done in prior segments.
   - Findings #1–55 were logged.

2. This segment:
   - **Skill**: added a recipe "Items use the wrong DataTemplate" (SKILL.md ~100–104, generic names).
   - **Logged TemplateDetective run1** (4/4) and finding #56 in TestPass.md.
   - **PixelPerfect run1, ~9.5/10.**
     - Every answer-key item was done; the only miss was CornerRadius 14 instead of 12.
     - The harness failed with "session dir not found": the prompt contains a backslash, which is JSON-escaped in events.jsonl.
     - Fixed `Find-SessionDirForPrompt` in Harness.psm1 to also try the escaped forms of the snippet, then resumed with -ResumeDir for the follow-ups.
     - Feedback: apply_hot_reload returned `applied:true` with `noNewActivity:true`, which was ambiguous. The model wants a mockup-diff tool.
     - Fix: when nothing is new, apply_hot_reload now returns `applied=null`, `status="noChange"`, and `lastActivity {secondsAgo, message}` from the log buffer (XamlHotReloadLogBuffer entries have Time = DateTime.Now).
     - Built and redeployed. Logged the row, findings #57–58, and a harness note.
   - **Paused-debugger test (VanishingSave tag `paused1`).**
     - A temporary `pre-VanishingSave.ps1` called `Debugger.Break` before the prompt. I deleted it afterwards.
     - Bugs found:
       - (a) **xaml_capture_image hung ~12 minutes**. PrintWindow sends WM_PRINT to the suspended UI thread.
       - (b) **xaml_apply_hot_reload reported `applied:true` while paused**. `VisualStudioXamlDiagnosticsHost.ApplyXamlChangesAsync` (~line 209) ignores requests in break mode.
       - (c) find_elements and visual_tree silently returned results from the cache.
       - (d) list_apps showed `debuggerState:"paused"` with no hint. The agent edited source while paused and didn't call debugger_continue, even though it was available.
     - I resumed the debugger manually via DTE, and the session continued.
     - After resuming, the agent:
       - called debugger_continue itself;
       - verified;
       - spawned a sub-agent that called debugger_pause and evaluate_expressions (which failed with E_FAIL), then continued;
       - tried set_element_property on `ColumnDefinitions[2].Width` (PROPERTY_NOT_FOUND).
     - It completed with 4 fixes: the CanSave binding, the compact-footer default, the status overlay, and disabled-style opacity 0.
     - The follow-up wasn't sent because `SendWait(^a)` failed. **The workstation is locked** (LogonUI is running).
   - **Fixes for the paused case** (built, 0 errors, **NOT yet deployed**):
     - A shared `ContinueDebuggerHint` constant: "Call debugger_continue now … unless the user said they paused on purpose…".
     - `GetPausedCacheWarning(endpoint)`, added as a `warning` field to get_visual_tree and find_elements results.
     - list_apps `hint` when paused.
     - The get_diagnostics_status issue uses the new hint.
     - CaptureImage (window) calls `ThrowIfDebuggerPaused(target.endpoint)` before capturing, and checks the new `XamlAgentImaging.IsWindowResponding` (SendMessageTimeout WM_NULL, SMTO_ABORTIFHUNG, 3 s) first. If that fails it throws TAP_TIMEOUT "isn't responding". The old `paused` description suffix was removed.
     - ApplyHotReloadAsync throws DEBUGGER_PAUSED ("Nothing was applied … ignores apply requests in break mode…") when paused and a debug endpoint exists.
     - The SKILL.md paused paragraph (~145) now says to check debuggerState first and call debugger_continue before anything else; don't edit and verify while paused; read exceptions first if one broke in.
</history>

<work_done>
Repo `Q:\src\VS_xaml`: all edits are uncommitted.
- `XamlAgentService.cs` changes this segment:
  - ContinueDebuggerHint and GetPausedCacheWarning (~215–228).
  - ThrowIfDebuggerPaused message (~230).
  - ListApps hint (~290).
  - diagnostics_status paused issue (~409).
  - visual_tree warning (~553), find_elements warning (~632).
  - ApplyHotReload paused throw (~1691) and noChange/lastActivity (~1720–1750).
  - CaptureImage paused and responding checks (~1956–1980).
- `XamlAgentImaging.cs`: `IsWindowResponding` (~155–164) and a SendMessageTimeout P/Invoke (~341).
- `SKILL.md`: DataTemplate recipe; paused paragraph.
- Harness: Harness.psm1 `Find-SessionDirForPrompt` matches escaped forms.

Deploy state:
- The last deploy includes the noChange apply_hot_reload change.
- The paused fixes and the DataTemplate/paused skill edits are built but **not deployed**.

TestPass.md:
- Rows through PixelPerfect run1; findings through #58.
- **VanishingSave paused1 is not yet logged.**

Save location: run artifacts are in `Q:\source\XamlAgentDemos-notes\test-runs\VanishingSave\paused1\`. Runner.log is there, and transcript/events were probably saved by Run-Demo. Session dir: `%LOCALAPPDATA%\Microsoft\VisualStudio\CopilotCli\session-state\856b19e0-19c5-4e1d-8833-8a2122b143e7`.
</work_done>

<technical_details>
- **Build:**
  ```
  cd Q:\src\VS_xaml; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diag.txt
  ```
  Check for " 0 Error(s)". WpfTap projects are `src\Xaml\Shared\Source\WpfTap\Core\WpfCoreTap.csproj` and `...\Framework\WpfTap.csproj`.
- **Deploy:** `& "$h\Redeploy.ps1"` closes VS, deploys elevated, verifies the System.Drawing redirect `0.0.0.0-10.0.0.14 → 10.0.0.0` in `C:\vs\fastmain\Common7\IDE\devenv.exe.config` (temporary until PR 807376), and relaunches Exp.
  - `$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`
- **Run a demo:**
  ```
  $a="-NoProfile -File `"$h\Run-Demo.ps1`" -Name X -Tag runN"; Start-Process pwsh -ArgumentList $a -RedirectStandardOutput ... -PassThru -WindowStyle Hidden; .WaitForExit()
  ```
  - Run with initial_wait 600.
  - Resume with `-ResumeDir <sessionDir>` (waits for the turn, then sends the follow-up).
  - Prompts come from prompts.json.
  - Pre-scripts: `$h\pre-<Name>.ps1 $appPid` runs in Run-Demo scope, so the module functions Get-Dte/Invoke-Dte/Log are available.
- **Tools:**
  - `node $h\peek.js <events.jsonl>` gives a tool timeline (it needs the file path, not the dir).
  - `$env:TEMP\pend.js` shows pending calls.
  - Import-Module `$h\Harness.psm1` and use `$dte=Get-Dte; Invoke-Dte { $dte.Debugger.Go($false) }`. Debugger modes: 1 = design, 2 = break, 3 = run.
- **Locked desktop:** SendKeys and CopyFromScreen fail ("handle is invalid") and LogonUI.exe is present. UI driving needs the user to unlock. KeepAwake is PID 77596.
- **Asserts:** Close-Asserts uses Win32 to post WM_COMMAND IDIGNORE(5) to "Assertion Failed*" windows.
- **Writing files:**
  - TestPass.md: use `[IO.File]::WriteAllLines` (UTF-8, no BOM). Insert rows after the previous demo's row; insert findings before `## Harness notes` (minus 1).
  - XamlAgentService.cs: no BOM, CRLF line endings.
- **Edit tool:** fuzzy matches sometimes replace closest lines, so verify the output.
- **Skill examples** must use generic names (to avoid cheating).
- **Git:** never push, rebase or amend; finish with a single new local commit, offered to the user.
- **Unresolved:**
  - Whether pending XAML edits auto-apply on resume. The tool message now just says to apply again after continuing.
  - set_element_property can't address `ColumnDefinitions[n].Width`; the agent needs the ColumnDefinition element ID. ColumnDefinitions aren't in the visual tree, so find_elements(name=SaveColumn) returns 0. This is a possible finding.
  - The sub-agent paused the debugger to evaluate expressions despite the skill guidance, and the evaluation failed with E_FAIL.
  - The profiler `collect_trace` failure, the XamlResourceManager assert (a product bug), and the ResponsiveDashboard minimize cause.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Main tool implementation. See the line numbers in work_done.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentImaging.cs`
  - Window capture via PrintWindow; the new IsWindowResponding.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\skills\xaml-diagnostics\SKILL.md`
  - Agent guidance: style section ~85–98, the DataTemplate recipe ~100, the paused paragraph ~145, Rules ~149+.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\VS\VisualStudioXamlDiagnosticsHost.cs:195-235`
  - ApplyXamlChangesAsync ignores requests in break mode (read only).
- `Q:\source\XamlAgentDemos-notes\TestPass.md`
  - The results table and findings #1–58.
- Harness `$h`:
  - Run-Demo.ps1, Harness.psm1 (Find-SessionDirForPrompt ~122, Close-Asserts, Wait-TurnDone), Redeploy.ps1, prompts.json, peek.js.
</important_files>

<next_steps>
1. Log VanishingSave paused1 in TestPass.md:
   - The row: 4 fixes; the run was blocked about 12 minutes by the capture hang until I resumed manually; the follow-up wasn't sent because the screen was locked.
   - Findings #59–62:
     - capture hang on a paused app (fixed);
     - apply_hot_reload false success while paused (fixed);
     - silent cache results plus no list_apps hint, and the agent didn't continue (fixed with a hint and skill change);
     - open: ColumnDefinition isn't addressable or findable, and the sub-agent paused the debugger to evaluate expressions.
2. Wait for the user to unlock, or check whether LogonUI is gone. Then run Redeploy.ps1 to deploy the paused fixes and skill edits.
3. Re-run the paused test:
   - Recreate the temporary `pre-VanishingSave.ps1` (Break) with tag `paused2`.
   - Verify that the agent calls debugger_continue first and that capture fails fast instead of hanging.
   - Then delete the pre-script.
4. Optionally rerun BindingStorm, ThemeBreaker and TemplateDetective to validate the recent fixes.
5. Wrap up:
   - Write the final summary in TestPass.md.
   - Stop KeepAwake (PID 77596).
   - Remind the user: re-enable UAC; the redirect patch is temporary until PR 807376; the RDP-minimize setting; the XAML language service assert.
   - Offer a single new local commit (no push).
   - Ask about updating skills (writing-skills).
   - Call task_complete.
</next_steps>