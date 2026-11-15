<overview>
The user (@spadapet) wants every Visual Studio "XAML Diagnostics" capability exposed to Copilot AI so the model can diagnose, debug, and fix running XAML apps through VS and the injected TAP. That covers:
- Live Visual Tree and Live Property Explorer
- Live Preview images and the list of top-level windows
- Binding failures
- The accessibility checker
- Hot reload: state, errors, log, and apply
- The list of debugged apps and their platforms
- "Why is this unavailable" explanations

A plan was written in plan mode and approved. Implementation started right after approval and must continue until the work is actually done and verified. This is a prototype, so the user wants whatever works most easily.
</overview>

<history>
1. **Plan mode: user asked for a full feature plan.**
   - Researched the Copilot extensibility points, the XAML Diagnostics host model, the TAP protocol, and the existing in-app Copilot. Details are in the technical section.
   - Asked the user six scope questions with ask_user. Answers:
     - **Surfaces:** in-proc agent-mode tools plus a built-in skill. **No dedicated XAML agent** ("stay away… unless really needed"). Users stay in normal Agent mode or the Debugger agent.
     - **Assembly:** use the **existing Diagnostics DLL**, not a new one.
     - **Skill content:** general knowledge of how XAML diagnostics and hot reload work, **plus XAML-writing guidance so the XAML works well with the XAML designer**.
     - **Mutations:** confirmation `Required`; the user can "always allow" per session.
     - **New TAP messages:** allowed, but **only if no existing message can provide the info or action**.
     - **Platform rollout:** WPF first, then WinUI/UWP, then MAUI.
     - **In-app Copilot prototype:** re-route it through the new tools and integrate the prototype with the new implementation.
     - **MAUI design-time sessions:** included.
   - Wrote plan.md, inserted 12 todos and their dependencies into SQL, and called exit_plan_mode. The plan was approved.

2. **Implementation began after approval.**
   - Read the following, gathering the API details listed in the technical section:
     - `XamlDiagnosticsHost.cs`, `IXamlDiagnosticsHost.cs`, `Diagnostics.csproj`
     - `Copilot.csproj`, the CMake function provider
     - `DebuggerUIFunctionProvider` header, `CopilotFunctionHandler.cs`, `CopilotExtensions.cs`
     - `ImageContextProvider.cs`, `MiscellaneousContextProvider.cs`
   - No code has been written yet. I was about to create the `Copilot\` folder in Diagnostics and start Phase 0 plumbing.
</history>

<work_done>
Files created:
- `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\plan.md`: the full approved plan (architecture, tool catalog, new TAP messages, skill content, in-app re-route, cross-cutting concerns, open questions, phasing).

SQL todos (all pending), with dependencies:

| Todo | Depends on |
|---|---|
| plumbing | — |
| function-provider | plumbing |
| copilot-registration | function-provider |
| skill | plumbing |
| readonly-tools | function-provider |
| hot-reload-tools | function-provider |
| mutation-tools | readonly-tools |
| tap-wpf | readonly-tools |
| inapp-reroute | readonly-tools |
| tap-winui | tap-wpf |
| tap-maui | tap-wpf |
| docs-tests | mutation-tools, tap-wpf |

No repository files have been modified yet. Nothing has been built.
</work_done>

<technical_details>
**Approved architecture.** All new code goes in `src\Xaml\Diagnostics\Source\Diagnostics`, new folder `Copilot\`.

- **`XamlAgentService`** (MEF `[Export]`): a façade over `IXamlDiagnosticsHost`.
  - Element IDs have the form `"{endpointKey}:{instanceHandle}"`.
  - Paging defaults: depth 3, 200 nodes, hard cap 2000. Images default to ≤1280px (the render-target-bitmap maximum is 2048).
  - Each call has a 10s timeout.
  - Structured error codes: NO_APPS, ENDPOINT_GONE, ELEMENT_GONE, UNSUPPORTED_PLATFORM, UNSUPPORTED_BY_TAP, TAP_TIMEOUT, NOT_DEBUGGING, FEATURE_DISABLED.
- **`XamlDiagnosticsFunctionProvider`**:
  - Subclass `CopilotFunctionHandler` (public, in the contracts assembly; discovers `[CopilotFunction]` methods by reflection).
  - Export with `[ExportBrokeredService("Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions", "0.1", Audience = ServiceAudience.Local)]` plus `IExportedBrokeredService`.
  - Expose `public static readonly ServiceMoniker Moniker` and `ServiceDescriptor = CopilotDescriptors.CreateDescriptor(Moniker)`, and override `Descriptor`.
  - Implement `Task InitializeAsync(CancellationToken)`.
  - Method signature pattern from the debugger UI tools: `(string progressMessage, CopilotRequest originalRequest, IProgress<CopilotProgress> progress, CancellationToken ct, [CopilotDescription(...)] args...)`, returning `CopilotContext`, `CopilotContext[]`, or a string/value.
- **Tool names:**
  - Discovery and setup: `xaml_list_apps`, `xaml_get_diagnostics_status`
  - Tree: `xaml_get_visual_tree`, `xaml_find_elements`, `xaml_get_element_bounds`, `xaml_select_element`, `xaml_go_to_source`
  - Properties: `xaml_get_element_properties`, `xaml_get_property_value_details`, `xaml_set_element_property`
  - Visuals: `xaml_list_windows`, `xaml_capture_image`
  - Interaction: `xaml_interact`
  - Binding failures: `xaml_get_binding_failures`, `xaml_clear_binding_failures`
  - Accessibility: `xaml_run_accessibility_check`, `xaml_get_accessibility_results`
  - Hot reload: `xaml_get_hot_reload_status`, `xaml_get_hot_reload_log`, `xaml_apply_hot_reload`, optionally `xaml_set_hot_reload_option`
- **New UIContext** `XamlDiagnosticsActive`, driven by `IXamlHotReloadHost.EndpointChanged`. Possibly combined with DebuggingMode (open question).
- **Feature flag** `XamlDiagnostics.CopilotTools`.
- **Hot reload log tee:** a ring buffer of 500 entries holding XAML log messages, `UpdatesApplied`, and errors from `IMarkupChangeErrorManager`.
- **Skill:**
  - Export a trivial `ICopilotSkillsProvider` class with `[CopilotSkillsProvider("Copilot\\skills", "<uicontext guid>")]` (`src\Copilot\src\Copilot\AgentSkills\CopilotSkillsProviderAttribute.cs`; experimental, so needs `#pragma warning disable VSCOPILOT_BACKEND`).
  - The directory must be relative to the assembly and its deepest folder must be named `skills`; each skill folder holds a `SKILL.md`. Consumed by `MefAgentSkillsPaths.cs`.
  - Ship as VSIX content: `Copilot\skills\xaml-diagnostics\SKILL.md` plus `references\`. Possibly a separate `xaml-authoring` skill.
  - Add the skill name to `FirstPartyToolsProvider.FirstPartySkills` so it's enabled by default.
- **Copilot-repo changes** (need Copilot team approval):
  - Add an `AllFromProviderTool(moniker: new(...), uiContext: guid)` entry, with a Description/Repo/Project comment block, to `FirstPartyTools` in `src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs` (examples around lines 205-245; class definition at ~623).
  - `DebuggerSdkAgent.cs` (lines 50-80) builds a `CopilotFunctionAggregator` from injected providers via `CopilotFunctionProviderSource(provider)`. Add the XAML provider there; this needs a MEF-importable type or a brokered proxy.
- **New TAP messages** (capability-negotiated through `DiagnosticBits`):
  - `GetElementBoundsRequest`: WPF can reuse the `TryGetElementRect` logic in `TapAccessibilityCheckerService.cs` (~line 195).
  - `ElementAutomationActionRequest`: runs AutomationPeer patterns.
  - Before adding these, check whether `HitTest`, `RenderTargetBitmapRequest`, `TrackFocusElementRequest`, or the Live Preview selection messages can be reused.
- **In-app re-route:** implement `ICopilotExtension` (`[Experimental]`, `VSDIAG_API` pragma) in Diagnostics to send the prompt, images, and context to Agent mode chat. Which API submits a prompt into Agent mode is still unknown.

**Project and reference facts:**
- `Diagnostics.csproj` is SDK-style, targets `$(VSDefaultTFM)` (net472), and is a VSIX project.
  - It already references `$(INETROOT)\src\...` projects and `Microsoft.ServiceHub.Framework`.
  - Content items are declared like `<Content Include="VS\XamlHotReloadSettings.registration.json"><CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory></Content>` (around line 128).
  - The ProjectReference ItemGroup is at ~lines 147-163.
- Add `<ProjectReference Include="$(INETROOT)\src\Copilot\src\Copilot\Copilot.csproj" />`, the same pattern as CMake's `.csproj` line 368.
  - Copilot.csproj targets netstandard2.0, uses MessagePack, Nerdbank.MessagePack, PolyType, and StreamJsonRpc, and has a public API analyzer.
  - Assembly name is `$(CopilotAssemblyBaseName)`, i.e. `Microsoft.VisualStudio.Copilot`.
  - Possible issue: package version conflicts. The VSIX may also need to *not* ship Copilot.dll, since it's already in VS; consider `Private=false` / `IncludeInVSIX=false`.
- **Building images and strings** (`CreateImageContext` / `CreateStringContext` live in internal Copilot.Core `CopilotContextExtensions`, which isn't referenceable). Replicate them:
  - Image: `new CopilotContext(CopilotDescriptors.Context.Image.Moniker, "image", correlationId, CopilotDefaultTypes.ImageContextName, new CopilotImageContext{ Data=bytes, MimeType="image/png", Width=0, Height=0, FilePath=null! }) { CanReduce = false }`.
  - String: `new CopilotContext(new ServiceMoniker("Microsoft.VisualStudio.Copilot.MiscellaneousContextProvider", new Version(CopilotDescriptors.CurrentContextProviderVersion)), new CopilotContextDescriptor("miscellaneous","Miscellaneous context as plain text", CopilotDefaultTypes.StringName), correlationId, value)`.
  - Alternatively just return strings or JSON from tools.
  - Verify that `CopilotDescriptors.Context.Image` and the `CopilotImageContext` setters are public in the contracts assembly.
- `CopilotFunctionHandler.InvokeAsync` requires the function to be present in `context.OriginalRequest.Functions`.

**XAML host APIs** (namespace `Microsoft.VisualStudio.DesignTools.Diagnostics.Model`):
- `XamlDiagnosticsHost : XamlHotReloadHost, IXamlDiagnosticsHost` exposes:
  - `PropertyExplorerViewModel`, `LivePreviewManager`, `UserOptions` (IXamlUserOptions), `TreeContainer` (ElementTreeContainer), `BindingFailuresProvider`
  - `DocumentViewManager`, `HotReloadStatusReporter`, `CopilotExtension` (lazy MEF `GetExportedValueOrDefault<ICopilotExtension>`), `DiagnosticNotAvailableReason`, `ErrorReporting`, `ActivateHost`, `ShowWindow(XamlDiagnosticsWindow)`
- `OnSessionStarted` creates TreeContainer, the property explorer VM, LivePreviewManager, InAppUIManager, and `InAppUICopilotManager` (only if a CopilotExtension exists). `OnSessionStopped` disposes them, so these members are null when there are no endpoints.
- `OnEndpointChanged` logs to `HotReloadLogger.Value.LogMessageAsync(message, "XAML")`. This is a natural tee point for the ring buffer.
- `endpoint.InstanceManager() is HotReloadInstanceManager m` gives `m.IsEnabled`. `endpoint.Platform.DiagnosticBits`, `endpoint.Platform.Platform` (SupportedPlatform), and `endpoint.DisplayName` are available.
- How the VS host gets created: load package `8291C340-36B8-4C91-8C40-CCE75398FF75`, then query `IXamlHotReloadHost`. The VS implementation is `VisualStudioXamlDiagnosticsHost` (exported via MEF).
- Other APIs, from the earlier research summary:
  - LVT: `ElementTreeContainer.GetElementTree` / `GetElement` / `GetNamedElements`
  - LPE: `PropertyExplorerViewModel.SetValueAsync`, `PlatformObjectCache`
  - Binding failures: `IBindingFailure` fields, `IBindingFailures.ClearEntries()`
  - Accessibility: `AccessibilityChecker.Run()` and `IAccessibilityIssue` (WPF and WinUI only)
  - `RenderTargetBitmapManager.RequestRenderTargetBitmap(protocolHandler, handle, flags)`
  - Options use the `debugging.xamlHotReload.*` prefix
  - Source info requires `ENABLE_XAML_DIAGNOSTICS_SOURCE_INFO=1`, a Debug build, `XamlDebuggingInformation` (WPF) / `DisableXbfLineInfo=False` (UWP), launching with F5 rather than Attach, and a non-elevated app
  - `XamlDiagnosticsTestContract.cs` is the existing automation reference

**Constraints:**
- Build with `src\Xaml\Scripts\Build-Xaml.ps1` (needs a VS dev shell and the Modeling SDK), not dotnet build. Load the building-locally skill and run `src\Shared\Tools\Scripts\Prime-ForCopilot.ps1` in the same process before building.
- Tests: `Test-Xaml.ps1`, plus the Unit and Component test projects under `src\Xaml\Diagnostics\Test`.
- Never push, rebase, or amend the user's commits. Make a single new commit with trailers and stop for review.
- No time estimates in plans.
- Use `git -C <repo>`.
- At the end of the session, ask whether a skill should be updated.
</technical_details>

<important_files>
- `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\plan.md`: the approved plan and source of truth.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj`: add the Copilot ProjectReference and the skill Content items (ProjectReferences at ~147-163, Content at ~128).
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\Tool\Model\XamlDiagnosticsHost.cs`: the host the tools wrap. Session start/stop is at ~143-260 and the HotReloadLogger usage is in `OnEndpointChanged`.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot\Functions\CopilotFunctionHandler.cs`: base class for the provider.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\Debugging\DebuggerUIFunctionProvider.cs`: pattern for the provider (lines 27-40 header, 168-226 screenshot).
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Core\Debugging\CopilotExtensions.cs` (lines 60-95): image/string context construction to replicate.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`: `FirstPartyTools` (AllFromProviderTool examples ~205-245), `FirstPartySkills` (line 54).
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\Agents\Sdk\DebuggerSdkAgent.cs` (lines 50-80): Debugger agent tool aggregator.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot\AgentSkills\CopilotSkillsProviderAttribute.cs` and `Copilot.Vsix\AgentSkills\MefAgentSkillsPaths.cs`: built-in skill export mechanism.
- `Q:\src\VS_xaml\src\vc\projbld\CMake\Package\Copilot\CMakeCopilotFunctionProvider.cs`: an external-team brokered function provider example.
- Diagnostics model files:
  - `Tool\Managers\InAppUICopilotManager.cs`, `ICopilotExtension.cs`
  - `Tool\Managers\RenderTargetBitmapManager.cs`
  - `Bindings\IBindingFailure.cs`
  - `AccessibilityChecker\IAccessibilityIssue.cs`
  - `ElementTree\ElementTreeContainer.cs`
  - `VS\OptionNames.cs`
  - `XamlDiagnosticsTestContract.cs`
- TAP contracts: `Shared\Source\XamlTapContract\Networking\XamlMessageType.cs`, `TapOM\XamlJsonData.cs`. WPF TAP: `Shared\Source\WpfTap\...`.
</important_files>

<next_steps>
Immediate next steps (todo "plumbing", then "function-provider"):
1. Mark the SQL todo `plumbing` as in_progress.
2. Load the building-locally skill and prime the environment. Confirm that Diagnostics builds with the new Copilot ProjectReference (watch for MessagePack/StreamJsonRpc version conflicts and for Copilot.dll being included in the VSIX).
3. Check the remaining API shapes before writing code:
   - `ElementTreeContainer` / `IElement`
   - `PropertyExplorerViewModel` / `PlatformObjectCache` property fetch
   - `IBindingFailures`
   - `AccessibilityChecker`
   - `LivePreviewManager` root windows
   - `IXamlUserOptions`
   - `IMarkupChangeErrorManager`
   - `UIContext` creation (`UIContext.FromUIContextGuid(...).IsActive = true`)
4. Create in `Diagnostics\Copilot\`:
   - `XamlAgentService.cs`
   - `XamlAgentDtos.cs`
   - `XamlAgentElementIds.cs`
   - `XamlHotReloadLogBuffer.cs`
   - `XamlDiagnosticsFunctionProvider.cs` (subclass `CopilotFunctionHandler`, brokered export)
   - `XamlDiagnosticsSkillsProvider.cs`
   - `skills\xaml-diagnostics\SKILL.md` plus `references\*.md` (enablement/troubleshooting, tool workflows, designer- and hot-reload-friendly XAML authoring per platform)
   - The UIContext GUID constant and its activation from EndpointChanged
5. Implement the read-only tools, then hot reload, then mutations. Then the WPF TAP messages (bounds and automation action), then the in-app `ICopilotExtension` re-route.
6. Copilot-repo edits: the FirstPartyToolsProvider entry, adding the skill name to `FirstPartySkills`, and adding the tools to the DebuggerSdkAgent aggregator.
7. Unit tests in `src\Xaml\Diagnostics\Test\Unit`, docs (`Diagnostics\README.md`, `Documentation\copilot-tools.md`), then build and test.
8. Finally, create a single commit with trailers and don't push. Ask whether a skill should be updated.

Open questions:
- Which UIContext gates the tools.
- One skill or two.
- Which API submits a prompt into Agent mode for the in-app re-route.
- How to include the tools in the Debugger agent: brokered proxy vs. MEF type.
- How to map an endpoint's GUID ProcessId to an OS PID.
</next_steps>