<overview>
The user (@spadapet) wanted every Visual Studio XAML Diagnostics feature exposed to Copilot, so AI models can inspect, debug and fix running XAML apps through VS and the TAP. That covers the Live Visual Tree, Live Property Explorer, Live Preview images, binding failures, the accessibility checker, Hot Reload, app/platform discovery, and explanations of why a feature is unavailable.

The prototype is implemented as in-proc Copilot agent tools plus a built-in skill in the Diagnostics DLL, with new capability-gated TAP messages (560 GetElementBounds, 561 ElementAutomationAction) for WPF, WinUI/UWP and MAUI. Style and resource tools were added as well.

All work is committed locally and never pushed. The final phase was recording lessons learned in repo skills.
</overview>

<history>
1. **Earlier segments (summarized):**
   - Planned and implemented the 18 `xaml_*` tools, the `xaml-diagnostics` skill, Copilot registration, the hot reload log buffer, the WPF TAP handler, the in-app toolbar re-route, unit tests and docs.
   - Moved the `SupportsAgentTools` capability bit to TAP-reported status.

2. **UwpTap handlers and the user's questions**
   - Implemented the bounds and automation-action handlers in `UwpTap.cpp`. They compiled for both WinUI3 and UWP x64; linking failed only because `Casablanca.StaticCrt.lib` was missing (a `-NoProjectReferences` build artifact).
   - The user asked how the tools and skill become available. Answered:
     - Skill discovery already exists via the `CopilotSkillsProvider` attribute.
     - The skill is made default-on by an entry in `FirstPartyToolsProvider.FirstPartySkills`.
     - Tools are registered through an `AllFromProviderTool` entry gated on `UICONTEXT_DiagnosticToolWindowsAvailable`.
     - Gave a full tool input/output inventory.
   - The user asked about completeness, the in-app toolbar, and debugging scenarios. Answered with the gaps, the toolbar re-route explanation, and 16 scenarios.

3. **The user asked whether to add style/resource tools**
   - Asked via `ask_user`; the answer was `scope=tier1and2, order=after` (do it after the UwpTap/MAUI work, before the commit).
   - In segments not detailed here, this was completed along with UwpTap linking, MAUI, rebuilds/tests and docs. Commits:
     - `e92845d6d4a8` Expose XAML Diagnostics to GitHub Copilot (prototype)
     - `4b38d3e7ed20` UWP/WinUI and MAUI TAP support, style and resource tools

4. **Skill updates**
   - Asked via `ask_user`; the user answered "Update all of them".
   - Commit `319232bd8061` covered:
     - `building-locally`: the PSModulePath fix, and the warning about piping to `Select-Object -First`.
     - `xaml-build-test-deploy` skill: build with project references after a TAP contract change; `-Filter` example.
     - `src\Xaml\copilot-instructions.md`: the `-Filter` comma rule and an "Adding a host-to-TAP message" section on the capability bit.
     - `Test-Xaml.ps1` help, and a `DiagnosticBits.h` comment fix.
   - It was validated with a fresh agent (5/5) and the skill validator (0 errors).
   - That draft wrongly left out the git safecrlf guidance. The critic required adding it, because the user had selected "Update all of them".

5. **Current revision: adding the safecrlf guidance**
   - Confirmed the machine Git system config (`C:/Program Files/Git/etc/gitconfig`) has `core.safecrlf=true` and `core.autocrlf=true`.
   - Added a pointer paragraph to `.github\skills\building-locally\SKILL.md` (line 26), after the PSModulePath block.
   - Added a new section "## Git rejects LF line endings" to `references\troubleshooting.md` (~lines 66-86), before "Missing Visual Studio components". It covers:
     - the error text;
     - `git config --show-origin` checks;
     - a PowerShell snippet that converts the rejected file to CRLF (UTF-8 without BOM);
     - keep the original encoding (`encoding-conversion` skill); don't change machine Git config; don't convert files marked `eol=lf` in `.gitattributes`.
   - These edits are **not yet committed**.
</history>

<work_done>
Files modified (uncommitted):
- `Q:\src\VS_xaml\.github\skills\building-locally\SKILL.md`: added the safecrlf pointer paragraph at ~line 26.
- `Q:\src\VS_xaml\.github\skills\building-locally\references\troubleshooting.md`: added the "Git rejects LF line endings" section (~66-86).

Local commits (none pushed): `e92845d6d4a8`, `4b38d3e7ed20`, `319232bd8061`.

All SQL todos are done (14/14).

Remaining:
- [ ] Ensure the two edited files use CRLF, so `git add` passes under safecrlf. Convert them if needed.
- [ ] Run the skill validator if one is available.
- [ ] Commit as a new commit, with no amend or rebase.
</work_done>

<technical_details>
- **Git constraints:** never push, rebase or amend; add new commits only. Use `git -C Q:\src\VS_xaml`. Commit trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- **Line endings:** the machine-level Git config sets `safecrlf=true` and `autocrlf=true`. As a result, `git add` aborts on LF files with `fatal: LF would be replaced by CRLF`. Fix by converting the file to CRLF.
- **Build:**
  - In pwsh 7, reset `PSModulePath` to the Windows PowerShell defaults before running `Prime-ForCopilot.ps1`, to avoid the msrustup restore failure.
  - Don't pipe builds into `Select-Object -First`; it orphans MSBuild and causes MSB4104.
  - UwpTap builds need project references (Casablanca), otherwise linking fails with LNK1181.
- **Capability negotiation:** a TAP reports `DiagnosticBits.SupportsAgentTools` (0x20) in `TapInitialized.Status`. The host gates messages 560/561 on that bit, because a TAP never replies to a message it doesn't know.
- **In-app toolbar:** `XamlInAppCopilotExtension` is the only `ICopilotExtension` export. It forwards the prompt, screenshots and file paths to Copilot Chat. `HasChanges` is always false, and the Reject/Feedback callbacks do nothing. Feature flag: `Xaml.Diagnostics.InAppCopilotChat`.
</technical_details>

<important_files>
- `.github\skills\building-locally\SKILL.md`
  - The build skill. Holds the PSModulePath fix (~20-24), the safecrlf pointer (26), and the Select-Object warning (~82).
- `.github\skills\building-locally\references\troubleshooting.md`
  - Contains the new "Git rejects LF line endings" section (~66-86).
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\*`
  - The tools, service, skill, and in-app extension. Already committed.
- `src\Xaml\Diagnostics\Documentation\copilot-tools.md`
  - Feature documentation. Already committed.
</important_files>

<next_steps>
1. Check the line endings of the two edited skill files and convert them to CRLF if needed.
2. Run `git -C Q:\src\VS_xaml add` on those two files, then make a new commit with the trailers, for example "Skills: document git safecrlf LF rejection". No amend, no push.
3. Give the final summary to the user. It should:
   - list all skill updates, now including the safecrlf guidance;
   - list the local commits (`e92845d6d4a8`, `4b38d3e7ed20`, `319232bd8061`, plus the new one);
   - state that nothing was pushed.
</next_steps>