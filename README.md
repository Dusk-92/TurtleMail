# TurtleMail - WoW 1.12 / Turtle WoW

This fork keeps the original TurtleMail features while adding a compatibility and safety layer for **Turtle WoW 1.18.x / Octo**.

> Stable release: **1.4.6**  
> Based on upstream **sica42/TurtleMail 1.4.5**.  
> The compatibility work is isolated in `TurtleMailFix.lua` so upstream changes remain easy to compare and merge.

## Features

- **Automatically opens mail, very rapidly**
- **Mails multiple items at once, very rapidly**
- **Autocompletes recipient names**
- **Icons to show if mail was returned or is from AH**
- **Shows collected gold from opened mails**
- **Apply COD to 1st or all mails**
- **Logging of all sent and received mails**

**\<Right Click>** on inbox items to loot the gold, loot the item and destroy the letter, in that order, if any.<br/>
**\<Right Click>** or **\<Left Drag>** to add inventory items to the attachments.<br/>
**\<Right Click>** to add inventory items to the trade frame.

Note that COD is always ignored when opening, both automatically as well as by **\<Right Click>**.

Logging is disabled by default. Enable with `/tm log`.

## Turtle WoW compatibility fixes

Version **1.4.6** addresses:

- `MailHorizontalBarLeft` / `MailHorizontalBarRight` nil crashes.
- Missing or malformed `TurtleMail_AutoCompleteNames` SavedVariables.
- Broken learning of sender names for autocomplete.
- Sent-money logging not being recorded correctly.
- Inbox index/COD nil safety during automatic opening.
- Stale AH/returned icons on empty inbox rows.
- Fragile mailbox/package-frame lookups.
- A calendar tooltip nil/stale-value edge case.
- Several additional guards around mailbox UI replacements and malformed state.

See [`AUDIT.md`](AUDIT.md) for the full audit and remaining architectural risks.

## Validation status

Version **1.4.6** has been promoted to stable after in-game testing on Turtle WoW 1.18.x completed without Lua errors in the tested setup.

The patch intentionally keeps the original send/open workflow instead of redesigning it. Addons that heavily replace or re-parent the Blizzard mail UI can still create compatibility issues; known architectural risks are documented in `AUDIT.md`.

## Screenshots

![TurtleMail](https://i.imgur.com/H0MUmXd.png)

![TurtleMail](https://i.imgur.com/LM7tRcx.png)
