<overview>
The goal is to autonomously test all 17 XAML Diagnostics demo apps in the Visual Studio **fastmain Exp hive** (`C:\vs\fastmain`, `/rootsuffix Exp`; only Exp has the new Copilot code). For each demo the loop is:
- Drive Copilot Chat with a realistic prompt and ask a feedback follow-up.
- Save the transcript and diff, then grade them against the hidden DEMO.md answer key.
- Improve the XAML agent tools or the skill when results show gaps, then rebuild and redeploy.

The user filed PR 807376 to fix the System.Drawing.Common redirect properly. Until it lands, I keep the fastmain `devenv.exe.config` redirecting System.Drawing.Common to 10.0.0.0 by hand.
</overview>

<history>
1. Earlier checkpoints:
   - Built and deployed the TAP and Diagnostics changes.
   - GhostClicks and LostWindows run2 succeeded (findings 10–17 recorded in TestPass.md).
   - A11ySweep run1 was invalid (the System.Drawing.Common load failure was swallowed and reported as an empty result). Run2 failed before prompting.
   - Patched the redirect with an elevated MatchEvaluator script.

2. The user asked me to keep the redirect patched manually and continue the scenario tests.
   - Relaunched fastmain Exp with `Q:\source\XamlAgentDemos\XamlAgentDemos.sln`. The chat showed the Sessions list; invoking `createNewThread` brought up the composer.
   - Hardened the harness:
     - `New-ChatThread` now retries and opens the chat via a DTE command.
     - Found that **the VS main window becomes hidden (IsWindowVisible=false, MainWindowHandle=0) after F5 starts the demo**. Added `VsWin` (EnumWindows to find the "Microsoft Visual Studio" titled window) and `Get-VsMainHwnd`, which re-shows the window with ShowWindow(5). `Get-VsRoot` and `Focus-Vs` now use it.
   - **A11ySweep run3 completed** (artifacts in `test-runs\A11ySweep\run3`):
     - The checker ran correctly (redirect fix works) and returned 8 NameNotNull issues with file and line: Back, Play, Forward, Shuffle, Like, VolumeSlider, SearchBox and EpisodeList.
     - The model added AutomationProperties.Name to these, hot reloaded, re-scanned (0 issues), captured an image, and declared the app clean.
     - It **missed** these answer-key items: the CoverArt image name, SubscribeChip (Border → Button), SearchBox LabeledBy, low-contrast colors #C4C4C4/#BDBDBD/#C8C8C8, and Episode list item names (`A11ySweep.Episode`).
     - Root cause: VS's checker runs plain Axe.Windows automated rules (`ScanOptions` default), which don't cover these.
     - In feedback the model wrongly claimed the scan omitted the Like toggle; it was reported, with elementType Button.
   - Fixes made:
     - The skill now explains that a clean scan isn't a full audit and gives a manual review checklist.
     - The tool result includes a `coverage` note.
     - A failed scan now throws an error instead of returning a false "clean" result.
   - Built Diagnostics successfully, closed VS via DTE.Quit, and deployed with an elevated DeployToVs (exit 0). The DLL and SKILL.md were copied, and the redirect is still 10.0.0.0.
   - Relaunched VS and the composer is available. Started **A11ySweep run4** harness (pwsh PID 65344) with output in `Q:\source\XamlAgentDemos-notes\test-runs\A11ySweep-run4.out` / `.err`.
</history>

<work_done>
Files modified (repo `Q:\src\VS_xaml`, uncommitted):
- `src\Xaml\Diagnostics\Source\Diagnostics\AccessibilityChecker\ToolWindow\AccessibilityIssuesViewModel.cs`: added the `public string LastRunError { get; private set; }` property. `RunOnProcessesAsync` clears it at the start and sets it for: already running, no processes, exception (cancellation vs `{Type}: {Message}`).
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs` (~1838–1905):
  - `RunAccessibilityCheckAsync` now throws `XamlAgentException(NotAvailable, "The accessibility check didn't complete: ...")` when `LastRunError != null`, and resets `lastAccessibilityRun`.
  - `GetAccessibilityResultsAsync` output gained a `coverage` string listing what Axe doesn't check.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\skills\xaml-diagnostics\SKILL.md`, "Fix accessibility issues" section (~lines 87–96):
  - Prefer LabeledBy when a visible label exists.
  - New step 4: "A clean scan is not a full audit", with a checklist covering mouse-only handlers → Button, image names / decorative Raw view, contrast via `xaml_explain_property_value` (WCAG AA), list items named by ToString → ItemContainerStyle name binding, and inputs/sliders without labels.

Harness (session folder `files\harness\Harness.psm1`):
- `VsWin` type, `Get-VsMainHwnd`, and a robust `New-ChatThread`. `Focus-Vs` and ShowWindow use `Get-VsMainHwnd`.

Status:
- [x] Redirect is 10.0.0.0 (verified after deploy).
- [x] A11ySweep run3 is valid (partial pass: 8/≈13 items).
- [x] Built and deployed the a11y fixes.
- [ ] A11ySweep run4 is running; needs grading.
- [ ] TestPass.md isn't yet updated with run3/run4 findings (Axe coverage gap, the hidden VS window after F5, the harness fixes, the a11y false-success fix).
- [ ] Remaining demos: BugRepro, CrispPixels, DesignPolish, GermanReady, HotReloadDoctor, PixelPerfect, PrecedenceWars, ResponsiveDashboard, SlowScroll, StyleMaze, TemplateDetective, ThemeBreaker, BindingStorm, and any others of the 17 not yet run.
</work_done>

<technical_details>
- **Redirect workaround**:
  - Axe.Windows needs System.Drawing.Common. The installed assembly version is 10.0.0.0, but the config redirected to 10.0.0.14.
  - Patch script: `files\Patch-DrawingRedirect.ps1` (elevated, MatchEvaluator; `$110` regex gotcha). Rollback: `files\Restore-DevenvConfig.ps1`.
  - DeployToVs runs updateconfiguration, but the redirect survived. Re-check after every deploy or install.
- **Build**: in the same process, `. src\Shared\Tools\Scripts\Prime-ForCopilot.ps1`, then `Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diagbuild.txt`.
- **Deploy** (VS must be closed): `Start-Process pwsh -Verb RunAs -Wait -ArgumentList @('-NoProfile','-Command',"& 'Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1' -VSInstallPath 'C:\vs\fastmain' -Diagnostics -NonInteractive *> <log>")`. UAC is off. The skill deploys to `C:\vs\fastmain\Common7\IDE\CommonExtensions\Microsoft\XamlDiagnostics\AgentTools\skills\xaml-diagnostics\SKILL.md`.
- **Closing VS**: `Import-Module Harness.psm1; Stop-Demo; (Get-Dte).Quit()`. **Relaunch**: `Start-Process C:\vs\fastmain\Common7\IDE\devenv.exe -ArgumentList '/rootsuffix','Exp','Q:\source\XamlAgentDemos\XamlAgentDemos.sln'`, wait about 75 s, then `New-ChatThread`.
- **Harness run**: `Start-Process pwsh -ArgumentList @('-NoProfile','-File',"$h\Run-Demo.ps1",'-Name',X,'-Prompt','"..."','-Tag','runN') -RedirectStandardOutput "$n\X-runN.out" -WindowStyle Hidden`.
  - Output goes to `Q:\source\XamlAgentDemos-notes\test-runs\X\runN\`: transcript.md, events.jsonl, fix.diff, status.txt, vs-final.png.
  - A turn takes about 1–3 min. The Stats line lists the tool counts.
- **The VS main window hides after F5** (cause unknown, possibly a product or IDE behavior worth reporting). The harness auto-re-shows it.
- A lingering LogonUI process doesn't mean the workstation is locked; `OpenInputDesktop` succeeded. KeepAwake (pwsh PID 77596) is still running.
- The VS accessibility checker = Axe.Windows `ScanOptions()` default automated rules. It doesn't cover contrast, non-UIA clickable Borders, image names (sometimes), list item ToString names, or label association.
- Per user memory: never push, rebase or amend; add the work as a single new commit for review, done later.
- DEMO.md answer keys are in `Q:\source\XamlAgentDemos-notes\src\<Demo>\DEMO.md` (hidden from the demo repo).
</technical_details>

<important_files>
- `C:\vs\fastmain\Common7\IDE\devenv.exe.config`: System.Drawing.Common redirect is 10.0.0.0 (temporary; superseded by PR 807376).
- `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness\Harness.psm1`, `Run-Demo.ps1`, `Run-Batch.ps1`, `KeepAwake.ps1`, `render.js`: the test harness, modified this segment as noted above.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`: per-demo results and findings 1–17. Needs new entries.
- `Q:\source\XamlAgentDemos-notes\test-runs\A11ySweep\run3\` (valid baseline) and `run4\` (in progress).
- `...\Diagnostics\AgentTools\XamlAgentService.cs`, `...\AccessibilityChecker\ToolWindow\AccessibilityIssuesViewModel.cs`, `...\AgentTools\skills\xaml-diagnostics\SKILL.md`: modified as described.
- `...\Diagnostics\AccessibilityChecker\AccessibilityChecker.cs`: the Axe scan (`ScanOptions` default); not modified.
</important_files>

<next_steps>
Immediate:
1. Monitor A11ySweep run4 (`Get-Content $n\A11ySweep-run4.out -Tail`). When it finishes, read `run4\transcript.md` and `fix.diff`, and grade against DEMO.md. Expect it to now also handle CoverArt, SubscribeChip→Button, LabeledBy, contrast and item names.
2. Write the TestPass.md entries:
   - run3 and run4 results.
   - Finding: Axe coverage gap → skill checklist plus `coverage` field.
   - Finding: a11y false success → `LastRunError` error.
   - Harness: hidden VS window after F5, and New-ChatThread robustness.
   - Model misreport about the Like toggle.
3. Continue the remaining demos one by one with realistic, hint-free prompts. Grade each one, fix the skill or tools when needed, and batch tool rebuilds (close VS → build → elevated deploy → verify redirect → relaunch). The harness resets the demo repo between runs.

At the end:
- Summarize all changes and findings in TestPass.md.
- Stop KeepAwake (PID 77596).
- Remind the user to restore the UAC prompt and that the config redirect is a temporary workaround until PR 807376 lands.
- Offer a single new local commit (no push or amend).
</next_steps>