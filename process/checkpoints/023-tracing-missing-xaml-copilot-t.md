<overview>
The user wants Visual Studio's XAML Diagnostics exposed to Copilot so AI can inspect and debug running XAML apps. The scope covers the Live Visual Tree, properties, styles and resources, Live Preview, binding failures, accessibility checks, Hot Reload and TAP capabilities. A prototype has been implemented and committed locally, 17 demo WPF apps were created, and `DeployToVs.ps1` was extended to deploy the skill files. The current issue is that in the user's fastmain Experimental instance, the `xaml-diagnostics` skill appears in the Copilot session but the `xaml_*` tools do not, and we are tracing why.
</overview>

<history>
1. Earlier work (before the previous compaction):
   - Planned and implemented the prototype: 22 `xaml_*` tools, TAP messages, the skill, and style/resource tools. It was reviewed, fixed and committed.
   - Created the 17 demo apps.
   - Extended `DeployToVs.ps1` to deploy the skill tree; this change is uncommitted.
   - Diagnosed that the installed Copilot DLL lacked the XAML entry in its first-party tools list.
2. The user said they F5-deployed the Copilot solution from VS IntPreview into fastmain and asked whether other DLLs needed updating.
   - The Experimental instance (`18.0_ca393f20Exp`) has the F5-deployed Copilot DLL (version 42.42.42.42).
   - The XAML Diagnostics and TAP DLLs are current.
   - The installed skill files match the source exactly.
   - We answered that no other DLLs are needed and that the tools appear only while a XAML app is being debugged with Diagnostics connected.
3. The user ran fastmain with `/log`; the tools still don't appear, but `SKILL.md` does.
   - **ActivityLog** (`%APPDATA%\Microsoft\VisualStudio\18.0_ca393f20Exp\ActivityLog.xml`, 1:45 PM):
     - `XamlDiagnosticsPackage` loaded.
     - There are no XAML errors and no NotLocallyRegistered entry for the XAML service.
     - Azure's `AzureFunctionHandlerAggregator` was declined as NotLocallyRegistered.
   - **MEF cache** (`ComponentModelCache`, built 1:03 PM): contains `XamlDiagnosticsFunctionProvider`, `XamlDiagnosticsSkillsProvider` and `XamlAgentService`. The `.err` file has no errors for these parts, so MEF composition is fine.
   - **Copilot tool plumbing** (traced through the code):
     - `FirstPartyToolsProvider.ToolsState` subscribes at init to every first-party tool moniker, using `GetSafeObservable<ICopilotFunctionProvider>` (`FirstPartyToolSubscriptions`).
     - `FirstPartyToolEvaluator` only includes descriptors while the tool's UI context is active.
     - `CopilotFunctionRegistry` merges first-party tools into session tools as "recommended tools" (`GetSessionToolsAsync`), unless the responder sets `DisallowRecommendedTools`.
   - **Other in-proc handlers register explicitly:** for example, `CopilotCppFunctionHandler` (vc), CMake and BuildInsights call `ICopilotRegistrationService.RegisterFunctionProviderAsync`. The XAML provider does not; it relies only on the first-party list.
   - **The session is likely the CLI-based harness:** a `~/.copilot` file changed during the run. Its tools are bridged via `src\Copilot\src\Copilot.Vsix\Backends\HostTools\CliFunctionProvider.cs`, which:
     - Filters registry tools whose provider name is in `FirstPartyProviderNames` (line ~87) down to `FirstPartyAllowlist` (line ~51).
     - Has an `ExcludedRegistryTools` denylist (line ~71).
     - Treats `FirstPartyToolProviderConstants.Moniker` specially (lines ~119–149).
   - **Leading hypothesis:** the harness `CliFunctionProvider.Classify` drops the XAML tools because:
     - The first-party provider moniker is in `FirstPartyProviderNames`.
     - The `xaml_*` names are not in `FirstPartyAllowlist`.
   - This was being verified when compaction occurred.
</history>

<work_done>
- **VS repo** `Q:\src\VS_xaml`:
  - HEAD is `c15a32e78cc0`, "Expose XAML Diagnostics to GitHub Copilot (prototype)".
  - `src\Xaml\Scripts\DeployToVs.ps1` has an uncommitted change around lines 460–485 that deploys the skill tree.
- **Demo repo** `Q:\source\XamlAgentDemos`: commits `d4ddfb1`, `a3f6100` and `1ce572f`, containing the 17 apps.
- **This turn:** no code changes, investigation only. A background PowerShell command (shellId 288) searching for recent Copilot log files may still be running or finished; its output has not been read.
</work_done>

<technical_details>
- **XAML service:**
  - Name `Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions`, version "0.1".
  - Exported with `[ExportBrokeredService(..., Audience = Local)]` on `XamlDiagnosticsFunctionProvider : CopilotFunctionHandler, IExportedBrokeredService`.
  - Listed in `FirstPartyToolsProvider.FirstPartyTools` as an `AllFromProviderTool` gated by UI context `5C69788A-62F3-42C8-880A-1A4CE40C6671` (Debugging | DiagnosticConnectionActive), around lines 263–269.
- **Visibility path for first-party tools:**
  1. `ToolsState` subscribes to the provider.
  2. The evaluator includes descriptors only while the UI context is active.
  3. `FirstPartyToolsProvider` (moniker `FirstPartyToolProviderConstants.Moniker`) publishes them.
  4. `CopilotFunctionRegistry.GetFirstPartyToolsAsync` adds them to session tools.
  5. In the CLI harness, `VsToolsSessionProvider` subscribes to the registry, and `CliFunctionProvider.Classify` filters the result.
- **Explicit registration:** non-first-party in-proc providers register with `ICopilotRegistrationService.RegisterFunctionProviderAsync(moniker, identity, ct)`, obtained via `serviceBroker.GetProxyAsync<ICopilotRegistrationService>(CopilotDescriptors.InteractionService)`. See `vc\designtime\Managed\Copilot\CopilotCppFunctionHandler.cs` around lines 650–690. Tools registered this way pass the harness filter unless denylisted ("registry/extension allowed").
- **Skill vs. tools:** a skill only provides guidance and never adds tools. The skill appears through `XamlDiagnosticsSkillsProvider`.
- **Subscription faults:** `FirstPartyToolSubscriptions` never retries a faulted subscription except on `AvailabilityChanged`.
- **User git preference:** never push, rebase or amend. Make only a new commit when asked, then stop for review.
- **Builds:** the VS repo requires priming via the `building-locally` skill before building. Never build the whole repo.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\Backends\HostTools\CliFunctionProvider.cs`
  - The harness tool filter and the likely culprit.
  - Key sections: `FirstPartyAllowlist` (around line 51), `ExcludedRegistryTools` (around line 71), `FirstPartyProviderNames` (around line 87) and `Classify` (around lines 106–150).
  - Not yet fully read.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`
  - First-party list and `ToolsState`; the XAML entry is around lines 260–269.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolEvaluator.cs` and `FirstPartyToolSubscriptions.cs`
  - Evaluation and subscription logic.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Core\Functions\CopilotFunctionRegistry.cs`
  - Merges registered and first-party tools; see `GetSessionToolsAsync` around line 309 and the wrapper around line 1082.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - The XAML tool provider; it may need explicit registration.
- `Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1`
  - Contains the uncommitted skill-deploy change.
</important_files>

<next_steps>
1. Read `CliFunctionProvider.cs` fully and confirm whether the `xaml_*` tools are dropped:
   - First-party provider names plus allowlist, or
   - The `AskTools`/ask-mode restriction.
   Check whether there is trace logging of Classify decisions, which may appear in the Copilot output pane or logs.
2. Optionally read the result of shellId 288, the log-file search.
3. Propose a fix to the user. Options:
   - **(a)** Add the `xaml_*` tool names (or a XAML-provider exemption) to the harness allowlist in `CliFunctionProvider.cs`.
   - **(b)** Have the XAML provider register itself via `ICopilotRegistrationService.RegisterFunctionProviderAsync` while the diagnostics connection is active, unregistering on disconnect, following the `CopilotCppFunctionHandler` pattern. Keep or remove the first-party entry as appropriate.
   Explain the trade-offs and implement after confirmation. Rebuild only the affected projects after priming, then have the user F5-redeploy and retest while debugging a XAML app.
4. Commit only if the user asks (a new commit only).
</next_steps>