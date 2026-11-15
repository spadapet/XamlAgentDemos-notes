<overview>
The user is exposing Visual Studio XAML Diagnostics to Copilot through 22 `xaml_*` tools (in Diagnostics.dll) and a deployed `xaml-diagnostics` skill. The tools are exercised with 17 WPF demo apps in `Q:\source\XamlAgentDemos`.

Current request: autonomously test every demo in the running fastmain VS, iterating as many times as needed while results improve. For each demo:
- Build it, run it, and prompt Copilot Chat.
- Ask follow-up questions.
- Save the logs, then fix the skill and tools.
- Reset the repo.
- Record all changes and findings in notes.

I drive VS with a PowerShell/UIA/DTE harness. DEMO.md answer keys live in `Q:\source\XamlAgentDemos-notes` and are used only for grading; the chat agent never sees them.
</overview>

<history>
1. Earlier work (prior checkpoints):
   - Implemented the tools, the skill, registration, the tool Group, and threading fixes.
   - Created the demos and moved the notes out of the demo repo.
   - Applied the fixes from the BindingStorm log analysis.
   - Built the harness. VanishingSave run1 passed 4/4 with findings 1–6.
   - Nothing is committed.

2. Continuing the "start your work" autonomous test pass:
   - **Batch 1 attempt 1 failed.** Every demo failed at `SetFocus` on the chat input. The probable cause was focus or popup state left by the mode selector. LostWindows also failed because the W32 Add-Type was redefined.
   - **Hardened the harness:**
     - Guarded the Rot Add-Type.
     - Renamed the W32 class to `W32b` and added `mouse_event`.
     - Added `Click-Element`.
     - `Set-ChatText` now retries 6× (ShowWindow SW_SHOW=5, Focus-Vs, SetFocus; on failure it sends ESC, then falls back to a mouse click).
     - Verified manually that it works.
   - **Restarted batch 1** as async shell `batch1b` (ThemeBreaker, BindingStorm, GhostClicks, LostWindows, Tag run1).
   - **Implemented tool fixes** in Diagnostics while the batch ran, then built Diagnostics successfully (1 warning, 0 errors). It is **not yet deployed**, because deploying requires closing VS after the batch.
   - **ThemeBreaker run1 finished: 6/6 causes found**, plus an extra fix to the toggle's checked trigger.
     - Problem: the agent stopped debugging, rebuilt, and restarted the app, because hot reload of the key rename `AccentBush`→`AccentBrush` in Dark.xaml (a theme dictionary loaded from code) didn't reach runtime.
     - Agent feedback:
       - `xaml_apply_hot_reload` said `applied=true` with no errors even though the change didn't apply.
       - Property tools return `DynamicResourceExtension`/`BindingExpression` instead of the resolved value.
       - The hot reload log had no edit-level outcomes.
   - **Investigating** how to return resolved values for expression properties. TapPropertyValue has no evaluated-value field. WPF `WpfDependencyPropertyValueSource` has `IsExpression`, and `DispatcherVisualTreeContext.cs:313` handles `source.IsExpression`. Still need to find how the LPE shows the evaluated value (possibly a separate chain entry or a Handle to expand).
   - BindingStorm was running at the time of compaction (session `80e69ee7-...`, started 20:39).
</history>

<work_done>
**Harness** (`C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness\`):

| File | Contents |
|---|---|
| `Harness.psm1` | Get-VsPid, Get-Dte, Invoke-Dte, Find-Ui, Get-ChatInput, Set-ChatText (now with retry), Send-ChatPrompt, New-ChatThread, Set-Autopilot, Approve-PendingPermission, Start-Demo/Stop-Demo, Reset-Demos, Save-VsScreenshot, Wait-TurnDone, Get-VsDialogs/Close-VsDialogs (click Disable for Hot Reload dialogs) |
| `Run-Demo.ps1` | Runs a single demo |
| `Run-Batch.ps1` | `-Names -Tag`; reads `prompts.json` |
| `pre-ThemeBreaker.ps1` | Pre-run setup for ThemeBreaker |
| `render.js`, `peek.js` | Log rendering and inspection |
| `KeepAwake.ps1` | Keep-awake loop, running in shell `keepawake2` |

Run output goes to `Q:\source\XamlAgentDemos-notes\test-runs\<Demo>\<tag>\`. Each run folder holds `transcript.md`, `events.jsonl`, `fix.diff`, `runner.log`, `dialogs.log`, `status.txt`, and `vs-final.png`.

**VS repo changes in this segment** (uncommitted, built, not deployed):

`XamlAgentService.cs`:
- New `MaxPropertiesPerCall = 120` constant.
- `GetElementPropertiesAsync`:
  - `includeAll` now hides overridden non-binding duplicates.
  - Results are capped at 120 with a `truncated` count, and the hint suggests `nameFilter`.
- `ELEMENT_GONE` hint now explains that hot reload, template changes, and tab switches recreate elements.
- Element bounds:
  - Adds `insideWindowFraction` and `clippedByWindow`, computed from the element's screen rect intersected with the root HWND client rect (`System.Windows.Rect` fully qualified).
  - The note explains that `isVisible` doesn't account for clipping.
- `GetHotReloadLog` now returns `dotNetHotReloadPane` (the last 40 non-empty lines of the .NET Hot Reload output pane, filtered by `textFilter`).
- `ApplyHotReloadAsync` with `includeCodeChanges`:
  - Records the pane line count before posting the command.
  - Waits up to 15 s for pane output to settle or for a modal dialog to appear.
  - Returns `codeHotReloadOutput` (up to 50 new lines) and `visualStudioPromptOpen`.
  - When a prompt is open, the hint explains rude edits and tells the agent to stop and tell the user.
- New helpers:
  - `HotReloadOutputPaneGuid` (`7BD3920C-C53C-40ED-8D79-4D2F601BEFB0`).
  - `ReadHotReloadPaneLines()`: uses EnvDTE `dte.Windows.Item(vsWindowKindOutput).Object as OutputWindow`, finds the pane by Guid, and reads `TextDocument` via EditPoint.GetText.
  - `IsVisualStudioShowingModalDialog()`: true when `Application.Current.MainWindow`'s HWND is disabled (`IsWindowEnabled` returns false).

`XamlAgentImaging.cs`:
- Added `IsWindowEnabled` (public wrapper and P/Invoke).
- Added `GetClientRect`, a `POINT` struct, and `ClientToScreen` P/Invokes.
- Added `GetClientScreenRect(IntPtr)`, which returns `Rect?`.

`XamlDiagnosticsFunctionProvider.cs`:
- The `xaml_get_hot_reload_log` description now mentions the .NET Hot Reload pane tail.

`SKILL.md` (`AgentTools\skills\xaml-diagnostics\SKILL.md`):
- Added a note that IDs go stale after hot reload or tab switches, so the agent should re-find elements by name.
- Code edits: keep them additive (don't delete or rename types, members, or fields, and don't change signatures). Read `codeHotReloadOutput`. If `visualStudioPromptOpen` is set, tell the user and stop.
- Bounds step now covers `clippedByWindow` and `insideWindowFraction`.

**Status:**
- [x] Harness focus fix
- [x] ThemeBreaker run1 (6/6; it rebuilt and restarted, and gave feedback)
- [ ] BindingStorm, GhostClicks, LostWindows (`batch1b` running)
- [ ] Deploy new Diagnostics.dll and SKILL.md (after the batch)
- [ ] Resolved-value fix for expression properties (investigating)
- [ ] TestPass.md not yet updated with ThemeBreaker results or this segment's changes
- [ ] 12 remaining demos: A11ySweep, BugRepro, CrispPixels, DesignPolish, GermanReady, HotReloadDoctor, PixelPerfect, PrecedenceWars, ResponsiveDashboard, SlowScroll, StyleMaze, TemplateDetective
</work_done>

<technical_details>
**Chat UIA:**
- The chat input has Name 'Ask Copilot' and supports only the Text and Selection patterns, so text goes in by paste.
- Automation IDs: Send button `SendButton` (absent while a turn is busy), new session `createNewThread`, mode selector `ConversationModeSelector` (menu item 'Autopilot').
- The permission button is 'Allow this time'.
- `SetFocus` can throw "Operation is not valid due to the current state of the object". The cause is probably an open popup or VS not being in the foreground. The fix is ESC plus retry, with a mouse-click fallback.

**PowerShell quirks:**
- Add-Type in the same process can't redefine a type, so guard it with `-as [type]` or rename the class.
- PowerShell DTE enumeration of OutputWindowPanes returned count 0 out-of-proc. In-proc it should work (untested).

**Session logs:** `%LOCALAPPDATA%\Microsoft\VisualStudio\CopilotCli\session-state\<id>\events.jsonl`.

**Build and deploy:**
- Build: in one process, `cd Q:\src\VS_xaml; & src\Shared\Tools\Scripts\Prime-ForCopilot.ps1; msbuild src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj /restore /m /v:m /nologo /clp:ErrorsOnly`. Takes about 3.5 minutes.
- Deploy: close VS first (`$dte.Quit()`), then run `Start-Process pwsh -Verb RunAs -Wait` with `Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1 -VSInstallPath c:\vs\fastmain -Diagnostics -NonInteractive`. UAC prompts are disabled.
- Relaunch `c:\vs\fastmain\Common7\IDE\devenv.exe` non-elevated. The title showed "EXP", so check the rootsuffix the user used. Open `Q:\source\XamlAgentDemos\XamlAgentDemos.sln`.
- A SKILL.md-only change needs just a new chat.

**Diagnostics.dll conventions:**
- `XamlAgentService.cs` uses the fully qualified `Microsoft.VisualStudio.Shell.Package` and is saved without a BOM.
- Tool bodies run on the UI thread: `RunAsync` switches to the main thread first.
- EnvDTE is referenced (used in BindingFailuresFromOutput and MauiHotReloadE2ETracker). Avoid EnvDTE80.

**Hot reload behavior:**
- The .NET Hot Reload pane GUID is `7BD3920C-C53C-40ED-8D79-4D2F601BEFB0`.
- Rude edits (deleting a class or field) cause a "Hot Reload - Changes not supported" modal (Edit / Disable / Restart / Stop). The harness clicks Disable.
- XHR didn't apply a key rename in a theme dictionary that was loaded and swapped from code (ThemeBreaker Dark.xaml). Options: detect this, or have the skill tell the agent to verify with `xaml_find_resource` after hot reload and explain that a restart may be needed.

**Other:**
- Python isn't installed; use Node.
- User constraints: no push, rebase, or amend; commit only if asked. The user wants the UAC prompt restored at the end.
- Open question: how to get the evaluated value of a DynamicResource or Binding property. Possible routes: a property chain entry, `PropertyValueDetails` on the expression Handle, or a TAP change.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Implementation of every tool.
  - Key areas: properties ~582–655, FindElement/ELEMENT_GONE ~160–180, bounds ~1060–1130, hot reload log ~1470–1505, apply ~1506–1570, new pane/modal helpers ~1572–1610, PostCodeHotReloadCommand after that, ListWindows ~1650.
- `...\AgentTools\XamlAgentImaging.cs`: Win32 helpers. Added `IsWindowEnabled` and `GetClientScreenRect` (~40–60) plus P/Invokes (~248–270).
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`: tool descriptions. `RunAsync` ~383. Hot reload tools ~260–300.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`: the skill. IDs note ~42–45, Apply-fix section ~61–69, Reproduce/bounds ~100–105, Rules ~109.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\XamlTapContract\TapOM\TapPropertyValue.cs` and `XamlJsonData.cs` (`ElementBoundsInfo` ~585): TAP contracts.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\WpfVisualTreeService\VisualTree\DispatcherVisualTreeContext.cs:313`: WPF expression value-source handling, relevant to the resolved-value fix.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`: master results and findings. Needs ThemeBreaker results plus the new changes.
- `Q:\source\XamlAgentDemos-notes\src\<Demo>\DEMO.md`: answer keys.
- Harness folder (see work_done).
</important_files>

<next_steps>
1. Monitor `batch1b` with `read_powershell` (BindingStorm, then GhostClicks, then LostWindows). For each finished run:
   - Read `runner.log`, the transcript tail, the follow-up answers, `fix.diff`, and `dialogs.log`.
   - Grade against DEMO.md.
   - Add rows and findings to TestPass.md.
   - Record the result in the SQL `demo_runs` table.
2. Add ThemeBreaker run1 to TestPass.md:
   - 6/6 plus the toggle fix.
   - Findings: theme dictionaries loaded from code don't hot reload a key rename, and apply reports success anyway; expression values aren't resolved; the agent rebuilt and restarted.
   - List all tool and skill changes from this segment.
3. Finish the resolved-value investigation. Find how the LPE shows evaluated values for DynamicResource/Binding and add an `evaluatedValue` to the property tools. Possibly also have apply hot reload warn about resource dictionaries swapped in from code, and add skill guidance to verify with `xaml_find_resource` after hot reload.
4. After the batch:
   - Rebuild if more changes were made.
   - Close VS via DTE, deploy elevated, and relaunch fastmain (check the EXP rootsuffix).
   - Verify the harness, including the PID.
   - Re-run ThemeBreaker and VanishingSave as run2 to validate the fixes.
5. Run the remaining 12 demos in batches, iterating while results improve.
6. At the end:
   - Stop `keepawake2`.
   - Reset the demo repo.
   - Remind the user to re-enable the UAC prompt.
   - Summarize all changes.
   - Ask whether to update a repo skill (writing-skills).
</next_steps>