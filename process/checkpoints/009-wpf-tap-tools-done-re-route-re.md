<overview>
The user (@spadapet) wants every Visual Studio XAML Diagnostics feature exposed to Copilot AI, so models can diagnose, debug, and fix running XAML apps through VS and the injected TAP:
- Live Visual Tree (LVT) and Live Property Explorer (LPE)
- Live Preview images and windows
- binding failures
- the accessibility checker
- Hot Reload: status, log, and apply
- the list of apps and their platforms
- explanations of why a feature is unavailable

The plan is approved, and the work is a prototype ("whatever works most easily"). The design is in-proc Copilot agent-mode tools (a brokered `CopilotFunctionHandler`) plus a built-in skill, all in the existing Diagnostics DLL, with no dedicated agent. A few capability-gated TAP messages are added, WPF first.
</overview>

<history>
1. **Plan mode** (earlier): researched the codebase, wrote plan.md and SQL todos. The user approved the plan.
2. **Earlier implementation segments**:
   - Added the Copilot ProjectReference.
   - Created AgentTools: `XamlAgentService`, Imaging, Exception, HotReloadLogBuffer, and `XamlDiagnosticsFunctionProvider` (16 tools at that point).
   - Added the skills provider, SKILL.md, and 2 reference files, plus csproj Content and files.swr entries.
   - Edited FirstPartyToolsProvider in the Copilot repo. It was hand-verified only, because Copilot.Vsix restore fails in the Rust tooling.
   - Found that the Debugger agent already gets first-party tools (`IncludeBuiltInContributions = true`), so no DebuggerSdkAgent change was needed.
   - Added the Phase 3 contract pieces: message types 560/561, payloads, and the `SupportsAgentTools` bit.
3. **This segment**:
   - Created `WpfTap\AgentTools\TapAgentToolsService.cs` and wired it into the projitems and `DiagnosticVisualTreeService`.
   - Added `GetElementBoundsAsync` and `InteractAsync` to `XamlAgentService`.
   - Added the `xaml_get_element_bounds` (NotRequired) and `xaml_interact` (Required, with confirmation) tools to the provider.
   - Updated SKILL.md: tools table, a new "Reproduce a problem by driving the UI" workflow with a debugger-tool fallback, and a rule against destructive interactions.
   - All 5 affected projects build: RuntimeHostBase, DiagnosticsBase, WpfTap (Framework), WpfCoreTap, and Diagnostics. WpfTap needed restore, so it was built without `-NoRestore`.
   - Marked SQL todo `tap-wpf` done.
   - Started the **in-app Copilot re-route** (todo `inapp-reroute`). Researched the Copilot APIs (details below). No re-route code has been written yet.
</history>

<work_done>
All paths are under `Q:\src\VS_xaml`.

**Done and building:**
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\`:
  - `XamlAgentService.cs`. It now includes:
    - `ThrowIfAgentToolsUnsupported`
    - `GetElementBoundsAsync(string[] ids, ct)`: groups IDs by endpoint, sends `GetElementBoundsRequest`, and maps each result to id, isVisible, windowHandle hex, dpiScale, `screen{}` (physical px) and `window{}` (DIPs). Per-ID errors are returned as JSON.
    - `InteractAsync(elementId, action, value, ct)`. Both are inserted after `SetElementPropertyAsync` (~line 697).
  - `XamlDiagnosticsFunctionProvider.cs`: 18 tools, including `xaml_get_element_bounds` and `xaml_interact` (~lines 127-152).
  - `XamlAgentImaging.cs`, `XamlAgentException.cs` (it has error codes including UnsupportedByTap, TapError, NotAvailable; plus `Code` and `Hint`), `XamlHotReloadLogBuffer.cs`.
  - `XamlDiagnosticsSkillsProvider.cs`.
  - `skills\xaml-diagnostics\SKILL.md` (updated) and `references\enablement-and-troubleshooting.md`, `references\xaml-authoring.md`.
- `Diagnostics.csproj`: Content glob for the skills.
- `src\SetupPackages\Xaml\Diagnostics\core\files.swr`: skill files.
- `VisualStudioXamlDiagnosticsHost.cs`: wraps the hot reload logger.
- `src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`: the skill name, the `XamlDiagnosticsToolsUIContext` guid, and an `AllFromProviderTool` entry. Not compiled locally.
- Contract:
  - `XamlTapContract\Networking\XamlMessageType.cs` (560/561) and `UwpTap\XamlMessageType.h`.
  - `TapContract\TapOM\DiagnosticBits.cs`: `SupportsAgentTools = 0x20`, host-only.
  - `UwpTap\DiagnosticBits.h`: comment only.
  - `WpfDiagnosticPlatform.cs`: adds the bit.
  - `XamlTapContract\TapOM\XamlJsonData.cs`: ElementBounds* and ElementAutomationAction* DataContracts.
- **NEW** `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`:
  - Bounds come from PresentationSource, TransformToAncestor, PointToScreen, and the DPI from `TransformToDevice`.
  - Actions run through AutomationPeer patterns: invoke/click, toggle, select/add/remove selection, expand/collapse, setValue/setText (Value or RangeValue), focus, scrollIntoView.
  - It runs on the element's Dispatcher.
- `WpfTap\WpfTapItems.projitems`: Compile item added.
- `WpfTap\WpfVisualTreeService\DiagnosticVisualTreeService.cs`: field, using, creation in Initialize, and Dispose.

**SQL todos:**
- done: plumbing, function-provider, readonly-tools, copilot-registration, skill, hot-reload-tools, mutation-tools, tap-wpf
- pending: inapp-reroute (in progress; research done), tap-winui, tap-maui, docs-tests

**Not done / untested:**
- No runtime testing has been done, and no unit tests exist yet.
- `get_visual_tree(includeBounds)` was skipped; `xaml_get_element_bounds` takes many IDs instead.
- Annotated captures aren't implemented.
</work_done>

<technical_details>
**Build** (run from `Q:\src\VS_xaml` in one PowerShell call):
```
& src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null
& src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project <csproj> -NoProjectReferences [-NoRestore]
```
Pipe the output through `Select-String "error|Build succeeded|Build FAILED| -> "`.
- Build order: RuntimeHostBase → DiagnosticsBase → WpfTap → WpfCoreTap → Diagnostics.
  - `XamlMessageType.cs` is linked into RuntimeHostBase and WpfTapItems.
  - `DiagnosticBits.cs` is linked into DiagnosticsBase and WpfTapItems.
  - `XamlJsonData.cs` is in RuntimeHostBase and WpfTapItems.
- WpfTap/WpfCoreTap need a restore (no assets file), so build them without `-NoRestore`.
- Copilot.Vsix can't restore locally (msrustup Expand-Archive failure).

**TAP facts**
- `IProtocolHandler.RegisterMessageObserver<TReq,TResp>` replies synchronously.
- An unknown message gets no reply. That's why the capability bit plus the 10 s timeout (`TapTimeout`) are needed.
- Host DiagnosticBits 0x4+ are hard-coded per platform host-side.

**In-app re-route research**
- `ICopilotExtension` (`Diagnostics\ICopilotExtension.cs`) has these members:
  - `IsCopilotAvailable`
  - `StartSession()` / `EndSession()`
  - `Task<CopilotResponse> SendCopilotRequestAsync(Guid correlationId, string promptText, ImageData[] contextImages, string[] contextPaths, CancellationToken)`
  - `OnCopilotRejectAsync`
  - `OnCopilotFeedbackAsync(CopilotFeedback, ct)`
  - `event EventHandler<CopilotEventArgs> SessionChanged`

  It is marked `[Experimental(ExperimentalFeatures.Api)]`.
- Consumers:
  - `XamlDiagnosticsHost.cs:69-73` gets it lazily via `componentModel.DefaultExportProvider.GetExportedValueOrDefault<ICopilotExtension>()`, or via the service provider for tests.
  - `InAppUICopilotManager` registers the CopilotRequest observer only when `DiagnosticBits.SupportsInAppMenu` is set. It maps images and paths, then calls the extension.
  - There's no existing implementation in the repo or in the Copilot repo, so exporting one won't create duplicates.
- TAP types:
  - `CopilotResponse` has `ResponseText`, `HasChanges`, and `ResponseStatus` (Unknown/Success/Failure). It lives in `RuntimeHost.TapOM` and collides by name with `Microsoft.VisualStudio.Copilot.CopilotResponse`/`CopilotRequest`, so aliases are needed.
  - `ImageData` has Data (byte[]), Width, Height, and MimeType.
  - `CopilotEventArgs(CopilotEventKind kind, bool? isAvailable, Guid? correlationId)`, where the kinds are StatusChanged and ResponseInvalidated.
- Copilot API:
  - Get the service: `IBrokeredServiceContainer` → `GetFullAccessServiceBroker()` → `GetProxyAsync<ICopilotService>(CopilotDescriptors.CopilotService, ct)`.
  - **Backend mode** (when `IsBackendModeEnabledAsync` is true; members are `[Experimental(ExperimentalFeatures.Backend)]`):
    - `CreateSessionAsync(new CreateSessionOptions { Feature = new CopilotFeatureId("..."), DefaultAgent = null /*default agent with tools*/, IsEphemeral = false })`. A non-ephemeral session ensures the chat window is shown.
    - Then call `SendRequestAsync(sessionId, new CopilotUserMessage { Prompt, DisplayPrompt, Attachments = [CopilotImageAttachment{Data,MimeType,DisplayName}, CopilotFileAttachment{FilePath}, CopilotTextAttachment{Label,Content}] }, ct)`, which returns `CopilotMessageResponse`.
    - There's no feature-ID allowlist.
    - The pattern is in `src\debugger\Razor\CopilotServices\DebugWithCopilotCommand.cs:56-77`.
  - **Legacy fallback**: `StartThreadAsync(new CopilotThreadOptions(new CopilotClientId("...")))`, then `thread.Session.SendRequestAsync(new Microsoft.VisualStudio.Copilot.CopilotRequest { Content = [new CopilotContentMarkdownPart(prompt){Visibility=All}], Context = contexts, ResponseFormat = Markdown }, ct)`.
    - The example is `Copilot.Vsix\OutputWindow\ExplainWithCopilotCommand.cs`.
    - Image context: `new CopilotContext(CopilotDescriptors.Context.Image.Moniker, "image", correlationId, CopilotDefaultTypes.ImageContextName, new CopilotImageContext{Data,MimeType,Width,Height,FilePath=""}){CanReduce=false}` (see the provider at ~line 260).
    - It's unclear whether legacy mode forces Agent mode; it likely uses the current chat mode.
- The provider uses `#pragma warning disable VSCOPILOT_API`. The skills provider uses `VSCOPILOT_BACKEND`. The backend APIs may need the Experimental diagnostic ID suppressed (check `ExperimentalFeatures.Backend` for its ID string).

**Constraints**
- Never push, rebase, or amend. Make a single commit at the end with these trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Use `git -C`.
- Use the dashed Copyright header style.
- At the end, ask the user whether to update a skill. Candidates:
  - WpfTap leaf builds need a restore.
  - Copilot.Vsix restore fails on msrustup.
  - A Required confirmation needs an `ICopilotFunctionBroker` parameter plus `AskConfirmationAsync`.
  - `IncludeBuiltInContributions` makes first-party tools flow into SDK agents.
  - The backend `CreateSessionAsync`/`SendRequestAsync` is the way to submit a prompt plus images to chat.
</technical_details>

<important_files>
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - The façade.
  - Helpers are at lines ~57-185.
  - Bounds and interact are at ~697-823.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - The tools.
  - The image context pattern is at ~243-275.
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`: the new WPF TAP handler.
- `src\Xaml\Diagnostics\Source\Diagnostics\ICopilotExtension.cs`, `Tool\Managers\InAppUICopilotManager.cs`, `Tool\Model\XamlDiagnosticsHost.cs:69-73`: the in-app re-route integration points.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\skills\xaml-diagnostics\SKILL.md`: skill content (the tools table at ~19-37).
- `src\Copilot\src\Copilot\ICopilotService.cs`, `CreateSessionOptions.cs`, `CopilotUserMessage.cs`, `CopilotMessageAttachment.cs`: the APIs for the re-route.
- `src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`: registration (not compiled locally).
- plan.md (session folder): the approved plan.
</important_files>

<next_steps>
**Immediate: implement `inapp-reroute`.**
1. Create `AgentTools\XamlInAppCopilotExtension.cs` as `[Export(typeof(ICopilotExtension))]`.
   - Keep it behind a feature flag or option if easy.
   - Use the `Microsoft.VisualStudio.Copilot` namespace with aliases for the TAP `CopilotResponse`.
2. `IsCopilotAvailable`: true (or check the Copilot signed-in UIContext).
3. `SendCopilotRequestAsync`:
   - Get `ICopilotService`.
   - If backend mode: `CreateSessionAsync` (Feature "Microsoft.VisualStudio.Xaml.Diagnostics.InAppCopilot", non-ephemeral), then `SendRequestAsync`. The prompt is a preamble ("The user asked this from inside their running XAML app (app key X, platform Y); use the xaml_* tools and the xaml-diagnostics skill…") plus the user prompt as `DisplayPrompt`. Attach `CopilotImageAttachment` for each image and `CopilotFileAttachment` for each path.
   - Otherwise: legacy `StartThreadAsync` with a CopilotRequest that carries markdown and image contexts.
   - Fire and forget, or await. Return `CopilotResponse { ResponseStatus = Success, ResponseText = "Sent to GitHub Copilot Chat in Visual Studio.", HasChanges = false }`. Return Failure with the message on exception.
   - Raise `SessionChanged` (StatusChanged) as needed.
   - To include the app key, `XamlAgentService` may need a public `GetEndpointKey`; the extension only gets the correlationId, so a generic preamble is fine for the prototype.
4. Reject and feedback are no-ops (log them).
5. Build Diagnostics. Check whether existing tests (`InAppUICopilotManagerTests`, `WpfInAppCopilotTests`) rely on there being no MEF export; the service-provider injection covers tests.

**Then:**
- `docs-tests`:
  - Unit tests for XamlAgentService in `src\Xaml\Diagnostics\Test\Unit`. Build with `src\Xaml\Scripts\Build-Xaml.ps1 -Component Diagnostics -Scope Test`; run with `Test-Xaml.ps1 -Suite diagnostics -Filter X`.
  - Update `src\Xaml\Diagnostics\README.md` and add `Documentation\copilot-tools.md`.
- `tap-winui` (native UwpTap C++) and `tap-maui`: large. Consider asking the user whether to do them now or leave them as follow-ups.
- Final builds, then a single local commit with the trailers and no push.
- Ask the user about updating a skill.
</next_steps>