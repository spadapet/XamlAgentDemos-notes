<overview>
The user (@spadapet) wants every Visual Studio XAML Diagnostics feature exposed to Copilot AI, so models can diagnose, debug and fix running XAML apps through VS and the injected TAP. That covers the Live Visual Tree (LVT), Live Property Explorer (LPE), Live Preview images, binding failures, the accessibility checker, Hot Reload, app/platform discovery, and why a feature is unavailable.

The approved `plan.md` (in the session folder) is being built as a prototype:
- in-proc Copilot agent-mode tools (`xaml_*`) plus a built-in skill, all in the Diagnostics DLL;
- capability-gated new TAP messages: 560 `GetElementBounds` and 561 `ElementAutomationAction`.

WPF, WinUI/UWP and MAUI TAP support are now done. Still to do, before a single local commit:
- the style and resource tools, Tier 1 (host-only) and Tier 2 (new TAP messages);
- doc updates.
</overview>

<history>
1. **Earlier segments**
   - Planned and implemented:
     - 18 `xaml_*` tools, the skill and its references, and Copilot registration;
     - the hot reload log buffer;
     - the contract (560/561, payloads, the `SupportsAgentTools=0x20` bit reported in `TapInitialized.Status`);
     - the WPF TAP service `TapAgentToolsService`;
     - the in-app Copilot re-route;
     - unit tests and docs.
   - Answered the user's questions:
     - how the tools and skill become available in VS (`FirstPartySkills` and `AllFromProviderTool` in the Copilot repo `FirstPartyToolsProvider`);
     - the full tool inventory with inputs and outputs;
     - what's incomplete;
     - how the legacy in-app toolbar now routes through `XamlInAppCopilotExtension`;
     - 16 debugging scenarios.
   - The user agreed to add style and resource tools (Tier 1 and Tier 2) after the UwpTap and MAUI work and before the commit. This is recorded as an addendum in `plan.md`.
   - Implemented UwpTap 560/561 handlers in `UwpTap.cpp`. They compiled, but linking was blocked by a missing Casablanca lib.

2. **This segment**
   - **UwpTap linking**
     - Built `src\edev\ClientDiagnostics\Source\Common\Casablanca\StaticCrt\Casablanca.StaticCrt.vcxproj` for x64 (succeeded).
     - The link then needed `Ipc.StaticCrt.lib`, so I built `UwpTap.StaticCrt.WinUI3.vcxproj` WITH project references (with restore, x64). It succeeded.
     - Then built `UwpTap.StaticCrt.vcxproj` (`-NoProjectReferences -NoRestore -Platform x64`). It succeeded.
     - Marked the `tap-winui` todo done.
   - **Managed rebuild**
     - Rebuilt RuntimeHostBase, DiagnosticsBase, TapContract, XamlTapContract, WpfTap, WpfCoreTap, DiagnosticsMobile and Diagnostics.
     - Diagnostics failed: `DiagnosticPlatformFactory.cs` was missing `using Microsoft.VisualStudio.DesignTools.Diagnostics.TapOM;`. Added it and the rebuild succeeded.
     - Built `Test\Unit\Unit.csproj`. Ran `Test-Xaml.ps1 -Suite diagnostics -Filter "XamlAgentTools,DiagnosticPlatform,HostDebugger,InAppCopilot"`: 36/36 passed.
     - The filter is comma-separated, not a regex.
   - **MAUI TAP**
     - Created `MauiTap\AgentTools\TapAgentToolsService.cs`.
     - Registered it in the base `VisualTreeService.RegisterProtocolHandlers` before `TapInitialized` is posted, set `SupportsAgentTools` in Status, and dispose it in `Dispose`.
     - `MauiTap.csproj` builds (one `VisualElement` ambiguity fixed with an alias).
     - Marked `tap-maui` done.
   - **Tool descriptions**: updated the `xaml_get_element_bounds` and `xaml_interact` descriptions in `XamlDiagnosticsFunctionProvider.cs` from "Supported for WPF apps" to WPF/WinUI/UWP/MAUI, with MAUI caveats.
   - **Tier 1 style tools** (todo `style-tools-tier1` set in_progress)
     - Was investigating how LPE builds source categories:
       - `CategoryViewModel.InitializeSourcePropertiesAsync` ~366-400;
       - `PlatformObjectCache` computed-category insertion ~280-296;
       - `MarkupDocumentManager.FindResourceAsync` ~637.
     - No Tier 1 code written yet.
</history>

<work_done>
**Done and building**
- Diagnostics `AgentTools\*`:
  - `XamlAgentService.cs`
  - `XamlDiagnosticsFunctionProvider.cs` (descriptions updated this segment)
  - `XamlDiagnosticsSkillsProvider.cs`
  - `XamlHotReloadLogBuffer.cs`
  - `XamlAgentImaging.cs`
  - `XamlAgentException.cs`
  - `XamlInAppCopilotExtension.cs`
  - `skills\xaml-diagnostics\SKILL.md` and `references\*.md`
- Unit tests: `Test\Unit\AgentTools\XamlAgentToolsTests.cs`.
- Docs: `Documentation\copilot-tools.md` and a README link. These still say WPF-only and need updating.
- Contract:
  - `XamlMessageType.cs`
  - `XamlJsonData.cs` (~570-668: `ElementBoundsRequest`/`Info`/`Response`, `ElementAutomationActionRequest`/`Response`)
  - UwpTap `XamlMessageType.h`
  - `DiagnosticBits.cs`/`.h`
- WPF TAP: `WpfTap\AgentTools\TapAgentToolsService.cs`.
- UwpTap: `UwpTap.cpp`/`.h`. WinUI3 and UWP StaticCrt x64 now **link successfully**.
- MauiTap (**new this segment**):
  - `AgentTools\TapAgentToolsService.cs`
  - `VisualTreeService\VisualTreeService.cs`: registration, the status bit, dispose, and a `using` for AgentTools.
- Host capability plumbing:
  - `WpfDiagnosticPlatform`
  - `WinRTDiagnosticPlatform`
  - `DiagnosticPlatformFactory` (`using` fixed this segment)
  - DiagnosticsMobile `DiagnosticPlatform`
  - `HostDebuggerExtension`
  - `NonDebugProcessManager`
  - `PublicAPI.Unshipped.txt`
- Copilot repo:
  - `FirstPartyToolsProvider.cs` (tool provider and `FirstPartySkills`)
  - `files.swr`
  - `Diagnostics.csproj` content

**SQL todos**
- `tap-winui`: done
- `tap-maui`: done
- `style-tools-tier1`: in_progress
- `resource-tools-tier2`: pending
</work_done>

<technical_details>
**Build**
- Command:
  ```
  cd Q:\src\VS_xaml; $env:PSModulePath = "$env:ProgramFiles\WindowsPowerShell\Modules;$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules"; & src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project <proj> -NoProjectReferences [-NoRestore] [-Platform x64] *> .vs\<name>.txt
  ```
- Then grep the output file for `": error "`. Don't pipe the build into `Select-Object -First`; it orphans MSBuild.
- UwpTap link dependencies: Casablanca.StaticCrt and Ipc.StaticCrt. Building the WinUI3 TAP with project references (no `-NoProjectReferences`) builds them.
- Unit tests:
  ```
  src\Xaml\Scripts\Test-Xaml.ps1 -Suite diagnostics -Filter "A,B"
  ```
  The filter is comma-separated substrings. Build `src\Xaml\Diagnostics\Test\Unit\Unit.csproj` first.
- Managed build order: RuntimeHostBase → DiagnosticsBase → TapContract/XamlTapContract → WpfTap → WpfCoreTap → DiagnosticsMobile → Diagnostics. MauiTap builds with restore.
- The `DiagnosticBits` namespace is `Microsoft.VisualStudio.DesignTools.Diagnostics.TapOM` in host code, and `...TapContract.TapOM` in TAP-contract DLL consumers.

**MAUI TAP specifics**
- netstandard2.0 against MAUI 6.0.312 references, so only cross-platform MAUI APIs are available.
- The MAUI agent has its own `ProtocolHandler`/data bridge, making it a separate endpoint from the WinUI TAP, so there's no double-reply problem.
- Bounds:
  - `Maui.Platform.ViewExtensions.GetBoundingBox(view)` gives window-relative DIPs.
  - Density comes from `window.VisualDiagnosticsOverlay?.Density`.
  - Window X/Y are read via reflection.
  - Screen values are approximate (no chrome); `RootWindowHandle` is 0.
  - Requires `view.Handler?.PlatformView`.
- Actions:
  - `IButton.Pressed`/`Released`/`Clicked`, `IMenuItemController.Activate`, and `TapGestureRecognizer.SendTapped` via reflection, falling back to Command.
  - Toggle: Switch, CheckBox, RadioButton.
  - Select: RadioButton, `SelectableItemsView`/`ListView` via `BindingContext`, `TabbedPage`.
  - Expand: reflection on `IsExpanded`.
  - Set value: InputView, Slider, Stepper, Switch, CheckBox, DatePicker, TimePicker, Picker.
  - `Focus`; `ScrollIntoView` via `ScrollView.ScrollToAsync` or `ItemsView`/`ListView.ScrollTo`.
  - Patterns are reported with UIA names.
  - Work runs on the element's dispatcher via `DispatcherExtensions.Invoke`.
- `VisualElement` is ambiguous with the TapOM `VisualElement`; resolved with an alias.

**Data for Tier 1 style tools**
- `XamlAgentService.RequestPropertiesAsync(endpoint, handle, ct)` returns a `PropertyValuesHolder` with:
  - `Properties` (`TapPropertyValue`: `PropertyName`, `Value`, `ValueType`, `Type`, `DeclaringType`, `PropertyChainIndex`, `Overridden`, `SourceInfo`, `IsValueBindingExpression`, `ReadOnly`, `Index`);
  - `Sources` (`TapPropertySource`: `Handle`, `TargetType`, `Name`, `Source` (a `BaseValueSource`), `SourceInfo`).
- A property appears once per chain source. `Overridden=true` means it lost.
- `GetPropertySource(holder, property)` maps the index to its source.
- `BaseValueSource` values: Unknown=0, Default, BuiltInStyle, Style, Local, Inherited, DefaultStyleTrigger, TemplateTrigger, StyleTrigger, ImplicitStyleReference, ParentTemplate, ParentTemplateTrigger, Animation, Coercion, Accessibility.
- LPE resolves a style's x:Key when `Source==Style` and `Name` is empty: `host.MarkupDocumentManager.FindResourceAsync(endpoint.Platform, source.SourceInfo)` → `IDictionaryEntry`. If `entry.Key.Kind == ResourceKeyKind.String`, it uses `entry.Key.ToString()`. LPE first calls `ResolveRuntimeSourceInfo`/`NormalizeSourceInfo`.
- `CategoryViewModel.GetDisplayText(source)` (internal static) builds the display names.
- `SourceResolver` in `XamlAgentService` (~1270) resolves `SourceInfo` to `{file,line,col}`.
- The agent service code runs on the main thread after `SwitchToMainThreadAsync` for markup work.

**Capability gating**
- `XamlAgentService.ThrowIfAgentToolsUnsupported` gates the TAP-message tools. A TAP that doesn't know a message never replies.

**Tool output**
- Tools return JSON via Newtonsoft with null values omitted.
- Errors are `{error, message, hint}`; a declined confirmation is `USER_DECLINED`.
- Element IDs look like `a1:<handle>`.

**Constraints**
- Never push, rebase or amend. Make one local commit at the end via `git -C Q:\src\VS_xaml`, with trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Use the dashed copyright header.
- At the end, ask the user about skill updates. Candidates:
  - the PSModulePath msrustup fix
  - `Select-Object -First` orphaning MSBuild
  - WpfTap and WinUI3 need a restore
  - UwpTap link dependencies (Casablanca, Ipc): build with references
  - Test-Xaml filter commas
  - TAP-reported capability-bit pattern
  - `FirstPartySkills` for default-on skills
</technical_details>

<important_files>
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - The façade. Add the Tier 1 and Tier 2 methods here.
  - Properties ~556-623: `GetElementPropertiesAsync`, `GetPropertySource`, `RequestPropertiesAsync`.
  - Set property ~625; bounds and interaction ~700-810; `SourceResolver` ~1270.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - The tool definitions. Bounds and interact are at ~127-145.
  - Add the new style and resource tools here.
- `src\Xaml\Shared\Source\MauiTap\AgentTools\TapAgentToolsService.cs`: new MAUI 560/561 handlers. Add 562/563 here for Tier 2.
- `src\Xaml\Shared\Source\MauiTap\VisualTreeService\VisualTreeService.cs`: registration (~84), status bit (~88), dispose (~212).
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`: WPF handlers. Add Tier 2 here.
- `src\Xaml\Shared\Source\UwpTap\UwpTap.cpp`: native handlers (~1485-1827), registrations (~290), status (~301). Add Tier 2 here.
- Contract for new messages:
  - `src\Xaml\Shared\Source\XamlTapContract\Networking\XamlMessageType.cs`
  - `XamlTapContract\TapOM\XamlJsonData.cs`
  - UwpTap `XamlMessageType.h`
- LPE references for Tier 1 semantics:
  - `src\Xaml\Diagnostics\Source\Diagnostics\Tool\UI\LivePropertyExplorer\ViewModel\CategoryViewModel.cs` ~366-440
  - `Model\PlatformObjectCache.cs` ~270-296
  - `DiagnosticsBase\Markup\MarkupDocumentManager.cs` ~637
- Docs to update:
  - `src\Xaml\Diagnostics\Documentation\copilot-tools.md`
  - `AgentTools\skills\xaml-diagnostics\SKILL.md`
- `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\plan.md`: the plan with the style and resource addendum.
</important_files>

<next_steps>
1. **`style-tools-tier1`** (in progress, host-only)
   - `xaml_get_element_styles(elementId)`:
     - Group `holder.Sources` with style-like kinds (Style, BuiltInStyle, ImplicitStyleReference, StyleTrigger, DefaultStyleTrigger, TemplateTrigger, ParentTemplate, ParentTemplateTrigger).
     - For each: kind, name or key (resolve with `FindResourceAsync` on the main thread when `Name` is empty), targetType, location via `SourceResolver`.
     - Include the setters: properties with that chain index, with value and `won = !Overridden`.
     - Keep chain order as precedence.
   - `xaml_explain_property_value(elementId, propertyName)`:
     - Return all `TapPropertyValue` entries for the name across sources, in chain order, each with source kind, name, location, value and binding flag.
     - Return the winner (the non-overridden entry) and a short explanation of precedence.
   - Add the functions to the provider (NotRequired) and unit tests if feasible. Rebuild Diagnostics and Unit, then rerun the tests.
2. **`resource-tools-tier2`**
   - Add contract messages 562 `FindResourceRequest` (`{Handle, Key}` → value, value type, winning dictionary plus `SourceInfo`, shadowed definitions, theme) and 563 `GetResourceDictionariesRequest` (`{Handle?}` → tree of merged/theme dictionaries with source URI and keys). Add them to the C# and `.h` contract.
   - Implement in the WPF TAP (`FrameworkElement.TryFindResource` plus a walk of `Resources`/`MergedDictionaries`/Application/theme), MauiTap (`Element.TryGetResource`/`Resources.MergedDictionaries`, `Application.Resources`) and UwpTap (`FrameworkElement.Resources`, `ThemeDictionaries`, `Application::Current().Resources()`).
   - Add the `xaml_find_resource` and `xaml_get_resource_dictionaries` tools, gated by `ThrowIfAgentToolsUnsupported`.
   - Rebuild all TAPs and the host.
3. **Update docs**: `copilot-tools.md`, `SKILL.md` and references should cover multi-platform support and the new tools.
4. **Wrap up**
   - Mark the todos done.
   - Run `git -C Q:\src\VS_xaml status` and make the single local commit with the trailers (no push).
   - Ask the user about skill updates.
</next_steps>