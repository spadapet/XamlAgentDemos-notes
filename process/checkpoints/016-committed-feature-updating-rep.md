<overview>
The user (@spadapet) wants Copilot AI to have access to every Visual Studio XAML Diagnostics feature, so models can diagnose, debug and fix running XAML apps through VS and the injected TAP. That covers the Live Visual Tree, property explorer, Live Preview images, binding failures, accessibility, Hot Reload, app discovery, styles and resources.

The approved prototype is complete and committed locally:
- in-proc `xaml_*` Copilot agent tools (22) and a built-in skill, both in the Diagnostics DLL;
- new TAP messages 560-563 in all TAPs;
- the in-app Copilot re-route.

The user then asked to update repo skills with the lessons learned ("Update all of them"), and that work is in progress.
</overview>

<history>
1. **Earlier segments**
   - Planned and implemented the whole feature: tools, skill, Hot Reload log buffer, the 560-563 contract, the `SupportsAgentTools=0x20` bit, and the WPF, UwpTap and MauiTap handlers.
   - Added the style tools (Tier 1) and resource tools (Tier 2), the Copilot `FirstPartyToolsProvider` registration, and unit tests (36/36 pass).
   - Answered the user's questions on availability, inventory, completeness, the legacy toolbar and scenarios.

2. **This segment: finished docs and committed**
   - **Docs**
     - `SKILL.md`: added the 4 style/resource tools to the table and dropped "(WPF)" from bounds/interact. Added the recipe "A style, setter, or resource isn't applying". The `UNSUPPORTED_BY_TAP` fallback text now cites older TAPs (remote debugger), and the description mentions "styles and resource lookup".
     - `copilot-tools.md`: added tool rows, a table of messages 560-563, a TAP files table, per-platform resource lookup order, and an F5 note covering all platforms.
     - `xaml-authoring.md`: the Resources section now points to `xaml_find_resource` and `xaml_get_resource_dictionaries`.
   - **Commits**
     - The first `git add` aborted with "fatal: LF would be replaced by CRLF" on the MauiTap `TapAgentToolsService.cs`. The commit still went through with only the previously staged files: **e92845d6d4a8** "Expose XAML Diagnostics to GitHub Copilot (prototype)".
     - Amending isn't allowed, so I normalized that file to CRLF and made a second commit: **4b38d3e7ed20** "XAML Copilot tools: UWP/WinUI and MAUI TAP support, style and resource tools". Both commits have the trailers.
     - The working tree was clean, and nothing is pushed.

3. **Asked about skill updates; the user chose to update all of them**
   - Loaded the `writing-skills` skill and verified facts:
     - Prime and a `-NoRestore` build work in pwsh 7 without the PSModulePath reset. The original failure was in restore: `src\ConfigData\Molds\Rust\msrustup.proj:60` runs `powershell.exe` 5.1 on `Install-MsRustup.ps1`, which calls `Expand-Archive` at line 283. Under pwsh 7 it inherits `PSModulePath` and loads the wrong Archive module (`MethodCountCouldNotFindBest`).
     - An unquoted `-Filter a,b` binds to a `[string]` as "a b" (verified).
     - `core.safecrlf=true` comes from the machine's Git system config (`C:/Program Files/Git/etc/gitconfig`), not from the repo. I decided not to write a skill rule for it, and must explain this to the user.
     - The UwpTap shproj references `$(CasablancaProj)`, `$(IpcProj)` and `$(UtilityProj)` (lines 107-109).
     - The host platform classes copy only explicit `tapStatus` bits.
   - Made the edits listed in work_done.
   - The validator ran (`Validate-CopilotTooling.ps1`): frontmatter for 92 skills passed and markdownlint passed. The output was 130 KB and the link-check tail is unreviewed; it's saved at `C:\Users\peterspa\AppData\Local\Temp\1794434955836-copilot-tool-output-5872-4f74d48c-cc8d-46d7-8260-6531a621e10e.txt`.
   - Launched a background explore subagent, `skill-test` (agent_id `d8ec9f72-9231-473e-acea-51437cfeab64`), as the behavioral test. It got five questions with no hints: the Test-Xaml multi-filter, CS0246 after a contract change, the msrustup error, adding a TAP message, and `Select-Object -First`. Its result has not been read yet.
</history>

<work_done>
**Committed** (local only): e92845d6d4a8 and 4b38d3e7ed20, covering the whole feature and its docs.

**Uncommitted skill and doc updates (current diff, 6 files)**
- `.github\skills\building-locally\SKILL.md`
  - Build tool section: an msrustup / `MethodCountCouldNotFindBest` / PowerShell 7 paragraph with the `$env:PSModulePath = "$env:ProgramFiles\WindowsPowerShell\Modules;$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules"` fix (rerun prime and restore in the same process).
  - "Running builds from terminals": redirect output to a file and search it; don't pipe to `Select-Object -First N` (MSBuild keeps running and the next build fails with MSB4104).
- `src\Xaml\.copilot\skills\xaml-build-test-deploy\SKILL.md`
  - Quoted comma `-Filter` example plus an explanation.
  - A bullet "After changing a shared TAP contract…": build with references; stale DLL gives CS0246; UwpTap gives LNK1181. It links to `#shared-tap-contract-changes`.
- `...\xaml-build-test-deploy\references\build-test-lessons.md`: new section "## Shared TAP contract changes" (managed consumers, UwpTap link dependencies).
- `src\Xaml\Scripts\Test-Xaml.ps1`: the `.PARAMETER Filter` help explains comma-separated substrings and quoting.
- `src\Xaml\copilot-instructions.md`: new section at the end, "## Adding a host-to-TAP message", with 5 steps:
  1. message ID and its native mirror, plus payloads;
  2. the `DiagnosticBits` flag, `PublicAPI.Unshipped`, and the `.h` mirror;
  3. set the bit in each TAP's status (WpfTap and MauiTap `VisualTreeService.cs`, `UwpTap.cpp`);
  4. pass it through `WpfDiagnosticPlatform`, `WinRTDiagnosticPlatform` and the mobile `DiagnosticPlatform`;
  5. check the bit before sending.

  It cites `SupportsAgentTools` as the example.
- `src\Xaml\Shared\Source\UwpTap\DiagnosticBits.h`: the stale `SupportsAgentTools` comment now covers 560-563.

**Checklist**
- [x] Docs and commits
- [x] Skill edits, validator (frontmatter and markdownlint pass)
- [ ] Read the behavioral subagent result and fix any guidance it missed
- [ ] Check the validator link-check for failures in the edited files
- [ ] Commit the skill updates as a third local commit (no amend, no push)
- [ ] Final summary to the user
</work_done>

<technical_details>
**Build**
```
cd Q:\src\VS_xaml; $env:PSModulePath = "...WindowsPowerShell..."; & src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project <proj> [-NoProjectReferences] [-NoRestore] [-Platform x64] *> .vs\<name>.txt
```
Then `Select-String` the output for errors and "Build succeeded".

**Tests**
```
src\Xaml\Scripts\Test-Xaml.ps1 -Suite diagnostics -Filter "XamlAgentTools,DiagnosticPlatform,HostDebugger,InAppCopilot"
```
36/36 pass.

**Git**
- This machine has `core.safecrlf=true` and `core.autocrlf=true` in its system config. `git add` of an LF file aborts the add, so normalize to CRLF first.
- Repo files use `text=auto`.

**Shell quirk**: in the PowerShell tool, `R` is an alias (`Invoke-History`), so don't name helper functions `R`.

**Constraints**
- Never push, rebase or amend. Make local commits via `git -C Q:\src\VS_xaml` with trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Skill files are UTF-8 without BOM.

**writing-skills rules**
- No incident narration; guidance must be conditional and grounded.
- Behavioral test with a fresh subagent that gets no hints.
- Run the validator: `& "Q:\src\VS_xaml\.github\skills\shared\scripts\Validate-CopilotTooling.ps1" -DotGithubRoot "Q:\src\VS_xaml\.github" -FailOnError`.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\.github\skills\building-locally\SKILL.md`: msrustup fix (~line 20) and the Select-Object rule (~line 79). Uncommitted.
- `Q:\src\VS_xaml\src\Xaml\.copilot\skills\xaml-build-test-deploy\SKILL.md` (~lines 62-67, 129-135) and `references\build-test-lessons.md` (~line 126): XAML lessons. Uncommitted.
- `Q:\src\VS_xaml\src\Xaml\copilot-instructions.md` (end of file): the TAP-message capability pattern. Uncommitted.
- `Q:\src\VS_xaml\src\Xaml\Scripts\Test-Xaml.ps1` (lines 34-37) and `src\Xaml\Shared\Source\UwpTap\DiagnosticBits.h` (line 21). Uncommitted.
- Feature files, already committed:
  - `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\*` (`XamlAgentService.cs`, `XamlDiagnosticsFunctionProvider.cs`, `skills\xaml-diagnostics\SKILL.md` + references)
  - `src\Xaml\Diagnostics\Documentation\copilot-tools.md`
  - the TAP handlers in WpfTap, UwpTap and MauiTap `AgentTools`.
</important_files>

<next_steps>
1. Read the `skill-test` subagent result with read_agent (`d8ec9f72-9231-473e-acea-51437cfeab64`).
   - For each answer it got wrong or where it missed the guidance, fix the governing instruction (its visibility or routing).
   - If edits are needed, rerun a fresh subagent.
2. Grep the saved validator output for link failures (`[✖]` or "ERROR") in the edited files. The `xaml-build-test-deploy` skill is under `src\Xaml`, not `.github`, so the validator may not cover it. Check its anchor link `#shared-tap-contract-changes` manually.
3. Run `git -C Q:\src\VS_xaml status` and diff, then make a third local commit (for example "Skills: build and XAML TAP lessons from Copilot tools work") with the trailers. Don't push.
4. Give the user a brief final summary:
   - which skills and docs were updated, and where;
   - that the safecrlf lesson was not added, because `core.safecrlf=true` comes from this machine's Git system config, not the repo; offer a placement if they still want it;
   - the three commit IDs.
</next_steps>