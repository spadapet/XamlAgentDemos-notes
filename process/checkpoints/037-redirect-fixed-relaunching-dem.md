<overview>
The goal is to autonomously test all 17 XAML Diagnostics demo apps in Visual Studio's **fastmain Exp hive** (`C:\vs\fastmain`, `/rootsuffix Exp` — only Exp has the new Copilot code). For each demo: drive Copilot Chat with a realistic prompt, ask a feedback follow-up, save the transcript and diff, grade it against the hidden DEMO.md answer key, and improve the XAML tools or skill when testing shows problems. The user filed PR 807376 to fix the System.Drawing.Common redirect bug for real. Until it lands, I must **manually keep the generated `devenv.exe.config` for fastmain redirecting System.Drawing.Common to 10.0.0.0**, then continue the scenario tests.
</overview>

<history>
1. Earlier work (from prior checkpoints): built and deployed the TAP and Diagnostics changes to fastmain. GhostClicks and LostWindows run2 succeeded, with findings 10–17 in TestPass.md. A11ySweep run1 hit an Axe.Windows assertion: System.Drawing.Common failed to load because of a version mismatch, and the exception was swallowed and reported as `ran=true,count=0` (invalid). BugRepro and CrispPixels harness runs failed before prompting because chat UI was unavailable.

2. Testing the binding-redirect hypothesis (with VS closed):
   - Direct edit of the config was denied (EACCES), so I created an elevated patch script, `files\Patch-DrawingRedirect.ps1`.
   - The first literal-replace version failed: `Replace()` matched many unrelated 10.0.0.14 redirects.
   - The `$1`+`10.0.0.0` regex replacement became `$110...` and corrupted the entry (the System.Drawing.Common block disappeared). I restored it from the backup via `files\Restore-DevenvConfig.ps1`; the hash was verified identical.
   - Switching to a MatchEvaluator scoped to the System.Drawing.Common dependentAssembly worked. Verified: `<bindingRedirect oldVersion="0.0.0.0-10.0.0.14" newVersion="10.0.0.0" />`, exactly one entry.
   - Relaunched `C:\vs\fastmain\Common7\IDE\devenv.exe /rootsuffix Exp Q:\source\XamlAgentDemos\XamlAgentDemos.sln` (PID 28496 at the time). DTE connection verified: Experimental Instance, solution loaded, mode=1.
   - Started the A11ySweep run2 harness (async). It failed with "You cannot call a method on a null-valued expression" right after the app started (pid 31896), before prompting. This is likely `New-ChatThread` failing because `createNewThread` was not found.

3. The user said PR 807376 fixes the redirect. Keep patching the Exp config manually to 10.0.0.0 and continue the scenario tests.
   - Checked: the config still has the 10.0.0.0 redirect.
   - **However, `Get-Process devenv` found no devenv process**: the fastmain VS appears to have exited or crashed. It must be relaunched.
</history>

<work_done>
Files created (session folder `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\`):
- `Patch-DrawingRedirect.ps1`: an elevated, encoding-preserving regex patch with a MatchEvaluator. It changes only the System.Drawing.Common redirect from 10.0.0.14 to 10.0.0.0 and throws if that redirect isn't found exactly once. Run it with `Start-Process pwsh -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile','-File',$script)`.
- `Restore-DevenvConfig.ps1`: elevated restore from `devenv.exe.config.before-a11y-test`.

Modified:
- `C:\vs\fastmain\Common7\IDE\devenv.exe.config`: the System.Drawing.Common redirect now targets 10.0.0.0 (verified). This is a temporary local workaround per the user.

State:
- [x] Redirect patched and verified.
- [ ] VS fastmain Exp is NOT running (devenv process gone, cause unknown; possibly crashed during A11ySweep run2 start).
- [ ] A11ySweep run2 not completed (`Q:\source\XamlAgentDemos-notes\test-runs\A11ySweep\run2\runner.log` shows the failure).
- [ ] BugRepro, CrispPixels, DesignPolish, GermanReady, HotReloadDoctor, PixelPerfect, PrecedenceWars, ResponsiveDashboard, SlowScroll, StyleMaze, TemplateDetective (and others in the 17) remain.
- [ ] Product fix: surface accessibility-checker exceptions instead of returning a false empty success (not started).
</work_done>

<technical_details>
- **Redirect issue**: Axe.Windows 2.4.2 references System.Drawing.Common 8.0.x. The VS config redirected to assembly version 10.0.0.14, but the installed `PublicAssemblies\System.Drawing.Common.dll` has assembly identity 10.0.0.0 (file version 10.0.1426.52326), so the load failed. Redirecting to 10.0.0.0 is the workaround; PR 807376 is the real fix. `/updateconfiguration` or an install update may regenerate the config, so re-check and re-run the patch script after any such event.
- PowerShell regex replacement gotcha: `'$110.0.0.0$2'` is interpreted as group 110. Use a MatchEvaluator or `${1}`.
- The config file needs elevation to write (UAC prompt is disabled by the user, so `-Verb RunAs` works silently).
- Harness (`files\harness\`): `Run-Demo.ps1 -Name X -Prompt '...' -Tag runN [-KeepRunning] [-NoFollowUp] [-ResumeDir]`.
  - It does Stop-Demo, reset of the demo repo, Start-Demo via DTE (`Rot` `!VisualStudio.DTE.18.0:<pid>`), `New-ChatThread` (invokes AutomationId `createNewThread`), `Set-Autopilot` (`ConversationModeSelector`), and `Send-ChatPrompt` (UIA "Ask Copilot" plus clipboard paste, then `SendButton`).
  - It waits on `%LOCALAPPDATA%\Microsoft\VisualStudio\CopilotCli\session-state\<id>\events.jsonl`, sends a follow-up, renders `transcript.md` via `render.js`, and saves `fix.diff`, `status.txt`, and `vs-final.png`.
  - `Get-VsPid` matches devenv with a path under `C:\vs\fastmain\*`.
- The null-valued failure arises when chat UI elements are missing: the Chat pane is not open, or it shows the Sessions list. Make `New-ChatThread` and related calls null-safe and open the Copilot Chat window first if needed. Previously, clicking "Create new session" fixed it.
- `AccessibilityIssuesViewModel.RunOnProcessesAsync` catches exceptions, calls `Logger.Fail` (Debug.Fail → modal assert), and returns empty. `XamlAgentService.RunAccessibilityCheckAsync` then reports `ran=true` with 0 issues, which is misleading. This should be fixed to return an error.
- The keep-awake script `files\harness\KeepAwake.ps1` was running as pwsh PID 77596 (mouse nudge, F15, execution state). Verify it's still alive.
- Per user memory: never push to origin, rebase or amend; add work as a single new commit for review.
- Before any VS build: load the `building-locally` skill and run `src\Shared\Tools\Scripts\Prime-ForCopilot.ps1` in the same process.
- DEMO.md answer keys are at `Q:\source\XamlAgentDemos-notes\src\<Demo>\DEMO.md` (hidden from the demo repo so the agent can't cheat).
</technical_details>

<important_files>
- `C:\vs\fastmain\Common7\IDE\devenv.exe.config`: line ~1041-1042, System.Drawing.Common redirect, now 10.0.0.0. Re-verify before each VS launch.
- `...\files\Patch-DrawingRedirect.ps1` / `Restore-DevenvConfig.ps1` / `devenv.exe.config.before-a11y-test`: the patch and rollback tooling.
- `...\files\harness\Harness.psm1`, `Run-Demo.ps1`, `Run-Batch.ps1`, `KeepAwake.ps1`, `render.js`: the test harness. `New-ChatThread` needs null-safety and opening the chat pane.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`: per-demo results and findings 1–17. Continue adding to it.
- `Q:\source\XamlAgentDemos-notes\test-runs\<Demo>\runN\`: run artifacts. A11ySweep run1 is invalid; run2 failed before prompting.
- `Q:\source\XamlAgentDemos-notes\src\A11ySweep\DEMO.md`: answer key. Expected fixes: icon button names, CoverArt image, SubscribeChip Border→Button, SearchBox LabeledBy, VolumeSlider name, low-contrast colors #C4C4C4/#BDBDBD/#C8C8C8, Episode list item name.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AccessibilityChecker\ToolWindow\AccessibilityIssuesViewModel.cs` (~lines 320–380) and `...\AgentTools\XamlAgentService.cs` (~1838–1905): the false-success a11y path to fix.
</important_files>

<next_steps>
Immediate:
1. Check why fastmain devenv exited (look for a crash or Watson; check ActivityLog in the Exp hive if needed). Re-verify the config redirect is 10.0.0.0 and re-run `Patch-DrawingRedirect.ps1` if it was regenerated.
2. Relaunch `C:\vs\fastmain\Common7\IDE\devenv.exe /rootsuffix Exp Q:\source\XamlAgentDemos\XamlAgentDemos.sln`. Ensure the Copilot Chat pane is open and in a new-session state (composer visible).
3. Harden the harness: make `New-ChatThread` and `Set-Autopilot` null-safe, open the chat window via a DTE command if `createNewThread`/"Ask Copilot" are missing, and retry.
4. Verify KeepAwake (PID 77596) is still running.
5. Rerun A11ySweep (run2/run3) with the prompt: "Run an accessibility check on my running app, fix every issue in the XAML, and verify it's clean." Confirm real findings are returned with no assertion, then grade against DEMO.md.

Remaining:
- Fix the a11y checker false-success error path (build Diagnostics after priming, deploy with `Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1`, which requires VS closed), if time permits or if it blocks the tests.
- Run BugRepro, CrispPixels, and the rest of the 17 demos. Grade each, save artifacts, update TestPass.md, and reset the demo repo between runs (the harness does this).
- Fix skill and tools issues found along the way, and record all changes in TestPass.md.
- At the end: stop the keep-awake loop, remind the user to restore the UAC prompt, and note the temporary config redirect (it will be superseded by PR 807376).
</next_steps>