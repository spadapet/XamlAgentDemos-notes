# GhostClicks: "Some of my buttons don't respond to clicks"

**Wow moment:** the AI proves each click handler works (`xaml_interact invoke` fires it), then uses live bounds and the visual tree to find the **invisible element sitting on top** of each button. One of them is a fully transparent toast host that stays in the tree after its animation faded it out.

**Why this was hard before:** nothing is visible and nothing throws. Snoop-style tools need a human to hover around and guess. The model needs element bounds, z-order, `IsHitTestVisible` and Background (null vs Transparent) together, and those only exist in the running app.

## Setup
1. Set **GhostClicks** as the startup project and press F5.
2. Show the audience: Settings does nothing, clicking the empty part of a message row does nothing, the left part of Previous does nothing, and Reply/Forward/Archive do nothing. "Last action" never changes.

## Prompt
> In my running app, Settings, Reply, Forward, Archive and the left edge of Previous don't respond to mouse clicks, and message rows only work when I click right on the text. Find out why using the live app and fix it.

## Expected tool flow
1. `xaml_interact invoke` on ReplyButton. StatusText changes, so the handler is fine and this is a **hit-testing** problem.
2. `xaml_get_element_bounds` for ActionBar, ToastHost, PreviousButton, PageIndicator and HeaderBand.
   - ToastHost exactly covers ActionBar.
   - PageIndicator overlaps the left ~38 px of PreviousButton.
3. `xaml_get_element_properties` (with includeAll):
   - ToastHost and PageIndicator have `Background=Transparent`, so they hit-test.
   - Toast has Opacity 0 from an animation, but the host is still there.
   - HeaderBand has `IsHitTestVisible=False`, which is inherited by SettingsButton.
   - MessageRow Background is null, so empty space isn't hit-testable.
4. Optional live proof: `xaml_set_element_property ToastHost IsHitTestVisible False`, then the user clicks Reply and it works.
5. The AI fixes the source, then hot reload.

## Answer key
| Symptom | Root cause | Fix |
|---|---|---|
| Settings | `IsHitTestVisible="False"` on HeaderBand (inherited) | Remove it, or set it only on the decorative gradient |
| Row empty space | Border Background is null | `Background="Transparent"` |
| Previous (left edge) | PageIndicator (Transparent, Width 200) overlaps it | `Background="{x:Null}"`/`IsHitTestVisible="False"`, or fix the layout |
| Reply/Forward/Archive | ToastHost (Transparent) in the same row stays after the fade | `IsHitTestVisible="False"`, or collapse it when the animation completes |

## Reset
`git checkout -- src\GhostClicks`
