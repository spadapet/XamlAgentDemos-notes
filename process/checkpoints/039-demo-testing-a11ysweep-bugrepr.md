<overview>
The goal is to test all 17 XAML Diagnostics demo apps autonomously in the Visual Studio **fastmain Exp hive** (`C:\vs\fastmain`, `devenv.exe /rootsuffix Exp`; only Exp has the new Copilot code). For each demo the loop is:
- Drive Copilot Chat with a realistic, hint-free prompt, then ask a feedback follow-up.
- Save the transcript, events and diff, and grade them against the hidden DEMO.md answer key.
- Fix the XAML agent tools or the skill when results show gaps, then rebuild and redeploy.
- Record everything in TestPass.md.

The user's PR 807376 will fix the System.Drawing.Common redirect properly. Until it lands, I keep the fastmain `devenv.exe.config` redirecting System.Drawing.Common to 10.0.0.0 by hand.
</overview>

<history>
1. Earlier checkpoints:
   - Built and deployed the TAP and Diagnostics changes. GhostClicks and LostWindows passed.
   - A11ySweep run1 was invalid because of the redirect bug; I patched the redirect.
   - Hardened the harness: the hidden VS window after F5 is re-shown, and `New-ChatThread` is more robust.
   - A11ySweep run3 found 8/13 answer-key items.
   - Added the a11y fixes: a `coverage` note, a `LastRunError` error instead of a false "clean" result, and a skill checklist for what Axe doesn't check.

2. Continued the scenario tests (user asked to keep the redirect patched by hand and keep going).
   - **A11ySweep run4: 13/13**, a full pass.
     - Covered CoverArt name, SubscribeChip → ToggleButton bound to IsSubscribed, LabeledBy, #595959 contrast and ItemContainerStyle names.
     - In feedback the model said `xaml_get_visual_tree(depth=5)` returned only 6 nodes.
   - **Fixed `xaml_get_visual_tree`:**
     - Elements without source info that lead to XAML-declared content are now "pass-through" and don't use up depth.
     - Added a `depthLimitedNodes` count and better hints that tell maxNodes truncation apart from depth limits.
     - Updated the depth parameter description.
     - Built successfully. I accidentally added a UTF-8 BOM to XamlAgentService.cs and removed it again; the file has no BOM.
   - Updated TestPass.md:
     - A11ySweep run1, run3 and run4 rows.
     - Finding #10 updated to Fixed.
     - New findings #18–21.
     - Harness notes: hidden VS window, New-ChatThread, redirect workaround.
   - Deployed (elevated DeployToVs -Diagnostics); the redirect stayed at 10.0.0.0. Relaunched VS.
   - **BugRepro run2: 2/2.**
     - Fixes: reset isReverting in Cancel, plus an unneeded MarkDirty change, and UpdateSourceTrigger=PropertyChanged.
     - Applied with .NET and XAML Hot Reload and replayed the steps.
     - Problem: after `setValue`, Save's IsEnabled looked stale. The demo's RelayCommand relies on CommandManager.RequerySuggested. The model made 34 property reads and sent a Tab keystroke through PowerShell.
   - **Fixed the WPF TAP** (`TapAgentToolsService.cs`):
     - Calls `CommandManager.InvalidateRequerySuggested()` after every action.
     - The setValue result now explains when a TextBox Text binding commits only on LostFocus (Default or LostFocus trigger, two-way) and how to commit it.
     - Built WpfCoreTap and WpfTap successfully.
   - Added the BugRepro row and finding #22 to TestPass.md. Deployed (the TAPs were copied, redirect OK). Relaunched VS.
   - **CrispPixels run2: about 3.5/4.**
     - Correct: UseLayoutRounding with whole-number margins, the shadow moved to a sibling Border, and the Viewbox removed (with odd FontSize 13.5 and MaxWidth=475 tweaks).
     - Partial: the icons got `RenderOptions.BitmapScalingMode=NearestNeighbor` at 20×20 instead of Stretch=None at native 16×16.
     - Two failures: `xaml_explain_property_value` returned PROPERTY_NOT_FOUND for attached properties that weren't set (RenderOptions.BitmapScalingMode, TextOptions.TextRenderingMode).
     - The model complained that a "black" screenshot came back.
   - Investigated the screenshots:
     - **Every capture has black bands on the left, right and bottom.** `XamlAgentImaging.CaptureWindow` uses GetWindowRect, which includes Windows 10/11's invisible resize borders that PrintWindow leaves black. These were more noticeable after the model set the Window Width to 400.
     - I first added a black-pixel retry loop, then **reverted it completely** (XamlAgentService.cs and XamlAgentImaging.cs are back to the original capture code).
     - The decided fix is to crop to `DwmGetWindowAttribute(DWMWA_EXTENDED_FRAME_BOUNDS=9)`. Not implemented yet.
</history>

<work_done>
Files modified in repo `Q:\src\VS_xaml` (uncommitted):
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`:
  - Earlier: `RunAccessibilityCheckAsync` throws on `LastRunError`, and `GetAccessibilityResultsAsync` adds `coverage`.
  - Now in `GetVisualTreeAsync` (~374–485): `HasSource` (`SourceInfo is { IsEmpty: false }`), a memoized `HasSourcedDescendant`, pass-through depth for wrapper elements, `depthLimitedNodes`, and new hints.
  - The capture retry loop was added and then removed (net no change near line 1810). No BOM.
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`: the depth parameter description notes that wrapper elements don't count toward depth.
- `...\AgentTools\XamlAgentImaging.cs`: the GetBlackPixelFraction helper was added and then removed (net unchanged).
- `...\AccessibilityChecker\ToolWindow\AccessibilityIssuesViewModel.cs`: `LastRunError` (from the earlier checkpoint).
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`: a11y checklist (from the earlier checkpoint).
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`:
  - Added usings `System.Windows.Data` and `System.Windows.Input`.
  - `CommandManager.InvalidateRequerySuggested()` after the action switch in `RunAction`.
  - New `GetPendingTextBindingNote(target)`, appended to the setValue result.

Notes repo `Q:\source\XamlAgentDemos-notes\TestPass.md`: result rows for A11ySweep run1/run3/run4 and BugRepro run2; finding #10 updated; findings 18–22; harness notes.

Deployed to fastmain: the Diagnostics build with the visual-tree fix, and the WpfTap/WpfCoreTap with the requery and LostFocus note. VS Exp is running with XamlAgentDemos.sln open. KeepAwake (pwsh PID 77596) may still be running.

Status:
- [x] A11ySweep (13/13), BugRepro (2/2), CrispPixels run2 (≈3.5/4) tested.
- [ ] CrispPixels: implement the capture crop fix and the attached-property fix, then add the CrispPixels row and findings to TestPass.md.
- [ ] Remaining demos: DesignPolish, GermanReady, HotReloadDoctor, PixelPerfect, PrecedenceWars, ResponsiveDashboard, SlowScroll, StyleMaze, TemplateDetective. Optionally rerun ThemeBreaker, VanishingSave and BindingStorm with the new tools.
</work_done>

<technical_details>
- **Redirect workaround:**
  - Axe.Windows needs System.Drawing.Common; the installed version is 10.0.0.0.
  - The config line is `<bindingRedirect oldVersion="0.0.0.0-10.0.0.14" newVersion="10.0.0.0" />`.
  - Patch script: `files\Patch-DrawingRedirect.ps1`. Rollback: `files\Restore-DevenvConfig.ps1` (both in the session folder).
  - It survived every DeployToVs so far; verify after each deploy.
- **Build** (one process):
  - `cd Q:\src\VS_xaml; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project <csproj> -NoRestore -NoProjectReferences *> .vs\diagbuild.txt`
  - Projects: `src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj`, `src\Xaml\Shared\Source\WpfTap\Core\WpfCoreTap.csproj`, `src\Xaml\Shared\Source\WpfTap\Framework\WpfTap.csproj`.
  - DeployToVs `-Diagnostics` copies the Diagnostics DLLs, the skill and both WpfTaps (Core and Framework, x86/x64).
- **Close, deploy and relaunch** (in one command):
  - `Import-Module $h\Harness.psm1 -Force 3>$null; Stop-Demo; (Get-Dte).Quit()`, then wait for fastmain devenv to exit.
  - `Start-Process pwsh -Verb RunAs -Wait -ArgumentList @('-NoProfile','-Command',"& 'Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1' -VSInstallPath 'C:\vs\fastmain' -Diagnostics -NonInteractive *> '$log'")` (UAC is off).
  - `Start-Process C:\vs\fastmain\Common7\IDE\devenv.exe -ArgumentList '/rootsuffix','Exp','Q:\source\XamlAgentDemos\XamlAgentDemos.sln'`, `Start-Sleep 80`, then `New-ChatThread`.
- **Harness run:**
  - Harness folder: `$h='C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness'`. Notes folder: `$n='Q:\source\XamlAgentDemos-notes\test-runs'`.
  - Command: `Start-Process pwsh -PassThru -ArgumentList @('-NoProfile','-File',"$h\Run-Demo.ps1",'-Name',X,'-Prompt','"..."','-Tag','runN') -RedirectStandardOutput "$n\X-runN.out" -RedirectStandardError "$n\X-runN.err" -WindowStyle Hidden`.
  - Poll the process for up to 25 minutes; a run takes about 5–8 minutes.
  - Output goes to `$n\X\runN\`: transcript.md, events.jsonl, fix.diff, transcript_images.
  - Failed calls: in events.jsonl, filter `"success":false` and read `.data.error.message`.
  - The harness resets the demo repo, uses Autopilot, and re-shows the hidden VS window.
- The prompt is DEMO.md's "Prompt" section. If the demo expects an attached file, point to its path instead (BugRepro: "in src/BugRepro/bug-report.md").
- Editing gotchas:
  - PowerShell `.Replace` with here-strings fails on CRLF files; use the edit tool.
  - Don't use Set-Content `-Encoding utf8BOM` on repo files; XamlAgentService.cs has no BOM.
- WPF `CommandManager.RequerySuggested` is raised only by real input, so UIA actions need an explicit `InvalidateRequerySuggested`.
- **Capture black borders:**
  - `XamlAgentImaging.CaptureWindow` (~line 134) uses GetWindowRect plus `PrintWindow(PW_RENDERFULLCONTENT)`, which includes the invisible resize borders (black).
  - Fix: P/Invoke `dwmapi DwmGetWindowAttribute(hwnd, 9 /*DWMWA_EXTENDED_FRAME_BOUNDS*/, out RECT, Marshal.SizeOf<RECT>())` and crop with `CroppedBitmap(source, new Int32Rect(frame.Left-rect.Left, frame.Top-rect.Top, frameW, frameH))`, then freeze. Fall back to uncropped on failure.
  - `NativeMethods` is inside XamlAgentImaging.cs (~line 240+). GetWindowInfo (~line 61) also uses GetWindowRect; consider using the frame bounds there for consistency.
- **Attached properties:** `xaml_explain_property_value` and set_property return PROPERTY_NOT_FOUND for attached properties not set on the element (code near XamlAgentService.cs ~730 and ~923). Options:
  - Better hint: unset attached properties use their default value; set them with `xaml_set_element_property` or in the XAML.
  - Or resolve the DP by owner type in the TAP.
- Per user memory: never push, rebase or amend; finish with a single new local commit for review.
- DEMO.md answer keys are in `Q:\source\XamlAgentDemos-notes\src\<Demo>\DEMO.md` (hidden from the demo repo).
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`: the main agent tool implementation.
  - GetVisualTreeAsync ~374–485 (modified).
  - InteractAsync ~1210.
  - CaptureImageAsync ~1773–1822.
  - Accessibility ~1850+.
  - PROPERTY_NOT_FOUND hints ~730 and ~923.
- `...\AgentTools\XamlAgentImaging.cs`: window capture (`CaptureWindow` ~134, NativeMethods at the bottom). Next edit goes here (crop to the DWM frame).
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`: tool descriptions (visual tree ~74–85, interact ~196–212).
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`: WPF TAP actions.
  - RunAction ~178–309 (requery added).
  - GetPendingTextBindingNote ~315.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`: the skill (a11y checklist ~87–96).
- `Q:\source\XamlAgentDemos-notes\TestPass.md`: results table, findings 1–22, harness notes.
- `C:\vs\fastmain\Common7\IDE\devenv.exe.config`: temporary redirect patch.
- Harness: `files\harness\Harness.psm1`, `Run-Demo.ps1`, `KeepAwake.ps1`.
</important_files>

<next_steps>
Immediate:
1. Implement the capture crop in `XamlAgentImaging.CaptureWindow` using DWMWA_EXTENDED_FRAME_BOUNDS, with a fallback.
2. Improve the PROPERTY_NOT_FOUND handling for attached properties: at least a clearer hint saying an unset attached property has its default value and can be set or tested. Optionally resolve it by owner type.
3. Optionally add skill guidance for crisp bitmaps: prefer native size (Stretch=None or a matching Width/Height) over NearestNeighbor upscaling.
4. Build Diagnostics, then close VS, deploy, verify the redirect and relaunch.
5. Add the CrispPixels run2 row (≈3.5/4) and findings to TestPass.md:
   - #23: black capture borders (fix: crop).
   - #24: attached-property PROPERTY_NOT_FOUND.
   - Partial icon fix.

Then continue the remaining demos one by one: DesignPolish, GermanReady, HotReloadDoctor, PixelPerfect, PrecedenceWars, ResponsiveDashboard, SlowScroll, StyleMaze, TemplateDetective. For each: read DEMO.md, use its prompt, grade, fix, and batch the rebuilds.

At the end:
- Write the final summary in TestPass.md.
- Stop KeepAwake (PID 77596).
- Remind the user to re-enable UAC and that the redirect patch is temporary until PR 807376 lands.
- Offer a single new local commit (no push or amend).
- Ask whether any skills should be updated (writing-skills).
</next_steps>