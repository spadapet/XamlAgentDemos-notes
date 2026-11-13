# BugRepro: "Here's a bug report. Reproduce it, find it, fix it."

**Wow moment:** you paste a vague user bug report (`bug-report.md`). The AI **reproduces it in the live app** with `xaml_interact`: it types, clicks Cancel, types again, and watches Save stay disabled. It confirms the state with live property values, finds the stuck `isReverting` flag, fixes it, and replays the repro to prove the fix.

**Why this was hard before:** the bug only appears after a specific sequence of UI actions, and the model couldn't drive the UI or observe IsEnabled at each step. Static code reading makes it easy to miss that `isReverting` is never reset. There's also a second, subtler issue: the Email binding only updates on LostFocus.

## Setup
Set **BugRepro** as the startup project and press F5. Attach `bug-report.md` to the chat.

## Prompt
> Here's a bug report from a user. Reproduce it in my running app, find the root cause, fix it, and prove it's fixed by replaying the steps.

## Expected tool flow
1. `xaml_find_elements` locates DisplayNameBox, EmailBox, SaveButton and CancelButton.
2. `xaml_interact setValue` on DisplayNameBox, then `xaml_get_element_properties SaveButton` shows IsEnabled=True.
3. `xaml_interact invoke CancelButton`, then `xaml_interact setValue` again, and SaveButton IsEnabled is now False. **Reproduced.**
4. The AI reads ProfileViewModel.cs and finds that `Cancel()` sets `isReverting = true` and never resets it.
5. It also notices with `xaml_explain_property_value` that the Email binding has UpdateSourceTrigger=LostFocus.
6. Fix: a try/finally reset, plus `UpdateSourceTrigger=PropertyChanged`. The C# change needs a restart (or .NET Hot Reload), and then the AI replays the steps.

## Answer key
1. `ProfileViewModel.Cancel()` never resets `isReverting`.
2. The Email TextBox binding uses the default LostFocus trigger, so typing doesn't mark the form dirty until focus leaves.

## Reset
Restore the folder from source control.
