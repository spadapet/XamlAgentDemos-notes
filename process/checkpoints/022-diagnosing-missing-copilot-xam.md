<overview>
The user wants Visual Studio's XAML Diagnostics exposed to Copilot so AI can inspect and debug running XAML apps. The covered features are the Live Visual Tree, properties, styles and resources, Live Preview, binding failures, accessibility checks, Hot Reload and TAP capabilities. A prototype was implemented and committed locally, 17 intentionally buggy WPF demo apps were created, and the deployment script was extended to deploy the skill files. The latest question was why the tools don't appear in the user's fastmain VS install even though the skill is active.
</overview>

<history>
1. The user requested a feature plan and implementation exposing XAML Diagnostics to Copilot.
   - The prototype was implemented, reviewed, fixed and committed locally. It includes 22 `xaml_*` tools, TAP messages, the `xaml-diagnostics` skill, and style/resource tools.
2. The user requested demos with a strong "wow factor."
   - 17 WPF apps were created under `Q:\source\XamlAgentDemos`. Each has a `DEMO.md` containing a prompt, the expected tool flow and an answer key.
   - All apps build, but none has been run end to end with the actual Copilot tools.
3. The user asked about `SKILL.md`.
   - We explained the prototype's `xaml-diagnostics` skill and its workflows.
4. The user asked whether `SKILL.md` must be copied manually.
   - The build output contains the skill, but `DeployToVs.ps1` did not deploy it.
5. The user asked to update `DeployToVs.ps1` to deploy the skill files.
   - The script now recursively copies the `AgentTools\skills` tree.
   - Isolated tests passed in PowerShell 7 and Windows PowerShell 5.1.
   - The change is uncommitted.
6. The user reported that the installed fastmain build has the updated XAML Diagnostics DLLs and an active `SKILL.md`, but the tools don't appear in Copilot. They asked why and what makes registered tools appear.
   - Git log showed HEAD at `c15a32e78cc0 Expose XAML Diagnostics to GitHub Copilot (prototype)`; this appears to be the earlier prototype commits combined into one.
   - The installed `C:\vs\fastmain\Common7\IDE\Extensions\Microsoft\Copilot\Microsoft.VisualStudio.Copilot.Vsix.dll` is dated 10:07 AM and lacks the string `Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions`.
   - The built copy at `Q:\src\VS_xaml\out\binaries\amd64chk\bin\netsdk\Copilot\Copilot.Vsix\net472\Microsoft.VisualStudio.Copilot.Vsix.dll` is dated 11:22 AM and contains it.
   - We explained that the tools appear only when all of these are true:
     - The service is registered.
     - Copilot's `FirstPartyToolsProvider.FirstPartyTools` lists it.
     - A XAML app is being debugged with XAML Diagnostics connected.
     - Agent mode is active and the tools are enabled.
   - Fix: close fastmain, copy the built Copilot DLL over the installed one, and restart.
   - We offered to extend `DeployToVs.ps1` to also copy the Copilot DLL; the user has not answered yet.
</history>

<work_done>
- VS repo `Q:\src\VS_xaml`: the prototype is committed. `git log` shows HEAD `c15a32e78cc0`, which appears to be the earlier commits combined.
- `src\Xaml\Scripts\DeployToVs.ps1`: modified and uncommitted. Around lines 460–485, it deploys the skill tree beside the installed Diagnostics DLL. It reports per-file copies and reports the step as skipped when the skill output is missing.
- Demo repo `Q:\source\XamlAgentDemos` contains these commits:
  - `d4ddfb1`
  - `a3f6100`
  - `1ce572f`
- The demo apps are:
  - ThemeBreaker, VanishingSave, PixelPerfect, BindingStorm, GermanReady and A11ySweep
  - BugRepro, LostWindows, GhostClicks, SlowScroll, HotReloadDoctor and PrecedenceWars
  - ResponsiveDashboard, TemplateDetective, StyleMaze, DesignPolish and CrispPixels
- Nothing was changed in the latest turn; it was diagnosis only.
</work_done>

<technical_details>
- The XAML tool service `Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions` is provided by `XamlDiagnosticsFunctionProvider` in the Diagnostics DLL.
- Copilot loads only the first-party tool services listed in `FirstPartyToolsProvider.FirstPartyTools`, so the Copilot.Vsix DLL must include the XAML entry.
- The skill is contributed by `XamlDiagnosticsSkillsProvider`. It points to `AgentTools\skills` relative to its assembly and is gated by `UICONTEXT_DiagnosticToolWindowsAvailable` (`Debugging | DiagnosticConnectionActive`).
- Copilot's `MefAgentSkillsPaths` resolves paths beside the exporting assembly.
- `xaml-diagnostics` is listed among the default-enabled first-party skills.
- A skill alone provides guidance only and never adds tools.
- `DeployToVs.ps1` copies the XAML DLLs and the skill files, but not the Copilot DLL.
- The installed Copilot DLL lives at `C:\vs\fastmain\Common7\IDE\Extensions\Microsoft\Copilot\`. The build output is under `out\binaries\amd64chk\...\Copilot.Vsix\net472`; earlier Diagnostics output was under `x86chk`.
- User git preference: never push, rebase or amend. Make only a new commit when asked, then stop for review.
- The VS repo requires priming before builds via the `building-locally` skill. Never build the whole repo.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1`
  - Local deployment script.
  - Contains the uncommitted skill-deploy change around lines 460–485.
  - It could also be extended to deploy the Copilot DLL.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`
  - Allowlist of first-party tool services; includes the XAML entry.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsSkillsProvider.cs`
  - Skill path and UI-context registration.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\skills\xaml-diagnostics\SKILL.md`
  - Skill guidance, plus a `references` subfolder.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj`
  - Around line 146, copies the skill files to output.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Documentation\copilot-tools.md`
  - Prototype architecture notes.
- `Q:\source\XamlAgentDemos\README.md`
  - Demo inventory and ranking.
</important_files>

<next_steps>
- Wait for the user's answer on whether to extend `DeployToVs.ps1` to copy the built `Microsoft.VisualStudio.Copilot.Vsix.dll` into the Copilot extension folder under `Extensions\Microsoft\Copilot`. Its dependencies may also need copying; verify before adding.
- After deployment, the user should restart fastmain, debug a XAML app, and confirm the `xaml_*` tools appear in Agent mode.
- The `DeployToVs.ps1` change remains uncommitted; commit only if the user asks.
</next_steps>