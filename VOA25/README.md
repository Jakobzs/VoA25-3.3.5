# VoA 25 LFM Generator

An in-game port of `crates/voa25` for the original WoW **3.3.5a client (12340)**.
No libraries or other addons are required.

## Install

Copy the entire `VOA25` folder into your client's `Interface/AddOns` directory.
The final path must be `Interface/AddOns/VOA25/VOA25.toc`, without an extra nested
folder. Restart the client if it was running when you installed the addon, then
enable **VoA 25 LFM Generator** in the character-selection AddOns menu.

## Use

- Type `/voa25` or `/voa` to open or close the window. Escape also closes it.
- **Applicants** shows eight compact rows with player/whisper, assigned spec,
  status and actions. The selected tab has gold text and an underline.
  **Specs** shows the class grid with separate Open, Invited and Filled markers.
- Click a player's name or whisper text to open a whisper addressed to them.
  This also works in expanded Joined and Declined sections. Type your message
  and press Enter to send; clicking never sends a message automatically.
- The header separates **Raid** members (out of 25), filled **Specs** (out of 19),
  and outstanding tracked **Invites**. The Applicants count includes waiting and
  left players; invitations are counted separately. Leadership, party conversion
  and capacity blockers appear beneath the applicant list.
- **Recruiting** starts automatically the first time you open the updated addon.
  It keeps running when you close the window; uncheck Recruiting to stop collecting
  new whispers and observing new invites. Existing players are still reconciled
  with your group. The toggle is saved across `/reload`.
- Click an Open spec to mark it manually covered. Click a Filled or Invited spec
  to reopen recruitment for it:
  existing players stay in your group, but stop counting toward that slot. Later
  roster updates do not undo that decision. A newly assigned player joining can
  fill it again. An amber waiting marker means an invitation is pending; reopening
  releases the reservation without cancelling the game invitation. Each covered
  spec names its player or says Manual. Hover for all owners and reservations.
- Expand **Message options** to enter an optional **Message prefix** and
  **Message suffix**. The prefix goes immediately after `LFM VOA25`, before
  `need ...`; the suffix goes after the needed specs. For example, prefix
  `quick run` and suffix `- emblems welcome` produce
  `LFM VOA25 quick run need ... - emblems welcome`.
  Both start blank, update the preview as you type, and are saved per character.
  Include any punctuation you want; the generator adds a separating space.
  Clear either field to omit it. Collapsing options retains both values;
  the preview, byte counter and Put in chat button remain visible in both tabs.
- Click **Put in chat**, check the destination shown beside the chat input, and
  press Enter to send. It uses the default chat frame's current destination;
  choose your recruitment channel in chat beforehand. Nothing sends automatically.
- The byte counter shows the complete message length. **Put in chat** is disabled
  above the client's 255-byte limit; shorten the prefix or suffix, or mark filled specs.
  Each field accepts up to 255 bytes and preserves complete UTF-8 characters;
  the limit applies to the combined generated message before it can be posted.
- **Reset specs** in the Specs tab, or `/voa25 reset`, asks for confirmation before clearing manual
  selections, uncounting current assignments and releasing reservations. Applicant
  decisions, group membership, prefix and suffix are retained.
- **New run** or `/voa25 new` asks before clearing specs, assignments and applicant
  decisions and enabling Recruiting. It scans your current group again. The prefix, suffix
  and window position are retained. Outstanding game invitations are not cancelled.
- Drag the window background to move it. `/voa25 center` brings it back to the center.
- `/voa25 selftest` runs 11 quick checks and reports results and elapsed milliseconds
  in your local chat. It uses temporary data and does not change your selections,
  prefix, suffix, window, or chat destination. It never runs automatically.

Selections, prefix, suffix, window position and recruitment session are saved per character
on logout or `/reload`. Updating from 1.1.1 preserves every existing checkbox as a
manual selection. Saved joined assignments are revalidated against the live group;
old pending reservations are released and labelled **Invited - slot released**.
The counter tracks the original **19 spec categories**, not 25 players.
When all specs are filled, the message is `LFM VOA25` plus your optional prefix
and suffix, without a `need` section. Upgrading older settings leaves the new prefix blank.

WoW addons cannot synchronize the operating-system clipboard, so the desktop
Copy action is replaced by preparing the message directly in the chat input.

## Recruitment details

- Aliases include ret/retri/retribution, prot/protection, boomkin/boomie/moonkin/
  balance/bal, resto/restoration, ele/elemental, enh/enha/enhancement, and common
  class and role names. Matching uses complete words, ignores item links, and uses
  the whisper sender's class when the client supplies it. `prot` without a class,
  `ret/prot`, and other ambiguous messages require a spec choice. Talent names
  alone do not determine a DK's tank/DPS role.
- Each player has one row. Joined players needing a spec appear first, followed
  by the active queue in first-whisper order. Later messages update that row.
  Irrelevant follow-ups retain the established spec; an explicit choice in the
  addon takes precedence over later automatic parsing.
- Click the spec button to correct an assignment, or choose **No slot / emblems
  only**. Clear `emblems only`/`only emblems` whispers also default to not occupying
  a spec slot. The compact picker only shows that player's class when known,
  highlights the current selection, and retains all categories for unknown classes.
  There is no talent inspection or gear-score verification.
- **Invite** uses the normal game invite. `/invite`, right-click invitations and
  other calls to `InviteUnit` are observed too. A pending invite removes its spec
  from the LFM message, while additional applicants show **Reserved**. It becomes
  filled only once the player actually joins. Known applicants joining via another
  leader's invite are recognized by the roster as well.
- After **60 seconds**, **No response** offers **Keep waiting** or **Release slot**.
  It does not automatically reopen the slot. Localized, named decline/already-in-a-
  group/player-not-found messages release the matching reservation. Unnamed errors
  are not guessed against a player. Release slot only changes addon tracking; a
  late acceptance can still join the raid and fill its assigned spec.
- **Covered** applicants remain available as backups. **Invite extra** explicitly
  permits an additional player of that spec. Permission and group-capacity guards
  still apply. Convert your party to a raid yourself when you reach its limit.
- **Decline** moves a waiting applicant to the collapsed Declined section, with
  **Undo**. Repeat whispers cannot reactivate them during the same run. No reply
  whisper is sent. Already-invited players offer Release slot instead.
- **Joined** rows move into the collapsed Joined section after **5 seconds**.
  Joined players with unknown specs stay highlighted at the top as **Needs a spec**
  until assigned or explicitly marked No slot. Empty history sections are hidden.
  Expand Joined and click a player's spec field to edit their assignment.
  Players who leave show **Left group** with Restore
  and Decline; the slot reopens if no other counted player or manual selection
  covers it. Offline players still in the group continue to cover their slots.
- Use the mouse wheel or scrollbar for longer lists. At most 250 player records
  are retained per run. Start a New run to clear the previous run's records.

## Compatibility and verification

Targets Interface `30300` and Lua 5.1, using legacy frame backdrops and chat APIs.
The chat integration follows the [3.3.5 FrameXML source](https://github.com/wowgaming/3.3.5-interface-files/blob/main/ChatFrame.lua).
This is for the original Wrath client, not the modern Wrath Classic client.

Run the automated checks from the repository root with Lua 5.1:

```sh
lua tests/voa25_test.lua
```

The full suite checks all 524,288 spec combinations, prefix/suffix handling, persistence,
chat length limits, UI callbacks and self-test failure handling. It also runs
`tests/voa25_recruitment_test.lua` for parsing and recruitment state transitions,
plus mocked client-event and pooled-UI integration checks. No test sends real
whispers or invitations. The optional in-game self-test still covers the generator
and saved-data normalizer only.

For an in-client smoke test, enable `/console scriptErrors 1`, open `/voa25`, toggle
each class's checkboxes, prepare a message, and cancel it with Escape. Verify the
chat destination before actually sending. Drag the window, `/reload`, and confirm
selections, suffix and position survive. Confirm a blank suffix removes the extra
text and a long suffix disables posting. Test `/voa25 reset`, `/voa25 center` and
`/voa25 selftest` as well.

After installing version 1.3.0, restart WoW so the new `UI.lua` file in the TOC is loaded.
For recruitment smoke testing, use a second player and check:

1. Whisper `ret`, `boomkin`, an ambiguous spec and a longer message. Repeat a
   whisper; verify one row per player and correct manual spec choices.
2. Invite via the addon, `/invite`, and right-click. Verify amber reservations,
   another same-spec applicant showing Reserved, and Joined after acceptance.
3. Decline an application, whisper again, then Undo. Check that the spec and LFM
   message were not changed by the decline.
4. Decline a game invite, try an unavailable/already-grouped player, and leave an
   invite unanswered for 60 seconds. Verify only identifiable failures release
   automatically, and Keep waiting/Release slot behave as labelled.
5. Confirm Joined collapses after 5 seconds. Uncheck its spec, cause a roster update,
   and verify the slot stays open. Test leaving, duplicate-spec members and a
   party-to-raid conversion, plus `/reload` with joined and pending applicants.
6. Check scrolling, long whisper tooltips, spec chooser, Escape, both tabs and a
   smaller UI scale. Check New run confirmation and the Recruiting toggle.
7. Leave a joined hybrid class unassigned for more than five seconds; verify it
   stays visible, then assign it or choose No slot. Check the picker contains only
   that class's specs and that the grid names the player once assigned.
8. Expand/collapse Message options, including at a smaller UI scale. Verify the
   prefix and suffix survive collapsing and the preview and chat action remain visible.
   Check Open/Invited/Filled markers, manual coverage, owner tooltips and reopening.
9. Click a player's name or whisper text, including after scrolling and inside
   Joined/Declined. Verify chat targets that player and nothing sends until Enter.
   Check spec selection, Invite and section headers still perform their own actions.

Automated mocks cannot verify the client's actual rendering, secure-hook behavior
or server-specific event timing; those require this in-game check.
