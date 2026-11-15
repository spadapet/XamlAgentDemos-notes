<overview>
The user is exposing Visual Studio XAML Diagnostics to Copilot through 22 `xaml_*` tools in Diagnostics.dll and a deployed `xaml-diagnostics` skill. The tools are demonstrated with 17 WPF demo apps in `Q:\source\XamlAgentDemos`.

The current request is to autonomously test every demo, iterating as many times as needed while results keep improving. For each demo:
- Build it and run it in the running fastmain VS.
- Prompt Copilot Chat and ask follow-up questions.
- Save the session logs and analyze them.
- Fix the skill and tools.
- Reset the demo repo.
- Collect notes on every change.

I built a PowerShell/UI Automation/DTE harness to drive VS. The DEMO.md answer keys in `Q:\source\XamlAgentDemos-notes` are used only for grading; the chat agent never sees them.
</overview>

<history>
1. **Earlier work (prior checkpoints):**
   - Implemented the 22 tools, the skill, and Copilot registration.
   - Fixed threading and the tool Group.
   - Created the demos and moved the notes out of the demo repo.
   - Fixed issues found in the BindingStorm log analysis, then built and deployed to `c:\vs\fastmain`. Nothing is committed.

2. **User asked whether I could run all demos myself.**
   - Answered yes. Found that VS Copilot session logs are at `%LOCALAPPDATA%\Microsoft\VisualStudio\CopilotCli\session-state\<id>\events.jsonl`.
   - Added the test-pass plan to plan.md.

3. **User turned off the UAC prompt** (`ConsentPromptBehaviorAdmin=0`, EnableLUA still 1).
   - Confirmed that elevated deploys via `Start-Process -Verb RunAs` now run silently.
   - VS must run non-elevated so UI Automation can drive it.

4. **User: "fastmain is running. Start your work, take your time, do many iterations."**
   - Built the harness: ROT/DTE access, chat input via UIA plus clipboard paste, the Send button, new thread, transcript renderer.
   - Ran VanishingSave run1, which hit three blockers in turn:
     - **Interactive mode:** a new chat thread defaults to Interactive (Manual), so a permission prompt blocked `xaml_clear_binding_failures`. I approved it and added `Set-Autopilot`.
     - **Locked workstation:** the screen locked, so SetFocus and the screenshot failed. The user chose the keep-awake mouse-nudge helper.
     - **Hot Reload modal:** a "Changes not supported" dialog appeared (the agent deleted a class and a field, which are rude edits). The user said to click Disable. I added a dialog watcher that does this automatically.
   - VanishingSave run1 completed: all 4 answer-key causes found and verified live. The follow-up feedback was captured.
   - Created TestPass.md with results and findings.
   - Started batch 1 (ThemeBreaker, BindingStorm, GhostClicks, LostWindows) asynchronously.
   - Began looking at `XamlAgentService.cs` for tool fixes.
</history>

<work_done>
**Harness** (`C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness\`):

| File | Purpose |
|---|---|
| `Rot.cs` | Reads the COM Running Object Table to get DTE (`!VisualStudio.DTE.18.0:<pid>`). |
| `Harness.psm1` | `Get-VsPid` (fastmain devenv), `Get-Dte`, `Invoke-Dte` (retries while VS is busy), `Find-Ui`, `Get-ChatInput` (Name 'Ask Copilot'), `Set-ChatText` (focus, Ctrl+A, paste via Set-Clipboard), `Send-ChatPrompt` (verifies the text, then invokes `SendButton`), `New-ChatThread` (`createNewThread`), `Set-Autopilot` (expands `ConversationModeSelector`, clicks the 'Autopilot' MenuItem), `Approve-PendingPermission` ('Allow this time'), `Start-Demo` (sets StartupProjects to `src\<Name>\<Name>.csproj`, `Debugger.Go`, waits for the process and debug mode 3), `Stop-Demo`, `Reset-Demos` (git checkout plus `clean -fdq`), `Save-VsScreenshot`, `Find-SessionDirForPrompt`, `Wait-TurnDone`, `Get-VsDialogs`, `Close-VsDialogs` (clicks Disable for Hot Reload dialogs, otherwise OK/Close/Cancel/No, and logs to `$script:DialogLog`). |
| `Run-Demo.ps1` | Params: `-Name -Prompt -Tag -NoFollowUp -KeepRunning -ResumeDir`. Stops debugging, closes all docs without saving, resets the repo, F5s, runs an optional `pre-<Name>.ps1`, opens a new thread and sets Autopilot, sends the prompt, waits, sends the feedback follow-up, then copies events and renders the transcript, `fix.diff`, `status.txt`, and `vs-final.png`, closes dialogs, and stops. Output goes to `Q:\source\XamlAgentDemos-notes\test-runs\<Name>\<Tag>\`. |
| `Run-Batch.ps1` | `-Names <list> -Tag`; reads prompts from `prompts.json`. |
| `prompts.json` | Verbatim DEMO.md prompts. BugRepro and PixelPerfect were adjusted to name the file paths (`src\BugRepro\bug-report.md`, `src\PixelPerfect\design\mockup.png`). |
| `pre-ThemeBreaker.ps1` | Toggles DarkModeToggle through UIA. |
| `render.js` | Node script that writes `transcript.md` plus an `_images` folder and prints tool-usage stats. |
| `peek.js` | Quick tool-call timeline. |
| `KeepAwake.ps1` | Sends a zero-distance mouse nudge every 60 s. |

**Notes repo:**
- `Q:\source\XamlAgentDemos-notes\TestPass.md` has the results table and findings 1–6.
- `test-runs\VanishingSave\run1\` holds that run's artifacts.

**Running async shells:**
- `keepawake2`: the keep-awake loop. Stop it when the test pass ends.
- `batch1`: ThemeBreaker, BindingStorm, GhostClicks, LostWindows (started around 20:30).

**Status:**
- [x] Harness works end to end (VanishingSave run1: 4/4).
- [ ] Batch 1 running.
- [ ] Remaining demos: A11ySweep, BugRepro, CrispPixels, DesignPolish, GermanReady, HotReloadDoctor, PixelPerfect, PrecedenceWars, ResponsiveDashboard, SlowScroll, StyleMaze, TemplateDetective.
- [ ] Tool and skill fixes for the findings.
- Earlier uncommitted VS repo changes (BindingStorm fixes, registration, Group, threading, `DeployToVs.ps1`) are still uncommitted.
</work_done>

<technical_details>
**Chat UIA:**
- The input has Name 'Ask Copilot' (WpfTextView). It supports only Text and Selection patterns, so text goes in by paste.
- Other controls by automation ID: Send button `SendButton` (absent while a turn is running, which is the busy signal), new session `createNewThread`, mode `ConversationModeSelector` (ExpandCollapse; menu items Interactive/Autopilot/Plan).
- The permission prompt button is 'Allow this time'.

**Session events:**
- Types include `user.message`, `assistant.message` (toolRequests), `tool.execution_start`/`complete`, `permission.requested`, `external_tool.requested`, `session.task_complete`, `session.binary_asset` (base64 images), `assistant.turn_end`, `session.shutdown`.
- `Wait-TurnDone` returns 'done' on task_complete or shutdown. It returns 'idle' when there was a turn_end, 30 s passed quietly, and the Send button is present. After 60 s quiet it auto-approves permissions, and after 900 s quiet it returns 'stalled'.

**Environment:**
- fastmain VS PID was 31064 and the solution is `Q:\source\XamlAgentDemos\XamlAgentDemos.sln`.
- In DTE, `Commands.Count` returns 0, so there is no command route to chat.
- Python isn't installed; use Node.
- In PowerShell, `ConvertFrom-Json` turns timestamps into DateTime objects.
- The LogonUI process exists even when the session is unlocked, so test for a lock with a screenshot instead.

**Hot Reload:**
- Deleting a class or field is a rude edit. With `includeCodeChanges` the Hot Reload command is posted, and VS shows a modal 'Hot Reload - Changes not supported' (buttons Edit, Disable, Restart affected projects, Stop). The tool doesn't know about it.

**VanishingSave findings** (in TestPass.md):
1. The rude-edit modal is invisible to the tool.
2. `includeAll` property output exceeds the response limit.
3. Element IDs go stale after hot reload (ELEMENT_GONE).
4. Bounds report `isVisible=true` when the element is clipped off-window.
5. ColumnDefinition widths are not exposed.
6. The hot reload log has no result for code updates.

**Fix ideas:**
- Skill: avoid deleting types/members during live code hot reload, and re-find elements by name after hot reload.
- ELEMENT_GONE error: add a hint.
- Bounds (`XamlAgentService.cs` ~1098 and ~1560): add a clipped/outside-window flag.
- Properties: cap or paginate `includeAll`.

**Build and deploy:**
- Build: `cd Q:\src\VS_xaml`, run `& src\Shared\Tools\Scripts\Prime-ForCopilot.ps1`, then `msbuild <proj> /restore /m /v:m /nologo /clp:ErrorsOnly`, all in the same process. Diagnostics.csproj takes about 3–5 minutes.
- Deploy: `Start-Process pwsh -Verb RunAs -Wait` running `Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1 -VSInstallPath c:\vs\fastmain -Diagnostics -NonInteractive`. UAC no longer prompts.
- A DLL deploy requires closing VS. A SKILL.md-only deploy just needs a new chat.
- After closing VS, restart it with `c:\vs\fastmain\Common7\IDE\devenv.exe` (non-elevated) and open the solution. The title showed an "Experimental Instance" hive; check how the user launched it (rootsuffix) before relaunching.

**Other:**
- In `XamlAgentService.cs`, use the fully qualified Shell `Package` and keep the file without a BOM.
- User preference: never push, rebase, or amend. Commit only if asked.
</technical_details>

<important_files>
- `Q:\source\XamlAgentDemos-notes\TestPass.md`: the master test notes (results table, findings, harness notes). Update after every run.
- `Q:\source\XamlAgentDemos-notes\test-runs\<Demo>\<tag>\`: run artifacts (`transcript.md`, `events.jsonl`, `fix.diff`, `dialogs.log`, `runner.log`).
- `Q:\source\XamlAgentDemos-notes\src\<Demo>\DEMO.md`: the answer keys used for grading.
- The harness folder listed in work_done.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`: tool implementations. Key spots:
  - Properties: ~581–640
  - Bounds: ~1098
  - Binding failures: ~1310
  - Apply hot reload and `PostCodeHotReloadCommand`: ~1472–1540
  - Window/visible info: ~1560
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`: tool descriptions.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`: the skill. Workflows start around line 46 and Rules around line 107.
</important_files>

<next_steps>
1. Monitor `batch1` with `read_powershell` (each demo takes about 10–20 minutes). For each finished demo:
   - Read `runner.log`, the transcript's final message and follow-up answer, `fix.diff`, and `dialogs.log`.
   - Grade against DEMO.md and add rows and findings to TestPass.md.
   - Record the result in the SQL `demo_runs` table.
2. After batch 1, implement the accumulated fixes:
   - Skill guidance for rude edits and stale IDs.
   - Tool changes: clipped flag in bounds, `includeAll` size cap, ELEMENT_GONE hint, rude-edit/code hot reload result reporting if feasible.
   - Rebuild Diagnostics (and the TAPs if changed).
   - Close VS via DTE (`$dte.Quit()`), deploy elevated, relaunch fastmain, and verify the harness still works (update the PID).
3. Run the remaining 12 demos in batches. Re-run demos affected by fixes with Tag `run2` and later. Iterate while results improve.
4. Record every change made (VS repo files and skill) in TestPass.md.
5. At the end:
   - Stop `keepawake2`.
   - Remind the user to turn the UAC prompt back on.
   - Reset the demo repo.
   - Summarize.
   - Consider asking whether to update a repo skill (writing-skills).
</next_steps>