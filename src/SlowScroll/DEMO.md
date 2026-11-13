# SlowScroll: "My log viewer takes 10 seconds to open"

**Wow moment:** the AI *measures* the problem in the live app. 3,000 of 3,000 ListBoxItems are realized and the list is 62,000 px tall. It then fixes three stacked virtualization killers **one at a time**, re-measuring after each hot reload, until only ~25 items are realized and first render drops from seconds to milliseconds.

**Why this was hard before:** there's no error, just slowness. Any one of the three causes alone is enough to disable virtualization, so fixing one shows no improvement and people give up. A model reading XAML can guess, but it can't count realized containers or measure the list's actual height.

## Setup
1. Set **SlowScroll** as the startup project and press F5. Note the startup delay.
2. The status bar at the bottom shows entries, first render time, realized ListBoxItems and list height.

## Prompt
> My log viewer is very slow to open and scroll. Use the running app to prove what's wrong, then fix it and show me the improvement after each change.

## Expected tool flow
1. `xaml_find_elements type=ListBoxItem maxResults=2000` returns `truncated=true`: thousands of containers exist.
2. `xaml_get_element_bounds LogList` shows the height is ~62,000 px, so it has infinite height.
3. `xaml_get_visual_tree` from PageScroller shows ScrollViewer > StackPanel > LogList.
4. `xaml_get_element_properties LogList` shows `ScrollViewer.CanContentScroll=False` and grouping without `VirtualizingPanel.IsVirtualizingWhenGrouping`.
5. Fix loop, one change at a time, with `xaml_apply_hot_reload` then `xaml_find_elements` count and capture of the status bar after each:
   1. Replace the outer ScrollViewer/StackPanel with a Grid (star row). The list now has a finite height, but the count is still high.
   2. Remove `CanContentScroll="False"`. The count is still high because of grouping.
   3. Add `VirtualizingPanel.IsVirtualizingWhenGrouping="True"` (and `VirtualizationMode="Recycling"`). The count drops to ~25.
6. Restart (or reopen) to show the new first-render time.

## Answer key
| Cause | Fix |
|---|---|
| ListBox inside ScrollViewer > StackPanel gets infinite height | Host it in a Grid row with `*` height |
| `ScrollViewer.CanContentScroll="False"` (pixel scrolling disables virtualization) | Remove it |
| Grouping without `IsVirtualizingWhenGrouping` | `VirtualizingPanel.IsVirtualizingWhenGrouping="True"` |

## Reset
`git checkout -- src\SlowScroll`
