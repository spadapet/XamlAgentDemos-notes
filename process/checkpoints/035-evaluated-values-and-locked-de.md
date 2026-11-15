<overview>
The user is exposing Visual Studio XAML Diagnostics to Copilot through 22 `xaml_*` tools in Diagnostics.dll and a deployed `xaml-diagnostics` skill. These are exercised with 17 WPF demo apps in `Q:\source\XamlAgentDemos`.

The current request is to autonomously test every demo in the running fastmain VS, iterating as long as results keep improving. For each demo:
- build, run and prompt Copilot Chat
- ask follow-up questions and save the logs
- fix the skill and tools
- reset the repo
- record all changes and findings in notes

I drive VS with a PowerShell/UIA/DTE harness. The DEMO.md answer keys in `Q:\source\XamlAgentDemos-notes` are used only for grading; the chat agent never sees them.
</overview>

<history>
1. **Earlier work (prior checkpoints):**
   - Implemented the tools, skill, registration, tool Group and threading fixes.
   - Created the demos and moved the answer-key notes out of the demo repo.
   - Applied fixes from analyzing the BindingStorm log.
   - Built the harness.
   - VanishingSave run1 found 4/4.
   - ThemeBreaker run1 found 6/6, but the agent rebuilt and restarted the app because a key rename in Dark.xaml wasn't applied by hot reload.
   - Built (but did not deploy) several tool fixes: property cap, bounds clipping, the .NET Hot Reload pane tail, code hot-reload output, and modal detection.
   - Nothing is committed.

2. **This segment (continuing the autonomous test pass):**
   - **BindingStorm run1:**
     - The main turn finished, but the follow-up failed with `SendKeys.SendWait` throwing "The operation completed successfully."
     - The events log was salvaged from the session dir and the transcript rendered. The `fix.diff` was lost to the next reset.
     - Graded **10/10** using valid alternatives: an AlternationIndex ItemContainerStyle instead of the AncestorType fix, and a DataTrigger instead of a converter. The agent verified 0 failures after driving all tabs and the dialog.
   - **Hardened the harness:**
     - Added a `Send-Keys` retry wrapper.
     - Guarded the ESC SendWait.
     - Wrapped the Run-Demo follow-up in try/catch so artifacts are always saved.
   - **TestPass.md:**
     - Added rows for ThemeBreaker and BindingStorm.
     - Filled the Action column for findings 1–6 (#5, ColumnDefinition sizes, is still open).
     - Added findings 7–9 from ThemeBreaker.
     - Added a harness note about SendWait.
   - **batch1b finished:**
     - GhostClicks failed with "Autopilot not set".
     - LostWindows failed with a null-valued expression.
     - Cause: the **desktop is locked**. LogonUI is running, `CopyFromScreen` reports "handle is invalid", and quser shows Active with 13 min idle in an RDP session. UIA input is impossible until the user unlocks. I decided not to bypass the lock (e.g., tscon as SYSTEM).
   - **While blocked, implemented finding #8 (resolved values for expression properties):**
     - TAP message 528 is designer-only.
     - WPF `TapProperty.GetValue(UnderlyingValueSourcePreferred)` only special-cases bindings, so local DynamicResources already resolve. Style setters report the raw `DynamicResourceExtension` / `Binding`.
     - Added optional `EvaluatedValue` and `EvaluatedValueType` fields to `TapPropertyValue`, filled them in the WPF TAP, and surfaced `evaluatedValue` in the host tools.
     - Added skill guidance.
   - I was about to build when compaction happened. A glob found only `XamlTapContract.csproj` under `Shared/Source/{WpfTap,WpfCoreTap,XamlTapContract}`, so the WpfTap project files still need to be located (likely under a different folder name or as `.csproj` files in subfolders).
</history>

<work_done>
**Harness** (`C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness\`):
- `Harness.psm1`:
  - New `Send-Keys([string]$k)` retries SendWait 5× with Focus-Vs between attempts.
  - `Set-ChatText` uses it for `^a`/`^v`.
  - The ESC SendWait in the focus-retry loop is wrapped in try/catch.
- `Run-Demo.ps1`: the follow-up send and wait are in try/catch, logging "Follow-up ERROR".
- Other files are unchanged: Run-Batch.ps1, prompts.json, pre-ThemeBreaker.ps1, render.js, peek.js, KeepAwake.ps1. The keepawake2 shell is still running; its SendInput mouse nudges with dx=0 apparently don't prevent the lock.

**Test results:**
- `Q:\source\XamlAgentDemos-notes\test-runs\BindingStorm\run1\` contains `runner.log`, `events.jsonl` and `transcript.md`.
- GhostClicks and LostWindows have no valid runs yet.

**VS repo changes in this segment** (uncommitted, NOT built):
- `Shared\Source\XamlTapContract\TapOM\TapPropertyValue.cs`:
  - Added `EvaluatedValue` and `EvaluatedValueType`, both `[DataMember(EmitDefaultValue=false, IsRequired=false)]`.
  - `EvaluatedValueType` is "null" when the value evaluates to null.
  - Both fields are copied in `Clone()`.
- `Shared\Source\WpfTap\WpfVisualTreeService\Properties\PropertyService.cs`:
  - `InitializePropertyAndSourceCaches` now calls the new `AddEvaluatedValuesForExpressions(targetObject)` before `InitializeAccessibilityProperties`.
  - For each non-overridden cache entry where `IsExpressionValue` is true (the IsValueBindingExpression bit, or a `System.Windows.*` type name ending in Expression, Extension or Binding), it skips MetadataProperty entries and calls `property.GetValue(targetObject, ValueKind.Default)`.
  - It serializes the result with `PropertyValueHelper.GetValueAsConvertableString`, using the converter from `property.Converter ?? TypeDescriptor.GetConverter(value)`, inside try/catch.
  - It has `[SuppressMessage CA1031]`.
- `Diagnostics\...\AgentTools\XamlAgentService.cs`:
  - New `DescribeEvaluatedValue(TapPropertyValue)` returns null, "null", or "value (ShortType)".
  - `evaluatedValue` was added to the get_element_properties items, the `Summarize` output in get_element_styles, explain_property_value chain entries, and the explain_property_value top level.
  - New note: when a DynamicResource (ResourceReferenceExpression or DynamicResourceExtension) evaluates to null, the key isn't found, so use `xaml_find_resource`.
- `SKILL.md`, "A style, setter, or resource isn't applying" section:
  - Step 1 now explains `evaluatedValue`.
  - New step 6: theme dictionaries that code loads at runtime may not hot reload. Verify with `xaml_find_resource`, re-trigger the theme switch via `xaml_interact`, and only then tell the user a restart is needed.

**Earlier (prior segment) changes:** built but not deployed. They are in XamlAgentService.cs, XamlAgentImaging.cs, XamlDiagnosticsFunctionProvider.cs and SKILL.md (see TestPass.md finding actions 1–4 and 6).

**Status:**
- [x] BindingStorm graded and recorded
- [x] Harness SendWait hardening
- [x] Code written for evaluated values (TAP, host and skill)
- [ ] Build XamlTapContract, WpfTap (Framework net472 and Core) and Diagnostics
- [ ] Deploy (needs VS closed; deploy script copies the TAP DLLs too)
- [ ] GhostClicks, LostWindows and the 12 other demos. Blocked: desktop locked.
</work_done>

<technical_details>
**Locked desktop:**
- When locked, UIA SetFocus/SendKeys and CopyFromScreen ("handle is invalid") fail.
- Indicators: LogonUI.exe running; quser shows the RDP session.
- Don't bypass the lock. Wait for the user. Non-UI work (build, deploy, DTE calls) still works.

**`SendKeys.SendWait`** can throw "The operation completed successfully". It is transient, so retry.

**WPF TAP property chain:**
- `PropertyService.InitializePropertyAndSourceCaches` builds the cache in precedence order (`SourceSortOrder`). `Overridden` means a higher-precedence entry already exists.
- Local and other sources use `GetValue(UnderlyingValueSourcePreferred)`, which returns a BindingExpression for bindings and otherwise the effective value.
- Style setters report `setter.Value`, which may be DynamicResourceExtension or Binding.
- `TryGetLocalValue` returns false for Expressions.
- The caches are ThreadLocal.
- `propertyIndexHelper.GetProperty(int)` maps `Index` to `ITapProperty`.
- `ValueKind` is {Default, UnderlyingValueSourcePreferred}.

**Messages:**
- 528 `GetUnderlyingValueWithMarkupExtensionLoss` is designer-only (LocalPropertyService in WpfSurface).
- Agent messages 560–563 exist: bounds, automation action, FindResource, GetResourceDictionaries.

**DeployToVs.ps1 output paths:**
- WpfCoreTap: `netsdk\WpfCoreTap\netcoreapp3.0\Core`
- WpfTap: `netsdk\WpfTap\net472\Framework`
- XamlTapContract: `netstandard2.0`
- UwpTap is native, so the optional field is simply absent there.

**Build:**
- In one process: `cd Q:\src\VS_xaml; & src\Shared\Tools\Scripts\Prime-ForCopilot.ps1; msbuild <proj> /restore /m /v:m /nologo /clp:ErrorsOnly`.
- Diagnostics takes about 3.5 min.
- The WpfTap csproj paths still need to be found (glob for `**/WpfTap*.csproj` or `**/WpfCoreTap*.csproj` under `src\Xaml\Shared`).

**Deploy:**
- Close VS with `$dte.Quit()`.
- Run `Start-Process pwsh -Verb RunAs -Wait` with `Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1 -VSInstallPath c:\vs\fastmain -Diagnostics -NonInteractive`. UAC prompts are off.
- Relaunch `c:\vs\fastmain\Common7\IDE\devenv.exe` non-elevated. The title showed "EXP", so check the rootsuffix.
- Open `Q:\source\XamlAgentDemos\XamlAgentDemos.sln`.

**Harness facts:**
- Chat input Name is 'Ask Copilot' and supports only Text/Selection, so text is entered by paste.
- Automation IDs: `SendButton`, `createNewThread`, `ConversationModeSelector` (menu item 'Autopilot').
- The permission button is 'Allow this time'.
- Session logs: `%LOCALAPPDATA%\Microsoft\VisualStudio\CopilotCli\session-state\<id>\events.jsonl`.
- The Run-Demo reset happens at the start of the next run, so `fix.diff` is captured only if the run reaches the end.

**Conventions:**
- XamlAgentService.cs uses the fully qualified `Microsoft.VisualStudio.Shell.Package`, has no BOM, and tool bodies run on the UI thread.
- Python isn't installed; use Node.

**User constraints:**
- No push, rebase or amend; commit only if asked.
- The user wants the UAC prompt restored at the end.

**Open findings:**
- #5: ColumnDefinition sizes aren't visible.
- #7: theme-dictionary hot reload reports success when it didn't apply. Only skill guidance has been added; no detection.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Implementation of every tool.
  - Properties ~582–655 (evaluatedValue at ~626); styles Summarize ~874–883; ExplainPropertyValueAsync ~895–985 (notes ~955–980); `DescribeEvaluatedValue` ~989; bounds ~1060–1130; hot reload log and apply ~1470–1610.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\WpfVisualTreeService\Properties\PropertyService.cs`
  - WPF property chain.
  - New `AddEvaluatedValuesForExpressions` and `IsExpressionValue` ~404–474; chain builder ~355–406; `CreatePropertyChainValue` ~1075.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\XamlTapContract\TapOM\TapPropertyValue.cs`: the new optional fields, ~65–78 plus Clone.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`: the skill. The style/resource section is ~79–85.
- `...\AgentTools\XamlAgentImaging.cs`, `XamlDiagnosticsFunctionProvider.cs`: changed in the prior segment.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`
  - Results table: VanishingSave, ThemeBreaker, BindingStorm.
  - Findings 1–9 with actions.
  - Harness notes.
- `Q:\source\XamlAgentDemos-notes\src\<Demo>\DEMO.md`: the answer keys.
- Harness folder: `Harness.psm1`, `Run-Demo.ps1`, `Run-Batch.ps1`, `prompts.json`.
</important_files>

<next_steps>
1. Find the WpfTap project files (Framework and Core) and build them along with XamlTapContract and Diagnostics. Fix any compile errors, e.g. a missing `MetadataProperty` namespace or `PropertyValueHelper` access in PropertyService.
2. Deploy once the build succeeds and VS can be closed via DTE (this works even while locked):
   - Run the elevated `DeployToVs.ps1 -Diagnostics`.
   - Relaunch fastmain and open the demo solution.
3. Wait for the user to unlock the desktop:
   - Check that LogonUI is gone and `Save-VsScreenshot` works.
   - If it stays locked, call task_complete with a status summary explaining the blocker rather than bypassing the lock.
4. When unlocked:
   - Re-run GhostClicks and LostWindows (`Run-Batch.ps1 -Names ... -Tag run1`).
   - Re-run ThemeBreaker and VanishingSave as run2 to validate the fixes.
   - Then run the 12 remaining demos: A11ySweep, BugRepro, CrispPixels, DesignPolish, GermanReady, HotReloadDoctor, PixelPerfect, PrecedenceWars, ResponsiveDashboard, SlowScroll, StyleMaze, TemplateDetective.
   - Grade each against DEMO.md, update TestPass.md (results plus findings and actions), and fix tools or skill as needed.
5. Update TestPass.md finding #8's action with the evaluatedValue implementation, and finding #7 with the skill step 6.
6. At the end:
   - Stop keepawake2 and reset the demo repo.
   - Remind the user to re-enable the UAC prompt.
   - Summarize all changes.
   - Ask whether to update a repo skill (writing-skills).
</next_steps>