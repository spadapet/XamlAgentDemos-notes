# TemplateDetective: "Every feed item says 'mentioned you'"

**Wow moment:** the activity feed should show comments, commits, deployments and security alerts, each with its own template. Instead every item renders with the generic fallback. The AI inspects the live tree to see **which DataTemplate each item actually got** and explains four different template-matching failures. One template even works perfectly in the sidebar, which is the clue to the scoping bug.

**Why this was hard before:** all five templates exist and look right. The failures come from implicit-template lookup rules: exact type identity (namespace), `x:Key` making a template non-implicit, interfaces never matching, and resource scope. No error is reported. Only the live tree shows what was generated for each item.

## Setup
Set **TemplateDetective** as the startup project and press F5.

## Prompt
> My activity feed should show different layouts for comments, commits, deployments and security alerts, but everything shows as "X mentioned you". Use the running app to find out why and fix it.

## Expected tool flow
1. `xaml_capture_image` shows every item as "mentioned you", while the sidebar deployment renders correctly.
2. `xaml_get_visual_tree` under Feed: each ContentPresenter's content is the FeedItem template. `xaml_get_element_properties` on a ContentPresenter shows `Content` type (Comment, Commit, ...) and ContentTemplate.
3. `xaml_get_resource_dictionaries elementId=Feed includeKeys=true` lists the template keys: `DataTemplateKey(legacy:Comment)`, a string key for the Commit template, `DataTemplateKey(IAlert)` and the FeedItem template. The Deployment template is missing, because it's in SidebarPanel.Resources.
4. `xaml_find_resource` with the DataTemplateKey from the sidebar vs the feed shows the scope difference.
5. The AI fixes each template, then hot reload and capture.

## Answer key
| Item | Root cause | Fix |
|---|---|---|
| Comment | Template DataType is `legacy:Comment`, a different type with the same name | Use `models:Comment` |
| Commit | Template has `x:Key`, so it isn't implicit | Remove `x:Key` (or use a DataTemplateSelector) |
| Security alert | DataType is the interface `IAlert`; implicit templates never match interfaces | DataType `models:SecurityAlert` |
| Deployment | Template is in SidebarPanel.Resources, out of scope for Feed | Move it to Window/App resources |

## Reset
`git checkout -- src\TemplateDetective`
