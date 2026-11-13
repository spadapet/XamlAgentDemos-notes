# PixelPerfect: "Make it match the design"

**Wow moment:** you give the AI only a designer's PNG (`design\mockup.png`). It screenshots the running app, lists every visual difference, measures the live element bounds, and iterates edit → hot reload → capture until the app matches the mockup side by side. There's no restart and no manual tweaking.

**Why this was hard before:** a model that can't see the running app can only guess what the XAML renders. With live captures and bounds it can measure (padding 16 vs 32, button left-aligned vs stretched) and *verify* each step visually, so it closes the loop on its own.

## Setup
1. Set **PixelPerfect** as the startup project and press F5.
2. Attach `src\PixelPerfect\design\mockup.png` to the chat.
3. Don't let the AI read `design-source\` (the loose XAML that generated the mockup).

## Prompt
> Here's the designer's mockup. Make my running sign-in page match it as closely as possible, and show me before/after screenshots.

## Expected tool flow
1. `xaml_capture_image` (before) and comparison against the attached mockup.
2. `xaml_get_visual_tree includeBounds` / `xaml_get_element_bounds` to measure padding, field heights and button width.
3. `xaml_set_element_property` for quick live experiments (Padding, CornerRadius, HorizontalAlignment).
4. The AI edits MainWindow.xaml → `xaml_apply_hot_reload` → `xaml_capture_image` and repeats until it matches.

## Answer key (app → mockup)
Background White → #F2F0F7. Card padding 16 → 32. CornerRadius 4 → 12. Border → no border plus a DropShadowEffect. Title 20 normal → 28 SemiBold. Field height 32/margin 4 → 36/margin 12. "Forgot password?" left → right. Sign in button: left-aligned, Width 100, #2D7FF9 → stretched, #5B3FD9, rounded. Footer left → centered.

## Regenerating the mockup
Run `.\Render-Mockup.ps1` from the repo root.

## Reset
Restore the folder from source control.
