# DesignPolish: design-system audit and live design variants

Two demos on one pricing page.

## Demo A: "Audit this page against our design tokens"

**Wow moment:** the AI walks the **live** visual tree and audits every spacing, font size, color and corner radius it finds against `design-tokens.md`. It produces a table of ~25 violations (7 vs 8 px, 13.5 vs 14 pt, `#343434` vs `#333333` vs `#2F2F2F`, `#5A3ED8` vs `#5C40DA` vs the `#5B3FD9` accent), then consolidates everything into token resources and shows before/after.

**Why this was hard before:** near-duplicates like `#343434` and `#333333`, or 13 vs 13.5, are invisible to the eye and scattered across many elements. Runtime values also include inherited and style-provided values that the source doesn't show directly.

### Prompt
> Audit my running pricing page against design-tokens.md. List every spacing, font size, color and corner radius that isn't a token, then fix the XAML to use token resources and show me before/after.

### Expected tool flow
1. `xaml_get_visual_tree` (depth 10) plus `xaml_get_element_properties` (nameFilter Margin|Padding|FontSize|Foreground|Background|BorderBrush|CornerRadius) on each element.
2. `xaml_capture_image` for the "before" shot.
3. The AI builds a violation table: element, property, value, nearest token.
4. The AI adds a `Tokens.xaml` dictionary (brushes, font sizes, thicknesses), merges it, and replaces the literals.
5. Hot reload, then capture for "after". Optionally `xaml_find_resource` to show each token resolves.

## Demo B: "Try three hero designs live"

**Wow moment:** the AI *designs in the running app*. It applies three hero-section variants using only runtime property changes, with no source edits and no rebuilds, and captures each so the user can pick one. Only the winner is written to XAML.

### Prompt
> Try three different designs for the hero section in my running app (for example a light variant, a left-aligned variant and a compact one). Show me a screenshot of each, and when I pick one, write it to the XAML.

### Expected tool flow
1. `xaml_find_elements name=Hero`, then `xaml_capture_image elementId` (WinUI) or a window capture (WPF).
2. For each variant: several `xaml_set_element_property` calls (Hero Background/Padding; HeroTitle FontSize/Foreground; HeroContent HorizontalAlignment; HeroCta Background/Foreground), then `xaml_capture_image`.
3. After the user picks, reset the experiment values (`reset=true`), edit MainWindow.xaml, then hot reload and capture.

## Reset
`git checkout -- src\DesignPolish`
