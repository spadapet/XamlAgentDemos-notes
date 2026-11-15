<overview>
The goal is to autonomously test all 17 XAML Diagnostics demo apps in the Visual Studio fastmain Exp hive (`C:\vs\fastmain`, `devenv.exe /rootsuffix Exp`). For each demo:
- Drive Copilot Chat with a realistic prompt that gives no hints, then send feedback follow-ups.
- Save the transcript, events and diff to the notes repo.
- Grade the result against the hidden DEMO.md answer key.
- Fix the XAML agent tools (`Diagnostics.dll`, WpfTap) and the skill (SKILL.md), then rebuild and redeploy.

The user's standing requests:
- Log every test run and every fix in `Q:\source\XamlAgentDemos-notes\TestPass.md`.
- Find blocked or unexpected states and explain them clearly to the agent, including how to recover.
- Keep improving the follow-up questions.
- Complete all the remaining demos.

Autopilot is the default in VS. The harness auto-clicks "Allow" permission prompts and now auto-ignores asserts.
</overview>

<history>
1. Earlier segments:
   - Passed: GhostClicks, LostWindows, A11ySweep, BugRepro, CrispPixels, DesignPolish A/B, GermanReady, PrecedenceWars, HotReloadDoctor, ResponsiveDashboard (run2), SlowScroll (run1 and run2).
   - Many tool and skill fixes; findings #1–46 were logged.

2. This segment:
   - **SlowScroll run2 graded and logged.**
     - It validated the one-change-at-a-time guidance: CanContentScroll alone left 3000 realized rows, grouping alone 3000, the bounded viewport 45.
     - It restarted the debug session itself with debugger_launch: startup went from 14.4 s to 1.08 s.
     - Follow-up 7: it admitted it timed only before and after the combined fix, not after each change.
     - Fixes (findings 47–50):
       - **WpfTap** `TapAgentToolsService.cs` setValue on a RangeValue: calls `UpdateLayout()` before reading the value back, so it reports the new value instead of the stale one.
       - `ExplainPropertyValueAsync`: an unset attached property (name contains '.') now returns `effectiveSource=Default` with an empty chain and a note, instead of PROPERTY_NOT_FOUND.
       - `SendTapMessageAsync` TAP_TIMEOUT: switches to the UI thread, includes debuggerState in the message, and gives a paused-specific or busy-specific hint.
       - Finding 50 (open): enum values shown as numbers; the model asked for a virtualization report tool.
     - Built Diagnostics, WpfCoreTap and WpfTap; deployed.
   - **StyleMaze run1: 4/5.**
     - Fixed: ToolBar.ButtonStyleKey, AccentBrush shadowing, the DangerButton subclass, the local implicit style.
     - Missed: the RecentProjects TextBlock style doesn't cross the DataTemplate boundary.
     - It also removed DangerButton's intended red Background and rewrote its doc comment to match.
     - Fixes (findings 51–53):
       - Skill step 2 in "A style isn't applying" lists the 5 implicit-style failure reasons with generic names, and says to check every element kind, including items generated from templates.
       - New rule "Keep the app's intended design… never edit comments/docs to match your change".
       - find_elements always returns a hint for type searches: it matches the class name, so subclasses with other names are excluded.
   - **StyleMaze run2: 4/5.**
     - It kept the red background and used BasedOn, but still missed the template text (admitted in follow-up 7).
     - A checked-build **assert** in the XAML language service blocked VS for ~17 minutes: `XamlResourceManager.RefreshReference`, "Why we did not find parented reference DocumentNode?". The user reported it. UIA hung, so I dismissed it via Win32 WM_COMMAND IDIGNORE(5).
     - The harness timed out ("stalled") and stopped debugging while the agent was still working.
     - Resumed with -ResumeDir for the follow-up.
     - Fixes (findings 54–55):
       - apply_hot_reload now returns `applied=false`, `status="partial"` and an `errorsNote` (explains the sealed-Style and null-key errors) when there are runtime errors.
       - Harness: new `Close-Asserts` (Win32), called first in Wait-TurnDone; it logs to dialogs.log.
     - Built and deployed. Logged rows plus findings 51–55.
   - Harness: Run-Demo.ps1 reads the prompt from prompts.json when `-Prompt` is omitted. Prompts with spaces or quotes broke Start-Process args.
   - **TemplateDetective run1 just finished (not yet logged): appears 4/4 correct.**
     - Comment → models:Comment.
     - Removed the Commit x:Key.
     - IAlert → models:SecurityAlert.
     - Moved the Deployment template from SidebarPanel.Resources to Window.Resources.
     - Verified live; no failed calls; follow-up 7 says yes.
     - Feedback:
       - explain_property_value on ContentTemplate doesn't show which template was selected or why. The model wants a template-selection diagnostic: candidate keys, scopes, match or fail.
       - Hot reload's "nothing new logged" was inconclusive.
       - It used source inspection for model types.
     - Note: the DEMO expected flow uses get_resource_dictionaries/find_resource; the model used source reading instead.
</history>

<work_done>
Repo `Q:\src\VS_xaml`: all edits are uncommitted. **Built and deployed** (last deploy includes the apply_hot_reload partial status).

`src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`:
- SendTapMessageAsync (~238): timeout includes debuggerState.
- FindElementsAsync hint (~608).
- ExplainPropertyValueAsync (~1021): default result for unset attached properties.
- ApplyHotReload return (~1721): applied/status/errorsNote.
- Earlier changes: applyMode, totalMatches, list_windows note, WINDOW_MINIMIZED, capture hashes, DEBUGGER_PAUSED, etc.

Other repo files:
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs` (~267): UpdateLayout before the RangeValue readback.
- `skills\xaml-diagnostics\SKILL.md`: style-reasons list (~87–94), Rules "keep intended design" (~146). Earlier: Slow lists section, step 7, paused-debugger paragraph.
- `XamlAgentException.cs`, `XamlDiagnosticsFunctionProvider.cs`: earlier changes.

Harness (`$h`):
- Harness.psm1: Close-Asserts function, called in Wait-TurnDone; Send-ChatPrompt retries.
- Run-Demo.ps1: prompt fallback from prompts.json; follow-up question 7.

TestPass.md has rows through StyleMaze run2 and findings through #55. **TemplateDetective run1 isn't logged yet.**

Demo status:
- [x] StyleMaze (run1, run2)
- [x] TemplateDetective run1 (graded mentally as 4/4; needs logging)
- [ ] PixelPerfect
- [ ] Optional reruns: BindingStorm, ThemeBreaker, VanishingSave
</work_done>

<technical_details>
- **Build:**
  ```
  cd Q:\src\VS_xaml; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project <csproj> -NoRestore -NoProjectReferences *> .vs\<name>.txt
  ```
  Check the file for " 0 Error(s)".
  - Projects: `src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj`, `src\Xaml\Shared\Source\WpfTap\Core\WpfCoreTap.csproj`, `src\Xaml\Shared\Source\WpfTap\Framework\WpfTap.csproj`.
- **Deploy:** `& "$h\Redeploy.ps1"` closes VS, deploys elevated via DeployToVs.ps1 (which also copies the WpfTap DLLs), verifies the redirect and relaunches Exp.
  - `$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`
  - The redirect `0.0.0.0-10.0.0.14 → 10.0.0.0` in `C:\vs\fastmain\Common7\IDE\devenv.exe.config` stays until PR 807376 lands.
- **Run a demo:**
  ```
  $a="-NoProfile -File `"$h\Run-Demo.ps1`" -Name $X -Tag runN"; Start-Process pwsh -ArgumentList $a -RedirectStandardOutput "$n\$X-runN.out" -RedirectStandardError ... -PassThru -WindowStyle Hidden; .WaitForExit()
  ```
  - Use initial_wait 600; `$n=Q:\source\XamlAgentDemos-notes\test-runs`.
  - Resume an existing session: `-ResumeDir <sessionDir>`. It waits for the turn, then sends the standard follow-up (or `-FollowUps`). It doesn't reset the repo, and it overwrites transcript.md, events.jsonl and fix.diff.
  - Session dirs: `%LOCALAPPDATA%\Microsoft\VisualStudio\CopilotCli\session-state\<id>`.
  - Run-Demo stops debugging at the end even if the main turn "stalled". Beware when an agent is still running.
- **Grading:** read the "Task complete" sections of transcript.md with a regex, the failed results (`success=false`), fix.diff, and DEMO.md at `Q:\source\XamlAgentDemos-notes\src\<Demo>\DEMO.md`.
- **Asserts:** checked-build asserts block the VS UI thread, so UIA root enumeration hangs. Use Win32 EnumWindows for a window titled "Assertion Failed*", then PostMessage WM_COMMAND (0x111) with wParam 5 (IDIGNORE).
- **Writing files:** TestPass.md with `[IO.File]::WriteAllLines` (UTF-8, no BOM). Insert rows after the previous demo's row; insert findings before the line `## Harness notes` (minus 1). Keep XamlAgentService.cs without a BOM and with CRLF line endings.
- **The edit tool's fuzzy match** sometimes drops lines. Always check the result view and restore if needed (this happened once in ExplainPropertyValueAsync).
- **Skill examples** must use generic names, not demo names, to avoid "cheating".
- **Debugger modes:** 1 = design, 2 = break, 3 = run.
- **Git:** never push, rebase or amend; finish with a single new local commit, offered to the user.
- **Unresolved:**
  - The ResponsiveDashboard minimize cause.
  - The profiler `collect_trace_from_app` fails (another team's issue).
  - The XamlResourceManager assert is a product bug in the XAML language service.
  - The model repeatedly misses the template-boundary text in StyleMaze.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Main tool implementation; see the line numbers above.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`
  - WPF TAP agent actions; the setValue readback fix at ~267.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`
  - Agent guidance: style section ~85–100, Slow lists, Reproduce step 7, Rules ~143.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`
  - Results table and findings 1–55.
- `Q:\source\XamlAgentDemos-notes\test-runs\<Demo>\<runN>\`
  - Saved runs (events.jsonl, transcript.md, fix.diff, runner.log, dialogs.log).
- Harness: `$h\Run-Demo.ps1`, `Harness.psm1` (Close-Asserts ~166, Wait-TurnDone ~133), `Redeploy.ps1`, `prompts.json`, `render.js`.
</important_files>

<next_steps>
Immediate:
1. Log the TemplateDetective run1 row in TestPass.md: 4/4 fixed and verified live; it used source reading instead of get_resource_dictionaries/find_resource.
2. Add finding #56: the model wants a template-selection diagnostic. Options:
   - a hint in explain_property_value for ContentTemplate/ItemTemplate: implicit DataTemplate lookup uses the exact DataType, not interfaces; x:Key makes a template non-implicit; resource scope; and to use `xaml_find_resource` with the DataTemplateKey;
   - a skill recipe "Wrong DataTemplate chosen" with generic names.
   Then build and deploy.
3. Run PixelPerfect: `Run-Demo.ps1 -Name PixelPerfect -Tag run1`. Its prompt references `src\PixelPerfect\design\mockup.png`. Grade, send follow-ups, fix, log.
4. Optionally rerun BindingStorm, ThemeBreaker, VanishingSave, and possibly a targeted DEBUGGER_PAUSED test via a pre-script (`$h\pre-<Name>.ps1`).

At the end:
- Write the final summary in TestPass.md.
- Stop KeepAwake (PID 77596).
- Remind the user to re-enable UAC, that the redirect patch is temporary until PR 807376, about RDP minimizing (`RemoteDesktop_SuppressWhenMinimized=2`), and about the XAML language service assert.
- Offer a single new local commit (no push or amend).
- Ask about updating skills (writing-skills).
- If rendering drops, poll for up to ~15 minutes; otherwise finish the notes and call task_complete explaining the blocker.
</next_steps>