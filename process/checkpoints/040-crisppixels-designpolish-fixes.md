<overview>
The goal is to test all 17 XAML Diagnostics demo apps autonomously in the Visual Studio **fastmain Exp hive** (`C:\vs\fastmain`, `devenv.exe /rootsuffix Exp`; only Exp has the new Copilot code). For each demo the loop is:
- Drive Copilot Chat with a realistic, hint-free prompt, then ask a feedback follow-up.
- Save the transcript, events and diff, and grade them against the hidden DEMO.md answer key.
- Fix the XAML agent tools or the skill when the results show gaps, then rebuild and redeploy.
- Record everything in TestPass.md.

Until the user's PR 807376 lands, the System.Drawing.Common redirect in the fastmain `devenv.exe.config` must be kept at 10.0.0.0 by hand.
</overview>

<history>
1. Earlier checkpoints: GhostClicks, LostWindows, A11ySweep (13/13 by run4) and BugRepro (2/2) passed, and a series of tool and skill fixes were made (see the earlier checkpoints for details).

2. This segment: continued the scenario tests.
   - **Capture crop (finding #23):** `XamlAgentImaging.CaptureWindow` now crops to `DwmGetWindowAttribute(DWMWA_EXTENDED_FRAME_BOUNDS=9)`, with a fallback to the uncropped image. This removes the black resize-border bands.
   - **Attached properties (finding #24):** added `GetPropertyNotFoundHint(propertyName)`, used by SetElementProperty and ExplainPropertyValue. For a dotted (attached) name, the hint explains that unset attached properties have their default value, aren't listed, and must be added in XAML plus hot reload.
   - **Skill additions:**
     - A blurry-rendering checklist: fractional pixel bounds, bitmap size vs rendered size, Effect on text, Viewbox scale.
     - A note that `setValue` doesn't move focus, so LostFocus bindings don't commit.
   - Built and deployed.
   - **Harness fix:** `Set-Autopilot` failed with "Autopilot not set" (a timing race), so I made it retry up to 4 times.
   - **CrispPixels run3: 4/4**, with 0 failed calls and no black capture borders. Fixes found: UseLayoutRounding with whole-number margins, vector DrawingImage icons, the shadow moved to a sibling Border, and the Viewbox removed.
     - Feedback: bounds were rounded to whole pixels. **Fix:** `screen` and `window` bounds now keep 2 decimals, and the note explains fractional pixels. The skill example changed to x=18.75.
   - **DesignPolish A (runA1): about 25/25** violations listed and replaced with token resources in Window.Resources.
     - Feedback 1: `xaml_get_resource_dictionaries` without an elementId shows only app scope. **Fix:** the note now explains this when no elementId is passed.
     - Feedback 2: LVT source lines are stale after hot reload. **Fix:** the apply_hot_reload hint now says so and suggests finding elements by x:Name or type.
   - **Harness:** added `-FollowUps` to Run-Demo.ps1 for extra user turns. Only a single string works through `-File`.
   - **DesignPolish B (runB1):** three variants were applied live and captured, and left-aligned was written after the user's pick.
     - Problem: in turn 1 the model wrote the compact variant to XAML before the user picked.
     - It undid experiments by setting original values. That's correct, because `reset` clears XAML attribute values too.
     - **Fixes:**
       - The reset parameter description now explains that XAML attributes are local values.
       - The set_property result note says hot reload re-applies only changed properties, so experiments must be undone first.
       - New skill step: compare variants, restore the originals, and stop until the user picks.
   - Added TestPass rows (CrispPixels run2/run3, DesignPolish A/B), findings #23–30 and a harness note. Built Diagnostics successfully.
   - Created `files\harness\Redeploy.ps1`, which closes VS, deploys elevated, verifies the redirect, relaunches Exp and starts a new chat. Ran it successfully; the redirect stayed OK.
   - **GermanReady run1 failed with "Autopilot not set" because the workstation is LOCKED.** LogonUI is running, the screenshot failed with "handle is invalid", and the mode selector can't be found. KeepAwake (PID 77596, which nudges the mouse and F15 every 30 s and calls SetThreadExecutionState) is running but did not prevent the lock, probably because of a policy lock. I can't unlock it.
</history>

<work_done>
Repo `Q:\src\VS_xaml` (uncommitted, all built successfully, latest deployed to fastmain):
- **`src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentImaging.cs`:** DWM frame crop in CaptureWindow (~line 163–179). Added `DWMWA_EXTENDED_FRAME_BOUNDS` and the `DwmGetWindowAttribute` P/Invoke in NativeMethods (~271–274).
- **`...\AgentTools\XamlAgentService.cs`:**
  - `GetPropertyNotFoundHint` (~715) and its use at the two PROPERTY_NOT_FOUND throws.
  - set_property note about undoing experiments (~800).
  - Bounds with 2 decimals plus the fractional-pixel note (~1189–1198).
  - Resource dictionaries note when there's no elementId (~1388).
  - apply_hot_reload hint about stale source lines (~1640).
  - Earlier edits still present: visual-tree pass-through depth, a11y LastRunError/coverage. No BOM.
- **`...\AgentTools\XamlDiagnosticsFunctionProvider.cs`:** reset parameter description (~178); depth description from earlier.
- **`...\AgentTools\skills\xaml-diagnostics\SKILL.md`:** design-variant step (~77), blurry checklist (~79–83), setValue/LostFocus note under "Reproduce a problem", and the earlier a11y checklist.
- **`src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`** (earlier): InvalidateRequerySuggested and GetPendingTextBindingNote.
- **`...\AccessibilityChecker\ToolWindow\AccessibilityIssuesViewModel.cs`** (earlier): LastRunError.

Notes repo `Q:\source\XamlAgentDemos-notes\TestPass.md`: results through DesignPolish B, findings 1–30, harness notes.

Harness (`C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness\`):
- Harness.psm1: Set-Autopilot retry.
- Run-Demo.ps1: `-FollowUps`.
- New Redeploy.ps1.

Status:
- [x] CrispPixels (4/4), DesignPolish A and B.
- [ ] GermanReady: blocked by the locked workstation.
- [ ] Remaining: HotReloadDoctor, PixelPerfect, PrecedenceWars, ResponsiveDashboard, SlowScroll, StyleMaze, TemplateDetective. Optional reruns: ThemeBreaker, VanishingSave, BindingStorm.
</work_done>

<technical_details>
- **Redirect workaround:**
  - Config line: `<bindingRedirect oldVersion="0.0.0.0-10.0.0.14" newVersion="10.0.0.0" />` in `C:\vs\fastmain\Common7\IDE\devenv.exe.config`.
  - Patch with `files\Patch-DrawingRedirect.ps1`; roll back with `files\Restore-DevenvConfig.ps1`.
  - Redeploy.ps1 verifies it after each deploy.
- **Build:** `cd Q:\src\VS_xaml; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diagbuild.txt`. WpfTap projects: `src\Xaml\Shared\Source\WpfTap\Core\WpfCoreTap.csproj` and `...\Framework\WpfTap.csproj`.
- **Deploy and relaunch:** `& $h\Redeploy.ps1` (UAC is off; uses the elevated DeployToVs `-Diagnostics -NonInteractive`).
- **Run a demo:**
  - Command: `Start-Process pwsh -PassThru -ArgumentList @('-NoProfile','-File',"$h\Run-Demo.ps1",'-Name',X,'-Prompt','"..."','-Tag','runN'[, '-FollowUps','"..."']) -RedirectStandardOutput "$n\X-runN.out" -RedirectStandardError "$n\X-runN.err" -WindowStyle Hidden`, then `WaitForExit`.
  - `$n='Q:\source\XamlAgentDemos-notes\test-runs'`. Output goes to `$n\X\runN\` (transcript.md, events.jsonl, fix.diff).
  - Inspect set_property arguments via events with `type tool.execution_start` and `data.toolName` / `data.arguments`.
- Prompts come from the "Prompt" section of each `Q:\source\XamlAgentDemos-notes\src\<Demo>\DEMO.md`.
- **The workstation lock blocks all UI Automation.** Check for it with `Get-Process LogonUI`. KeepAwake doesn't prevent a policy lock, so the user has to unlock.
- WPF `reset` (ClearValue) removes values set by XAML attributes. Hot reload re-applies only properties whose XAML changed, so runtime experiments persist.
- Editing gotchas:
  - Use the edit tool for CRLF files.
  - Write TestPass.md with UTF-8 without BOM via `[IO.File]::WriteAllLines`.
- Per user memory: never push, rebase or amend; finish with a single new local commit for review.
</technical_details>

<important_files>
- **XamlAgentService.cs**: main tool implementation.
  - set_property ~735–803, PropertyNotFound hint ~715, explain ~918.
  - Bounds ~1114–1203, resource dictionaries ~1345, apply_hot_reload ~1571–1643, SourceResolver ~1970.
- **XamlAgentImaging.cs**: window capture and crop.
- **XamlDiagnosticsFunctionProvider.cs**: tool descriptions.
- **SKILL.md** (xaml-diagnostics): workflows and checklists.
- **TapAgentToolsService.cs**: WPF TAP actions.
- **Q:\source\XamlAgentDemos-notes\TestPass.md**: results, findings and harness notes.
- **Harness files**: Harness.psm1, Run-Demo.ps1, Redeploy.ps1, KeepAwake.ps1.
</important_files>

<next_steps>
Immediate:
- Tell the user the workstation locked despite KeepAwake and that I'm blocked until they unlock it. Possibly suggest disabling the lock policy or screensaver.
- After unlock, check that VS Exp is still running and the chat window is present (otherwise run Redeploy.ps1 or relaunch). Then rerun GermanReady with:
  - Prompt: "Test my running checkout page in German and pseudo-localization. Find every place text is clipped or truncated and fix the layout so it works in all languages."
  - Answer key (6 items): header Height=58, label column Width=90, ComboBox Width=120, Apply button Width=64, horizontal StackPanel delivery note, footer buttons Width=96.

Then:
- Continue HotReloadDoctor, PixelPerfect, PrecedenceWars, ResponsiveDashboard, SlowScroll, StyleMaze and TemplateDetective: grade each, fix, batch the rebuilds and use Redeploy.ps1.
- At the end:
  - Write the final summary in TestPass.md.
  - Stop KeepAwake (PID 77596).
  - Remind the user to re-enable UAC and that the redirect patch is temporary until PR 807376.
  - Offer a single new local commit (no push or amend).
  - Ask whether to update skills (writing-skills).
</next_steps>