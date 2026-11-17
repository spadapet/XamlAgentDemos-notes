<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` tools in Diagnostics.dll, backed by TAP messages for WPF, UwpTap (WinUI/UWP) and MauiTap.
- A built-in skill (SKILL.md).

Everything is tested autonomously in the fastmain Exp hive. A harness drives the WPF demo apps in `Q:\source\XamlAgentDemos` through Copilot Chat, and every run is logged in the notes repo `Q:\source\XamlAgentDemos-notes`.

**Current request:** the user found that plain VS Copilot (no xaml tools) fixed BindingStorm, VanishingSave and CrispPixels just by reading source. They asked for new realistic, visual demo projects that TRULY can't be solved without the new tools.

**Rules:**
- Autopilot is on: decide without asking, verify the work, then call task_complete.
- Never push, rebase or amend. Add demo-repo and notes-repo work as new local commits only.
- VS repo changes stay uncommitted.
</overview>

<history>
1. **Earlier segments** (see checkpoints):
   - Planned and implemented the tools, the skill and the harness.
   - Ran 17 demos and fixed findings #1–116 (including output compaction and the DPI fixes).
   - Recommended VanishingSave as the team demo.
   - The last finding logged is #116 (notes commit 53f49b8).

2. **Current request: demos that truly need the tools.**

   **Attempt 1: binary-only vendor kit.** Built `Contoso.UI.Kit.dll`; its source is in the notes repo `design-source\ContosoKit`, and only the DLL is in the demo repo's `lib\`. Three demos:
   - **TeamStrip:** the kit's PeopleStrip item template binds to DisplayName/Initials/AvatarColor/Role, but the app model has Name/Role/Email. Shows grey circles with only roles.
   - **DeadFollow:** the ActionCard template has a `PART_Sheen` Border (#01FFFFFF) covering content, so the Follow button can't be clicked. The correct fix is the `Actions` slot.
   - **KitToolbar:** the kit's implicit Button style sets MinWidth=88, MinHeight=36, Padding=16,6 and Margin=4. The app's IconButton is BasedOn it with Width=36, but MinWidth wins, so the toolbar is clipped.
   - Fixed a kit bug: the PeopleStrip style needed a Template setter with ItemsPresenter. Verified all three repro via `--snapshot` and `--trace-bindings`.
   - Committed to the demo repo as c2a07d6.
   - **Static-only baselines** (general-purpose subagents with read and terminal access, no app access) **solved ALL THREE** by reverse-engineering the DLL: reflection, ResourceReader on `g.resources`, BAML string extraction, and `Application.LoadComponent` plus XamlWriter on the theme. They gave 75–90% confidence and correct diffs.
   - Caveat: my prompt asked "whether you inspected the DLL", which may have nudged them.
   - Conclusion: anything shipped on disk can be reverse-engineered, so binary-only is insufficient.

   **Pivot: the root cause exists only in live process memory (user-entered data).**
   - **NewCustomer:** a form with Full name/Email/Phone/Country/Postal/Company. Save CanExecute requires all of these regexes to pass, and there's no error UI. The pre-script fills valid-looking values, but the phone number is `+1 425 555 0142` with NBSPs (U+00A0), so PhoneRegex `^\+?[0-9 ()\-]{7,20}$` fails and Save stays disabled.
   - **Timesheet:** Mon–Fri hours at 8 each, bound as doubles with UpdateSourceTrigger=PropertyChanged. The pre-script sets Wednesday to "7,5", which en-US parses as 75. The textbox redisplays "75", the total is 107 h, and the overtime banner shows.
   - Verified both repros via UIA: Save enabled=False, and the total reads "107 h".
   - Committed to the demo repo as 9d04668.
   - Started two neutral static baselines in the background (no DLL hint; told not to touch the running process):
     - baseline-newcustomer: agent_id 6c48d671-6e09-4297-b04c-9c83fe30d612
     - baseline-timesheet: agent_id ee45ed2f-eedb-4289-89db-c88a02931e0c
     - Results not yet read.
   - Concern: Timesheet may be statically deducible (107 − 32 = 75 → "7,5"), but the user's prompt gives no numbers.

   **Tool gap found and being fixed:** Newtonsoft emits NBSP raw, so the model can't distinguish it from a space.
   - Added `EscapeInvisibleCharacters` to XamlAgentService.
   - Restructured `CompactResult` to escape after compaction, because JObject parse/ToString would undo earlier escapes.

   **Exp VS:** launched (`C:\vs\fastmain\Common7\IDE\devenv.exe /rootsuffix Exp Q:\source\XamlAgentDemos\XamlAgentDemos.sln`) and New-ChatThread is done. However, the .sln was later modified by New-DemoApp (NewCustomer/Timesheet were added while VS was open), so VS may show a reload prompt or not have the new projects loaded.
</history>

<work_done>
**Demo repo** `Q:\source\XamlAgentDemos` (local commits, not pushed):
- c2a07d6:
  - `lib\Contoso.UI.Kit.dll`
  - `src\TeamStrip\` (TeamMember.cs, TeamViewModel.cs, MainWindow.xaml, App.xaml merges the kit theme)
  - `src\DeadFollow\` (DiscoverViewModel.cs with Creator/ToggleFollowCommand; MainWindow.xaml, Height 330)
  - `src\KitToolbar\` (App.xaml IconButton style; MainWindow.xaml with 7 MDL2 icon buttons, Width=480)
  - .sln updated
- 9d04668:
  - `src\NewCustomer\` (CustomerFormViewModel.cs with GeneratedRegex validators; MainWindow.xaml with x:Name FullNameBox/EmailBox/PhoneBox/CountryBox/PostalCodeBox/CompanyBox/SaveButton)
  - `src\Timesheet\` (TimesheetViewModel.cs with DayEntry; MainWindow.xaml with TextBox AutomationProperties.Name=Day, Total, overtime banner)
- Files were normalized to CRLF with a UTF-8 BOM. Without that, git refuses with "LF would be replaced by CRLF".

**Notes repo:** `design-source\ContosoKit\` (csproj, Controls.cs, Themes\Generic.xaml, Themes\Contoso.xaml) plus bin/obj output. **Not committed yet**; check the notes `.gitignore` before committing so bin/obj stay out.

**Harness** (session `files\harness`): new `pre-NewCustomer.ps1` and `pre-Timesheet.ps1`, which set values via UIA ValuePattern.

**VS repo** (uncommitted) `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`:
- `CompactResult(json)` is now `=> EscapeInvisibleCharacters(CompactJson(json))`; the old body was renamed to private `CompactJson` (~line 921).
- New `EscapeInvisibleCharacters` and `IsInvisibleCharacter` (~977–1010). They escape U+00A0, U+00AD, U+180E, U+3000, U+FEFF, U+2000–200F, U+2028–202F and U+2060–206F as `\uXXXX`.
- **NOT yet built or tested.**

**Status:**
- [x] Vendor kit demos built, committed and baselined (statically solvable)
- [x] NewCustomer and Timesheet demos built, verified and committed
- [ ] Read the NewCustomer/Timesheet baseline results
- [ ] Build Diagnostics, add a unit test for the escaping, run the tests, redeploy
- [ ] Add prompts to prompts.json and run the harness with tools
- [ ] Log findings in the notes repo
- [ ] Decide the fate of the vendor kit demos
- [ ] Answer the user
</work_done>

<technical_details>
**Key insight for the user:** strong models with a terminal can reverse-engineer anything on disk: source, compiled BAML (strings are plain ASCII in the DLL) and themes via LoadComponent. Problems that truly need runtime tools are:
- live, in-memory state: user-typed or pasted data and interaction history
- environment: DPI, theme, fonts, culture
- verification of a fix in the running app (the static baselines only reached 75–90% confidence)

Even then, models can often guess a generic hardening fix. The tools' unique value is the specific "why" plus certainty plus live verification.

**WPF behaviour:**
- In WPF, MinWidth overrides Width.
- A default style in generic.xaml for an ItemsControl subclass needs its own Template.
- Binding a double with en-US: "7,5" parses as 75 (thousands separator), not as a conversion error, and the TextBox re-displays "75".

**JSON escaping:** `CompactResult` is applied in `XamlDiagnosticsFunctionProvider.RunAsync` (~line 468: `LimitSize(CompactResult(JsonConvert.SerializeObject(result, JsonSettings)))`). Escaping must come after the JObject round trip.

**Build** (cwd must be the repo root):
```
cd Q:\src\VS_xaml; [Environment]::CurrentDirectory='Q:\src\VS_xaml'; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\x.txt
```
- Then check `.vs\x.txt` / the binlog for success.

**Tests:** `out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\DesignTools.Tests.Unit.XamlDiagnostics.exe -class "*XamlAgentToolsTests"` (22 existing tests). Test file: XamlAgentToolsTests.cs.

**Harness:**
- `Redeploy.ps1` runs DeployToVs. Devenv may not relaunch; if so, start it manually and wait about 110 s, then `Import-Module Harness.psm1; New-ChatThread`.
- `Run-Demo.ps1 -Name X -Tag T [-NoFollowUp] [-Prompt '...']` runs `pre-<Name>.ps1` automatically. Prompts come from `prompts.json` keyed by demo name. Output goes to `notes\test-runs\<Name>\<Tag>`.
- `Reset-Demos` does `git checkout` + `git clean -fdq`, so demos must be committed.

**PowerShell quirks:**
- Stop-Process requires a literal `-Id <number>`. Use `$p.CloseMainWindow()` instead.
- Demo apps build with `dotnet build` (outside the VS repo); output goes to `src\<n>\bin\Debug\net10.0-windows\<n>.exe`.
- DemoHost switches: `--snapshot file.png`, `--trace-bindings file.txt`, `--width`/`--height`.

**Open questions:**
- Do the property tools return VM string values (e.g., `DataContext.Phone`) with the NBSP intact from the TAP?
- Do binding failures catch anything in Timesheet? Probably not, since the parse succeeds.
</technical_details>

<important_files>
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`**
  - Main tool logic. Changed CompactResult/CompactJson and added EscapeInvisibleCharacters (~915–1010).
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`**
  - Tool definitions; RunAsync serialization at ~468.
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\skills\xaml-diagnostics\SKILL.md`**
  - Should gain a note: a `\u00A0` (etc.) in a value means an invisible character, often pasted; read view-model values via `DataContext.X`.
- **`Q:\source\XamlAgentDemos\src\NewCustomer\*`, `src\Timesheet\*`**
  - The new runtime-state demos.
- **`Q:\source\XamlAgentDemos\src\TeamStrip|DeadFollow|KitToolbar\*`, `lib\Contoso.UI.Kit.dll`**
  - The vendor-kit demos (shown to be statically solvable).
- **`Q:\source\XamlAgentDemos-notes\design-source\ContosoKit\`**
  - The kit source (uncommitted).
- **`Q:\source\XamlAgentDemos-notes\TestPass.md`, `process\Journal.md`**
  - Findings log; the next finding is #117. Log the baseline results and the NBSP escaping there.
- **Harness** `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness\`
  - Run-Demo.ps1, Harness.psm1, prompts.json, pre-NewCustomer.ps1, pre-Timesheet.ps1.
</important_files>

<next_steps>
1. **Read the baselines.** Use read_agent on 6c48d671-6e09-4297-b04c-9c83fe30d612 (NewCustomer) and ee45ed2f-eedb-4289-89db-c88a02931e0c (Timesheet). Check whether they identified the NBSP / "7,5"→75 cause specifically.
2. **Build and test the escaping.**
   - Build Diagnostics.csproj.
   - Add a focused test in XamlAgentToolsTests.cs: CompactResult turns `"+1\u00A0425"` into the literal `\u00A0` escape, the JSON stays valid, and normal text is unchanged.
   - Run the tests.
   - Add the SKILL.md note about invisible characters.
3. **Redeploy** (Redeploy.ps1), and make sure the Exp VS has the updated .sln with NewCustomer/Timesheet loaded. Relaunch devenv if needed.
4. **Run the harness with tools.** Add prompts to prompts.json:
   - NewCustomer: "In my running app I filled in the new customer form and everything looks valid, but Save stays disabled. Find out why and fix it so what I entered can be saved."
   - Timesheet: "I corrected one day in my running timesheet and now the total is way too high and it says I need overtime approval. I didn't work overtime. Find out why and fix it."
   - Optionally also run TeamStrip/DeadFollow/KitToolbar with tools.
   - Then `Run-Demo.ps1 -Name NewCustomer -Tag run1` etc.
5. **If baselines solve Timesheet statically,** consider dropping it or another design, such as runtime layout from user interaction (e.g., a widget board where user-dragged widgets overlap and block clicks, found via hit_test).
6. **Log in the notes repo** (TestPass.md/Journal.md finding #117+):
   - Static baselines beat the binary-kit demos.
   - The pivot to runtime state.
   - NBSP escaping.
   - Commit the notes repo (including ContosoKit source, excluding bin/obj) as a new local commit.
7. **Reset the demo repo** to committed state.
8. **Answer the user** (task_complete), honestly:
   - Anything on disk is reverse-engineerable.
   - Which demos truly require tools (live user input / runtime state, plus verification), with baseline evidence.
   - Recommend the best demo (likely NewCustomer: the invisible NBSP is found only via live values) and how to present it. The presenter pastes a phone number containing NBSP; consider putting demo input text in the notes repo.
</next_steps>