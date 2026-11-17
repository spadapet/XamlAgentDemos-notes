# Candidate demo ideas

The user found NewCustomer's non-breaking-space input contrived and requested a
large list of alternatives, without implementing a new app. These ideas and the
rankings below are hypotheses, not tested results. They are WPF-oriented and
should be evaluated with comparable tool-enabled and tool-free runs.

## Interaction history

1. **Hidden filter:** a collapsed search panel retains a filter and hides customers.
2. **Stuck spinner:** out-of-order async loads leave a busy overlay up.
3. **Validation on another tab:** an earlier edit on another tab disables Save.
4. **Animation holds a value:** a dismissed notification's storyboard holds a panel at opacity zero.
5. **Stale DataContext:** navigating to customer B leaves customer A's view model displayed.
6. **Recycled rows:** local visual state on recycled list rows shows highlights on the wrong items.
7. **Focus trap:** closing a flyout leaves focus on a collapsed element.
8. **Dragged widgets:** an invisible widget left over a button intercepts clicks.

## Per-user state and configuration

9. **Zero-width column:** a restored GridSplitter position hides a details pane.
10. **Off-screen window:** a saved position places a window on a disconnected monitor.
11. **Saved dashboard:** a broken tile is created at runtime from the user's saved layout.
12. **Remote configuration:** a startup feature flag hides a toolbar or changes the theme.

## Environment

13. **Theme or high contrast:** foreground and background colors make text invisible.
14. **Text scaling:** a fixed-height row clips labels at a larger Windows text size.
15. **Missing font:** fallback font metrics push controls out of view.
16. **Culture:** localized formatting overflows a column or right-to-left layout flips icons.
17. **Window size:** an adaptive threshold hides a sidebar at the current width.

## Runtime data

18. **Long values:** a customer's long name pushes row actions out of view.
19. **Wrong template:** a runtime data subclass selects an unintended template.
20. **Null nested path:** one record has a null address and renders a blank binding.
21. **Images fail to load:** runtime image URLs or dimensions produce collapsed cards.

## Windows and combined cases

22. **Dialog behind main window:** missing ownership makes a modal dialog look like a freeze.
23. **Popup left open:** moving the window leaves a popup covering another area.
24. **Dashboard after extended use:** combine the hidden filter, held animation and saved splitter position.

The initial shortlist was 2, 4, 8, 11 and 24, for their potential visual impact
and runtime-state dependence. Their realism, reproducibility, WPF behavior,
tool coverage and demo duration remain unverified. A source-only baseline cannot
prove that XAML tools are the only way to diagnose a case: screenshots, UI
Automation, debugger evaluation, custom scripts or saved configuration may
also reveal relevant state. Compare what each approach actually observes,
whether it diagnoses the specific cause, and how it verifies the fix.
