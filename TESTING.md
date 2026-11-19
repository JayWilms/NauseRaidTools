# Alpha.80 testing checklist

## Verified automatically

- All 28 suites passed against the current source.
- Final ZIP verified: 74 files, two matching addon folders/TOCs and protocol 19.
- Extracted ZIP passed initialization, solo/group council test commands and all SoftRes suites.
- SoftRes integration includes a 20-player overview, offline/missing filters, native item-loading refresh, dropdown selection, reserve caps, draft retention, staged award controls and separate item copies.

## Confirmed by tester on alpha.77

- Content selection and reservation submission.
- Valid rolls appear with SR priority and the expected winner.
- Winner confirmation records an award and consumes one reservation.

## Alpha.80 visual review

- [ ] Review Overview, Reservations, Rolls and Awards at normal UI scale.
- [ ] Check long player/item/content names, six slots, tooltips and scrollbar reach.
- [ ] Check All / Missing / Submitted / Offline totals and filters.
- [ ] Switch tabs with unsaved picks; confirm the draft remains and is not submitted automatically.
- [ ] Check the primary action during rolling, ties, a closed result and after an award.
- [ ] Check correction controls remain available when expanded and delivery remains separate from awarding.

## Live multiplayer checks still required

- [ ] Two players reserve the same item. Confirm both rolls and the correct SR winner.
- [ ] Check stacked reserves, tied-player rerolls, MS/OS priority and invalid extra rolls.
- [ ] Trade a real eligible item. Check exact-copy offering and native delivery evidence.
- [ ] Collect two copies of the same item and verify separate awards and deliveries.
- [ ] Reload/reconnect during open and locked reservations and pending delivery.
- [ ] Resume the original SoftRes host's saved run; verify an interrupted roll is cancelled.
- [ ] Test council backup recovery separately; it cannot run during SoftRes.
- [ ] Verify installed AtlasLoot Forever source coverage for intended raid content.

Historical detailed council tests remain in [docs/TESTING-alpha70.md](docs/TESTING-alpha70.md). They refer to the old Sanguine name and `/slt`; current commands use `/nrt`.

## Alpha.80 version check

- [ ] Open Settings > Advanced > Version Check as an ordinary raider and while solo.
- [ ] Outside a group, check that only the current character's installed addon versions appear.
- [ ] In a party or raid, compare NRT and SoftRes versions across current group members.
- [ ] Check mismatched versions, SoftRes disabled, offline peers and no reply.
- [ ] Verify guild members are not queried and raid management permissions stay unchanged.

Automated version tests cover these scopes, request throttling, stale and outsider replies, and separation from session authority. Everyone must update to alpha.79 to answer the new independent version query.

## Alpha.80 test modes

- [ ] Open Settings > Advanced > Test Modes and start/end each test using its button.
- [ ] Solo SoftRes: review 20 simulated players, reserve items, lock, queue duplicates separately, roll with MS/OS buttons, confirm awards and simulate delivery.
- [ ] Check SOLO TEST labels on overview, browser, results, awards, Loot and Timer.
- [ ] Exit and restart; confirm test results do not appear in real saved history.
- [ ] Confirm joining a group ends the solo SR test and the test buttons cannot replace live sessions.

Automated solo SoftRes checks cover 42 scenarios, including native side-effect isolation, saved-data preservation, command aliases, restart/group-join cleanup and both test buttons.
