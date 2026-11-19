# Alpha.78 testing checklist

## Verified automatically

- All 27 suites passed against the current source.
- Final ZIP verified: 72 files, two matching addon folders/TOCs and protocol 19.
- Extracted ZIP passed initialization, solo/group council test commands and all SoftRes suites.
- SoftRes integration includes a 20-player overview, offline/missing filters, native item-loading refresh, dropdown selection, reserve caps, draft retention, staged award controls and separate item copies.

## Confirmed by tester on alpha.77

- Content selection and reservation submission.
- Valid rolls appear with SR priority and the expected winner.
- Winner confirmation records an award and consumes one reservation.

## Alpha.78 visual review

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
