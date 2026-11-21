Nause Raid Tools 0.12.0-alpha.108 - private testing build

ALPHA.108 - ONE ADDON
Loot Council and SoftRes now ship together inside NauseRaidTools. Install only
NauseRaidTools and remove the old NauseSoftReserve addon folder. One NRT version
covers both loot systems, assignments and raid tools. LC saved settings remain.
SoftRes retains its NauseSoftReserveDB data format; keep the old companion save
file if historical data needs a one-time manual transfer.

COMMANDS
/nrt opens the main menu. Shortcuts: settings, assignments (My Assignments),
raidcheck, responses, loot, timer, softres, history, version and help.
Session actions use window buttons. Tests, resynchronisation and diagnostics
are in Settings > Advanced. LC recovery is in Settings > Session; SoftRes
recovery is offered in SoftRes setup. Leaders open the assignment editor from
My Assignments > Assignments or Settings > Raid Tools > Assignments.
The old /nrtsr, pugsetup, results, action subcommands and duplicate aliases are
removed. Reservation messages remain !sr, !mysr and !removesr.

Validation: 34 automated suites, including unified TOC loading, command routes,
shared LC/SR testing, catalogue sync, assignments, recovery and buff reminders.
Native in-game testing remains necessary. Includes all alpha.107 features.

ALPHA.107
My Assignments uses compact icon-and-text rows without Job/Target columns.
Healers see their assigned tank's full class-coloured name; multiple markers
for the same tank are grouped. Boss tank overrides update inherited healer
rows automatically. Buff, Dispel and Decurse icons show their assigned player
or groups beside them; hovering a row identifies its ability.
Loot, Response and Voting item lists use the shared scrollbar and mouse wheel.
Previous/Next item navigation buttons are removed. Assignment dropdowns use
class colours for real and practice players, including yourself while solo.
Assigned Buffs is smaller, with class-coloured names and out-of-combat
click-to-buff using the normal single-target spell. Native click casting needs
in-game testing. All four healer classes remain selectable regardless of spec.
Replace both addon folders. SoftRes remains experimental.30; protocol 19.

ALPHA.106
Test Raid now shares with the party or raid when started by the group leader.
Assign real members; they receive their duties through /nrt > My Assignments
without a separate join step. Out-of-combat buff reminders work in shared
assignment tests. Solo practice remains local. Test edits do not overwrite
saved assignments or profiles; End Test restores the previous setup.
Fresh Test Raid plans have no pre-filled boss overrides. Raid-Wide Assignments
carry into every boss until deliberately changed for that boss. Later default
changes update inheriting bosses and preserve manual overrides. Buffing stays
raid-wide only. Includes all alpha.105 features.
Replace both addon folders on every test client. All participants need
alpha.106: assignment messages now use version seven. SoftRes remains
experimental.30; LC/SR protocol 19. Native shared testing still needs a check.


ALPHA.105
My Assignments uses larger, heavier section headings without background bars.
The raid-default scope is now Raid-Wide Assignments; role names, buttons and
All Assignments use consistent capitalisation. Coverage still says Whole Raid
when it means all groups. Existing saved job identifiers are preserved.
Includes all alpha.104 features, including out-of-combat reminders for Kings,
Might and Wisdom and the other three assigned buff families. Party members
are treated as group one. For testing, create a normal shared assignment plan;
local Test Raid practice does not generate live rebuff reminders.
Replace both addon folders; use alpha.105 on clients sharing assignments.
SoftRes remains experimental.30; assignment message version six,
LC/SR protocol 19. Native buff reminder behaviour needs in-game testing.


ALPHA.104
Adds personal Assigned Buffs reminders for all six assignable buffs. Shows
confirmed missing buffs and optional expiry warnings within assigned groups,
uses backups when the primary buffer is unavailable, hides during combat,
and refreshes after combat and resurrection. Unknown data is not called
missing. Settings > Raid Tools > Assigned Buff Reminders controls this.
Native Forever behaviour is ready for in-game testing.
Tank lists now include Warriors, Paladins and Druids regardless of the native
group role. The personal tracker Assignments button opens the current raid
editor directly, preserving the selected boss and practice/live context.
Replace both addon folders; use alpha.104 on shared-test clients.
SoftRes remains experimental.30; assignment message version six and
LC/SR protocol 19. Includes all alpha.103 features.


ALPHA.103
Adds Auto Invite at the top of Settings > Raid Tools: a custom whisper keyword
(default inv), optional guild-only filtering and optional conversion to raid
when five members have joined. Auto Invite and conversion default off.
Invites are paced, duplicates suppressed, pending invites reserve capacity,
and requests wait for native raid conversion to finish. Settings are local
to the character. Native Forever invite/conversion behaviour needs testing.
The /nrt launcher now opens My Assignments directly. Full setup is at
Settings > Raid Tools > Assignments, also reachable through the personal
tracker's Settings button. Test Raid uses ten classic Molten Core bosses
with editable local practice jobs. My Assignments opens on Whole raid,
uses Job/Target columns and labels boss overrides; close it with X.
Buffing stays raid-wide. Raid Check restores compact short headings,
with full names on hover and an initial reset to automatic height.
Replace both addon folders; use alpha.103 on all shared-test clients.
SoftRes remains experimental.30; assignment message version six,
LC/SR protocol 19. Includes all alpha.102 features.


ALPHA.102
My Assignments is narrower, with compact rows, fewer repeated labels and a
section dropdown for All assignments, Whole raid and individual bosses.
Its opening height fits shorter lists; longer lists scroll. Each boss shows
inherited whole-raid duties alongside its own jobs, with matching overrides
applied. Buffing stays under Whole raid only, including backup duties.
Escape leaves My Assignments open. Main tabs now run Buffs, Debuffs,
Tanks & Healers, Kicks/CC/Tranqs, Dispels/Decurse. Replace both addon folders.
For shared testing, use this build on all clients. SoftRes remains
experimental.30; assignment message version six and LC/SR protocol 19.


ALPHA.101
Adds a separate My Assignments window with all your raid and boss duties,
including backups. It stays open independently, scrolls, resizes and refreshes
with the raid plan. The editor's cycling Show: All/Mine button is replaced by
My Assignments. Whole raid adds class-filtered Debuff assignments for four
Warlock curses, Faerie Fire and Expose Armor. Dispel/decurse targets can be
groups or individual players. Buffing and Debuffs stay under Whole raid.
Raid Check and Assignments now use full buff names; Raid Check headings have
wider columns and two-line labels. Replace both addon folders. All players
sharing assignment plans must use alpha.101 (assignment message version six).
Includes SoftRes experimental.30; LC/SR protocol remains 19.


ALPHA.96
Raid Check shows existing Fortitude/Mark/Intellect even when the caster is outside
the current group. Kings/Might/Wisdom columns stay fixed; non-required blessings
are dimmed while active blessings remain visible. Removes green/red cell fills and uses neutral
duration text with small status markers. A bottom-centre handle expands the
window downward; saved height, Auto Height, a visible scrollbar and mouse-wheel
scrolling support larger raids. The title-bar lock also locks resizing. Includes
SoftRes experimental.29 and all alpha.95 features. Replace both addon folders.

ALPHA.95
Forever character names display in full with a space, for example Zergul Exe,
across Raid Check rows/grouped views/announcements, council winners, setup and
history labels, and SoftRes messages. Internal identities and whisper routing
are unchanged. Raid Check's Paladin columns and window are wider so minute
labels fit beside icons. Includes SoftRes experimental.29 and all alpha.94
features. Replace both addon folders; use the same build for group testing.

ALPHA.94
Raid Check adds Kings, Might and Wisdom, including rank and Greater versions.
Columns appear when a Paladin is present or a blessing is active. Present
blessings show automatically; optional Require switches in Settings > Raid Tools
start off so every blessing is not demanded from every player. Required Might
applies to Warriors/Rogues/Hunters; Wisdom to mana classes; Kings to everyone
when a Paladin is present. Salvation is not included. The grid adjusts its width
to the relevant columns. Includes SoftRes experimental.28 and all alpha.93
features. Replace both addon folders.

ALPHA.93
Raid Check now uses a compact icon grid: class-coloured names and row backgrounds,
native ready symbols, separate Fortitude/Mark/Intellect/Food/Flask columns and
missing-player totals above each column. Missing effects show red crosses;
unknown data shows question marks; non-required effects are dim. Readable aura
expiry appears beside present icons. Hover an icon for a short explanation.
Window height adapts to small groups and large raids scroll. By Issue, filters,
native Ready Check and manual announcements remain. Includes all alpha.92
features and SoftRes experimental.28. Replace both addon folders.

ALPHA.92
Adds Raid Check, independent of loot sessions. Open /nrt raidcheck, choose Raid
Check from the launcher, or use Settings > Raid Tools. Solo viewing, parties and
raids are supported. The scrollable Players and By Issue views show native ready
replies, offline/dead players, Fortitude/Mark/Intellect and recognised food and
flask/elixir effects. Check requirements can be disabled in Raid Tools settings.
Group leaders and raid assistants can start native Ready Checks and manually
Announce Issues. Unknown/distant/restricted aura data is not announced as missing.
Loot test modes do not send real raid-check announcements or start ready checks.
Includes SoftRes experimental.28 and the alpha.91 session fix. Native visual and
API behaviour still need testing on Forever. Replace both addon folders.

ALPHA.91
Includes SoftRes experimental.28. Fixes group-test snapshots being rejected when
the host loot provider returns plain [Item Name] text instead of an item link.
Test loot now builds a valid hyperlink from its known item ID when needed.
Outgoing full snapshots are validated on the host, with a visible explanation
if invalid data blocks sync. Diagnostics now includes SoftRes mode, session and
snapshot validity. A transport regression covers the observed name-only provider
result, automatic joining and shared catalogue delivery.
Replace both addon folders on all clients. END the old test and START A FRESH
GROUP TEST; existing invalid test loot must be regenerated.

ALPHA.90
Includes SoftRes experimental.27. SoftRes live and group-test addon messages no
longer wait in NRT's outgoing queue solely because combat is active. Existing
client lockdown/throttle refusal handling still retries safely. Council traffic
keeps its combat guard. A new transport regression exercises actual encoding,
compression, fragmentation, sender pacing, receive, discovery and shared loot
catalogue delivery during simulated combat, including a client lockdown retry.
Includes all alpha.89 session discovery, content heading and link parsing changes.
Replace both addon folders; use the same build for all group-test participants.

ALPHA.89
Includes SoftRes experimental.26. Opening /nrtsr without a session now requests
the current leader's live run or group test. Explicit opening can rejoin a test
previously left. The reservation browser shows selected content in its own
heading, with clearer waiting/no-session messages. Refresh Items retries session
discovery when necessary. Item-link parsing tolerates icons, named colours and
alternate display labels, reading the item ID independently of cached names.
The reported Dungeon Journal link failure still needs native testing.
Includes all alpha.88 host-shared catalogue changes.
Replace both addon folders; use the same build for all group-test participants.

ALPHA.88
Includes SoftRes experimental.25. Only the host needs AtlasLoot Forever or a
compatible item database. Members receive the selected loot catalogue, item
names and boss sources from the host. Refresh Items requests a fresh host copy.
Applies to live sessions and party/raid group tests. Catalogue transfers are
paced, scoped to selected content, and checked against the current host/session.
Includes all alpha.87 commands, announcements and reservation improvements.
Replace both addon folders; use the same build for all group-test participants.

ALPHA.87
Includes SoftRes experimental.24. Reservation chat now uses !sr, !removesr and
!mysr; the old commands are removed. Full item names work with or without
brackets, alongside links and IDs. Repeat a name/link or add x2 for two picks.
Confirmation and query replies show item names and quantities, splitting long
lists into separate whispers. Overview has Announce and Announce Missing SRs
buttons. Missing announcements include each player's remaining slots, excluding
slots consumed by SR wins. Test announcements stay local. Refresh session is
renamed Sync session. Includes all alpha.86 changes.
Replace both addon folders; use the same build for all group-test participants.

ALPHA.86
Includes SoftRes experimental.23. Reservation chat commands now work in group
tests: !reserve, !unreserve and !myreserves. Replies are whispered with a TEST
label. Solo tests accept your own commands and show replies locally. Test chat
limits and request counters are restored when leaving the test. Live saved
reservations remain separate. All alpha.85 session/profile and UI changes remain.
Replace both addon folders; use the same build for all group-test participants.

ALPHA.85
Includes SoftRes experimental.22. Raid Session has separate Loot Council and
SoftRes buttons. Loot Council opens Quick Start, Load Raid Profile and Set Up
Raid; loading a profile lets you review it before starting. Current profile
names and modified settings are shown, including during active sessions.
SoftRes awards announce the item, winner and roll after confirmation. Roll and
reroll messages use available item names/links and name the tied players.
Reservations has a labelled Remove button. SoftRes replaces the old PuG wording.
Loot-window hover tooltips and the empty Levels 1-9 filter are removed.
Delivered buttons clear their pressed appearance consistently.
Replace both addon folders; use the same build for all group-test participants.

ALPHA.84
Includes SoftRes experimental.21. AtlasLoot's recommended level ranges are now
read correctly. Reservations no longer opens hover tooltips. Award confirmation
shows item names and loot colours. Awards has a scrolling table, Pending /
Delivered / All filters and a selected-item delivery panel with relevant actions.
Rolls has a scrolling results list, retaining winner/tie/invalid highlights.
Includes all alpha.82/.83 SoftRes UI, content-picker and test-scenario changes.
Replace both addon folders; use the same build for all group-test participants.
All 28 automated suites passed. Native in-game visual/trade/recovery checks remain.

ALPHA.83
Includes SoftRes experimental.20. Dungeon/raid setup now uses level-range and
content dropdowns with a selected-content list. Unknown levels remain available.
SoftRes dropdowns use drawn chevrons to replace unsupported square characters.
Reservations now has My reserves, All reserves, Search results and boss/instance
navigation, a scrolling item list, reserve totals and player names on hover.
Remaining slots and selected picks stay visible while browsing. Drafts still
require Submit. Replace both addon folders; update every group-test participant.
The new layout needs native in-game visual checking.

ALPHA.82
Includes SoftRes experimental.19: consistent styling/navigation, clearer
reservation browsing, roll/award/delivery flow and the Timer overlap fix.
Import Softres.it is directly visible on Overview; Queue All is retained.
Start SoftRes test opens the dungeon/raid picker and Test Scenario selector.
Choose Normal run, Tied rolls, No valid rolls, Stacked reserves, Pending delivery
or Import examples. Tests use the AtlasLoot/ItemDB catalogue. Replace both addon
folders and update everyone participating in group tests. Native in-game layout,
real trade and disconnect/recovery testing remain required.

INSTALL
Exit WoW. Remove the old SanguineLootTools or SanguineLootCouncil folder.
Copy both NauseRaidTools and NauseSoftReserve into Interface/AddOns.
Enable both addons to try SoftRes. For its loot catalogue, enable AtlasLoot
Forever Dungeons and Raids, or a compatible ItemDB.
The final path must be Interface/AddOns/NauseRaidTools/NauseRaidTools.toc.
Enable Nause Raid Tools at character selection. Commands start with /nrt.
This rebrand uses a fresh NauseRaidToolsDB for settings and history.
Run /nrt test solo or as group leader to start simulated loot.
Use /nrt leave-test to exit. Use /nrt help for the command list.

NEW IN ALPHA.80
- Settings > Advanced > Test Modes has matching Start / End buttons for council
  and SoftRes testing. Active sessions and the other test block starting a test.
- Solo SoftRes test includes 20 simulated players and 10 loot copies, automatic
  sample rolls, award confirmation and simulated delivery, without a raid.
- /nrt softres test starts or refreshes it; /nrt leave-test exits.
- Test windows are labelled. Real bags, trades, chat and saved SR history are
  isolated. Joining a real group ends the solo SoftRes test.

NEW IN ALPHA.79
- Settings > Advanced > Version Check is available at every raid rank.
- /nrt versions opens the same independent version window.
- Outside a group, only installed NRT and SoftRes versions are shown.
- Party and raid members can compare both addon versions without a loot session.
- No guild requests or extra launcher button. Pre-Raid Loot Check stays restricted.

NEW IN ALPHA.78
- SoftRes shares Overview, Reservations, Rolls and Awards navigation.
- Overview adds submission totals, player filters and a scrollable roster.
- Reserved items show names, icons and tooltips; player names use class colours.
- Browser adds dropdown filters, + / - controls, reserve counts and draft status.
- Unsaved selections survive switching tabs; untouched drafts follow confirmed picks.
- Roll controls follow the current stage: Stop, Award, Reroll or View delivery.
- Award correction controls are collapsed until requested.
- White body text, gold headings and consistent spacing across SoftRes screens.

NEW IN ALPHA.77
- Includes the experimental Nause Soft Reserve companion.
- /nrt softres opens SoftRes setup; /nrtsr opens player reservations.
- SoftRes uses the Loot and Timer windows for rolls, awards and delivery.
- Guild Member Help puts response colours before responding guidance and
  explains /nrt > Responses as another way to reopen responses.
- Real trades and reconnects still require in-game testing.

NEW IN ALPHA.76
- Guild Member Help explains personal response colours and where to edit them.
- The help pop-up is taller to keep all four sections spaced clearly.
- Replace the colour wheel rim with a circular mask to clip the outer fringe.
  Verify the visual result in game at your normal UI scale.

NEW IN ALPHA.75
- Setup response controls match Settings: order, rename, visibility and remove.
- Guild Member Help opens a pop-up with readable guidance sections.
- Session uses tighter spacing and two rows of equal-sized buttons.
- Adjust the colour wheel rim to cover stray edge pixels at scaled sizes.

NEW IN ALPHA.74
- The setup response page offers Add Transmog and Remove Transmog.
- Loot quality labels sit beside their dropdowns, with larger row gaps.
- Review uses gold section headings and increased line and section spacing.

NEW IN ALPHA.73
- Add Transmog from step 2 of guided setup, or re-enable an existing choice.
- Loot Handling uses the Settings toggle switches for collection and awards.
- Quality labels use matching loot colours in Loot Handling and Review.
- Review separates the profile name label, helper text and input box.

NEW IN ALPHA.72
- Settings > Session > Set Up Raid guides loot roles, responses, collection
  rules and a final review. Save setup or a new guild profile before starting.
- Review Saved Setup flags absent council and changed Master Looter roles.
- Recovery Preview explains takeover eligibility, verification and restored
  work. Group recovery still requires live verification.
- Add Loot accepts bag Shift-clicks after the input loses keyboard focus.
- All commands use /nrt. The renamed folder and logo paths are checked
  against the manifest, including solo and group test startup.

REBRAND
- Nause Raid Tools (NRT), with the NRT Settings logo.
- /nrt replaces /slt for every command.
- Addon directory, manifest, saved data and communication prefix renamed.

NEW SINCE ALPHA.70
- Loot puts copies needing attention first and shows their next action.
- Approaching trade deadlines get a short badge. Open Timer for exact times.
- Timer sorts by remaining time. Full mode shows the winner and Trade
  button where permitted. Compact mode keeps the item and countdown.

NEW SINCE ALPHA.69
- /nrt brings the launcher to the front when it is already open.
- /nrt test can start and restart solo and shared test sessions.

NEW SINCE ALPHA.68
- Takeover priority is Raid Leader, Master Looter, then the named Raid Assistant.
- Settings > Session and /nrt check open the Pre-Raid Loot Check.
- Settings > Display offers Compact Responses, Voting and Timer.
- History > Export CSV copies the currently filtered rewards.
- Council can right-click a tracked Timer item to suggest it. The Master
  Looter gets one notice per item copy and can queue or dismiss it from Loot.
- Settings > Announcements controls Raid chat notices for tracked loot,
  response openings, and awards or award corrections.

NEW SINCE ALPHA.67
- Recover a confirmed session after the Raid Leader reloads or changes.
- One designated Master Looter or council member keeps the private ballot
  backup. Recovery pauses if a complete copy of the latest known revision
  cannot be verified. Use /nrt sync to retry.
- Check pending trades and any deliveries in progress before re-enabling
  automatic collection and awards after recovery.

NEW SINCE ALPHA.66
- Enable Transmog from Settings > Responses > Raid Response Choices.
- Transmog checks the player's collection. A collected look counts even when
  learned from a different item. A collected or unlearnable appearance disables
  Transmog only. Unavailable collection data leaves the response Unverified.

NEW SINCE ALPHA.65
- The active Master Looter gets a council seat automatically.
- The raid leader can hand off the role in Settings > Council. With WoW Master
  Loot active, the addon waits for the game to confirm the new holder.
- Without WoW Master Loot, use the saved assignee or the raid leader. A handoff
  keeps the session, existing votes and tracked item holders.
- Ctrl-click an item name or icon in Responses to open WoW's dressing room.
  Shift-click links the item in chat. These follow WoW's modifier bindings.

NEW SINCE ALPHA.64
- Clear the Voting shade when award confirmation closes, before advancing.
- Show a yellow tick for your recorded vote and a green tick after award.
- Replace four test items with persistently unavailable tooltips. The 27-item
  pool now includes Walking Stick, Ring of Iron Will, Large Axe and Heavy
  Mithril Pants. Check the replacements on live Forever.

NEW SINCE ALPHA.63
- Request missing item data when loot arrives and refresh the active tooltip.
- /nrt test includes 27 items, with all three relic types and one recipe each
  for Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking and Tailoring.
- After a confirmed vote, select the next item with an available candidate.
- Forever uses both character names in roster, voting, loot, trade and history.
  Existing history entries retain their recorded names.

NEW SINCE ALPHA.62
- The 30-item test pool includes a libram, idol, totem and one sample for
  each of the nine professions covered by the recipe filter.
- Apply class rules to librams, idols and totems.
- Recipe filtering accepts profession lists with omitted empty slots.

NEW SINCE ALPHA.61
- Solo and group /nrt test use 23 Forever items, with Blacksmithing,
  Leatherworking, Enchanting and Tailoring recipes.
- Responses filters recipes by learned profession, regardless of skill rank.
  Unresolved recipes stay visible. Loot and Council show every recipe.

NEW SINCE ALPHA.60
- Item details come from the game. Native tooltips show stats, and class
  restrictions plus Forever armour and weapon rules drive auto-pass.
- Missing or ambiguous item data keeps responses available. The leader
  rechecks when data arrives and preserves explicit replies.
- ItemDB is no longer required. Item details load locally, so there are no
  new addon messages or wire fields for item data. Protocol 17 retained.
- Test on live Forever with ItemDB disabled. Check cached and uncached loot
  on both the leader and raider clients. See TESTING.md in the repository.

NEW SINCE ALPHA.59
- Routine loot transfers run quietly: no receiving-loot popup, fragment
  counters or loading text in response windows. History Sync keeps visible
  progress and completion; actionable communication failures remain visible.
- History removes All Players. Select All Shown changes to Deselect All
  when every shown record is selected; deselecting keeps delete mode open.
- New personal Display tab: Lock Window Positions, Reset All Windows,
  Reset One Window and Loot Window Auto-Open. Preferences are per character;
  raid profiles cannot override the personal auto-open setting.
- Response Timing moves from Session to Responses. Personal response colours
  remain in Responses. Session retains session controls and pre-raid checks.
- Settings uses a slim context bar and shows footer notices only when
  permissions or active-round locks need explaining, giving content more room.
- All twenty-one local suites pass. Native layout and raid checks remain pending.
- Protocol 17 retained; update testers together. Start a fresh session when
  upgrading from alpha.58 or older. Saved settings and profiles are retained.

NEW SINCE ALPHA.58
- Master Looter selection combines a typed Name-Realm and roster dropdown
  in one field. Turn off Follow in-game Master Looter, choose/type a member,
  then Assign. The repeated idle status line is removed.
- Voting rules say Candidates per item, with 1 Candidate / 2 Candidates /
  3 Candidates options. Voting behavior is unchanged.
- History audit uses a compact, content-fitting popup with scrolling for
  long records. Full search guidance, including DD/MM/YYYY and Shift-click
  linking, appears in the empty field; its hover tooltip is removed.
- Sync History moves to the bottom right. Crimson Delete History enters
  row-selection mode; Select All Shown respects the current filters.
  Delete Selected requires confirmation; Cancel leaves records intact.
  Deletion is local: active sessions or sync may restore records.
- Quality Rules directly control Ignore, Collect for council and Auto-award
  to recipient. The separate minimum-quality threshold is removed.
- Automatic Collection and Automatic Awards are adjacent, followed by
  Open Loot on discovery. Their descriptions explain council collection
  versus direct awards without a council vote. Repeated status text is
  hidden; actual routing progress/problems remain visible.
- Existing configured quality rules survive migration. Fresh defaults
  preserve epic/legendary council collection; lower qualities use Ignore.
  Review your existing rules before enabling automation.
- All twenty local suites pass. Native layout and raid checks remain pending.
- Protocol 17: update everyone together and start a fresh session. Do not
  resume an alpha.58/protocol-16 session; saved raid setups/profiles remain.

NEW SINCE ALPHA.57
- Council membership uses one raid-member dropdown per member, with Remove
  on the right and Add Council Member underneath. Changes save immediately.
- Replacing a member is atomic; duplicate selections are rejected. Saved
  absent members remain visible and removable. Leader and voting locks remain.
- Gold Settings headings capitalize the start of every word, including
  Saved Raid Profiles, Profile Name, Council Membership and Voting Rules.
- Repeated tab titles and introductions are removed. Content starts higher,
  giving controls and the docked Responses preview more room.
- All nineteen local suites pass, including council row regressions.
  Native layout checks remain pending. Protocol 16 retained.

NEW SINCE ALPHA.56
- History shows muted "Search name, date or item..." text inside the empty
  search box, replacing the long label above it. Typing hides the hint;
  clearing the field restores it.
- Hover over the box for DD/MM/YYYY date guidance and Shift-click item linking.
- Includes all alpha.56 History filters, Guild Bank separation, green-item
  exclusion and group History sync. Protocol 16 retained.
- All nineteen local suites pass; native layout and sync checks remain pending.

NEW SINCE ALPHA.55
- History search supports player names, dates (DD/MM/YYYY), item names and
  Shift-clicked item links. Search sits at the top left of History.
- My Rewards automatically filters to the logged-in character (name and realm).
  Click Back to All Rewards to return to the main list.
- Guild Bank opens a separate view of awards marked Guild Bank, with the same
  return button. These records are hidden from the main/personal reward lists
  and candidate reward counts. Search works in both views.
- Green-quality awards no longer consume the 500 retained History slots.
  Existing known green records are removed on load; green loot distribution
  and active trade tracking remain available.
- Sync History merges retained awards across compatible online members of
  the current raid or party. Regroup after split raids, or invite an absent
  member back, then have the leader, master looter or council start the sync.
  No active loot session is required. Everyone participating needs alpha.56.
- Syncing/progress/completion states appear in History, with a completion
  message in chat. Missing or interrupted peers are reported. Sync preserves
  newer correction/delivery revisions, complete audits and distinct item copies.
- The merged history keeps the latest 500 records, including Guild Bank items.
  Sync cannot recover records no longer retained by any participating member.
- All nineteen local test suites pass, including a 20-member split-raid and
  absence simulation. Native Forever sync and layout checks remain pending.
  Protocol 16 retained; alpha.55 cannot participate in the new History sync.

NEW SINCE ALPHA.54
- Early and urgent trade warnings use Alarm Clock 2 (sound 12867), replacing
  Raid Warning. The existing sound On/Off switch remains; no dropdown added.
- Completed automatic Disenchant and Guild Bank assignments leave the active
  Loot list and do not trigger Open Loot on discovery. History and archive
  records remain intact. Pending trades, delivery review, Other assignments
  and ordinary council awards remain visible.
- Native distribution and council collection from alpha.54 are retained.
  A live tester reported instant distribution; remaining raid checks continue.
- All seventeen local test suites pass. Protocol 16 retained.

NEW SINCE ALPHA.53
- Eligible automatic assignments use local native Master Loot confirmation.
  The next item does not wait for recipient addon messages or history sync.
- Green materials can merge into existing stacks. Native records retain
  quantities and distribution evidence without inventing physical bag GUIDs.
- Collect for council moves eligible single-copy loot into the actual Master
  Looter's bags, unawarded. Enable Automatic collection and satisfy both the
  council collection and game Master Loot thresholds. Queue for normal voting.
  Real bag GUIDs and trade timers remain tracked. Council stacks remain manual.
- Final Assign automatically rules still require Automatic assignment enabled,
  a nominated recipient and a reason. Resuming a session disables that switch.
- Pending result recording is retried in the background. Duplicate results
  cannot recreate an award; failed or unconfirmed gives are not marked delivered.
- All seventeen local suites pass. Native client timing still needs raid testing.

NEW SINCE ALPHA.52
- Existing stacks and known stackable materials are reported as requiring
  manual distribution. They no longer block eligible single-copy drops.
- Only the assigned recipient can report a pre-transfer stack blocker;
  a ready/started transfer cannot be cancelled by that report.
- Reuse prepared routes for different items when corpse slots compact,
  preserving a single receipt baseline per item.
- All sixteen local suites pass, including three green material slots ahead
  of two blues. Native interaction still needs confirmation. Protocol 15.

NEW SINCE ALPHA.51
- Loot, bag and state changes coalesce into assignment checks on the existing
  0.1-second loop, outside event/reducer calls. One-second fallback retained.
- Recipient readiness replies follow loot-slot order. Native authority, combat,
  corpse-open and new-copy receipt checks and network pacing remain enforced.
- All sixteen local suites pass. Simulation first-send time with a depleted
  burst allowance improves from 5.0 to 2.4 seconds; native timing is pending.

NEW SINCE ALPHA.50
- Prepare recipient snapshots for distinct boss drops together. Physical sends
  remain sequential, with fresh-GUID receipt proof for each copy.
- Identical item IDs retain separate baselines to prevent ambiguous receipts.
- Diagnostics distinguish automatic collection/assignment, the blue rule,
  addon/native Master Loot authority and whether the corpse window is open.
- All sixteen local suites pass. The two-client transport simulation reduces
  the gap between two distinct items from 14 seconds to 3 seconds at one message
  per second. Native raid timing remains unverified. Protocol 15 retained.

NEW SINCE ALPHA.49
- Receipt snapshots/reservations match item IDs across character-specific link
  metadata. Exactly one new bag GUID remains required to verify receipt.
- Duplicate automatic confirmations do not advance revisions or rebroadcast
  unchanged state. Diagnostics show pending stages and duplicate counts.
- Ordinary trades without pending awards no longer report loot activity.
  Expired background requests are counted quietly; validation errors remain.
- All fifteen local suites pass. Raid latency still needs native confirmation.

NEW SINCE ALPHA.48
- Automatic assignment handshakes use live-update priority without resending
  unrelated private ballot views. Repeated requests have bounded retries.
- Recipient bag confirmation remains required before the next item is sent.
- All fifteen local suites pass. Improvement to the reported 45-second delay
  still needs native raid confirmation. Protocol 15 retained.

NEW SINCE ALPHA.47
- Timer uses one clipped list with a mouse wheel, scrollbar arrows and draggable
  thumb. Headings stay fixed; countdown refreshes preserve scroll position.
- Automatic boss assignments skip terminal routes and distinguish different
  drops reusing a loot slot. Receipt confirmation still gates the next send.
- Loot Configuration shows when recipient bag confirmation is pending.
- All fifteen local suites pass. Native raid and scroll checks remain pending.

NEW SINCE ALPHA.46
- Voting details, headings, images and controls belong to the voting surface
  so its opaque background cannot cover them after reopening or focus changes.
- Repeated reopen, focus and collapse/expand cycles have regression coverage.
- All thirteen local suites pass. Native display checks remain pending.

NEW SINCE ALPHA.45
- Raid trade timers fall back to the exact bag item tooltip on Classic clients
  without C_TooltipInfo. Existing tracked copies refresh on a holder bag scan.
- Escape leaves Timer open; the close button still works.
- Solo and group test response rounds now start at 60 seconds. Normal raid
  response settings are unchanged. Restart the test to use the new default.
- All thirteen local suites pass; native confirmation is pending. Protocol 15.

NEW SINCE ALPHA.44
- Corrected shared dropdown layers so the outside-click catcher sits below
  the menu and its clickable options within the native frame-level limit.
- Regression checks now enforce the limit and option input ordering for both
  raid member pickers and other shared dropdowns. All twelve suites pass.
- Native mouse interaction still needs in-game confirmation.

NEW SINCE ALPHA.43
- Settings > Council has current-group dropdowns for Master Looter and council.
  Select a full Name-Realm, then click Assign or Add / remove to apply it.
- Current council members are marked; full raids can be scrolled. Manual name
  entry remains available while solo for preparing the next session.
- Roster changes dismiss stale pickers. Existing leader permissions, ballot
  locks and Follow in-game Master Looter restrictions still apply.
- Twelve local suites passed. Native layout and mouse checks remain pending.
- Protocol 15 and the previous dragging/quality-colour changes are retained.

NEW SINCE ALPHA.41
- Dragging follows mouse travel in UIParent coordinates without native anchor
  switching. The same anchor is retained while dragging and saved on release.
- Interrupted drags finish on hide, lock, layout reset or display/scale changes.
- Quality-rule labels use the matching in-game quality colours.
- Solo setup edits, profiles, reload persistence and leader-started session
  transfer have regression coverage; the existing setup behavior is retained.
- Eleven local suites passed. The reported jumps still need confirmation by the
  affected users in WoW: Forever; this is a candidate fix. Protocol 15 retained.

NEW SINCE ALPHA.40
- Opaque panels and separate drawing-level bands keep each window's content
  together. Opening/clicking a window raises the entire group of controls.
- Small dialogs are above their parent and block its mouse input until closed.
  Nested confirmations retain the correct order; dropdowns stay above dialogs.
- Timer remains an independent window. Background windows are not hidden just
  to solve overlap. Collapse/expand and dynamically created controls are covered.
- Confirmed class-restricted raiders show Auto Pass in Voting rather than waiting
  or timed out. Unknown eligibility does not cause a pass; explicit responses are
  preserved. The leader synchronizes late class information and new members.
- Change winner has a live 0/160-byte reason counter matching response notes.
- Removed the enforced 16-unit positioning margin. Windows can be placed flush
  against screen edges while remaining on-screen.
- Nine local suites passed, including window layering and class auto passes.
  Native mouse layering, handovers and raid behavior still need in-game checks.
- Protocol 15 and two-minute test response rounds retained. Update all testers.

NEW SINCE ALPHA.39
- Voting's winner button becomes Trade for a verified item held by the local
  player, and Delivered when delivery is confirmed. Existing trade checks apply.
- Change winner now uses a recipient dropdown instead of Previous/Next, with
  eligibility details below it. Typed reasons survive recipient changes.
- Holder handovers require the same GUID to be absent from the old holder and
  present in the recipient's bags. Reports can arrive in either order.
- Handovers keep physical holder and award winner separate. Delivery to the
  winner is verified; a delivered item returned elsewhere needs review.
- Queue/Queue All reject previously recorded, awarded, delivered and retired
  copies, including stale associations and duplicate tracking rows. Distinct
  physical copies of an identical item remain queueable.
- Awarded items leave the response list. Closed, unawarded rounds remain for
  review. This prevents old awards appearing alongside fresh response rounds.
- Diagnostics include confirmed/pending holder handovers.
- Local checks cover trade actions, dropdowns, handovers, queue protection,
  pickups, network replication and Lua 5.1 syntax. Native raid testing required.
- Protocol 15 and two-minute test response rounds retained. Update all testers.

NEW SINCE ALPHA.38
- Replaced the shared dropdown's nested scrolling frames with direct clickable
  option rows. Menu, rows, scrollbar and outside-dismiss area use explicit
  input layers, so the dismiss area stays beneath the option buttons.
- Menus can be reopened and changed repeatedly. Long lists show eight options
  at a time with wheel, arrows and slider; switching menus resets scroll state.
- Covers collection thresholds, actions, recipients, reasons, voting options
  and profile menus. Recipient and Edit reason controls remain available only
  for Assign automatically; the action menu itself stays editable for leaders.
- Diagnostics now report menu opens and option clicks without selected values.
- Simulated checks cover repeated action/threshold changes, saved reasons,
  42-choice recipient lists, scrolling, boolean choices and direct input layers.
  Native game mouse behavior still requires tester confirmation.
- Protocol 15, pickup detection, compact releases and two-minute tests retained.

NEW SINCE ALPHA.37
- The assignment-reason dropdown is an independent overlay, so collapsing the
  main Settings window cannot hide it behind a separate reason dialog.
- The reason choices display Disenchanted, Guild Bank and Other. Existing
  saved Disenchant values are retained and display as Disenchanted.
- Dropdown actions use the owning control's visibility and enabled state;
  closing the dialog removes the menu and its click-dismiss overlay.
- Simulated UI checks cover the collapse failure, all three choices, saving,
  reopening, recipient/note preservation and dismissal. Verify in-game.
- Protocol 15, pickup detection, compact releases and two-minute tests retained.

NEW SINCE ALPHA.36
- Fresh unbound pickups are matched by item ID and physical bag copy, rather
  than requiring identical chat and bag hyperlinks. Handles self loot and
  pushed-item messages, with a 30-second observation window.
- The normal session snapshots existing bag copies so a fresh pickup cannot
  automatically pull an older identical item into tracking. Quantity evidence
  limits new copies; bag-before-chat and chat-before-bag ordering are supported.
- Existing unbound items are not retrospectively collected. Use Add loot for
  the helmet already in your bags; test automatic collection on a fresh drop.
- Diagnostics now include real/test session mode, collection settings, pickup
  message count and bag scan status. Verify pickup behavior in-game.
- Unbound items show "Unbound — no BoP timer" instead of a countdown.
- Protocol 15, compact releases and two-minute test rounds retained.

NEW SINCE ALPHA.35
- Queue All reuses the tracked loot links/GUIDs already held by recipients,
  and sends shared response-round settings once instead of once per item.
- Public loot-release updates take priority over background council packets,
  preserving their required baseline/revision order.
- Sustainable send allowance now refills at one fragment per second with a
  bounded burst. Repeated failures back off below that rate instead of
  repeatedly probing toward ten per second.
- Diagnostics include the most recent loot release size and fragment count.
- Release/codec/recipient tests cover 2, 5 and 40 members, queued response
  coalescing and a slowly refilling shared server allowance. In the five-member
  fixture, the release update shrank from 16 fragments to 5.
- Actual in-game latency still requires testing. Exhausted server allowance or
  a baseline still in transit can delay delivery. Timers still start on queue;
  the test default remains 120 seconds.
- Protocol 15 is required for compact releases: update every tester together.

OPTIONAL ONE-TIME SETTINGS/HISTORY TRANSFER
With WoW CLOSED, copy WTF/Account/<account>/SavedVariables/NauseRaidTools.lua
to NauseRaidTools.lua in the SAME SavedVariables directory before launching.
Keep the file contents unchanged. Keep a backup; do not overwrite newer data.
Without this transfer the renamed addon starts with fresh settings/history.

NEW SINCE ALPHA.34
- A temporary network throttle now halves the send rate instead of immediately
  dropping it to one fragment per second. Continued throttling slows it further.
- Successful sends gradually restore the rate. Consecutive rejections extend
  the retry cooldown; temporary throttles never discard the current fragment.
- Diagnostics now include the last throttle result and how long ago it occurred.
- Simulated 19-fragment transfer with one throttle: alpha.34 19 seconds;
  alpha.35 4.1 seconds. These are simulated results, not an in-game guarantee.
- Two-minute test response rounds retained. Response timers still start when
  the leader queues loot; slow delivery still consumes response time.

NEW IN ALPHA.34
- Solo and group /nrt test response rounds now start at 120 seconds (two minutes)
  to allow more time while investigating throttling. Refreshing test mode keeps
  this two-minute default. This change does not fix the underlying throttling.
- Normal raid response settings and real item trade timers are unchanged.

NEW IN ALPHA.33
- Configure private saved raid setup before a session, including while solo.
- Existing Settings tabs cover responses/timer, council, Master Looter preference,
  voting rules, collection/recipients/reasons and alerts. Profiles is Raid Profiles.
- Save/apply Raid Profiles before starting. Session shows a compact setup summary.
- Start uses the Raid Leader's defaults. Absent council members are skipped,
  an absent manual Master Looter falls back, and absent named automatic-loot
  recipients pause automation for review without erasing saved preferences.
- Automatic recipient Name-Realm entry supports planning before players join.
- Active nonleaders cannot change shared settings; current item rules stay frozen.
- All alpha.32 popup, chevron, Voting advancement and title spacing work is retained.
- Protocol 14 retained. Everyone testing should install alpha.33.
Testing notes are supplied in chat; no separate checklist is included.

CARRIED OVER
Fixed sizes for other windows, title-bar lock/collapse controls, retained Response items after
expiry, modern Shift-click insertion, Voting loot navigation, SLT logo, clean
scrollbars, rounded Settings toggles, section dividers, immediate
response ticks, Loot-first manual additions and SoD-only 20-item tests.
/nrt test opens Loot for the Master Looter; queue items to start 60-second rounds.
Real bag/trade/history actions remain disabled in test mode. Soft Reserve is planned.
Add loot requires a physical single item in carried bags; Shift-click selects its exact copy.
Bag-added items use normal trading after award; stack splitting and trade eligibility apply.
Existing old manual placeholders still require delivery confirmation through Manage.

NATIVE ACCEPTANCE
Loot Configuration appearance, native corpse eligibility/verification, Shift-click,
physical bag-copy trading, multiplayer timing, saved-data transfer
and full-exit persistence still need in-game testing. Full-exit persistence is not
claimed fixed by this release.

COMMANDS
/nrt; /nrt settings; /nrt responses; /nrt loot; /nrt timer; /nrt history
/nrt check; /nrt sync; /nrt test; /nrt leave-test; /nrt resume; /nrt help
/nrt diagnostics; /nrt diagnostics start; /nrt diagnostics stop
See LICENSE.txt for private testing terms.

VERSION CHECK (included in alpha.79)
Open Settings > Advanced > Version Check, or /nrt versions, at any rank.
Outside a group it shows only your installed NRT and SoftRes versions, without
sending any requests. In a party or raid it compares group members. There is
no guild check and no extra launcher button.
A missing reply is unconfirmed, not proof an addon is absent. This checks
installed versions, not GitHub releases. Detailed Pre-Raid Loot Check remains
restricted to the raid leader and Master Looter; /nrt check opens Version Check
for other players.

TEST MODE BUTTONS (included in alpha.80)
Settings > Advanced > Test Modes has a Start / End Loot Council test button.
It uses the existing /nrt test flow: solo outside groups and shared group testing
when grouped. When Nause Soft Reserve is enabled, the matching Start / End
SoftRes test button appears beneath it. Live sessions and the other test mode
block starting a test; normal raid permissions are unchanged.

ALPHA.81 UPDATE
Test Modes now appears at the top of Settings > Advanced. SoftRes Test chooses
solo or shared party/raid testing automatically, using the same button or
/nrt softres test. The leader starts the shared test; group members submit their
own reservations and roll on simulated items. Update all participating clients.
Awards and delivery are simulated; saved SR sessions and history are untouched.
See NauseSoftReserve/README.txt for joining, leaving and reset behavior.

RAID CHECK (included in alpha.92)
Open Raid Check from /nrt's launcher, /nrt raidcheck, or Settings > Raid Tools.
Works independently of loot sessions in parties and raids. Refresh reads native
ready replies, offline/dead status, Fortitude/Mark/Intellect and recognised food,
flask/elixir effects. Intellect applies to mana classes; core buffs are checked
when a provider class is present. Disable optional requirements in Raid Tools.
Players need no addon for these native checks. Out-of-sight, unavailable and
restricted aura data shows Unknown and is not announced as missing. Players
and By Issue views scroll through the group. Leaders and raid assistants can
start a native Ready Check or manually Announce Issues. Loot test modes do not
start real ready checks or send issue announcements. Native visual/API testing
is still required on Forever before relying on this new window in a raid.

RAID CHECK ICON GRID (included in alpha.93)
Compact readiness layout: class-coloured rows/names, native ready symbols,
individual Fortitude/Mark/Intellect/Food/Flask columns, missing totals in their
headers, missing crosses and unknown question marks. Present effects retain
colour; non-required effects are dim. Readable aura expiry is shown beside the
icon, with short hover explanations. Window height follows group/view size;
large groups scroll. By Issue, filtering and manual announcements remain.

PALADIN RAID CHECKS (included in alpha.94)
Kings, Might and Wisdom are observed, including rank/Greater versions.
Their columns appear when a Paladin is in the group or a blessing is present.
Optional Require switches in Settings > Raid Tools start off: present blessings
are still shown, but absent optional blessings do not create missing alerts.
Required Might applies to Warriors/Rogues/Hunters; Wisdom to mana classes. Kings can
be required for everyone when a Paladin is present. The grid widens only when
these columns are relevant and compacts again without them.

FULL DISPLAY NAMES (included in alpha.95)
Forever character labels use full first name and surname separated by a space,
for example Zergul Exe. Raid Check rows, grouped views and announcements, loot
council winners, settings/reviews, history details and SoftRes labels/messages
use this presentation. Canonical character keys, packet fields, whisper targets
and saved identity records remain unchanged. Paladin-duration columns are wider
so their minute labels fit beside the icons.

RAID CHECK STATUS POLISH (included in alpha.96)
Buff cells use the underlying subtle class-coloured row without green/red fills.
Present effects retain full-colour icons with neutral duration text. Missing
crosses, unknown question marks, faint non-required icons and header totals
continue to distinguish status without colouring entire cells.

RAID CHECK HEIGHT AND SCROLLING (included in alpha.96)
Use the native-styled scrollbar or mouse wheel for large groups. Drag the bottom
centre handle downward to expand the visible list; the top and width remain in
place. Height is remembered per character across refresh/view changes/reopens.
Auto Height restores compact automatic sizing. The title-bar padlock also locks
resizing. Display > Reset Window includes Raid Check and clears its saved height.
Expanded lists have enough row frames for every raid member. Status cell colour
fills are removed and duration text is neutral.

EXISTING BUFF VISIBILITY (included in alpha.96)
Fortitude, Mark and Intellect show when already active, even if their provider
is outside the current group. Provider/class checks only decide whether absent
effects are required. Kings/Might/Wisdom columns remain visible in fixed positions. Non-required
blessings are dimmed; active blessings show normally without a Paladin present.

FIXED PALADIN COLUMNS (included in alpha.96)
Kings, Might and Wisdom remain visible in fixed columns. Absent non-required
blessings are dimmed; present blessings display normally even without a Paladin.
Missing warnings still require the configured effect and an available Paladin.
The grid no longer shifts or changes width as blessings expire or players leave.

Raid Assignments
Open /nrt assignments, the Assignments launcher button, or Settings > Raid Tools > Raid Assignments.
Alpha.98 includes the custom raid planner described below; alpha.97 contained the first tank/healer list.

ALPHA.97
Shared tank/healer assignments, launcher and /nrt assignments command, raid-profile templates, manual announcements and permissions. Raid Check Settings button opens Raid Tools directly.

CUSTOM RAID PLANS (included in alpha.98; no encounter mechanics assumed)
- Name a custom raid, add/rename/copy encounters, and save separate raid-plan templates. Raid Profiles also preserve the full plan. Old tank/healer lists and older profiles are migrated.
- Define Raid defaults first. Each encounter inherits those jobs; the same section, role, job label and slot number creates an override. Selecting an inherited job and saving in an encounter creates an override. Edit Raid defaults to change the shared default.
- Sections: Tanks, Healers, Interrupts, Dispels, Cooldowns, Custom Jobs. Slots are numbered 1-99. Slots may be unfilled. Custom jobs require a label. Group healers use groups 1-8.
- Link a job to another slot to follow its assigned player. Links to default slots follow matching encounter overrides. Deleting a referenced job is blocked until its links are removed. Copies keep their own linked slots.
- Add an optional backup; My jobs / backup shows both primary and backup responsibilities. Backups are explicit, never substituted automatically.
- The encounter dropdown browses locally. Follow current tracks the leader's selection; Set current encounter shares the selected encounter with the group. Announce manually posts only the viewed encounter and inherited defaults.
- Standalone templates support Save, Load and Delete. Replacing a live plan, overwriting/deleting a saved template, or removing an encounter requires an in-game confirmation; stale dialogs/edits are rejected. New raid starts a blank plan; save a template first to keep the old plan.
- Practice plan is solo only. It adds a clearly labelled fictional encounter with unfilled tank, linked healer and interrupt jobs. These are testing examples, not boss guidance.
- Up to 24 encounters, 480 jobs across a raid, 120 effective jobs per encounter, and 20 saved plan templates. The list scrolls and reduces its viewport to fit smaller screens.
- Native group leader hosts; assistants can edit jobs/encounters; members view. Profile/template management is leader only. Loot tests cannot modify/share plans. Updates wait until combat ends.
- Version-two assignment messages keep older assignment clients from flattening boss plans. All participants need the updated NRT version. Full snapshots recover missed updates; routine edits use small revision-checked messages. This does not change LC/SR protocol 19.

ALPHA.98
Custom raid plans, encounter overrides, linked slots, backups, six job sections, saved plan templates and fictional solo practice. SoftRes .30 aligns the raider Reservations tab left and aligns Refresh items above the Remove buttons. Shared raid plans require updated NRT on all participants.

SIMPLE ASSIGNMENT BOARD (included in alpha.99)
- /nrt > Assignments and /nrt assignments first open Choose a Raid. Saved raids and Test Raid are listed in a dropdown; New Raid creates a named saved setup. No raid data is assumed.
- The main board has three tabs: Tanks & Healers, Kicks & CC, Buffing. Target-marker rows use native Skull, Cross, Square, Moon, Triangle, Diamond, Circle and Star textures. Every player/backup is chosen through a dropdown.
- Tanks & Healers has a tank and two healer dropdowns for each marker. Healers link automatically to that marker's tank, including encounter overrides and tank replacements.
- Kicks & CC has separate Kick, Banish and Sheep player dropdowns for each marker. Buffing uses native spell icons for Intellect, Fortitude, Mark of the Wild, Kings, Might and Wisdom, with player, coverage and optional backup dropdowns. No Salvation assignment is included.
- Save Raid retains the setup. Change Raid returns to the chooser. Encounter editing and Save As/Delete Saved Raid live under Edit Raid. Other older jobs remain accessible separately when a loaded plan contains them.
- Test Raid is an isolated local rehearsal with twenty fictional players plus your available real members. It works for group members too. It never replaces the live plan, saves a practice raid, or announces to party/raid chat. Its announcement button prints a local preview.
- Normal shared assignments keep the native leader/assistant permissions. Members view the live tables and can practise locally. An open dropdown cannot overwrite a newer edit.
- Assignment message version three prevents older clients from interpreting marker/buff rows incorrectly. All live participants need the updated NRT build. Existing saved plans are preserved.

ALPHA.99
Assignments now opens a saved-raid chooser with New Raid and an isolated Test Raid. The simpler board has marker-based tank/healer and kick/banish/sheep tables, plus native buff icons and player dropdowns. Save Raid keeps the setup; encounter management is under Edit Raid. Everyone sharing live assignments must use alpha.99. SoftRes remains experimental.30.

ASSIGNMENT CLASS FILTERS (included in alpha.100)
The original simple board reused one unfiltered roster for every player field. Each field now uses its own capability rule, including backup dropdowns and Test Raid.
- Tanks: Warrior, Paladin, Druid. Healers: Priest, Paladin, Shaman, Druid. Known group/raid roles exclude DPS/healers from tank choices and DPS/tanks from healer choices. When no native role is available, current tank/healer assignments are used before falling back to the class. Unknown class data is not offered in a restricted dropdown.
- Kicks: Rogue, Shaman, Mage, Warrior, Warlock, matching the guild's requested rotation list. Warlocks are labelled Felhunter; the footer explains that Spell Lock requires that pet. This plans capability, not whether a spell is learned or a pet is currently summoned. Conditional stuns/silences from other classes are not added to this rotation.
- Sheeps: Mage only. Banishes: Warlock only.
- Intellect: Mage. Fortitude: Priest. Mark of the Wild: Druid. Kings, Might and Wisdom: Paladin. Buff eligibility does not require a healing spec. Salvation remains excluded.
- Filters are rechecked when selecting a player and by the host for marker-board requests. Receivers keep deterministic reducers, so missing local role data cannot break synchronisation. Existing saved assignments remain intact; confirmed incompatible current players are marked not eligible and can be cleared.
- Test Raid still has twenty fictional players, now with Warrior/Paladin/Druid tanks and Priest/Paladin/Shaman/Druid healers; known DPS hybrids are not offered as healers.
Research: client-derived Forever spellbooks, client 1.60.1.70938 with the recorded 17 November 2026 hotfix cache, consulted 20 November 2026. The interrupt class list is the user's explicit policy.
https://wowforevertalents.com/abilities/
https://wowforevertalents.com/abilities/mage/ (Polymorph, Counterspell, Arcane Intellect)
https://wowforevertalents.com/abilities/warlock/ (Banish, Summon Felhunter)
https://wowforevertalents.com/abilities/priest/ (healing, Power Word: Fortitude)
https://wowforevertalents.com/abilities/druid/ (healing, Mark of the Wild)
https://wowforevertalents.com/abilities/paladin/ (healing, Might/Wisdom/Kings, removed Salvation)
https://wowforevertalents.com/abilities/shaman/ (healing, Earth Shock interrupt)
https://wowforevertalents.com/abilities/rogue/ (Kick)
https://wowforevertalents.com/abilities/warrior/ (Pummel, Shield Bash)

TEST BOSSES, TRANQS AND GROUP CLEANUP (included in alpha.100)
- Test Raid now includes fictional bosses named exactly kicks, tranqs and dispels. Whole raid remains the default view. Every boss has Tanks & Healers, Kicks/CC/Tranqs, Dispels & Decurse, and Buffing tables.
- Tranq marker assignments use Hunter Tranquilizing Shot. The test roster still has twenty fictional players, including two hunters. Banish and sheep remain separate class-filtered columns.
- Whole-raid and encounter cleanup tables each show four Dispel and four Decurse slots with Player, Groups and optional Backup dropdowns. Dispel means friendly magic removal (Priest/Paladin); Decurse means curse/bane removal (Mage/Druid). This is class-based planning, not a check that a spell has been learned.
- Coverage dropdowns now include Whole raid; Groups 1–2, 3–4, 5–6, 7–8; existing Groups 1–4 and 5–8; and individual Groups 1 through 8. The same options apply to buffs and cleanup jobs.
- Test Raid starts with the four group pairs assigned. Each fictional boss can override whole-raid defaults without changing another boss. Practice changes remain local and are not saved over live raids.
- Narrower CC columns use wider player menus so full names and the Felhunter condition remain readable.
- Assignment feature messages use version four. Older saved raids remain supported; all participants sharing these new jobs need the updated NRT build. LC/SR protocol remains 19.
Sources consulted 20 November 2026, client-derived Forever spellbooks:
https://wowforevertalents.com/abilities/hunter/ (Tranquilizing Shot)
https://wowforevertalents.com/abilities/priest/ (Dispel Magic)
https://wowforevertalents.com/abilities/paladin/ (Cleanse)
https://wowforevertalents.com/abilities/mage/ (Remove Lesser Curse)
https://wowforevertalents.com/abilities/druid/ (Remove Curse)

ALPHA.100
Job-specific class and role filters apply to player/backup dropdowns and Test Raid. New fictional bosses: kicks, tranqs, dispels. New Hunter tranq marker assignments and whole-raid/boss magic-dispel and decurse group slots. Coverage includes Groups 1–2, 3–4, 5–6 and 7–8 for cleanup jobs and buffs. All live assignment participants must use alpha.100. SoftRes remains experimental.30; LC/SR protocol remains 19.

INDIVIDUAL CLEANUP TARGETS (source update)
The Dispels & Decurse table's Groups column is now Target. The dropdown offers all existing group coverage options followed by individual players, without applying caster class filters to recipients. Assigned dispellers and backups remain class-filtered. Selecting a group clears the individual recipient; selecting a player retains the group as a fallback but displays/announces only the individual target. Canonical full names are stored separately and survive saved plans, snapshots, deltas and encounter overrides. Buffing remains whole-raid-only in the simple board. Assignment feature messages use version five to prevent older clients from silently treating one-person jobs as group assignments. No LC/SR protocol change.

SOURCE UPDATE - WHOLE-RAID DEBUFF ASSIGNMENTS (included in alpha.101)
Whole raid now includes a Debuffs tab with spell icons, Player and Backup dropdowns for Curse of the Elements, Curse of Recklessness, Curse of Weakness, Curse of Tongues (Warlock), Faerie Fire (Druid) and Expose Armor (Rogue). Both dropdowns use the correct provider class. Debuffs are raid-wide defaults; the tab is hidden on individual bosses. Test Raid has example assignments. Save Raid, shared updates, Show: Mine and manual announcements include these jobs. Copying an encounter retains the raid defaults without creating boss-only debuff rows. One Warlock can maintain one curse per target; assignments are planning, not learned-spell or active-debuff checks.
Assignment feature messages now use version six; everyone sharing the new assignments needs the updated build. Old saved plans still load. LC/SR protocol remains 19. Included in the alpha.101 release package.
Forever client-derived spell references:
https://wowforevertalents.com/abilities/warlock/ (four trainer curses; Agony/Doom are Banes, Shadow/Idiocy removed)
https://wowforevertalents.com/abilities/druid/ (Faerie Fire)
https://wowforevertalents.com/abilities/rogue/ (Expose Armor)

SOURCE UPDATE - FULL RAID CHECK BUFF NAMES (included in alpha.101)
Raid Check column headings use full effect names, matching Assignments: Power Word: Fortitude, Mark of the Wild, Arcane Intellect and the three Blessing names. Shared buff labels also update assignment rows, settings, tooltips and issue announcements. Wider columns and two-line headings keep the full names readable without crowding the first player row. Duration widths, fixed column order and vertical resizing remain supported.

SOURCE UPDATE - PERSONAL ASSIGNMENT WINDOW (included in alpha.101)
The assignment board now has an explicit My Assignments button instead of the Show: All/Mine cycling filter. It opens a separate movable, resizable, scrollable personal window and closes the editor. All your raid-default and boss-specific jobs appear together, grouped by scope, including clearly labelled backup duties, targets and notes. Raid defaults are listed once; boss overrides are shown under their boss. The view refreshes when the shared plan changes, can remain open during play, and is closed explicitly rather than by Escape. It remembers its personal window position and size. The main editor always shows all assignments for its selected category. Local Test Raid previews remain isolated from live assignments.

SOURCE UPDATE - COMPACT PERSONAL ASSIGNMENTS (included in alpha.102)
My Assignments now starts narrower and fits its height to the list, with a scroll cap. Simple duties use compact rows; duplicate marker targets and generic debuff target text are omitted. Useful targets, backup players and notes retain extra space. A section dropdown offers All assignments, Whole raid and each boss. All keeps every duty grouped by raid/boss; boss sections include inherited defaults with overrides applied, except buffing, which stays raid-wide. Selecting a removed boss safely returns to All. The first opening after this update replaces the old oversized dimensions; position is retained and manual resizing remains available. Escape still leaves the personal window open. Main assignment tabs are ordered Buffs, Debuffs, Tanks & Healers, Kicks/CC/Tranqs, Dispels/Decurse.

SOURCE UPDATE - RAID DUTIES IN EVERY BOSS SECTION (included in alpha.102)
My Assignments now includes inherited whole-raid duties under every boss in the combined All assignments list as well as the individual boss dropdown views. A boss override replaces the matching raid job only for that boss. For example, a whole-raid Cross interrupt appears under tranqs alongside a boss-specific Square interrupt.

SOURCE UPDATE - BUFFING STAYS RAID-WIDE (included in alpha.102)
Personal buff assignments appear only under Whole raid, for primary and backup players. Boss sections exclude buffing in both the combined list and individual boss views. Other raid-wide duties still inherit into bosses with matching overrides applied.

SOURCE UPDATE - RESTORE COMPACT RAID CHECK (included in alpha.103)
Raid Check uses the previous short column headings and compact spacing again. Full spell names remain in hover details, assignment rows and announcements. The first opening after this update restores automatic height to clear the oversized saved layout; later manual height changes remain supported.

SOURCE UPDATE - MOLTEN CORE PRACTICE AND PERSONAL TRACKER (included in alpha.103)
Test Raid replaces kicks/tranqs/dispels with the ten classic Molten Core bosses: Lucifron, Magmadar, Gehennas, Garr, Baron Geddon, Shazzrah, Sulfuron Harbinger, Golemagg the Incinerator, Majordomo Executus and Ragnaros. The local fictional roster and editable practice assignments exercise tanks, linked healers, interrupts, CC, tranqs, cleanup and backup duties across the route. These sample assignments are for UI testing and do not encode confirmed Forever boss mechanics. Practice stays local and does not change a live plan.
My Assignments opens on Whole raid. All assignments and every boss remain available in the dropdown. Separate Job and Target columns reduce repeated text, and an Override label identifies boss-specific jobs. Buffing stays under Whole raid. The bottom Close button is removed; use the title-bar X. Escape still leaves the tracker open. It fits shorter lists and scrolls longer ones.
Classic Molten Core boss-name reference: https://warcraft.wiki.gg/wiki/Molten_Core

SOURCE UPDATE - RAIDER LAUNCHER AND SETTINGS ASSIGNMENTS (included in alpha.103)
The /nrt launcher replaces Assignments with My Assignments, opening the personal tracker directly for the current shared raid. Full setup is available at Settings > Raid Tools > Assignments, including the raid chooser, saved plans and Test Raid. Members can view shared plans; existing leader/assistant editing permissions remain. The launcher always selects live duties even after local Test Raid practice; the editor My Assignments button retains its current live/practice context.

SOURCE UPDATE - PERSONAL ASSIGNMENTS SETTINGS SHORTCUT (included in alpha.103)
My Assignments has a small Settings button beside the raid name. It opens Settings > Raid Tools, where Assignments opens setup, without dismissing the personal tracker. The button reserves its own width when the tracker is resized. Existing editing permissions remain unchanged.

SOURCE UPDATE - AUTO INVITE (included in alpha.103)
Settings > Raid Tools starts with Auto Invite. Enable it, choose and Save a single whisper keyword (default inv), optionally restrict invitations to guild members, and optionally enable Auto-convert to raid. Auto Invite and conversion default off; guild-only defaults on. Preferences are local to the character and are not part of shared raid profiles.
Keywords match the entire trimmed whisper, ignoring capitals. Invites use native full character identities, with modern and legacy API support. Solo hosts, party leaders and raid leaders/assistants can invite; party-to-raid conversion requires the leader. Conversion begins only after five actual members join; queued invites wait for native raid confirmation. Pending invitations reserve capacity, requests expire after 60 seconds, duplicate keywords have a 30-second cooldown, and sends are paced to one per second. Pending reservations expire after 45 seconds. Disabling or changing settings clears queued requests. Automation pauses in combat and is blocked during loot/assignment practice. Unknown guild/group data fails closed. Failed conversion is shown locally and does not repeatedly retry; toggle auto-convert or convert manually. Players whispering the keyword do not need NRT. Native Forever invite/conversion behaviour still needs an in-game check.

SOURCE UPDATE - TANK CANDIDATE ROLE FILTER (included in alpha.104)
Tank dropdowns offer Warriors, Paladins and Druids regardless of native group-role flags. A Damage flag no longer hides a tank-capable character or blocks the host from accepting that assignment. Healer and spell-provider filters remain in place. Candidates use native group class data and do not need NRT installed to appear in the list.

SOURCE UPDATE - DIRECT ASSIGNMENT EDITOR SHORTCUT (included in alpha.104)
The personal tracker shortcut is labelled Assignments and opens the current raid assignment editor directly, preserving local Test Raid versus live context and the selected raid/boss section. It does not open general settings or require choosing the raid again. The tracker stays open and existing editor permissions remain unchanged.

SOURCE UPDATE - ASSIGNED BUFF REMINDERS (included in alpha.104)
All six assignable buff families are monitored out of combat: Power Word: Fortitude, Mark of the Wild, Arcane Intellect, Blessing of Kings, Blessing of Might and Blessing of Wisdom. A compact Assigned Buffs window appears for confirmed missing buffs, or buffs with under a minute remaining when expiry warnings are enabled. It uses your shared whole-raid buff assignments and selected groups, not the optional Raid Check requirements. Rank and Greater variants use Raid Check's existing recognition. Intellect/Wisdom apply to mana classes; Might to Warriors/Rogues/Hunters. Buff recipients do not need NRT.
Settings > Raid Tools > Assigned Buff Reminders provides personal enable and expiry-warning switches, both initially on. Unassigned players get no prompts. Backups are prompted only when the primary is absent, explicitly offline or dead. Offline/dead recipients are skipped; out-of-range, restricted or unknown aura/subgroup data is not called missing. Unknown checks are counted alongside confirmed reminders. Reminders hide on entering combat, do not query auras in combat, and refresh immediately after combat, then every second while out of combat. Aura, roster and resurrection-related events trigger a fresh check. Closing X dismisses an unchanged list until it changes or combat ends. The list clears once recipients are buffed. The window is movable and scrolls for larger lists; it emits no chat, addon broadcasts or automatic spell casts. Loot and assignment practice do not act on live buff reminders. Native Forever reminder behaviour still needs in-game testing.

SOURCE UPDATE - PERSONAL TRACKER SECTION HEADINGS (included in alpha.105)
My Assignments removes the shaded bars behind raid/boss headings and uses larger, heavier gold text with a small gap between sections. Assignment rows keep their subtle alternating backgrounds. Reused rows reset their text style when changing section or scope.

SOURCE UPDATE - ASSIGNMENT LABEL CAPITALISATION (included in alpha.105)
Assignment views consistently use Whole Raid, All Assignments, Main Tank, Off-Tank, Tank Healer, Group Healer, Raid Healer, No Backup, Preview Announcement and title-cased management buttons. Built-in legacy saved job labels are formatted for display without changing stored slot identifiers or custom boss/job names.

SOURCE UPDATE - RAID-WIDE ASSIGNMENTS LABEL (included in alpha.105)
Assignment scope headings and dropdowns use Raid-Wide Assignments instead of Whole Raid. All Assignments still combines the raid-wide defaults and all boss sections. Coverage controls retain Whole Raid where it means every raid group, rather than an assignment scope. Stored scope IDs and existing plans are unchanged.

SOURCE UPDATE - SHARED ASSIGNMENT TEST RAID (included in alpha.106)
Choosing Test Raid while in a party or raid starts a shared test hosted by the actual group leader. It uses the ten Molten Core boss names and real group members; fictional recipients are cleared from the shared template. Assign real players through the normal class-filtered dropdowns. Members automatically receive the plan, including if a local rehearsal was open, and /nrt > My Assignments shows their duties without a separate join step. Out-of-combat buff reminders work against real party/raid members during this test. Auto Invite is paused and manual assignment announcements remain local previews.
The host's prior assignment plan is kept separately; test edits do not write over saved assignments or profiles. End Test restores and republishes the prior plan. Only the group leader can end the test, outside combat. Loading a normal saved plan also exits the test. A host reload restores the saved normal plan using a fresh persisted epoch, and ownership changes retire the previous leader's test. Stale test packets cannot replace the restored normal plan. Profile/template saves are blocked while a shared test is active. Solo Test Raid still uses fictional players and stays local.
Assignment feature messages now use version seven; all group testers need the new build. LC/SR protocol stays 19. Transport checks cover party and raid sharing, actual member duties and buff reminders, local-view adoption, late sync, end/restore, reload, stale messages and leadership changes. Native Forever testing is still required.

SOURCE UPDATE - RAID-WIDE DEFAULTS WITHOUT PRE-FILLED BOSS OVERRIDES (included in alpha.106)
Fresh Test Raid plans leave every boss on raid-wide defaults. Removed the sample boss-specific tank, interrupt, CC, cleanup and backup overrides, including empty rows that could mask a real raid-wide assignment when shared. Tranq samples and cleanup backups now live at raid-wide scope. Tanks, linked healers, interrupts, banishes, sheeps, tranqs, dispels and decurses therefore carry into all ten bosses until explicitly changed for one boss. A later raid-wide edit updates every inheriting boss while preserving deliberate overrides. Existing normal saved plans and intentional boss overrides are not reset. Buffing stays raid-wide only as requested. New checks exercise all categories across ten bosses, tank/healer links and shared-party propagation.

SOURCE UPDATE - HEALER CLASS ELIGIBILITY (not packaged yet)
Healer dropdowns now include all Paladins, Druids, Shamans and Priests, regardless of current spec, native group-role flags or existing tank duties. The same rule applies to local practice, shared plans and host-side edit validation. Other classes remain excluded, and class data is rechecked when a dropdown selection is applied. Tank and spell-provider class filters remain unchanged.

SOURCE UPDATE - COMPACT CLICK-TO-BUFF REMINDER (not packaged yet)
Assigned Buffs now uses a smaller 300-wide window with only spell headings and class-coloured full character names underneath. The Missing column, summary and footer are removed. Expiring buffs retain a small inline (<1m) marker. Longer lists scroll.
When supported by the client, left-clicking a visible name casts the corresponding normal single-target buff by its localized spell name (the game selects the highest learned rank). This uses a native secure click action and an explicit nocombat/help/nodead condition; the addon never executes a cast while scanning. Mana, spell availability, cooldown and cast-range restrictions still apply. Native Forever click execution must be verified in game.
Protected click actions live under a separate secure UI root, with absolute positions updated only out of combat. They are not parented or anchored to ordinary NRT windows. A native combat visibility driver hides them, while normal reminder chrome remains unprotected. Overlays follow window movement, scroll clipping and layering. Identity and assignment-version checks prevent stale raid slots or old plans from remaining castable. Missing secure API support leaves the readable reminder without click actions. Slot bindings are rebuilt after combat and after list/assignment changes.
Forever secure action source reference: https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua

Included in alpha.107: Loot, Response item rail and Voting item rail now use the shared scrollbar and mouse wheel instead of page arrows/counters. Selected items are brought into view without resetting manual scrolling on refresh. Shared SoftRes Loot uses the same scrolling list. Assignment player menus and selected values use class colours, including the player while solo.

Included in alpha.107: Removed Previous/Next item buttons from Responses and Voting; select items directly in their scrolling lists. Voting footer selection and history controls use the freed space. Player-list paging remains available for large council candidate lists.
