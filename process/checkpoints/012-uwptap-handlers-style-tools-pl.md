<overview>
The user (@spadapet) wants every Visual Studio XAML Diagnostics feature exposed to Copilot AI, so models can diagnose, debug and fix running XAML apps through VS and the injected TAP. That covers the Live Visual Tree (LVT), Live Property Explorer (LPE), Live Preview images, binding failures, the accessibility checker, Hot Reload, app/platform discovery, and why a feature is unavailable.

The approved plan (`plan.md` in the session folder) is being built as a prototype:
- in-proc Copilot agent-mode tools (`xaml_*`) plus a built-in skill, all in the Diagnostics DLL;
- capability-gated new TAP messages: 560 `GetElementBounds` and 561 `ElementAutomationAction`.

WPF is done. The user wants WinUI/UWP and MAUI TAP support, then (newly agreed) style and resource tools Tier 1 and Tier 2, all before a single local commit.
</overview>

<history>
1. **Earlier segments**
   - Planned and implemented the plumbing: 18 `xaml_*` tools, the skill and its references, Copilot registration, the hot reload log buffer, the contract (560/561, payloads, `SupportsAgentTools=0x20`), the WPF TAP `TapAgentToolsService`, the in-app Copilot re-route `XamlInAppCopilotExtension`, unit tests (4 pass), and docs.
   - Changed the design so the TAP reports `SupportsAgentTools` in the `TapInitialized` Status bits. Host platform constructors take a `tapStatus` parameter.
   - Started the UwpTap work: declarations, handler registrations, and the status bit.

2. **This segment: UwpTap implementation**
   - In `UwpTap.cpp`, added the Automation Peers/Provider/Media includes (`#ifdef WINUI3`, else the `Windows.UI.Xaml` versions).
   - Implemented, before `GetDispatcher`:
     - an anonymous-namespace helper block;
     - `GetRootWindowHandle`;
     - `HandleGetElementBounds`;
     - `HandleElementAutomationAction`.
   - Built the WinUI3 and UWP StaticCrt variants for x64. The first attempt needed a restore (`WASDKPackagePath` was empty with `-NoRestore`).
   - Result: `UwpTap.cpp` **compiles with no errors** in both variants. Both fail only at link: `LNK1181` for missing `out\binaries\amd64chk\bin\amd64\ClientDiagnostics\Common\lib\Casablanca.StaticCrt.lib`, a dependency that `-NoProjectReferences` skipped.

3. **User asked what's needed for the tools and skills to be available in VS, and for an inventory of tools and skills with inputs and outputs.**
   - Explained:
     - The skill is discovered through the existing `[CopilotSkillsProvider(@"AgentTools\skills", UICONTEXT_DiagnosticToolWindowsAvailable)]` and `MefAgentSkillsPaths`. It ships via the `Diagnostics.csproj` Content item and `files.swr`.
     - To be on by default, the skill name must be in `FirstPartyToolsProvider.FirstPartySkills` (Copilot repo). I added `xaml-diagnostics` there.
     - The tools are a brokered `CopilotFunctionHandler` (`Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions` v0.1). They're registered as an `AllFromProviderTool` in `FirstPartyToolsProvider`, gated on UI context `5C69788A-62F3-42C8-880A-1A4CE40C6671`.
   - Gaps noted:
     - There is no feature flag on the tools or skill.
     - The tools are unavailable before debugging starts.
     - The Copilot team must approve the two edits in their repo.
   - Gave the full inventory of 18 tools with inputs, outputs and confirmation requirements, plus the skill layout.

4. **User asked whether this is complete, how the legacy in-app toolbar Copilot prototype fits in, and for debugging scenarios.**
   - Not complete:
     - UwpTap is unlinked and untested; MAUI is pending.
     - The managed projects haven't been rebuilt and the tests not rerun.
     - The docs still say WPF only.
     - There's been no end-to-end test in VS, and Debugger-agent visibility is unverified.
   - In-app toolbar:
     - `XamlInAppCopilotExtension` is now the only `ICopilotExtension` export in the product, so the toolbar's Copilot button now appears.
     - It forwards the prompt, screenshots and source paths to Copilot Chat. On the older chat path it sends text only.
     - It always returns `HasChanges=false`, and Reject/Feedback do nothing, so the old Keep/Undo flow is unused.
   - Listed 16 scenarios: clipping and layout, value precedence, wrong style or theme resource, binding failures, template DataContext, UI flows that need interaction, hot reload failures, empty LVT, accessibility, visual regressions, DPI, mapping a screenshot to source, generated elements, live trial edits, disabled controls, multiple apps.

5. **User asked whether style and resource tools would help.**
   - Findings:
     - `PropertyChainRequest` already returns `PropertyValuesHolder.Sources` (`TapPropertySource`: Handle, TargetType, Name, `BaseValueSource`, SourceInfo).
     - `BaseValueSource` has these values: Default, BuiltInStyle, Style, Local, Inherited, DefaultStyleTrigger, TemplateTrigger, StyleTrigger, ImplicitStyleReference, ParentTemplate, ParentTemplateTrigger, Animation, Coercion, Accessibility.
     - `MarkupDocumentManager.FindResourceAsync(platform, sourceInfo)` maps source info to an `IDictionaryEntry`.
     - Message 539 `GetDictionaryEntryValue` exists.
     - There's no "resolve resource key" message and no "list dictionaries" message.
   - Proposed:
     - Tier 1 (host-only): `xaml_get_element_styles` and `xaml_explain_property_value`.
     - Tier 2 (new TAP messages): `xaml_find_resource` and `xaml_get_resource_dictionaries`, plus optional StaticResource/DynamicResource info.
   - User chose **Tier 1 + Tier 2, done after the UwpTap/MAUI work and before the commit**.
   - Appended an addendum to `plan.md` and added SQL todos `style-tools-tier1` and `resource-tools-tier2`, with dependencies on `tap-maui` and `tap-winui`. Marked `tap-winui` in_progress.
   - Started fixing the link: found `UwpTap.StaticCrt.Common.shproj:107` has `<ProjectReference Include="$(CasablancaProj)" />`.
</history>

<work_done>
**Done and building (earlier segments)**
- Diagnostics `AgentTools\*`:
  - `XamlAgentService.cs`
  - `XamlDiagnosticsFunctionProvider.cs`
  - `XamlDiagnosticsSkillsProvider.cs`
  - `XamlHotReloadLogBuffer.cs`
  - `XamlAgentImaging.cs`
  - `XamlAgentException.cs`
  - `XamlInAppCopilotExtension.cs`
  - `skills\xaml-diagnostics\SKILL.md` and `references\*.md`
- Unit tests: `Test\Unit\AgentTools\XamlAgentToolsTests.cs`
- Docs: `Documentation\copilot-tools.md` and a README link.
- Contract: `XamlMessageType.cs`, `XamlJsonData.cs`, UwpTap `XamlMessageType.h`.
- WPF TAP: `TapAgentToolsService.cs`, projitems, `DiagnosticVisualTreeService.cs`.
- Copilot `FirstPartyToolsProvider.cs`, `files.swr`, `Diagnostics.csproj`.

**Modified for the capability bit; managed projects not yet rebuilt**
- `DiagnosticBits.cs`
- `PublicAPI.Unshipped.txt`
- WPF TAP `VisualTreeService.cs`
- `WpfDiagnosticPlatform.cs`
- `WinRTDiagnosticPlatform.cs`
- `DiagnosticPlatformFactory.cs`
- DiagnosticsMobile `DiagnosticPlatform.cs`
- `HostDebuggerExtension.cs`
- `NonDebugProcessManager.cs`

**UwpTap (native)**
- Changed: `DiagnosticBits.h`, `UwpTap.h`, `UwpTap.cpp`.
- `UwpTap.cpp` compiles for WinUI3 and UWP x64. Linking is blocked on the Casablanca lib.

**SQL todos**
- `tap-winui`: in_progress
- `tap-maui`: pending
- `style-tools-tier1`: pending
- `resource-tools-tier2`: pending
- Everything else is done.
</work_done>

<technical_details>
**Build**
- Command:
  ```
  cd Q:\src\VS_xaml; $env:PSModulePath = "$env:ProgramFiles\WindowsPowerShell\Modules;$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules"; & src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project <proj> -NoProjectReferences [-NoRestore] [-Platform x64]
  ```
  The PSModulePath fix avoids the msrustup restore failure.
- Redirect build output to a file (e.g. `.vs\winui3build.txt`). Don't pipe to `Select-Object -First`; it orphans MSBuild.
- Managed build order: RuntimeHostBase → DiagnosticsBase → TapContract/XamlTapContract → WpfTap (needs restore) → WpfCoreTap → DiagnosticsMobile → Diagnostics.
- Unit tests: `src\Xaml\Scripts\Test-Xaml.ps1 -Suite diagnostics -Filter <name>`.
- UwpTap projects:
  - `UwpTap\UwpTap.StaticCrt\UwpTap.StaticCrt.vcxproj`
  - `UwpTap\UwpTap.StaticCrt.WinUI3\UwpTap.StaticCrt.WinUI3.vcxproj`
  - The WinUI3 build needs a restore, otherwise `WASDKPackagePath` is empty.
  - Error logs: `.vs\logs\src_Xaml_Shared_Source_UwpTap_<proj>_<proj>_x64.err`.
  - The language standard is C++20 (a templated lambda with `.template operator()<T>` is used).
- Linking needs `$(CasablancaProj)`, referenced in `UwpTap.StaticCrt.Common.shproj:107`. Resolve that property to build the Casablanca.StaticCrt lib for x64, or accept the compile-only verification.

**UwpTap implementation details**
- An anonymous namespace defines:
  - namespace aliases `xaml_peers` and `xaml_provider`;
  - `MaxBoundsPerRequest = 2000`;
  - the `FrameworkElementAutomationPeer` class name, chosen per platform;
  - the `AgentToolPatterns` list;
  - helpers `CurrentExceptionMessage()`, `ToLowerTrimmed`, `FormatDouble`, and `CreateAutomationPeer`, which uses `factoryProvider.GetWinrt<IFrameworkElementAutomationPeerStatics>(...).CreatePeerForElement`.
- **Bounds:**
  - Screen rect comes from `peer.GetBoundingRectangle()`; root rect from `TransformToVisual(nullptr).TransformBounds` of `RenderSize`.
  - DPI comes from `GetDpiForWnd(hwnd)/96`, with fallbacks.
  - Response: `{"Bounds":[{Handle, Found, IsVisible, RootWindowHandle, DpiScale, ScreenX…RootHeight, Error}]}`.
- **Action:**
  - Response: `{SupportedPatterns[], Result?, Error?, HResult?}`.
  - Errors are thrown as `winrt::hresult_error(E_NOINTERFACE, msg)` and caught into `error`.
- `GetRootWindowHandle` uses `m_roots.find(GetRootId(...))`, falling back to the single root. It's guarded by `#ifndef ONECORE_BUILD`.

**Capability negotiation**
- The TAP reports bits in `TapInitialized.Status`. The host ORs in only `SupportsAgentTools`.
- `XamlAgentService.ThrowIfAgentToolsUnsupported` gates the bounds and interaction tools.
- A TAP that doesn't know a message never replies, which is why the gate is needed.

**Tool output**
- Tools return JSON via Newtonsoft with null values omitted.
- Errors are `{error, message, hint}`; a declined confirmation is `USER_DECLINED`.
- Element IDs look like `a1:<handle>`; app keys like `a1`.

**In-app toolbar**
- `XamlDiagnosticsHost` (line ~69-73) gets `ICopilotExtension` via `GetExportedValueOrDefault`. `InAppUICopilotManager` is only created when an extension exists (~169).

**MAUI notes**
- MauiTap is at `src\Xaml\Shared\Source\MauiTap`. `TapInitializedEvent` is posted in `BaseMauiAgent.cs` ~88-98 and `VisualTreeService\VisualTreeService.cs` ~85-92.
- It may not build locally because `Microsoft.Maui.Controls.HotReload.Forms.dll` is missing.

**Style and resource data sources**
- `XamlAgentService.RequestPropertiesAsync` → `PropertyValuesHolder` (Properties with `PropertyChainIndex`, Sources list) and `GetPropertySource`.
- `MarkupDocumentManager.FindResourceAsync` (DiagnosticsBase\Markup ~637).
- LPE usage: `CategoryViewModel.cs:392`.
- WPF/MAUI `TapInstanceManager.GetAncestorForResourceDictionaryEntry`.

**Other gotchas**
- Use the Copilot type aliases.
- Pragmas: `VSDIAG_API`, `VSCOPILOT_API`, `VSCOPILOT_BACKEND`.
- `IVsFeatureFlags` is in `Microsoft.Internal.VisualStudio.Shell.Interop`.
- Write `Shell.Package`, not bare `Package`.
- ISB001: the `using` must wrap the proxy before the null check.

**Constraints**
- Never push, rebase or amend. Make one local commit at the end via `git -C Q:\src\VS_xaml`, with trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Use the dashed copyright header.
- At the end, ask the user about skill updates. Candidates:
  - the PSModulePath fix for msrustup
  - `Select-Object -First` orphaning MSBuild
  - WpfTap and UwpTap WinUI3 need a restore
  - Casablanca link dependency
  - TAP-reported capability-bit pattern
  - `IncludeBuiltInContributions`
  - backend `CreateSessionAsync`
  - `FirstPartySkills` for default-on skills
</technical_details>

<important_files>
- `src\Xaml\Shared\Source\UwpTap\UwpTap.cpp`
  - The native WinUI/UWP TAP.
  - Includes at ~38-47; handler registration ~290; status ~301.
  - New helpers and handlers at ~1485-1827, just before `GetDispatcher`.
- `src\Xaml\Shared\Source\UwpTap\UwpTap.StaticCrt.Common.shproj`: line 107 `$(CasablancaProj)` (the link dependency); line 35 C++20.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - The façade. Add the style and resource methods here.
  - Key methods:
    - properties ~536-600 (`GetElementPropertiesAsync`, `RequestPropertiesAsync`);
    - set property ~602;
    - bounds and interaction ~700-810;
    - `SourceResolver` ~1270.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - The tool definitions.
  - The "Supported for WPF apps" text at ~128 and ~138 needs updating.
  - Add the new style and resource tools here.
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`: WPF TAP handlers for 560/561. Add 562/563 here for Tier 2.
- `src\Xaml\Shared\Source\XamlTapContract\Networking\XamlMessageType.cs`, `XamlTapContract\TapOM\XamlJsonData.cs` (~570-668), UwpTap `XamlMessageType.h`: the contract for the new messages.
- `src\Xaml\Shared\Source\XamlTapContract\TapOM\TapPropertySource.cs`, `BaseValueSource.cs`: the property chain source data for Tier 1.
- `src\Xaml\Shared\Source\MauiTap\` (`BaseMauiAgent.cs`, `VisualTreeService\VisualTreeService.cs`): the next TAP to change.
- Docs to update for multi-platform support and the new tools:
  - `src\Xaml\Diagnostics\Documentation\copilot-tools.md`
  - `AgentTools\skills\xaml-diagnostics\SKILL.md`
- `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\plan.md`: the plan, now with the style and resource addendum.
</important_files>

<next_steps>
1. **Finish `tap-winui`.**
   - Resolve `$(CasablancaProj)`: grep the props for `CasablancaProj` and build that project for x64 (restore if needed).
   - Rebuild both UwpTap StaticCrt variants to confirm they link; OneCore too if feasible.
   - If the link remains blocked, accept the compile-only verification and note it.
   - Mark the todo done.
2. **Rebuild the managed projects** changed for the capability bit: TapContract, XamlTapContract, WpfTap, WpfCoreTap, DiagnosticsMobile, Diagnostics. Rerun the unit tests (`XamlAgentToolsTests`, plus the platform and `HostDebuggerDataBridge` tests if feasible).
3. **`tap-maui`.**
   - Add a 560/561 handler service in MauiTap: bounds from `VisualElement` plus the platform view; actions via `Button.SendClicked`/Command, `Switch.IsToggled`, `CheckBox.IsChecked`, `Entry.Text`, `Focus`, `ScrollTo`.
   - Register it and set `SupportsAgentTools` in `TapInitializedEvent.Status`.
   - Build if possible.
4. **`style-tools-tier1`.**
   - Add `xaml_get_element_styles(elementId)` and `xaml_explain_property_value(elementId, propertyName)`, using `PropertyValuesHolder.Sources`/`PropertyChainIndex` and `SourceResolver`. Optionally map styles to dictionary keys via `MarkupDocumentManager.FindResourceAsync`.
5. **`resource-tools-tier2`.**
   - Contract: new messages 562 `FindResource` (elementHandle, key → value, type, winning dictionary plus source, shadowed definitions, theme) and 563 `GetResourceDictionaries`.
   - Implement in the WPF TAP, UwpTap and MauiTap.
   - Add the `xaml_find_resource` and `xaml_get_resource_dictionaries` tools, gated on `SupportsAgentTools`.
6. **Update docs and descriptions**: tool descriptions, `SKILL.md` and `copilot-tools.md` should cover WPF/WinUI/UWP/MAUI and the new tools.
7. **Wrap up.**
   - Mark the SQL todos done.
   - Make the single local commit with the trailers (no push).
   - Ask the user about skill updates.
</next_steps>