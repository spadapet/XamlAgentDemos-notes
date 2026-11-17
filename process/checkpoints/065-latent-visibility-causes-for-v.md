<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` tools in Diagnostics.dll;
- TAP messages for WPF, UwpTap (WinUI/UWP) and MauiTap;
- a built-in SKILL.md.

All testing runs autonomously in the fastmain Exp hive. A harness drives the WPF demo apps through Copilot Chat, and every run is logged in the notes repo `Q:\source\XamlAgentDemos-notes`. Autopilot is on: decide without asking, verify the work, then call task_complete. Never push, rebase or amend; add a single new local commit.
</overview>

<history>
1. **Earlier segments (see checkpoints):**
   - Planned and implemented the tools, the skill and the harness.
   - Ran 17 demos and fixed findings #1–111.
   - Consolidated the tools and brought all platforms to parity.
   - Added hover, explain_visibility and audit_styles, plus the accessibility-checker integration.
   - Archived the whole process into notes `process\` (commit 4811f79; 128 files, verified).
   - Recommended VanishingSave as the team demo (journal commit b4308ed). GhostClicks is the backup and BindingStorm the finale.

2. **User report:** the short prompt "Where is my Save button?" in VanishingSave only explained the CanSave binding (1 of 4 causes) and didn't fix anything. The screenshot showed the agent calling explain_visibility once.
   - **Root cause:**
     - `xaml_explain_visibility` stopped once the button was Collapsed. The Grid-cell check was gated on `noRank1`, and the overlay check needed a hit test, which a collapsed element can't get.
     - As a result, the code-behind `SaveColumn.Width=0` (FooterSettings.UseCompactFooter=true) and the white `SyncStatusHost` Border (ZIndex 1, same column) were never reported.
     - The other two causes are the `CanSave` binding (the VM has `IsSaveAvailable`) and the `IsEnabled=False` → `Opacity=0` style trigger.
   - **Fixes:**
     - Added latent causes and a cause count in the verdict.
     - Updated SKILL.md guidance.
     - Fixed the JValue crash.
     - Added the `fixedInSource` tag for stale binding failures.
   - **Live verification:**
     - where1: 4/4, 1 failed call (the JValue crash).
     - where2: 4/4, 0 failed.
     - where3: 4/4, 0 failed, main turn 1.75 min.
     - r11 (standard prompt): 4/4, 0 failed, 2.4 min.
     - The first explain call now returns "4 separate causes, some latent…", and the final check returns "No reason found".
   - Logged finding #112 and the runs in TestPass.md (rows at lines 71 and 192), appended a Journal.md section, and made notes commit `6cf6507`.
   - Reset the demo repo (`git checkout -- .`).
</history>

<work_done>
VS repo (`Q:\src\VS_xaml`), uncommitted, on top of the earlier changes:

**XamlAgentService.cs:**
- `VisibilityCause.Latent` property.
- New helpers: `ParseCellIndex`, `GetEffectiveAny`.
- New `AddLatentOverlayCausesAsync`: checks up to 40 siblings in the parent Grid that share the element's cell (with spans) and draw above it (higher ZIndex, or the same ZIndex and later in order). Those siblings must be visible, have opacity ≥0.05 and a non-transparent Background. Each one becomes a rank-2 latent "covered" cause.
- ExplainVisibilityAsync:
  - `parentGrid` variable.
  - The Grid-cell check now also runs when a rank-1 cause exists. In that case it reports only an explicitly 0-sized definition, as latent, and includes the definition's x:Name hint.
  - The missing-definition check now requires `cell > 0` and is marked latent when a rank-1 cause exists.
  - The overlay check runs when a rank-1 cause or a size reason exists.
  - JObject-safe parsing of `inputTarget`/`clippedBy`, which fixes "Cannot access child value on JValue".
  - Binding failures carry `fixedInSource` (via BindingPathStillInSource). Only live failures count as a rank-3 cause.
  - Causes are ordered by rank, then latent; the verdict counts the causes; each cause has a `latent` field; the note has latent and fixedInSource text.

**Other files:**
- XamlDiagnosticsFunctionProvider.cs: the explain_visibility description mentions latent causes.
- SKILL.md (around lines 98–100): stacked/latent causes; "where is my X" means fix every cause, re-run explain_visibility, then capture.
- Documentation\copilot-tools.md (line 35): latent behavior.

**Verification:** build 0 warnings/0 errors; 19 unit tests pass; deployed to fastmain Exp (the redirect remains 10.0.0.0).
</work_done>

<technical_details>
- **Build:**
  ```
  cd Q:\src\VS_xaml; [Environment]::CurrentDirectory='Q:\src\VS_xaml'; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diag.txt
  ```
- **Unit tests:** `out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\DesignTools.Tests.Unit.XamlDiagnostics.exe -class "*XamlAgentToolsTests"`.
- **Harness** (`C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`):
  - `Redeploy.ps1` quits the Exp VS, deploys, checks the redirect and relaunches.
  - `Run-Demo.ps1 -Name X -Tag T [-Prompt ...]` writes results to `test-runs\<Name>\<Tag>` and leaves demo edits in place, so reset afterwards.
- **TAP JSON:** missing objects come back as JValue nulls; never index them with `?["x"]`, use `as JObject`.
- **Editing quirks:**
  - The edit tool often reports "closest match"; always check the result.
  - In PowerShell, don't write `$l.Insert($vi=70, ...)`.
  - Write TestPass.md with `[IO.File]::WriteAllLines`.
- **Component tests:** local net10 x86 hosting still fails (CoreCLR 0x80070057); no unit test was added for the latent logic, which depends on the live TAP.
- **Reminders for the user:**
  - Re-enable UAC.
  - PR 807376 fixes the System.Drawing.Common redirect (the Exp config is patched manually to 10.0.0.0).
  - Reset the demo repo before presenting.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - VisibilityCause and helpers at about lines 2532–2660.
  - ExplainVisibilityAsync at about lines 2660–3016: grid check around 2732, overlay call around 2803, hit-test parsing around 2908, binding failures around 2952, result around 2995.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`: lines 96–100, the "can't be clicked or seen" workflow.
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`: line 260, the explain_visibility description.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Documentation\copilot-tools.md`: line 35.
- `Q:\source\XamlAgentDemos\src\VanishingSave\`: the demo. Causes are in MainWindow.xaml lines 27–36 and 101–136, FooterSettings.cs, MainWindow.xaml.cs and CustomerViewModel.cs.
- `Q:\source\XamlAgentDemos-notes\TestPass.md` (finding #112 at line 192, run row at line 71), `process\Journal.md`, and `test-runs\VanishingSave\where1..3`, `r11`.
</important_files>

<next_steps>
- All work for the user's report is done and verified. Call task_complete with this summary:
  - The cause was explain_visibility missing latent causes behind Collapsed.
  - Fixed: latent column and overlay causes, the cause count, the JValue crash and stale binding-failure tagging, plus the skill guidance.
  - Results: where3 fixed 4/4 in about 1.75 min with 0 failed calls; r11 did too.
  - The short prompt "Where is my Save button?" is now a good demo prompt.
  - Notes commit 6cf6507.
  - Reminders: UAC, PR 807376, reset the demo repo.
- Optionally confirm that the demo repo is clean (`git -C Q:\source\XamlAgentDemos status --short`).
</next_steps>