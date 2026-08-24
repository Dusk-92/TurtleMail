# TurtleMail - WoW 1.12 / Turtle WoW

This fork keeps the original TurtleMail features while adding a small compatibility layer for **Turtle WoW 1.18.x / Octo**.

> Current test build: **1.4.6-compat.1**  
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

`1.4.6-compat.1` currently addresses:

- `MailHorizontalBarLeft` / `MailHorizontalBarRight` nil crashes.
- Missing or malformed `TurtleMail_AutoCompleteNames` SavedVariables.
- Broken learning of sender names for autocomplete.
- Sent-money logging not being recorded correctly.
- Inbox index/COD nil safety during automatic opening.
- Stale AH/returned icons on empty inbox rows.
- Fragile mailbox/package-frame lookups.
- A calendar tooltip nil/stale-value edge case.

See [`AUDIT.md`](AUDIT.md) for the full audit, remaining architectural risks, and the in-game validation checklist.

## Test status

This is intentionally marked as a **test build** until it has been validated in-game on Turtle WoW 1.18.x. Core mail sending/opening behavior has not been deliberately redesigned; the patch focuses on compatibility and safety around the upstream implementation.

Recommended checks after installing:

1. Open/close the mailbox repeatedly.
2. Test normal mail, item mail, gold, AH, returned mail, and COD.
3. Test one-item and multi-item sends.
4. Test recipient autocomplete.
5. Test the sent/received log.
6. If you use pfUI, test with its mailbox skin enabled and disabled.

## Screenshots

![TurtleMail](https://i.imgur.com/H0MUmXd.png)

![TurtleMail](https://i.imgur.com/LM7tRcx.png)
