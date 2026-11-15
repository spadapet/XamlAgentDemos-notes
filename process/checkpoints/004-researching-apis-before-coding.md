<overview>
The user (@spadapet) wants every Visual Studio "XAML Diagnostics" feature exposed to Copilot AI, so the model can diagnose, debug and fix running XAML apps through VS and the injected TAP. That covers:
- Live Visual Tree (LVT) and Live Property Explorer (LPE)
- Live Preview images and the list of windows
- binding failures
- the accessibility checker
- hot reload: state, errors, log, and triggering an apply
- the list of apps being debugged and their platforms
- explanations of why a feature is unavailable

The plan was approved and implementation is underway. It's a prototype: the user wants whatever works most easily. The design is in-proc Copilot agent-mode tools (a brokered `CopilotFunctionHandler` subclass) plus a built-in skill, all inside the existing Diagnostics DLL, with no dedicated agent.
</overview>

<history>
1. **Plan mode.**
   - I researched the Copilot extensibility points, the XAML Diagnostics host, the TAP protocol, and the existing in-app Copilot prototype.
   - I asked six scope questions and got answers.
   - I wrote plan.md and added 12 SQL todos. The plan was approved via exit_plan_mode.

2. **Implementation, earlier segment.**
   - Read the Copilot contracts and loaded the building-locally skill.
   - The baseline build with `-NoProjectReferences` failed with MC1000 because referenced binaries were missing (environment problem, not a code problem).
   - Started async build `build2`, which builds with references.

3. **Implementation, this segment.** I continued researching the APIs needed to write the code; no code has been written yet.
   - Marked SQL todo `plumbing` as in_progress.
   - Studied:
     - the CMake and DebuggerUI function providers and the `CopilotFunctionHandler` method-discovery rules,
     - `XamlDiagnosticsPackage` (how the host is acquired, plus existing UIContexts),
     - `XamlDiagnosticsHost` (session lifecycle),
     - ElementTreeContainer, IProtocolHandler, the PlatformObjectCache property protocol,
     - the RTB request/response contracts and the XamlMessageType list,
     - LivePreviewManager, IActiveElementTracker, IXamlUserOptions,
     - the binding, a11y and hot-reload interfaces.
   - `build2` was still running as of the last check (binlog `Q:\src\VS_xaml\.vs\logs\src_Xaml_Diagnostics_Source_Diagnostics_Diagnostics_20261111_143604_124.binlog`).
</history>

<work_done>
- `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\plan.md` holds the approved plan and is the source of truth.
- No repository files have been modified yet.

SQL todos: `plumbing` is in_progress; all others are pending. Dependencies:

| Todo | Depends on |
|---|---|
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

The async build `build2` may be finished; check it with `read_powershell build2`, or read the binlog with the aitools-binlog tools (deferred; use tool_search first).
</work_done>

<technical_details>
**Function provider pattern**
- Shape: `[ExportBrokeredService(Name, "0.1", Audience=ServiceAudience.Local)] public sealed class X : CopilotFunctionHandler, IExportedBrokeredService`.
  - Statics: `Moniker = new ServiceMoniker(Name, new Version("0.1"))` and `ServiceDescriptor = CopilotDescriptors.CreateDescriptor(Moniker)`.
  - Members: `public override ServiceRpcDescriptor Descriptor => ServiceDescriptor;` and `public Task InitializeAsync(CancellationToken) => Task.CompletedTask;`.
  - It can have an `[ImportingConstructor]`, which may be private.
- Tool methods carry `[CopilotFunction(name, description, CopilotConfirmationRequirement.X)]`. That attribute also has Group, Guidance (init), ToolInitializingMessage, AlwaysShowToUser and Hidden.
- Parameters:
  - Special parameter types are excluded from the schema: CancellationToken, `IProgress<CopilotProgress>`, IProgressWithCompletion, CopilotRequest, CopilotSessionId, CopilotFunctionInvocationContext, ICopilotFunctionBroker.
  - **A Required-confirmation function MUST take an `ICopilotFunctionBroker` or a `CopilotFunctionInvocationContext` parameter, otherwise ArgumentException.**
  - Other parameters need `[CopilotDescription("...")]`. Optional parameters use C# default values.
- Return types: `Task<string>`, `Task<CopilotContext>`, or `Task<CopilotContext[]>`.
  - Helpers (namespace Microsoft.VisualStudio.Copilot): `"text".CreateStringContext(originalRequest.CorrelationId)` and `bytes.CreateImageContext("image/png", correlationId)`. The bytes→image context helper was used in DebuggerUIFunctionProvider; verify it is public in Copilot.dll and not Vsix-internal.
- Progress: `progress.Report(msg)` and `progress.Report(msg, CopilotProgressStatus.Error)` (extension in `CopilotActiveResponseExtensions`).
- Pattern: the first parameter is `[CopilotDescription(ProgressMessageDescription)] string progressMessage`, then CopilotRequest originalRequest, `IProgress<CopilotProgress>` progress, and CancellationToken.
- Some APIs need `#pragma warning disable VSCOPILOT_API` (and `VSCOPILOT_BACKEND` for the skills provider).

**UIContext.** The existing `GuidList.UICONTEXT_DiagnosticToolWindowsAvailable` rule is "Debugging | DiagnosticConnectionActive", and `GuidList.UICONTEXT_DiagnosticConnectionActive` also exists. Use the former for tool/skill registration, so no new UIContext is needed. This resolves open question 1.

**Host acquisition**
- `VisualStudioXamlDiagnosticsHost` is MEF-exported (`[Export(typeof(IXamlDiagnosticsHost))]`, `[Export(typeof(VisualStudioXamlDiagnosticsHost))]`). But the package must have called `InitializeServices()` on it.
- So load the package: `new VsPackageLoader(ServiceProvider.GlobalProvider, GuidList.GuidXamlDiagnosticsPkg).LoadPackageAsync(ct)`, cast to `IXamlDiagnosticsPackage`, and subscribe to `Initialized`. If the host already exists, the add-accessor invokes the handler immediately. Then use `pkg.XamlDiagnosticsHost`.
- Session objects (TreeContainer, PropertyExplorerViewModel, LivePreviewManager, ActiveElementTracker…) are created in `OnSessionStarted` and nulled in `OnSessionStopped`.

**Tree**
- `XamlDiagnosticsHost.TreeContainer` is an ElementTreeContainer.
  - `RootNode` has children that are process roots (`Type="Process"`, Name=endpoint.DisplayName, grouped by DisplayName).
  - An endpoint's root elements are ProcessRoot children whose `(child as IElement).Endpoint == endpoint`.
  - `GetElement(endpoint, handle)` returns an Element; `GetNamedElements(name)` is also available.
- `LiveNodeWithChildren` exposes Handle, ParentHandle, SourceInfo, Name, TypeFullName, Index, ChildIndex, Children (non-null), Parent, IsRoot, Kind (ElementKind), and IsInTree.
- The tree is mutated on the UI thread, so read it on the UI thread.

**Protocol**
- `IProtocolHandler.SendMessageAsync<TReply>(int messageType, object payload)`, plus PostMessage, IsReady, and CancellationToken.
- `XamlMessageType` (namespace `Microsoft.VisualStudio.DesignTools.RuntimeHost.Networking`, file `Shared\Source\XamlTapContract\Networking\XamlMessageType.cs`, must stay in sync with `UwpTap\XamlMessageType.h`) goes up to 559 (LocalizedPropertiesResponse). New messages would start at 560.
- Useful existing messages: PropertyChainRequest 500, SetPropertyRequest 501, HostSelectionChange 509, RenderTargetBitmapRequest 514, HitTest 526, MapAccessibilityErrorsRequest 551.

**Properties**
- Request: `SendMessageAsync<PropertyValuesHolder>(XamlMessageType.PropertyChainRequest, new PropertiesRequestInfo{Object=handle, Reset=false})`, wrapped in `using (endpoint.TapExceptionSuppressor()?.Suppress())`. PropertiesRequestInfo also has PropertyRequestLevel.
- Holder: Error, `Sources` (TapPropertySource: Handle, TargetType, Name, Source as BaseValueSource, SourceInfo), and `Properties` (TapPropertyValue).
  - TapPropertyValue fields: Index (uint), Type, DeclaringType, ItemType, Overridden, PropertyName, PropertyChainIndex, IsAttached, Value, ValueType, Handle, MetadataBits, SourceInfo, ReadOnly, IsCollection, IsValueBindingExpression.
  - PropertyChainIndex indexes into Sources.
- `BaseValueSource` enum: Unknown, Default, BuiltInStyle, Style, Local, Inherited, DefaultStyleTrigger, TemplateTrigger, StyleTrigger, ImplicitStyleReference, ParentTemplate, ParentTemplateTrigger, Animation, Coercion, Accessibility, …
- Set: `SetPropertyRequestInfo{Object, Index, CreateInstanceType, Value}`.
  - CreateInstanceType is `typeof(string).FullName` for WPF/MAUI and `prop.Type` for UWP/WinUI.
  - The response is `ResponseWithError`.

**Images**
- **WPF TAP does NOT implement RenderTargetBitmapRequest; only UwpTap does.**
- `RenderTargetBitmapRequestInfo{InstanceHandle, RenderFlags (0), MaxWidth, MaxHeight}` returns `RenderTargetBitmapResponseInfo{ReturnCode, InstanceHandle, SourceBitmapDescription, RenderedBitmapDescription{Width,Height,PixelFormat,OpacityMode}, Stride, DataSize, DataStartingIndex, DataPacketToWrite, Data}`. These are in `Shared\Source\RuntimeHost\TapOM\JsonObjects.cs`.
- Pixel format is Pbgra32 when `RenderTargetBitmapManager.TryConvertToPixelFormat` succeeds.
- To produce PNG, use `BitmapSource.Create` + Freeze + `PngBitmapEncoder` (works off-UI if frozen).
- Plan for window capture: do it host-side with `PrintWindow(hwnd, hdc, PW_RENDERFULLCONTENT=2)`. Get HWNDs from `LivePreviewManager.RemoteContents` (RemoteContent: Id, Endpoint, Handle, HandleKind, LayoutInfo, …), which is updated on the UI thread. Fall back to EnumWindows for the OS PID (`endpoint.GetProperty<int>(ContractStrings.WindowsProcessId)`).
- Element capture: RTB for UWP/WinUI. For WPF, return UNSUPPORTED_BY_TAP until a bounds TAP message exists; after that, crop the window capture.
- Remote endpoints aren't capturable.

**Selection.** `host.ActiveElementTracker.ActiveElement = element` (IElement) selects in the LVT.

**Hot reload**
- `IXamlHotReloadHost` exposes: MarkupChangeErrorManager.RuntimeErrors, HotReloadProcessingInformation (IsProcessing, ProcessingStartTime, Changed event), HotReloadOptions, HotReloadLogger, and `ApplyXamlChangesAsync(ct)`.
- MarkupChangeError fields: Message, ErrorType, ErrorCode, Severity, Category, Offset, Length, DocumentLocator (Path, RelativePath, ProjectName), ProjectName.
- **Log tee:**
  - `IHotReloadLogger` (namespace Microsoft.VisualStudio.Debugger.Contracts.HotReload, external) has methods `LogAsync(...)` and `LogMessageAsync(message, category)`.
  - Writers are HotReloadInstanceManager:534, MarkupChangeErrorManager:219, MauiHotReloadManager:163, XamlDiagnosticsHost:222, and MauiHotReloadSessionState:96.
  - `VisualStudioXamlDiagnosticsHost` ctor (line ~67) imports `Lazy<IHotReloadLogger>`. That's where a decorator could wrap it, but I still need the exact interface members, so inspect the reference assembly.
  - Simplest alternative: a tee only in XamlDiagnosticsHost.OnEndpointChanged plus the error manager.
- `IXamlUserOptions` covers hot reload, platform enables, JMX, in-app selection, binding failures and similar settings.

**Binding failures.** Read `host.BindingFailuresProvider.BindingFailures` (Entries/CountedEntries/ClearEntries). The `IBindingFailure` fields are listed in the important-files section.

**Accessibility**
- `IAccessibilityIssue`: Rule, HowToFix, Description, AutomationId, ProcessId, ScanData (WindowId, WindowHandle, SourceNavigator, EndpointForSelection), ElementInfo.
- `IAccessibilityElementInfo`: RuntimeId, ClassName, ElementName, AutomationId, Rectangle, HitTestPoint, WindowHandle, SourceInfo.
- Run it through `AccessibilityIssuesViewModel(host).RunAsync()` on the UI thread, then wait for SourceInfoReceived.

**Build**
- Use `Prime-ForCopilot.ps1` then `Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj` in the same process. Never `dotnet build`.
- Diagnostics.csproj is SDK-style net472. Add `<ProjectReference Include="$(INETROOT)\src\Copilot\src\Copilot\Copilot.csproj" />` (ProjectReferences ~lines 147-163, content items ~128), as CMake does (`src\vc\projbld\CMake\Package\...csproj:368`). Watch for MessagePack/StreamJsonRpc conflicts.

**Constraints**
- Never push, rebase, or amend. Make a single commit with these trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Use `git -C`.
- At the end, ask the user whether to update a skill.

**Open questions:** one skill or two; which API submits a prompt into Agent mode for the in-app re-route; how the Debugger agent includes the tools (proxy vs. MEF); the exact IHotReloadLogger members.
</technical_details>

<important_files>
- **plan.md** (session folder): the approved plan.
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj`**: add the Copilot ProjectReference and the skill Content items.
- **`...\Diagnostics\XamlDiagnosticsPackage.cs`**:
  - Package attributes (lines 30-92), including the UIContext rules for `UICONTEXT_DiagnosticToolWindowsAvailable`.
  - `Initialized` event (lines 117-133); Initialize creates the host (~line 165).
- **`...\Diagnostics\XamlDiagnosticsTestContract.cs`** (lines 47-135): the host-acquisition pattern.
- **`...\Diagnostics\Tool\Model\XamlDiagnosticsHost.cs`**:
  - Members (lines 84-115), OnSessionStarted (157), OnEndpointChanged plus the hot-reload log call (175-230), OnSessionStopped (233).
- **`...\Diagnostics\VS\VisualStudioXamlDiagnosticsHost.cs`**: MEF export (line 45); the ctor imports the logger at line 67.
- **`...\Diagnostics\ElementTree\ElementTreeContainer.cs`**: tree structure.
- **`...\Tool\UI\LivePropertyExplorer\Model\PlatformObjectCache.cs`** (lines 130-200): the property request pattern.
- **`...\Tool\Managers\RenderTargetBitmapManager.cs` and `BitmapDataPayload.cs`**: RTB handling.
- **`...\Tool\UI\LivePreview\Model\LivePreviewManager.cs`** (lines 84-160): RemoteContents.
- **`...\Bindings\IBindingFailure*.cs`** and **`...\AccessibilityChecker\*`**: binding and a11y data.
- **Shared TAP contract files:**
  - `Shared\Source\XamlTapContract\Networking\XamlMessageType.cs`
  - `Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs`
  - `Shared\Source\RuntimeHost\TapOM\JsonObjects.cs`
  - `Shared\Source\UwpTap\UwpTap.cpp:792`
- **Copilot:**
  - `src\Copilot\src\Copilot\Functions\CopilotFunctionHandler.cs`, `CopilotLocalFunctionDescriptorHelpers.cs` (lines 44-111)
  - `src\Copilot\src\Copilot.Vsix\Debugging\DebuggerUIFunctionProvider.cs` (lines 20-230)
  - `src\vc\projbld\CMake\Package\Copilot\CMakeCopilotFunctionProvider.cs`
  - `Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs` (~lines 205-245), `Agents\Sdk\DebuggerSdkAgent.cs` (lines 50-80), `Copilot\AgentSkills\CopilotSkillsProviderAttribute.cs`
</important_files>

<next_steps>
Immediate:
1. Check `build2` with `read_powershell build2`, or read the binlog. If it failed for environment reasons, try `src\Xaml\Scripts\Build-Xaml.ps1 -Component Diagnostics -Scope Source -BuildReferences`, or report the problem.
2. Add the Copilot ProjectReference to Diagnostics.csproj, then rebuild to check for conflicts.
3. Create the files in `src\Xaml\Diagnostics\Source\Diagnostics\Copilot\`:
   - **`XamlAgentService.cs`**: a MEF `[Export]` that:
     - acquires the host,
     - assigns endpoint keys,
     - handles DTOs as JSON (System.Text.Json or Newtonsoft, whichever Diagnostics already references),
     - covers tree, find, properties, set property, bindings, a11y, hot-reload status/apply, window list, and capture (PrintWindow + RTB),
     - builds the status reasons,
     - wraps calls in timeouts and returns the error codes.
   - **`XamlHotReloadLogBuffer.cs`**: a ring buffer of 500 entries.
   - **`XamlDiagnosticsFunctionProvider.cs`**: all the `xaml_*` tools. Required-confirmation tools must take a `CopilotFunctionInvocationContext` parameter.
   - **`XamlDiagnosticsSkillsProvider.cs`**: `[CopilotSkillsProvider("Copilot\\skills", UICONTEXT_DiagnosticToolWindowsAvailable)]`.
   - **Skill content**: `Copilot\skills\xaml-diagnostics\SKILL.md` + `references\*.md`, shipped as VSIX content.
4. Then do the rest, in order:
   - the Copilot-repo registration (FirstPartyTools AllFromProviderTool, FirstPartySkills, DebuggerSdkAgent)
   - the mutation tools
   - the WPF TAP messages (`GetElementBoundsRequest` = 560, `ElementAutomationActionRequest` = 561), capability-gated via a new DiagnosticBits flag
   - the in-app ICopilotExtension re-route
   - WinUI and MAUI TAP support
   - unit tests in `src\Xaml\Diagnostics\Test\Unit`, and docs
5. Build and test, make a single commit with the trailers, don't push, and ask the user about updating a skill.
</next_steps>