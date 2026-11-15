# XAML Diagnostics for Copilot: process journal

This is a chronological record of how the `xaml_*` Copilot tools and the `xaml-diagnostics` skill were designed, built, deployed, tested and iterated on. The detail lives in:
- `checkpoints/` (001–062): working summaries written at each context compaction, oldest first. `checkpoints/index.md` lists them.
- `plan.md`: the approved feature plan, with addenda.
- `session-transcript.md`: the full Copilot CLI session rendered as Markdown. `session-events.zip` holds the raw `events.jsonl`.
- `../TestPass.md`: the run table and numbered findings (#1–111).
- `../test-runs/<Demo>/<tag>/`: per-run artifacts (runner.log, transcript.md, events.jsonl, fix.diff, status.txt, vs-final.png).
- `harness/`: scripts that drove VS and Copilot Chat. `analysis/`: log-mining scripts, `feedback.md`, and deploy/redirect helpers.

## Phase 1: research and plan (checkpoints 1–2)
- Read the public docs (LVT/LPE, binding diagnostics, Live Preview, hot reload, troubleshooting) and the Diagnostics host model: `XamlDiagnosticsHost`, `ElementTreeContainer`, `PropertyExplorer`, binding failures, Accessibility Checker, `LivePreviewManager`, and the hot reload host.
- Chose the surface: in-proc Copilot agent-mode tools (`[CopilotFunction]` provider exported as a brokered service) plus a built-in skill. No custom agent, because the tools must work in Agent mode and in the Debugger agent.
- Decisions: put the code in `Microsoft.VisualStudio.DesignTools.Diagnostics.dll`; mutating tools require confirmation; add new TAP messages only when no existing message can do the job, and gate each on a capability bit; roll out WPF → UwpTap (WinUI/UWP) → MAUI; re-route the in-app toolbar Copilot prototype into Copilot Chat.

## Phase 2: implementation (checkpoints 3–17)
- Built `XamlAgentService`: endpoint keys, element IDs (`endpointKey:handle`), paging and output budgets, DTOs, and structured error codes with hints.
- Built `XamlDiagnosticsFunctionProvider` and registered it with Copilot (FirstPartyToolsProvider, Debugger agent).
- Added a skill provider that ships `skills/xaml-diagnostics/SKILL.md`.
- Added new WPF TAP messages: element bounds, automation actions (interact), find resource, resource dictionaries, and later hit-test and hover. Then ported them to UwpTap (native) and MauiTap, behind the `SupportsAgentTools` capability bit.
- Added style and value-precedence tools: `xaml_get_element_styles` and `xaml_explain_property_value`.
- Re-routed the in-app Copilot prototype into Copilot Chat with XAML context.
- Wrote docs (`Documentation/copilot-tools.md`) and unit tests. Committed the feature locally once.

## Phase 3: demo apps (checkpoints 18–20, 29)
- Built 17 small WPF apps in `Q:\source\XamlAgentDemos`, each with planted bugs that are hard to find without runtime data.
- Moved the answer keys (`DEMO.md`) out of the demo repo into this notes repo (`src/*/DEMO.md`), so the agent under test couldn't read the solution.

## Phase 4: deployment problems (checkpoints 21–28, 36–37)
- Patched the fastmain Exp instance with the built DLLs (`harness/Redeploy.ps1`, verified by hash).
- The tools didn't show up in Copilot CLI-backed chat sessions. Root-caused it to tool group/registration, then fixed it (checkpoints 22–26).
- Fixed threading problems (UI-thread hops, JTF) found in live calls (27–28).
- The Accessibility Checker failed on a System.Drawing.Common assembly conflict. The workaround was a manual redirect to 10.0.0.0 in the Exp `devenv.exe.config` (`analysis/Patch-DrawingRedirect.ps1`). The real fix is PR 807376.

## Phase 5: automated test harness (checkpoints 30–35)
- `harness/Run-Demo.ps1` drives VS through DTE (COM ROT): open the project, build, F5, wait for the TAP.
- It sends the prompt to Copilot Chat through UI Automation and waits for the turn to finish by watching the CLI session `events.jsonl`.
- It then asks follow-up feedback questions ("what did you verify", "what blocked you", "which tools were confusing") and collects artifacts. Finally it resets the demo repo with git checkout/clean.
- Operational lessons:
  - A locked or minimized RDP desktop breaks SendKeys and screen capture. Fixed with `KeepAwake.ps1` and longer sleep times on the host machine.
  - Tool permission prompts sometimes appeared even with "allow all". The harness auto-clicks Allow through UIA.
  - Debug asserts from the checked build were found and fixed (for example, a telemetry assert from a tool call, checkpoint 53).
  - A paused debugger blocks every TAP call. The tools now return a clear `DEBUGGER_PAUSED`-style error telling the agent to resume (`debugger_continue`). The skill documents this (checkpoints 41, 45).

## Phase 6: test passes and feedback-driven fixes (checkpoints 34–57)
- Ran all 17 demos, many several times. Each run's feedback became a numbered finding in `TestPass.md` and usually a tool or skill fix, followed by a rebuild, redeploy and rerun.
- Major additions driven by the runs:
  - `xaml_hit_test` (GhostClicks).
  - Glob name filters.
  - Evaluated values and item paths (`ColumnDefinitions[2].Width`).
  - Output-size budgets (`OUTPUT_TOO_LARGE` with hints).
  - Hot reload status that surfaces .NET (code) hot reload failures.
  - `IsEnabled` and disabled-opacity explanations.
  - Paused-debugger handling.
  - Expanded SKILL.md XAML-authoring guidance.
- `analysis/feedback.md` collects the agent feedback answers. The `analysis/*.js` scripts mined `calls.jsonl` for call counts, failures, durations and argument shapes.

## Phase 7: tool consolidation and cross-platform parity (checkpoints 48–52)
- Merged four status/list tools into `xaml_get_status`.
- Added list (batch) inputs, so one call can cover many elements, properties or windows. This cut round trips.
- Kept the tool names descriptive, so models still know which tool to pick.
- Ported the new TAP features (hit-test, etc.) to UwpTap and MauiTap.
- Retested on the consolidated tools: 0 failed calls on GhostClicks and VanishingSave.

## Phase 8: new diagnostic tools (checkpoints 58–61)
- `xaml_interact` hover simulation.
- Tighter nameFilter matching (exact, then glob, then substring, with match-kind reporting).
- `xaml_explain_visibility`: a ranked "why isn't this visible" list (Visibility chain, zero size, clipping, opacity, z-order overlap, 0-width grid column, off-screen).
- `xaml_audit_styles`: finds local values that override or duplicate style or design-token values.
- Binding failure status (still failing vs. stale).
- Retest fixes: Visibility enum numbers misread as causes (#105), binding value display (#104), 0-width column detection (#106), null item paths (#107), and `applied=true` while code hot reload failed (#108).

## Phase 9: Accessibility Checker pane integration (checkpoint 62 and later)
- `xaml_run_accessibility_check` now runs through the same view model as the Accessibility Checker pane, so the pane updates and shows the results. Results include the XAML file, line and column.
- Stop (cancel) in the pane returns `CANCELED`. The agent is told to ask the user before rerunning.
- If a check is already running, the tool joins it instead of restarting it.
- Fixed run ownership and `LastRunError` races in the view model.
- Added component test `AccessibilityChecker_CancelAndConcurrentRun`. It doesn't run locally because of a CoreCLR testhost error.
- Logged as finding #111.

## Key commands
```powershell
# Build Diagnostics (from Q:\src\VS_xaml, primed shell)
. src\Shared\Tools\Scripts\Prime-ForCopilot.ps1
& src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences
# Unit tests
out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\DesignTools.Tests.Unit.XamlDiagnostics.exe -class "*XamlAgentToolsTests"
# Redeploy to fastmain Exp (elevated, VS closed) and run one demo
.\process\harness\Redeploy.ps1
.\process\harness\Run-Demo.ps1 -Name VanishingSave -Tag myrun
```

## Lessons learned
- Real agent runs against real apps found far more issues than unit tests: 111 findings, most of them in tool ergonomics rather than crashes.
- Asking the agent structured follow-up questions after each fix was the best source of tool improvements.
- Every error needs an actionable hint: a paused debugger, no source info, unsupported TAP, output too large, a cancelled check.
- Batch inputs and fewer, well-named tools reduced round trips without hurting tool selection.
- Hide answer keys from the agent under test. Keep the desktop unlocked for UIA-driven harnesses.
- Hot reload "applied" must account for code (.NET) hot reload failures, not just XAML.

## Demo recommendation (2026-11-15)
- **VanishingSave** (primary). Prompt: "There should be a Save button in the footer of my running app, but I can't see it. Find out every reason it's not visible and fix them." Four stacked causes: CanSave binding collapsing the button, a 0-width footer column (compact-footer default), a status overlay covering it, and disabled opacity 0.4. 4/4 fixed in every pass. Recent runs: 2.1 min (run-consolidated), 3.0 min (r9), 2.5 min (r10, 0 failed calls). Shows `xaml_explain_visibility`, bounds/hit-test, live set-property experiments, hot reload and before/after captures.
- **GhostClicks** (backup, 1.2–1.5 min). Hit-test proves an invisible overlay eats clicks; less visual change.
- **BindingStorm** (finale). 10/10 binding failures across tabs and a dialog, many screenshots, but 2.6–5.0 min.

## Finding #112: short demo prompt (user report)
The user ran "Where is my Save button?" and got only an explanation of 1 of the 4 causes. `xaml_explain_visibility` couldn't see causes masked by Collapsed (the zero-width column and the overlay). Added latent causes, a cause count in the verdict, a JValue-null crash fix and stale binding-failure tagging, and the SKILL.md guidance "where is X means fix it". Reran where1-3 and r11: all 4/4, the last three with 0 failed calls. Demo prompt can now be the short "Where is my Save button?".

## Finding #113: overlap check for latent overlays
A critic review of #112 found that the latent `covered` cause didn't verify overlap. Added a batched bounds check (at least 50% coverage) with a stretch-to-fill fallback for zero-size layouts. Live run where4 exposed two more bugs: WPF alignment enum numbers, and the fixedInSource window being too small for multi-line tags. Both were fixed and verified in where5 (4/4, 0 failed calls, 1.6 min). See TestPass.md #113.
