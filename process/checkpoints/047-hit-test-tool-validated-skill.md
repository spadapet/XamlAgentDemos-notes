<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` tools in Diagnostics.dll,
- WPF TAP messages,
- a built-in skill, SKILL.md.

All 17 demo apps were tested autonomously in the fastmain Exp hive, and every run and fix was logged in the notes repo.

The current request is to use the testing feedback to propose new test cases, add new `xaml_*` tools or make the existing ones more robust, and add SKILL.md guidance that helps people write better XAML, then make the fixes. Autopilot mode is on: decide without asking, verify, then call task_complete.
</overview>

<history>
1. Earlier segments planned and implemented the tools, the skill and a test harness. All 17 demos ran, and findings #1–62 are in `Q:\source\XamlAgentDemos-notes\TestPass.md`. The previous segment fixed the paused-debugger handling and added the ColumnDefinitions hint. That work was built and deployed.

2. Current request: improvements based on the test feedback.
   - Earlier in this segment (before the last compaction), implemented:
     - the `xaml_hit_test` tool (WPF only), backed by a new TAP message, 564;
     - find_elements glob support (`*`, `?`), a `namedOnly` parameter, and `type="*"`;
     - an `xaml_interact` note that automation invoke bypasses hit testing.
   - This segment:
     - Updated copilot-tools.md: the tool row, message 564, and the WPF file list.
     - The first build hit CS0433 because `HitTestRequest` collides with an existing type in RuntimeHost. Renamed the types in all files to `ElementHitTestRequest`, `ElementHitTestResponse` and `ElementHitTestItem`. The enum member is also now `ElementHitTestRequest = 564`. The rebuild gave 0 errors.
     - Updated SKILL.md:
       - the find_elements row now covers wildcards and namedOnly;
       - a new xaml_hit_test row in the tool table;
       - a new workflow, "A control can't be clicked, or can't be seen";
       - step 4 of "Reproduce a problem" now mentions hit_test;
       - the authoring rule now points to the reference file with a "check new XAML against it" sentence.
     - Expanded `references\xaml-authoring.md` with:
       - more Bindings rules: verify paths, DataTemplate DataContext, LostFocus, TwoWay read-only throws, code-built bindings;
       - a new Layout section;
       - a new "Styles and templates" section;
       - Resources: duplicate keys, DynamicResource for theme switching;
       - Accessibility: icon buttons, real controls, ItemContainerStyle names.
     - Started KeepAwake (async shellId `keepawake`, still running). Ran Redeploy.ps1, which succeeded and relaunched VS Exp.
     - Ran GhostClicks run3. The agent used 12 xaml_hit_test calls and fixed and verified all the issues live in about 1 minute; run2 had never verified real pointer hit-testing. Its feedback:
       - hit_test was the most useful tool;
       - xaml_apply_hot_reload returned `noChange` with an empty log even though the edit was live. lastActivity was the 66-seconds-ago "Connected..." message, because incremental hot reload doesn't log per update;
       - it wanted hit_test to flag a null Background;
       - it wanted a "dead click zones" scan;
       - elements recreated by hot reload had no source location.
     - Implemented the null-background flag:
       - contract `NullBackground` with `[DataMember]`;
       - the TAP sets it for Panel, Border and Control with a null Background;
       - the host adds a summary sentence and a `nullBackground` output field.
     - Was investigating how to track the time of the last XAML hot reload apply, to fix the `noChange` ambiguity, when compaction happened.
</history>

<work_done>
All changes are uncommitted in repo `Q:\src\VS_xaml`. Files changed for this request:
- `src\Xaml\Shared\Source\XamlTapContract\Networking\XamlMessageType.cs`: `ElementHitTestRequest = 564`.
- `src\Xaml\Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs` (~637–770):
  - `ElementHitTestRequest`, `ElementHitTestItem`, and `ElementHitTestResponse`;
  - new `[DataMember] bool NullBackground` (~line 747).
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.HitTest.cs` (new):
  - FillHitTest (sets NullBackground near line 65), FillInteractiveState, FillClipping, GetClipBounds, DescribeHit, Describe.
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`: registers the observer.
- `src\Xaml\Shared\Source\WpfTap\WpfTapItems.projitems`: compile entry for the new file.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`:
  - find_elements globs and namedOnly;
  - the indexed-path hint;
  - the interact note;
  - HitTestAsync (~1391–1530), including the nullBackground summary and output field;
  - ApplyHotReloadAsync is at ~1860–1960.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`: find_elements parameters and the xaml_hit_test function.
- `src\Xaml\Diagnostics\Documentation\copilot-tools.md`: hit_test row, message 564, WPF file list.
- `SKILL.md` and `references\xaml-authoring.md`, as described in the history.
- `Q:\src\VS_xaml\.vs\copilot.proj`: a temporary traversal project (gitignored) covering RuntimeHostBase, XamlTapContract, WpfCoreTap, WpfTap (Framework) and Diagnostics.

Status:
- [x] Build of everything before the NullBackground change: 0 errors. Deployed, and GhostClicks run3 passed and verified the fixes live.
- [ ] NullBackground change: not built or deployed yet.
- [ ] apply_hot_reload `noChange` improvement: in progress.
- [ ] TestPass.md logging for run3, the new findings and proposed test cases: not done.
- Run3 artifacts are in `Q:\source\XamlAgentDemos-notes\test-runs\GhostClicks\run3\` (events.jsonl, runner.log).
</work_done>

<technical_details>
- **Build** (run from `Q:\src\VS_xaml`; check `.vs\diag.txt` for " 0 Error(s)"):
  ```
  . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project .vs\copilot.proj -NoRestore -NoProjectReferences *> .vs\diag.txt
  ```
- XamlJsonData.cs is compiled into RuntimeHostBase, XamlTapContract and WpfTap. Diagnostics sees types from both RuntimeHost and RuntimeHostBase, so new contract type names must not collide with RuntimeHost types. `HitTestRequest` already existed; hence the ElementHitTest* prefix.
- **Deploy:** `& "$h\Redeploy.ps1"`, where `$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`. It:
  - closes VS;
  - deploys elevated, including the WpfTap Core/Framework DLLs and the contracts;
  - patches the System.Drawing redirect to 10.0.0.0 in `C:\vs\fastmain\Common7\IDE\devenv.exe.config` (temporary until PR 807376);
  - relaunches `devenv /rootsuffix Exp`.

  Wait about 60 s before running a demo.
- **Run a demo:** `& "$h\Run-Demo.ps1" -Name X -Tag runN`. It resets the repo, starts the app, sends the prompt from prompts.json, then the standard 7-question feedback follow-up. Output goes to `Q:\source\XamlAgentDemos-notes\test-runs\<Name>\<Tag>`. For a tool timeline use `node $h\peek.js <events.jsonl>`. Read assistant messages from events.jsonl (`type=assistant.message`, `data.content`) and tool results (`tool.execution_complete`, `data.result.content`).
- **Lock detection:** use OpenInputDesktop (via Add-Type user32). LogonUI is a false signal over RDP. The desktop was usable this segment.
- **Hot reload logging:** incremental XAML hot reload (applied while editing) writes nothing to the IHotReloadLogger, so XamlHotReloadLogBuffer gets no "applied" entry. As a result, ApplyHotReloadAsync's `lastActivity` can show a stale "Connected..." message.
- **Planned fix for `noChange`:** subscribe to `host.HotReloadProcessingInformation.Changed`. It's an `IMarkupChangeProcessingInformation` (in RuntimeHostBase `Pipeline\ChangeScope`). It has `event EventHandler Changed`, `IsProcessing` and `ProcessingStartTime`, and fires when processing starts and stops. Record a static "last apply started/ended" time (for example in XamlHotReloadLogBuffer, or a new static tracker hooked in `GetHostAsync`, XamlAgentService.cs line 73). Then report `lastXamlApply.secondsAgo` in the noChange result and in xaml_get_hot_reload_status, and change the note so a recent apply after the edit confirms the edit was applied. You need to confirm that IMarkupChangeProcessingInformation exposes `Changed` (the abstract class does).
- **Other GhostClicks run3 feedback, open ideas:**
  - a window-wide "dead click zones" scan tool;
  - elements recreated by hot reload lose their source location (related to #14).
- **Earlier open ideas:** #5 ColumnDefinition widths, #14 recreation info, #35 inactive triggers, #40 markup vs code Local values, #50 enum names and a virtualization report, #56 which DataTemplate was chosen, #58 mockup diff, a resize-window tool.
- **TAP compatibility:** gate on DiagnosticBits.SupportsAgentTools. Hit test is WPF-only; the host checks the platform first.
- **Writing files:** TestPass.md via `[IO.File]::WriteAllLines` (UTF-8, no BOM). XamlAgentService.cs: no BOM, CRLF.
- The edit tool fuzzy-matches lines, so verify results.
- Skill examples must use generic names, not demo names.
- **Git:** never push, rebase or amend. Offer a single local commit at the end.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Implementation of every tool: HitTestAsync ~1391–1530, ApplyHotReloadAsync ~1860–1960 (the noChange note ~1946), GetHostAsync line 73.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlHotReloadLogBuffer.cs`
  - Static ring buffer of the hot reload log; a possible place for the last-apply timestamp.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.HitTest.cs`
  - TAP hit-test logic.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs` (~637–770)
  - Hit-test contract.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\skills\xaml-diagnostics\SKILL.md` and `references\xaml-authoring.md`
  - Skill content, updated this segment.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Documentation\copilot-tools.md`
  - Tool and TAP docs.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\RuntimeHostBase\Pipeline\ChangeScope\MarkupChangeProcessingInformation.cs`
  - The Changed event used for apply tracking.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`
  - Results table, findings #1–62, the Pending section at the end. Needs run3 plus the new findings.
</important_files>

<next_steps>
1. Implement last-apply tracking:
   - Subscribe once to `host.HotReloadProcessingInformation.Changed` and record the start and end times of the last XAML apply.
   - Expose it in ApplyHotReloadAsync's noChange result (`lastXamlApply`) and in xaml_get_hot_reload_status.
   - Update the note.
   - Optionally mention in the hint that elements recreated by hot reload may have no source location.
2. Rebuild `.vs\copilot.proj` until it reports 0 errors, then Redeploy.
3. Optionally re-run GhostClicks (run4) to confirm nullBackground and lastXamlApply. Make sure the desktop is unlocked and KeepAwake is running (shellId `keepawake`).
4. Log in TestPass.md:
   - the GhostClicks run3 row (verified live with hit_test, about 1 min);
   - findings #63+: the hit_test tool, find_elements globs and namedOnly, the interact note, the CS0433 rename, nullBackground, noChange/lastXamlApply, the skill authoring additions;
   - a "Proposed new test cases" section: click-through overlay, disabled command CanExecute, element clipped by a ScrollViewer, derived Window/Button discovery, paused debugger (paused2), code-built bindings without source, DataTemplate selection mismatch, hot reload rude edit, multi-window/multi-app, null-background row;
   - remaining tool ideas: dead-click-zone scan, #5, #14, #35, #40, #50, #56, #58, resize window.
5. Stop KeepAwake and delete `.vs\copilot.proj`.
6. Wrap up:
   - Remind the user to re-enable UAC, that the redirect patch is temporary until PR 807376, and about the XAML language service assert.
   - Offer a single local commit.
   - Ask about updating skills (writing-skills).
   - Call task_complete with a summary answering all three questions: new test cases, new or more robust tools, and SKILL.md XAML-authoring additions.
</next_steps>