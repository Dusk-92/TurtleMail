# TurtleMail 1.4.5 — Compatibility audit

Target: Turtle WoW 1.18.x / Octo client.

## Fixed in 1.4.6-compat.1

- **Horizontal mail bar crash:** the upstream code creates `MailHorizontalBarLeft/Right` and then assumes the textures are exported as globals. Some client/UI combinations return the textures without the expected global, causing `attempt to index field 'MailHorizontalBarLeft' (a nil value)`. The compatibility layer guarantees valid texture references before setup and updates.
- **Autocomplete SavedVariables crash:** `TurtleMail_AutoCompleteNames` and its realm/faction table are used without schema validation. The patch initializes/repairs missing or malformed SavedVariables before `ADDON_LOADED`, `PLAYER_LOGIN`, slash commands, and autocomplete.
- **Broken sender-learning hook:** upstream `GetInboxHeaderInfo` hook reads `arg[3]`/`arg[12]` from function inputs even though sender/canReply are return values. The patch captures return values first, so received senders can actually populate autocomplete.
- **Sent money not logged:** upstream checks the nonexistent `state.send_money` field. The patch records sent money when it is not COD and `sent_money > 0`.
- **Inbox bounds/COD safety:** header data is no longer queried/compared unsafely after the inbox index has moved past the last mail; nil COD values are treated as zero.
- **Stale inbox icons:** AH/returned icons are explicitly hidden on empty rows/pages.
- **Fragile package-button regions:** `MAIL_SHOW` no longer assumes regions 1 and 3 always exist.
- **Mailbox frame guards:** bag updates, attachment bookkeeping, inbox locking, and money display tolerate missing/replaced frames instead of immediately throwing Lua errors.
- **Locale-safe COD label:** unexpected `COD_AMOUNT` formatting no longer turns the label into nil and causes string concatenation errors.
- **Malformed log entries:** logging tolerates missing subjects/participant fields and repairs missing log tables.
- **Calendar tooltip:** disabled/empty calendar days no longer concatenate a nil/stale `mails` value.
- **OnUpdate rebinding:** `TurtleMail:init()` binds the original `on_update` function before the compatibility file loads; the patch explicitly rebinds the frame script so the safer handler is actually used.

## Remaining architectural risks upstream

These are intentionally not rewritten in the compatibility layer because changing them would be much more invasive and could alter mail behavior:

1. TurtleMail directly replaces global Blizzard functions during `PLAYER_LOGIN` rather than using a cooperative hook system. This makes load order important when another addon also replaces the mail/bag functions.
2. `sendmail_load()` temporarily/proxy-replaces global `SendMailMailButton` and `SendMailSubjectEditBox`. This is a clever Vanilla-era workaround but can conflict with UI replacements.
3. Several layouts rely on specific Blizzard frame names and region ordering. The compatibility layer protects the confirmed/high-risk cases, but a full mail-frame replacement can still be incompatible.
4. The pfUI skin accesses pfUI internals (`MailFrame.backdrop`, `pfUI_config`, specific widget members). A future pfUI layout change can therefore break the skin even when core TurtleMail remains functional.
5. Inbox polling is frame-count based (`200` OnUpdate ticks), so the interval changes with FPS. It is not a correctness bug but is less predictable than elapsed-time polling.
6. The addon has no automated runtime test harness for Turtle WoW mail APIs; final validation still needs an in-game test with empty mail, item mail, gold, COD, AH mail, multi-attachment send, autocomplete, and (if used) pfUI.

## Compatibility context

The upstream repository already had a Turtle WoW 1.18.1 report where `MailFrame` became nil; that report was ultimately traced to MoveAnything. This reinforces that TurtleMail is sensitive to addons that replace or re-parent the mail UI.

## Suggested in-game validation

- Open and close the mailbox repeatedly.
- Open a normal letter, item mail, gold mail, AH mail, and returned mail.
- Confirm COD mail is skipped by Open All.
- Send one item and then several items.
- Send money and confirm the log records it.
- Type a previously seen sender in the recipient field and confirm autocomplete.
- Switch inbox pages and verify AH/returned icons do not remain on empty rows.
- If pfUI is installed, test with its mailbox skin both enabled and disabled.

## Status

`1.4.6-compat.1` is a **test build**, not a final release. The fixes are intentionally isolated in `TurtleMailFix.lua` so upstream code stays easy to compare and future upstream changes remain easier to merge.
