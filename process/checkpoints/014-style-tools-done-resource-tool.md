<overview>
The user (@spadapet) wants Copilot AI to have access to every Visual Studio XAML Diagnostics feature, so models can diagnose, debug and fix running XAML apps through VS and the injected TAP. That covers the Live Visual Tree, Live Property Explorer, Live Preview images, binding failures, the accessibility checker, Hot Reload, app/platform discovery, and why a feature is unavailable.

The approved `plan.md` in the session folder is being built as a prototype:
- in-proc Copilot agent-mode tools (`xaml_*`) plus a built-in skill, all in the Diagnostics DLL;
- new TAP messages that only run when the TAP reports the capability.

WPF, WinUI/UWP and MAUI TAP support for 560/561 is done, and so are the Tier 1 style tools. Tier 2 resource tools (562/563) are in progress. Docs and a single local commit remain.
</overview>

<history>
1. **Earlier segments**
   - Planned and implemented:
     - 18 `xaml_*` tools, the skill and its references, and Copilot registration;
     - the hot reload log buffer;
     - the 560/561 contract and the `SupportsAgentTools=0x20` capability bit;
     - the WPF TAP service;
     - the in-app Copilot re-route;
     - unit tests and docs.
   - Answered the user's questions on availability (`FirstPartySkills`, `AllFromProviderTool`), the tool inventory, completeness, the legacy toolbar re-route, and 16 scenarios.
   - The user agreed to add style and resource tools (Tier 1 and Tier 2) before the commit.
   - UwpTap 560/561 now links: Casablanca.StaticCrt is built, and the WinUI3 TAP is built with project references.
   - MauiTap 560/561 is done.
   - All managed projects were rebuilt, and 36/36 unit tests passed.

2. **This segment: Tier 1 style tools (done)**
   - Added to `XamlAgentService.cs` (~698-959, after `SetElementPropertyAsync`):
     - `StyleSourceKinds`
     - `DescribeValueSource`
     - `GetPrecedenceAdvice`
     - `GetElementStylesAsync(elementId)`
     - `ExplainPropertyValueAsync(elementId, propertyName)`
     - `GetWinningValues`
     - `DescribeSourceShort`
     - `GetStyleKeyAsync`, which resolves x:Key through `host.MarkupDocumentManager.FindResourceAsync(endpoint.Platform, source.SourceInfo)` the same way LPE does.
   - Added `using Microsoft.VisualStudio.DesignTools.Xaml.LanguageService.ResourceResolver;` (sorted before `Microsoft.VisualStudio.Shell`).
   - Added the `xaml_get_element_styles` and `xaml_explain_property_value` tools (NotRequired) to `XamlDiagnosticsFunctionProvider.cs`, after `xaml_get_element_properties`.
   - Diagnostics.csproj built successfully.
   - SQL todos: `style-tools-tier1` is done; `resource-tools-tier2` is in_progress.

3. **This segment: Tier 2 resource tools (in progress)**
   - **Contract**
     - `XamlMessageType.cs`: added `FindResourceRequest = 562` and `GetResourceDictionariesRequest = 563`.
     - UwpTap `XamlMessageType.h`: same constants, and removed the stale "Not implemented by UwpTap yet" comments.
     - `XamlJsonData.cs`, after `ElementAutomationActionResponse`, added:
       - `FindResourceRequest{long Handle; string Key}` (Handle 0 = app)
       - `FindResourceResponse : ResponseWithError{bool Found; string Theme; List<ResourceDefinitionInfo> Definitions}`
       - `ResourceDefinitionInfo{Key, Scope, OwnerHandle, OwnerType, OwnerName, DictionaryPath, DictionarySource, ValueType, Value, SourceInfo SourceInfo, bool Effective}`
       - `ResourceDictionariesRequest{long Handle; bool IncludeKeys; int MaxKeysPerDictionary}`
       - `ResourceDictionariesResponse : ResponseWithError{string Theme; List<ResourceScopeInfo> Scopes}`
       - `ResourceScopeInfo{Scope, OwnerHandle, OwnerType, OwnerName, ResourceDictionaryInfo Dictionary}`
       - `ResourceDictionaryInfo{Path, Source, Type, int KeyCount, List<string> Keys, SourceInfo SourceInfo, List<ResourceDictionaryInfo> MergedDictionaries, List<ResourceDictionaryInfo> ThemeDictionaries}`
   - **WPF TAP**
     - Made `TapAgentToolsService` partial and registered the 562/563 observers in its constructor.
     - Created `WpfTap\AgentTools\TapAgentToolsService.Resources.cs`:
       - Scopes are walked in lookup order: element Resources (using the internal `HasResources` via reflection so empty dictionaries aren't created), Style.Resources, Control Template.Resources, then parents (logical → visual → TemplatedParent), then Application.
       - Merged dictionaries are searched in reverse.
       - The effective entry is the one `ReferenceEquals` the `TryFindResource` result. If nothing matches, a synthetic "Theme" definition is added.
       - `{x:Type X}` keys are supported.
       - Values are described in a short form, capped at 256 chars.
       - `SourceInfo` comes from `objectIdentityService.GetSourceInfo(value)`.
     - Added the file to `WpfTapItems.projitems`.
     - XamlTapContract, WpfTap and WpfCoreTap **all built successfully**. The WPF TAPs compile `XamlJsonData.cs` directly via a projitems link.
   - **MAUI TAP**
     - Created `MauiTap\AgentTools\TapAgentToolsService.Resources.cs` as a partial class:
       - Scopes come from the `Element.Parent` chain using `IResourcesProvider.IsResourcesCreated`, then Application.
       - Within a dictionary: own Keys, then the private `_mergedInstance` (Source) via reflection, then MergedDictionaries in reverse.
       - The first definition is marked Effective.
       - Theme = `Application.Current.RequestedTheme`.
     - **Not yet compiled.** Known issues to fix:
       - `TryGetResourceContext` uses `target is IApplication`, which is ambiguous between Maui's `IApplication` and the MauiTap wrapper `Microsoft.VisualStudio.DesignTools.MauiTap.VisualTreeService.VisualTree.IApplication`. Replace it with a check on `handle == Constants.ApplicationHandle` (`Constants.ApplicationHandle = 1`, in `Microsoft.VisualStudio.DesignTools.TapContract.Utility`), or `target is Application`.
       - The main `MauiTap\AgentTools\TapAgentToolsService.cs` class is still `internal sealed class`. It must become `partial`, and the 562/563 registrations must be added to its constructor.
       - Possible nullability warnings, e.g. `request.MaxKeysPerDictionary` after `request?.`.
</history>

<work_done>
**Done and building**
- Diagnostics `AgentTools\*`:
  - `XamlAgentService.cs` (now including the Tier 1 methods)
  - `XamlDiagnosticsFunctionProvider.cs` (now 20 tools)
  - `XamlDiagnosticsSkillsProvider.cs`
  - `XamlHotReloadLogBuffer.cs`
  - `XamlAgentImaging.cs`
  - `XamlAgentException.cs` (has the `PropertyNotFound` code)
  - `XamlInAppCopilotExtension.cs`
  - the skill files
- Contract: 560-563 in the C# and .h files, plus the payloads in `XamlJsonData.cs`.
- WPF TAP: 560-563 (`TapAgentToolsService.cs` plus the `.Resources.cs` partial). WpfTap and WpfCoreTap build.
- UwpTap: 560/561 only. It builds and links for WinUI3 and UWP StaticCrt x64.
- MauiTap: 560/561 build. The 562/563 partial file exists but is unfinished and uncompiled.
- Host capability plumbing, the Copilot repo registration, and unit tests (`Test\Unit\AgentTools\XamlAgentToolsTests.cs`).

**Remaining**
- [ ] Finish MauiTap 562/563, then build.
- [ ] UwpTap 562/563 native handlers.
- [ ] Host: `xaml_find_resource` and `xaml_get_resource_dictionaries` in the service and provider, gated by `ThrowIfAgentToolsUnsupported`.
- [ ] Rebuild everything and run the tests.
- [ ] Docs.
- [ ] Commit.
- [ ] Ask the user about skill updates.
</work_done>

<technical_details>
**Build**
- Command:
  ```
  cd Q:\src\VS_xaml; $env:PSModulePath = "$env:ProgramFiles\WindowsPowerShell\Modules;$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules"; & src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project <proj> -NoProjectReferences [-NoRestore] [-Platform x64] *> .vs\<name>.txt
  ```
- Then `Select-String` the output for `": error |Build succeeded|Build FAILED"`. Don't pipe the build into `Select-Object -First`.
- Project paths:
  - `src\Xaml\Shared\Source\XamlTapContract\XamlTapContract.csproj`
  - `WpfTap\Framework\WpfTap.csproj`
  - `WpfTap\Core\WpfCoreTap.csproj`
  - `MauiTap\MauiTap.csproj` (needs restore)
  - `src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj`
  - `src\Xaml\Diagnostics\Test\Unit\Unit.csproj`
- UwpTap: `UwpTap.StaticCrt.WinUI3.vcxproj` and `UwpTap.StaticCrt.vcxproj` with `-Platform x64`.
- Managed build order: RuntimeHostBase → DiagnosticsBase → TapContract/XamlTapContract → WpfTap → WpfCoreTap → DiagnosticsMobile → Diagnostics.
- Tests:
  ```
  src\Xaml\Scripts\Test-Xaml.ps1 -Suite diagnostics -Filter "XamlAgentTools,DiagnosticPlatform,HostDebugger,InAppCopilot"
  ```
  The filter is comma-separated substrings.

**Property chain semantics**
- Sources are cached in precedence order, so a lower `PropertyChainIndex` means higher precedence (WPF `PropertyService.HasPropertyBeenSetWithHigherPrecedenceValue`). `Overridden=true` means the value lost.

**UwpTap native patterns** (`UwpTap.cpp`)
- Handlers have the form `value Handler(value request)` with cpprest JSON: `request.at(L"Handle").as_number().to_int64()`, `ToJSON(...)`, `value::array(...)`.
- They're registered at ~299 with `m_protocolHandler.Register(XamlMessageType::X, this, &WindowsXamlDiagnosticsTap::HandleX)` and declared in `UwpTap.h`.
- UI work goes through `WinrtRunOnUIThread(GetDispatcher(ObjectIdentifier(handle)), DispatcherPriority::Normal, [&]{...})`, with `m_identityService->TryGetObject<xaml_winrt::UIElement>(id)`.
- Helpers in an anonymous namespace at ~1485: `CurrentExceptionMessage`, `FormatDouble`.
- JSON field names must match the C# DataMember names exactly (PascalCase).

**Planned UwpTap 562/563 approach**
- Walk `FrameworkElement.Resources()` up `VisualTreeHelper.GetParent`, then `Application::Current().Resources()`.
- Within each dictionary: own key (`HasKey(box_value(key))`), then `ThemeDictionaries` for `ActualTheme` ("Light"/"Dark", then "Default"), then `MergedDictionaries` in reverse. `Source()` gives the URI.
- Value type: `winrt::get_class_name`.
- No SourceInfo; the host can map the owner element instead.
- Mark the first definition as effective, and report Theme.

**Tool and error conventions**
- Capability gating: `XamlAgentService.ThrowIfAgentToolsUnsupported`. A TAP that doesn't know a message never replies, so `SendTapMessageAsync` times out.
- Tools return Newtonsoft JSON with nulls omitted.
- Errors are `{error, message, hint}`; a declined confirmation is `USER_DECLINED`.
- Element IDs look like `a1:<handle>`.
- `FindElement(host, elementId)` must run on the UI thread.
- `SourceResolver.Resolve(SourceInfo)` returns `{file, line, column}`.

**Other gotchas**
- MauiTap `GetObject(1)` returns the IApplication wrapper.
- The `VisualElement` name is ambiguous in MauiTap; it's aliased there.

**Constraints**
- Never push, rebase or amend. Make one local commit via `git -C Q:\src\VS_xaml` with trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Use the dashed copyright header.
- At the end, ask the user about skill updates. Candidates:
  - the PSModulePath fix
  - `Select-Object -First` orphaning MSBuild
  - UwpTap link dependencies: build with references
  - Test-Xaml filter commas
  - the capability-bit pattern
  - `FirstPartySkills`
</technical_details>

<important_files>
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - The host façade.
  - Tier 1 methods at ~698-959; `FindElement` at ~141; `SendTapMessageAsync` at ~167; bounds and interaction after ~961; `SourceResolver` near the end.
  - Add `FindResourceAsync` and `GetResourceDictionariesAsync` here. Resolve each definition's SourceInfo and owner element ID via `GetElementId`/`TreeContainer`.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - The tool definitions. The style tools are at ~109-128.
  - Add `xaml_find_resource(elementId or app, key)` and `xaml_get_resource_dictionaries(app|elementId, includeKeys)`.
- `src\Xaml\Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs`: the new payloads at ~670-830.
- `src\Xaml\Shared\Source\XamlTapContract\Networking\XamlMessageType.cs` (~338-348) and `UwpTap\XamlMessageType.h` (~334-342): the 562/563 constants.
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs` and `TapAgentToolsService.Resources.cs`: WPF 562/563, done.
- `src\Xaml\Shared\Source\MauiTap\AgentTools\TapAgentToolsService.Resources.cs`: new, needs fixes. In the main `TapAgentToolsService.cs`, make the class partial and register 562/563 (constructor ~40-48).
- `src\Xaml\Shared\Source\UwpTap\UwpTap.cpp` / `UwpTap.h`: add the native 562/563 handlers (registration ~299; handlers ~1581+).
- Docs:
  - `src\Xaml\Diagnostics\Documentation\copilot-tools.md`
  - `AgentTools\skills\xaml-diagnostics\SKILL.md` and its references
  - These still say WPF-only and are missing the 4 new tools.
- `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\plan.md`: the plan with the style and resource addendum.
</important_files>

<next_steps>
1. **MauiTap**
   - Fix the `IApplication` ambiguity: use `handle == 0 || handle == Constants.ApplicationHandle || target is Application`, with `using Microsoft.VisualStudio.DesignTools.TapContract.Utility;`.
   - Make the main class `partial`.
   - Register 562/563 in the constructor.
   - Build `MauiTap.csproj` with restore and fix any errors or nullable warnings.
2. **UwpTap**
   - Implement `HandleFindResource` and `HandleGetResourceDictionaries`: declare them in `UwpTap.h`, register them at ~299, and write the bodies in `UwpTap.cpp`.
   - Build the WinUI3 and UWP StaticCrt TAPs for x64.
3. **Host**
   - Add the `XamlAgentService` methods, gated by `ThrowIfAgentToolsUnsupported`. They should map `OwnerHandle` to element IDs, resolve `SourceInfo`, and return a hint when the key isn't found.
   - Add the 2 tools to the provider.
   - Optionally add unit tests.
   - Rebuild Diagnostics and Unit, then run the tests.
4. **Docs**: update `copilot-tools.md`, `SKILL.md` and references to cover multi-platform support for bounds/interact and the 4 new style/resource tools, with workflow recipes such as "why isn't my style applying".
5. **Wrap up**
   - Mark the SQL todos done.
   - Run `git -C Q:\src\VS_xaml status` and make the single local commit with the trailers (no push).
   - Summarize for the user, then ask about the skill updates.
</next_steps>