# ResponsiveDashboard: "Make it work on a small laptop"

**Wow moment:** the AI **resizes the running window itself** to 1024 and 800 px wide, captures each, measures what overflows (the search box covers the user menu, KPI tiles and the chart are cut off, the footer runs off-screen), and rewrites the fixed-pixel layout. Then it re-runs the same resize sweep to prove the fix at every size.

**Why this was hard before:** the layout looks perfect at the developer's window size. Reproducing at other sizes means manual dragging and squinting. The model can't see the app or measure overlap without live bounds and captures.

## Setup
Set **ResponsiveDashboard** as the startup project and press F5. It looks fine at 1280×760.

## Prompt
> Customers on small laptops say my dashboard is broken. Test the running app at 1280, 1024 and 800 px wide, show me what breaks at each size, then fix the layout and prove it works at all three.

## Expected tool flow
1. `xaml_list_windows` gives the main window size. `xaml_set_element_property` on the Window `Width=1024`, then `xaml_capture_image`. Repeat at 800.
2. `xaml_get_element_bounds` for SearchBox, UserArea, KpiTiles, RefundsTile, ChartCard and Footer:
   - SearchBox overlaps UserArea (Canvas.Left=420, Width=360).
   - RefundsTile and ChartCard extend past their parent.
   - Footer text runs past the window edge.
3. `xaml_get_element_properties` on NavPanel/ActivityPanel shows fixed widths 220/280. KpiTiles has 4 fixed 170-px columns.
4. The AI rewrites:
   - Header: Grid with `*` search column and MaxWidth.
   - Nav and activity: MinWidth/MaxWidth, or collapse Activity under a breakpoint.
   - KPIs: `UniformGrid`/WrapPanel.
   - Chart: Viewbox or `Stretch`.
   - Footer: WrapPanel / DockPanel.
5. Hot reload, then the same resize-and-capture sweep at all three widths. Restore Width to 1280.

## Answer key
| Element | Problem | Fix |
|---|---|---|
| Header Canvas | Absolute SearchBox position overlaps UserArea | Grid columns (Auto, *, Auto) |
| NavPanel / ActivityPanel | Fixed 220/280 widths | Proportional/min widths; hide Activity when narrow |
| KpiTiles | 4 × 170 px fixed columns | UniformGrid or WrapPanel |
| ChartCard | 660 px Polyline | `Stretch="Fill"` in a sized container or a Viewbox |
| Footer | Horizontal StackPanel with long text | WrapPanel / TextTrimming |

## Reset
`git checkout -- src\ResponsiveDashboard`
