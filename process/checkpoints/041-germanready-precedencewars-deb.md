<overview>
The goal is to test all 17 XAML Diagnostics demo apps autonomously in the Visual Studio **fastmain Exp hive** (`C:\vs\fastmain`, `devenv.exe /rootsuffix Exp`; only Exp has the new Copilot code). For each demo the loop is:
- Drive Copilot Chat with a realistic, hint-free prompt, then ask a feedback follow-up.
- Save the transcript, events and diff, and grade them against the hidden DEMO.md answer key.
- Fix the XAML agent tools or the skill when the results show gaps, then rebuild and redeploy.
- Record everything in TestPass.md.

Until the user's PR 807376 lands, the System.Drawing.Common redirect in the fastmain `devenv.exe.config` must be kept at 10.0.0.0 by hand. The user is away (autopilot) and asked me to keep going and to try to prevent locking.
</overview>

<history>
1. Earlier checkpoints:
   - Passed: GhostClicks, LostWindows, A11ySweep, BugRepro, CrispPixels (4/4) and DesignPolish A/B.
   - Fixes made: DWM crop in capture, attached-property hint, fractional bounds, resource dictionary note, stale-line hint, design-variant skill step, and others.
   - GermanReady was blocked by an apparent lock.

2. The user unlocked and asked me to continue and prevent locking.
   - **"Locked" diagnosis:** the session is an RDP session (session 2, `rdp-sxs…`, Active).
     - `LogonUI` runs in console session 1, so it's a **false lock indicator**.
     - A real lock check is `OpenInputDesktop`, which succeeds when unlocked.
     - Capture failing with "handle is invalid" while the session is unlocked means the RDP client is minimized or the client PC is locked, so the session stops rendering.
     - No idle or lock policies were found. KeepAwake (PID 77596) is still running.
   - **GermanReady run2: 6/6.**
     - Fixes: header Height removed, label column Auto, ComboBox width removed, Apply button MinWidth, delivery note DockPanel with wrap, footer buttons MinWidth/WrapPanel.
     - It also added a ScrollViewer and a global Button style with a wrapping ContentTemplate (heavy-handed but OK).
     - Feedback: hot reload recreated the UI and reset the language selection with no warning; a capture was partial after the window moved off-screen (Top=2368).
   - **Fixes for that feedback:**
     - `XamlAgentImaging.IsPartlyOffScreen(hwnd)` checks each window corner (16 px inset) with `MonitorFromPoint` and `MONITOR_DEFAULTTONULL`. Added the P/Invoke, the constant and `using System.Linq`.
     - The capture description now warns when the window is partly off-screen.
     - The apply_hot_reload hint now says structural edits recreate elements and reset runtime state.
     - Built successfully (build1).
   - Created `pre-HotReloadDoctor.ps1`, which uses DTE to make the 3 presenter edits and save them. Not yet tested.
   - **PrecedenceWars run1:**
     - Source fixes for all 5 cards:
       - Hover: style BasedOn with a Background setter.
       - Counter: removed the `CountText.Text =` line and forced the binding to re-apply via `Path=`.
       - Banner: `BeginAnimation(OpacityProperty, null)`.
       - Release notes: FontSize bound to the slider.
       - Export: `IsBusy=false` in finally.
     - Problems:
       - The model launched a background **debugger sub-agent that called `debugger_pause`** and evaluated expressions. **The app is left in break mode** (DTE CurrentMode=2).
       - The main turn ended without task_complete ("waiting for debugger verification").
       - Hover verification tried to move the cursor with PowerShell and failed.
     - The runner is still waiting: shellId 617, using `Find-Ui SendButton`, which fails without rendering.
     - I rendered the transcript and diff manually into `test-runs\PrecedenceWars\run1\`.
   - Rendering stopped again at about 09:08 (capture fails; the desktop is unlocked).
     - I asked the user (ask_user): they're unavailable.
     - I decided **not** to run `tscon` to the console, for security reasons and because it would disconnect their RDP session.
   - **Started a break-mode fix (unbuilt):**
     - New error code `DEBUGGER_PAUSED`.
     - `GetDebuggerState()` uses IVsDebugger.GetMode and returns running, paused or notDebugging.
     - `ThrowIfDebuggerPaused(endpoint)` skips NoDebugMode endpoints and is called at the start of SendTapMessageAsync, which now switches to the main thread first.
     - `debuggerState` was added to list_apps and get_diagnostics_status.
     - A "Debugger is paused" issue was added to get_diagnostics_status.
     - The TAP timeout hint now mentions debuggerState.
</history>

<work_done>
Repo `Q:\src\VS_xaml` (uncommitted):
- **`...\AgentTools\XamlAgentImaging.cs`:**
  - `using System.Linq`.
  - `MONITOR_DEFAULTTONULL` constant (~line 25).
  - `IsPartlyOffScreen` (~131–151).
  - `MonitorFromPoint` P/Invoke (~307).
  - The earlier DWM crop.
- **`...\AgentTools\XamlAgentService.cs`:**
  - `using Microsoft.VisualStudio.Shell.Interop`.
  - `GetDebuggerState` and `ThrowIfDebuggerPaused` (~185–218).
  - SendTapMessageAsync switches to the main thread and runs the paused check (~220).
  - `debuggerState` in ListApps (~261) and in diagnostics status, plus the paused issue (~381–391).
  - The off-screen capture warning (~1860).
  - The hot reload hint about structural edits resetting state (~1678).
  - All earlier edits.
- **`...\AgentTools\XamlAgentException.cs`:** `DebuggerPaused = "DEBUGGER_PAUSED"`.
- **Build status:**
  - The off-screen and hot reload hint edits were built successfully.
  - **The debugger-paused edits are NOT built yet.**
  - **Nothing from this segment is deployed yet**; VS still has the previous build.

Notes and harness:
- `files\harness\pre-HotReloadDoctor.ps1` (new): DTE OpenFile, `TextDocument.ReplacePattern`, then Save for:
  - Foreground #1F2937 → DarkGreen,
  - the TipTemplate TextBlock SemiBold → Bold (exact string `<TextBlock FontWeight="SemiBold" Text="{Binding Title}" />`),
  - Skin.xaml `Color="#F5F3FF"` → `#FFF7ED`.
- Test runs saved:
  - `test-runs\GermanReady\run2\` (complete).
  - `test-runs\PrecedenceWars\run1\` (events, transcript and fix.diff rendered manually; the follow-up wasn't sent).
- TestPass.md is **not yet updated** for GermanReady run2 or PrecedenceWars run1.

Status:
- [x] GermanReady (6/6).
- [~] PrecedenceWars: 5/5 fixes in source, but it ended in a paused-debugger state; a rerun is needed after the paused fix.
- [ ] Remaining: HotReloadDoctor (needs the pre script; part 2 is optional), PixelPerfect (needs the mockup attached or referenced by path), ResponsiveDashboard, SlowScroll, StyleMaze, TemplateDetective.
</work_done>

<technical_details>
- **Redirect workaround:**
  - Config line: `<bindingRedirect oldVersion="0.0.0.0-10.0.0.14" newVersion="10.0.0.0" />` in `C:\vs\fastmain\Common7\IDE\devenv.exe.config`.
  - Patch with `files\Patch-DrawingRedirect.ps1`; restore with `files\Restore-DevenvConfig.ps1`.
  - Redeploy.ps1 verifies it after each deploy.
- **Build:** `cd Q:\src\VS_xaml; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diagbuild.txt`, then check for "Build succeeded" and "0 Error(s)".
- **Deploy and relaunch:** `& "$h\Redeploy.ps1"`. It closes VS, deploys elevated, verifies the redirect, relaunches Exp and starts a new chat.
  - `$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`.
- **Run a demo:**
  - Command: `Start-Process pwsh -PassThru -ArgumentList @('-NoProfile','-File',"$h\Run-Demo.ps1",'-Name',X,'-Prompt','"..."','-Tag','runN') -RedirectStandardOutput "$n\X-runN.out" -RedirectStandardError "$n\X-runN.err" -WindowStyle Hidden`, then `WaitForExit`.
  - `$n='Q:\source\XamlAgentDemos-notes\test-runs'`.
  - Render a transcript with `node "$h\render.js" events.jsonl transcript.md`.
  - `pre-<Demo>.ps1 $appPid` runs automatically if it exists.
  - Session events are at `%LOCALAPPDATA%\Microsoft\VisualStudio\CopilotCli\session-state\<id>\events.jsonl`.
- **Rendering and lock:**
  - Use `OpenInputDesktop` to detect a real lock. Test rendering with `Drawing.Graphics.CopyFromScreen`.
  - When the RDP client is minimized, capture and chat UIA input fail. The fix is on the client side (`RemoteDesktop_SuppressWhenMinimized=2`, keep the window restored) or `tscon`, which I declined.
- **DTE debugger modes:** 1 = design, 2 = break, 3 = run. Stop-Demo stops debugging when the mode isn't 1.
- Prompts are in `Q:\source\XamlAgentDemos-notes\src\<Demo>\DEMO.md` ("Prompt" section):
  - **HotReloadDoctor:** "XAML Hot Reload is broken in my running app. I made three edits (title color, tip template, page background in Skin.xaml) and none of them show up. Figure out what's going on." Answer key: code-behind OnLoaded overrides Foreground; ItemTemplate swapped to CompactTipTemplate; Skin loaded via XamlReader with no Source URI.
  - **PixelPerfect:** "Here's the designer's mockup. Make my running sign-in page match it as closely as possible, and show me before/after screenshots." (mockup `src\PixelPerfect\design\mockup.png`; don't read `design-source\`). Answer key: background #F2F0F7, padding 32, CornerRadius 12, shadow with no border, title 28 SemiBold, fields 36 high with margin 12, forgot-password link right-aligned, stretched #5B3FD9 rounded button, centered footer.
  - **ResponsiveDashboard:** "Customers on small laptops say my dashboard is broken. Test the running app at 1280, 1024 and 800 px wide, show me what breaks at each size, then fix the layout and prove it works at all three." Answer key: header Canvas → Grid; Nav/Activity fixed widths; KPI tiles → UniformGrid/WrapPanel; chart Stretch/Viewbox; footer WrapPanel.
  - **SlowScroll:** "My log viewer is very slow to open and scroll. Use the running app to prove what's wrong, then fix it and show me the improvement after each change." Answer key: ScrollViewer/StackPanel → Grid star row; remove CanContentScroll=False; IsVirtualizingWhenGrouping=True.
  - **StyleMaze:** "We have a brand style in Themes/Brand.xaml, but a lot of my running app doesn't use it. Find every element that isn't branded, explain why, and fix it." Answer key: ToolBar.ButtonStyleKey; AccentBrush overridden by LegacyReports.xaml merged last; DangerButton subclass; local implicit style without BasedOn; implicit TextBlock style not crossing the template boundary.
  - **TemplateDetective:** "My activity feed should show different layouts for comments, commits, deployments and security alerts, but everything shows as "X mentioned you". Use the running app to find out why and fix it." Answer key: legacy:Comment namespace; x:Key on the Commit template; IAlert interface; Deployment template scoped in SidebarPanel.Resources.
- **WPF quirks:**
  - `reset` (ClearValue) also removes values set by XAML attributes.
  - Hot reload re-applies only properties whose XAML changed.
  - IsMouseOver can't be simulated by xaml_interact.
- **Editing and git:**
  - Use the edit tool for CRLF files.
  - Write TestPass.md as UTF-8 without BOM via `[IO.File]::WriteAllLines`.
  - Per user memory: never push, rebase or amend; finish with a single new local commit.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Main tool implementation. Changed this segment: debugger state (~185–230), list_apps (~258), diagnostics status (~381), apply_hot_reload hint (~1678), capture (~1860).
- `...\AgentTools\XamlAgentImaging.cs`
  - Window capture, the DWM crop, and the off-screen check.
- `...\AgentTools\XamlAgentException.cs`
  - Error codes; DEBUGGER_PAUSED added.
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - Tool descriptions.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`
  - Workflows and checklists. Planned additions are listed under next steps.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`
  - Results, findings 1–30 and harness notes. Needs new rows and findings.
- Harness files in `$h`:
  - Harness.psm1, Run-Demo.ps1, Redeploy.ps1, render.js, KeepAwake.ps1.
  - pre-ThemeBreaker.ps1, plus the new, untested pre-HotReloadDoctor.ps1.
</important_files>

<next_steps>
Immediate:
1. Check whether rendering has resumed (CopyFromScreen). Check runner shellId 617 (PrecedenceWars) and stop it if it's stuck.
2. Continue the debugger if it's still paused: `$dte.Debugger.Go($false)`, or Stop-Demo.
3. Build Diagnostics with the debugger-paused edits and fix any compile errors (`DBGMODE`/`ErrorHandler` come from Microsoft.VisualStudio.Shell.Interop / Shell).
4. Add skill guidance in SKILL.md:
   - Don't pause the debugger or spawn debugger sub-agents to verify UI or view-model state. Use xaml_get_element_properties for bound values, and xaml_interact to invoke commands such as a sync/export button. If you do pause, continue before calling xaml tools.
   - IsMouseOver/hover triggers can't be simulated. Prove trigger precedence via the explain_property_value chain instead (and compare with a working control).
   - After a C# hot reload, re-trigger the code path through UI interaction to verify.
5. Redeploy with Redeploy.ps1 (needs a rendering desktop for the chat steps).
6. Update TestPass.md:
   - Rows: GermanReady run2 6/6; PrecedenceWars run1 5/5 source fixes, but the debugger was left paused and there's no task_complete.
   - Findings #31 (state reset on structural hot reload), #32 (off-screen capture), #33 (debugger paused by a sub-agent), #34 (hover can't be simulated).
   - Harness note: LogonUI is a false lock signal under RDP; a minimized RDP client stops rendering.

Then:
- Rerun PrecedenceWars (run2).
- Run HotReloadDoctor with the pre script; check the DTE edits worked.
- Run ResponsiveDashboard, SlowScroll, StyleMaze, TemplateDetective, and PixelPerfect (reference the mockup path in the prompt, or attach it).
- Batch fixes, rebuild and redeploy.

At the end:
- Write the final summary in TestPass.md.
- Stop KeepAwake (PID 77596).
- Remind the user to re-enable UAC, that the redirect patch is temporary until PR 807376, and about the RDP-minimize issue (client registry `RemoteDesktop_SuppressWhenMinimized=2`).
- Offer a single new local commit (no push or amend).
- Ask about updating skills (writing-skills).

Blocker: if the desktop still isn't rendering, chat-driven tests can't proceed. Do the builds and notes, then finish with task_complete explaining that the user needs to restore the RDP window.
</next_steps>