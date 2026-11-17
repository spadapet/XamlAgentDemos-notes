<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` tools in Diagnostics.dll, backed by TAP messages for WPF, UwpTap (WinUI/UWP) and MauiTap.
- A built-in skill (SKILL.md).

Everything is tested autonomously in the fastmain Exp hive. A harness drives the WPF demo apps (XamlAgentDemos) through Copilot Chat, and every run is logged in the notes repo (`Q:\source\XamlAgentDemos-notes`).

Autopilot is on: decide without asking, verify the work, then call task_complete. Never push, rebase or amend. Add notes-repo work as new local commits only. The VS repo changes stay uncommitted.
</overview>

<history>
1. **Earlier segments (see the checkpoints):**
   - Planned and implemented the tools, the skill and the harness.
   - Ran all 17 demos and fixed findings #1–113.
   - Archived the process in the notes repo and recommended VanishingSave as the demo.

2. **Chattiness reduction (#114):** done.
   - `CompactResult` shortens framework type names and factors out the common source file as `defaultSourceFile`.
   - Notes were shortened.
   - The run compact1 used 24 calls, 51.9 KB of output and 5.7 min. Single calls shrank: explain_visibility −29%, hit_test −35%, hot reload −21%, tree −12%.

3. **LVT usefulness question:** answered.
   - The tree tools were used in 56 of 62 runs: find_elements in 47 runs (152 calls), get_visual_tree in 44 runs (85 calls).
   - The LVT mostly serves as a locator, and the targeted tools do the source mapping.

4. **DPI bug (#115):** compact1 exposed it.
   - `xaml_get_element_bounds` reported insideWindowFraction=0 and clippedByWindow=true for every element, including the Window. The app was on a 150% monitor at screen y≈3387.
   - I added `PhysicalPixelsScope` (SetThreadDpiAwarenessContext PMv2) to XamlAgentImaging's GetClientScreenRect, GetWindowInfo, IsPartlyOffScreen and CaptureWindow.
   - Built; 22/22 tests pass; redeployed.
   - compact2: 4/4 fixed, 14 calls, 14.0 KB, 1.8 min. **However, compact2 never called get_element_bounds or hit_test, so the fix isn't actually verified.**
   - Logged #114, #115 and the LVT analysis; notes commit 61ca41a. The task was marked complete.

5. **Current user question:** "Are there other places where DPI issues could cause problems? Like where Windows provides pixel coordinates?"
   - Audited every screen-coordinate producer and consumer:
     - **VS side (XamlAgentImaging):** GetClientScreenRect (used by bounds insideWindowFraction and the hover containment check), GetWindowInfo (status bounds and dpiScale), IsPartlyOffScreen, CaptureWindow (crop mixes GetWindowRect with the always-physical DWM EXTENDED_FRAME_BOUNDS), MoveCursorOverWindow/MoveCursorAway (already PMv2).
     - **TAP side:** WPF `PointToScreen` in TapAgentToolsService.FillBounds (line ~120) and TapAgentToolsService.HitTest.cs FillHitTest (~line 57, the hover point). These return the app thread's coordinates, which are *virtualized* for system-aware/unaware apps on a monitor whose DPI ≠ system DPI.
     - **UwpTap** (UwpTap.cpp ~2590–2612 hit-test, ~1646 bounds): uses UIA BoundingRectangle with a ClientToScreen fallback. WinUI/UWP/MAUI apps are per-monitor aware, so this is likely fine. XAML Islands in system-aware hosts are an unhandled edge case.
     - **DPI-safe:** hit_test visibleFraction (computed in DIP/root space in the TAP), the explain_visibility inside-window check, and the overlap check (compares TAP rects against each other).
     - **Not ours:** the existing TapLivePreviewService PointToScreen and the accessibility checker ClientToScreen.
   - Probe results:
     - This machine now has a single 1920x1200 monitor at 96 DPI, so mixed DPI can't be reproduced now.
     - The devenv main window has awareness=2 (per-monitor), so VS threads may already be physical. Yesterday's mismatch may have been app-side (the demo apps have no manifest, so WPF defaults to system-aware), in which case the VS-side scope alone wouldn't have fixed it.
   - I was checking the demo app's awareness when the command was rejected: `Stop-Process -Id $p.Id` must have a literal PID.
</history>

<work_done>
**VS repo** (`Q:\src\VS_xaml`), uncommitted.

Earlier segments:
- **XamlAgentService.cs:** CompactResult and the shortened notes.
- **XamlDiagnosticsFunctionProvider.cs:** RunAsync wraps results with CompactResult; descriptions updated.
- **SKILL.md:** line 51 explains the compaction.
- **XamlAgentToolsTests.cs:** 2 new tests.

This segment:
- **`...\Diagnostics\AgentTools\XamlAgentImaging.cs`:** added a private `readonly struct PhysicalPixelsScope : IDisposable` (Enter() sets PMv2, Dispose restores), at about lines 44–64. `using PhysicalPixelsScope scope = PhysicalPixelsScope.Enter();` was added at the start of GetClientScreenRect (~71), GetWindowInfo (~194, after the null check), IsPartlyOffScreen (~263) and CaptureWindow (~297). Built; 22/22 tests pass; deployed.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\NativeMethods.cs`:** new `public static System.Windows.Media.Matrix GetLogicalToPhysicalScreenTransform(IntPtr hwnd)`, just before GetWindowRenderBounds (~322–358).
  - Returns identity when: hwnd is zero, the per-monitor API is unavailable, the thread is already PerMonitorAware, GetWindowRect fails, the width is ≤ 0, logical.Left ≤ −30000 (minimized), or the PMv2 switch fails.
  - Otherwise it compares GetWindowRect in the thread's own context with GetWindowRect in PMv2 and returns a scale+offset matrix. Matrix is used because the TAP doesn't use ValueTuple (it builds for .NET Framework).
- **`...\WpfTap\AgentTools\TapAgentToolsService.cs`** FillBounds (~118–134): computes `hwnd` from the HwndSource and `Matrix toPhysical`, transforms both PointToScreen results, sets `RootWindowHandle = hwnd.ToInt64()`, and sets `DpiScale = TransformToDevice.M11 * toPhysical.M11`, with a comment.
- **`...\WpfTap\AgentTools\TapAgentToolsService.HitTest.cs`:** added `using System.Windows.Interop;`. screenPoint (~57) is now `NativeMethods.GetLogicalToPhysicalScreenTransform(source is HwndSource hwndSource ? hwndSource.Handle : IntPtr.Zero).Transform(target.PointToScreen(local))`.

The WpfTap changes are **NOT built yet** (projects: `src\Xaml\Shared\Source\WpfTap\Framework\WpfTap.csproj` and `...\Core\WpfCoreTap.csproj`).

**Notes repo:** HEAD 61ca41a, clean except for any new runs. **Demo repo:** reset/clean.
</work_done>

<technical_details>
- **Build** (from `Q:\src\VS_xaml`; the cwd must be the repo root):
  ```
  cd Q:\src\VS_xaml; [Environment]::CurrentDirectory='Q:\src\VS_xaml'; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project <csproj> -NoRestore -NoProjectReferences *> .vs\x.txt
  ```
  - Tests: `out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\DesignTools.Tests.Unit.XamlDiagnostics.exe -class "*XamlAgentToolsTests"` (22 pass).
  - Check whether the WpfTap unit tests (`Shared\Test\Unit\WpfTap`) also need running.
- **Harness** (`$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`):
  - `Redeploy.ps1`, then sleep about 60 s.
  - `Run-Demo.ps1 -Name X -Tag T -NoFollowUp -Prompt '...'`: output goes to `Q:\source\XamlAgentDemos-notes\test-runs\<Name>\<Tag>` (events.jsonl, fix.diff, transcript.md).
  - Reset the demo repo: `git -C Q:\source\XamlAgentDemos checkout -- .; git clean -fdq`.
  - Check whether Redeploy deploys the WpfTap DLL too; the TAP is injected into the app.
- **DPI reasoning:**
  - Effective physical-pixels-per-DIP = monitorDpi/96 for any awareness mode.
  - For a system-aware WPF app, TransformToDevice.M11 = systemDpi/96, and the virtualization factor = monitor/system.
  - DWMWA_EXTENDED_FRAME_BOUNDS is always physical.
  - For DPI-virtualized windows, PrintWindow likely returns the unscaled (logical-size) redirection surface. This is not verified. If true, CaptureWindow in PMv2 would produce a physical-size bitmap with black/partial content. A safer design is to get the rect in the window's own context (`GetWindowDpiAwarenessContext(hwnd)`) and scale the DWM frame insets by logical/physical width.
  - GetWindowInfo's dpiScale uses GetDpiForWindow, which for a system-aware window returns the system DPI, not the effective scale. Consider GetDpiForMonitor(MonitorFromWindow, MDT_EFFECTIVE) so that the "Window.Width = bounds.width/dpiScale" note holds.
  - Hover: VS computes target = TAP screen + dipOffset*info.DpiScale and moves the cursor in PMv2. This is consistent once the TAP reports physical coordinates and the effective DpiScale.
  - Uncertain: whether VS threadpool threads were already PMv2 (devenv window awareness=2 suggests so). If they were, yesterday's #115 root cause was app-side virtualization, and the VS-side scope was harmless but not the real fix. The #115 note in TestPass.md may need correcting.
- PowerShell: `Stop-Process` requires a literal `-Id <PID>`. Capture the PID as a number and print it, or stop it in a separate call.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentImaging.cs`
  - All host-side Win32 coordinate code.
  - PhysicalPixelsScope ~44–64; GetClientScreenRect ~69; MoveCursorOverWindow ~104; GetWindowInfo ~186; IsPartlyOffScreen ~261; CaptureWindow ~295 (DWM crop ~327).
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Bounds visibleFraction ~2212–2231; hover ~2367–2430; hit_test screen output ~2616; overlap check ~2784; GetWindowInfos/WindowBoundsNote ~4175–4192; CaptureImageAsync ~4288.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\NativeMethods.cs`
  - New GetLogicalToPhysicalScreenTransform ~322–358.
  - Existing GetWindowRenderBoundsDpiAware is the prior art (~270).
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs` (FillBounds ~110–140) and `TapAgentToolsService.HitTest.cs` (FillHitTest ~44–75; FillClipping ~166, DIP-space)
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\UwpTap\UwpTap.cpp`
  - Bounds ~1646; hit-test screen point ~2590–2612.
- `Q:\source\XamlAgentDemos-notes\TestPass.md` and `process\Journal.md`
  - Findings log; the next number is #116.
</important_files>

<next_steps>
1. Finish verifying the demo app's DPI awareness.
   - Launch `Q:\source\XamlAgentDemos\src\VanishingSave\bin\...\VanishingSave.exe`, print its PID and its GetWindowDpiAwarenessContext awareness, then stop it by literal PID.
   - Expected: 1 (system-aware), since there's no manifest.
2. Optionally improve the VS side:
   - CaptureWindow: use the window's own DPI context for GetWindowRect, and scale the DWM frame insets.
   - GetWindowInfo: report dpiScale from monitor DPI (effective scale).
3. Build WpfTap.csproj and WpfCoreTap.csproj (plus Diagnostics.csproj if changed). Run the unit tests (XamlAgentToolsTests, and the WpfTap tests if they're relevant).
4. Redeploy. Run a quick live check with get_element_bounds, hit_test and hover (e.g. GhostClicks or VanishingSave with a bounds-focused prompt). Confirm there are no regressions on a 96-DPI single monitor. Mixed DPI can't be reproduced here, so say so plainly.
5. Log finding #116 (TAP-side DPI virtualization; inventory of coordinate paths; a possible correction to #115's root cause) in TestPass.md and Journal.md. Commit the notes repo locally (new commit; no push/amend).
6. Reset the demo repo, then call task_complete. Answer with the inventory of DPI-sensitive places:
   - What's fixed: VS-side helpers; WPF TAP bounds and hover point.
   - What's safe: hit_test visibleFraction, explain_visibility, overlap check, WinUI/UWP/MAUI (per-monitor aware).
   - Remaining risks: PrintWindow on virtualized windows, XAML Islands in system-aware hosts, the existing Live Preview and accessibility-checker paths.
   - Unverified: mixed-DPI behavior, because no mixed-DPI setup is available.
</next_steps>