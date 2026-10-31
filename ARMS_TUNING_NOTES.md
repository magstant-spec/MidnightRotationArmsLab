# MidnightRotationArmsLab Arms/Fury Tuning Notes

Originally created: 2026-09-07
Last reviewed: 2026-09-23

This file captures the current tuning/debugging state so work can resume after a reboot.

## Documentation Maintenance

- Update the tuning documentation after every work session that changes addon code, the TOC version, trace findings, validation results, or next steps.
- The latest detailed continuation is in `SESSION_HANDOFF_2026-09-19.md`; keep that handoff current until a newer dated handoff replaces it.
- Do not rely on an older "Current Addon State" section without checking `MidnightRotationArmsLab.toc` and the newest handoff file.
- Current verified TOC version at this review: `0.5.0-all-dps-specs` (2026-10-29; see the 0.5.0 section at the end). The 'Current Addon State' section below is historical.

## Current Addon State

Latest version in `MidnightRotationArmsLab.toc`:

```text
0.1.139-arms-opener-no-execute
```

Current manual target mode behavior:

- `/midrotlab st` forces single target mode.
- `/midrotlab aoe` forces AOE mode.
- No automatic target-count switching.
- The small label under the icon should only show `ST` or `AOE`.
- No target debug/status spam should print to chat during normal mode changes.

For boss testing, use:

```text
/midrotlab st
```

For trash/dungeon AOE testing, use:

```text
/midrotlab aoe
```

## Trace Commands

Clean trace workflow:

```text
/midrotlab trace stop
/midrotlab trace clear
/reload
/midrotlab st
/midrotlab trace start
```

After the test segment:

```text
/midrotlab trace stop
/reload
```

SavedVariables path seen during testing:

```text
C:\Games\World of Warcraft\_retail_\WTF\Account\250487950#3\SavedVariables\MidnightRotationArmsLab.lua
```

Trace data lives under:

```lua
MidnightRotationArmsLabDB.rotationTrace.entries
```

Trace now includes Heroic Strike / Master of Warfare debug fields:

- `mow`
- `mowProc`
- `mowStack`
- `hMight`
- `hsGlow`
- `hsCount`
- `hsCountOn`
- `hsOvGlow`
- `hsOvCount`
- `hsOvCountOn`
- `slamGlow`
- `slamCount`
- `slamCountOn`

## Important Trace Findings

Earlier trace, before `0.1.125`:

- `Heroic Strike` was cast 19 times.
- `Heroic Strike` was recommended 0 times.
- All Master of Warfare / Heroic Strike proc signal fields were false.
- Conclusion: the proc detector was blind.

Later trace, after `0.1.125`:

- Rolling buffer had 2000 entries.
- `Heroic Strike` was recommended 33 times.
- `Heroic Strike` was cast 24 times.
- This confirmed the direct spell usability path improved Heroic Strike recommendations.

Cooldown trace finding:

- Opener cooldowns were not delayed in the checked trace.
- `Avatar` recommended at about `8.63s`, cast at `9.33s`.
- `Colossus Smash` recommended at about `9.35s`, cast at `10.12s`.
- `Bladestorm` recommended at about `10.12s`, cast at `11.67s`.
- Later cooldowns were also being recommended, but tuning order still mattered.

## Recent Analyzer Symptoms

Fury reports were generally around 63-70% accuracy. Common issues:

- Bloodbath skipped while Bloodthirst was ready and Recklessness was present.
- Rampage skipped when usable.
- Execute skipped when Sudden Death or execute range was active.
- Crushing Blow/Raging Blow related issues.

Arms reports were the active focus. Common issues:

- Heroic Strike skipped when Master of Warfare was present.
- Heroic Strike skipped below 35% HP with Master of Warfare.
- Mortal Strike skipped when target was not/below 35% HP.
- Mortal Strike skipped with 2 Executioner's Precision stacks below 35%.
- Execute skipped when Execute was usable or Sudden Death was active.
- Overpower skipped with 2 Opportunist stacks.

Latest user-provided Arms issues before this note:

- `Mortal Strike` skipped: 21% of mistakes.
- `Execute` skipped when usable or Sudden Death active: 13% of mistakes.
- `Heroic Strike` skipped when Master of Warfare was present.
- Example shape: addon recommended/cast `Overpower` or `Slam` when WowAnalyzer expected `Execute`. Exact timestamps were not important.

## Version History From This Session

### 0.1.118 manual target mode

- Removed automatic ST/AOE switching.
- Added manual `/midrotlab st`, `/midrotlab aoe`, and `/midrotlab targets ...`.
- Mode label changed to only `ST` or `AOE`.

### 0.1.119 arms combat opener

- Added an Arms combat opener window.
- During first few seconds of combat, Arms can force:
  - Avatar
  - Colossus Smash / Warbreaker
  - Bladestorm when Colossus Smash is up

### 0.1.120 / 0.1.121 Heroic Strike and cooldown lift work

- Added Heroic Strike spell handling.
- Added Heroic Strike display/keybind mapping where needed.
- Added Arms cooldown helper for Avatar / Colossus Smash or Warbreaker / Bladestorm.
- Lifted cooldown recommendations so they were not buried too deeply after the opener.

### 0.1.122 arms Colossus AOE Bladestorm

- Added Bladestorm recommendation to Colossus AOE after Colossus Smash/Warbreaker.

### 0.1.123 arms ST cooldown priority

- Moved major cooldowns earlier in ST Arms.
- This helped cooldown visibility but risked making Mortal Strike look skipped to WowAnalyzer.

### 0.1.124 arms trace HS signals

- Added trace output for Master of Warfare / Heroic Strike signal debugging.

### 0.1.125 arms strict HS usable

- Changed Heroic Strike logic so the real Heroic Strike spell can be recommended when WoW reports it usable.
- Removed the hard dependency on our Master of Warfare signal for the real Heroic Strike spell.
- Kept the Slam fallback behind the proc-signal gate.

### 0.1.126 arms MS/HS tighten

- Moved ST cooldown recommendations back below routine Mortal Strike and Sudden Death Execute.
- Added Master of Warfare aura-name detection.
- Broadened Heroic Strike range checks by allowing Slam/Mortal Strike range fallback.

### 0.1.127 arms execute trust

- Arms now trusts WoW's direct Execute usability result.
- Fury keeps the stricter guard because raw Execute usability can over-report outside real Fury Execute windows.
- ST Arms now checks Sudden Death Execute before 2-stack Opportunist Overpower.

### 0.1.128 macro keybind priority

- Macro spell bindings now beat plain direct spell bindings.
- This was added because Avatar can be inside a cooldown macro with other non-GCD spells.
- Expected behavior: if the addon recommends `Avatar`, it should show the keybind for the macro that casts Avatar, not the text `AVATAR`.
- If it still fails, use:

```text
/midrotlab binddump Avatar
```

That should print whether the addon sees the macro body and which keybind it found.

### 0.1.129 arms ST execute fallback

- Added a generic Arms `Execute` fallback in the active ST paths after `Mortal Strike`.
- This targets cases where WoW reports Execute usable, but the specific Sudden Death detector was not confident enough.
- Expected improvement: fewer `Overpower` or `Slam` recommendations when WowAnalyzer expects `Execute`.

### 0.1.130 arms AOE execute sanity

- Aligned AOE paths with the ST Execute fallback behavior.
- Slayer AOE now checks generic usable `Execute` before plain `Overpower`.
- Colossus AOE now checks capped Sudden Death and generic usable `Execute` before plain `Overpower`/`Slam`.


### 0.1.131 arms ST Cleave start

- Added a ST-only Cleave setup check to the active Arms combat opener before Avatar/Colossus cooldown recommendations.
- This lets `Cleave` apply/refresh Rend at the start of ST combat when Cleave is talented and Rend is missing/expiring.
- Updated Colossus ST refresh points to prefer the Cleave refresh helper before falling back to standalone `Rend`.
### 0.1.132 arms Slayer Executioner opener

- Added a Slayer-only `Executioner` priority check: at 4+ stacks, recommend `Execute` when it is actually usable.
- The active ST combat opener checks this before entering Bladestorm, so high `Executioner` stacks are not ignored before a Bladestorm window.
- Active Slayer ST also checks this before regular `Mortal Strike`.
- This does not switch the rotation into the full execute-phase path; it is a local priority override only.
### 0.1.133 arms Slayer pre-Bladestorm Execute

- Tightened the active ST combat opener so Slayer checks Execute before opener Bladestorm when there is a capped Sudden Death proc, 4+ Executioner stacks, or a valid pre-Bladestorm Execute setup with fewer than 3 Imminent Demise stacks.
- This fixes the case where an Execute proc could be visible during the opener but Bladestorm still won the recommendation.
- Scope remains ST opener only; AOE and Colossus priorities were not changed.
### 0.1.134 arms Slayer MS before Execute

- Lowered normal Slayer `Execute` priority relative to `Mortal Strike` in active ST.
- Capped Sudden Death can still win before `Mortal Strike`; regular Sudden Death, generic usable `Execute`, and 4+ `Executioner` now sit after ready `Mortal Strike` in the ST path.
- The ST opener still protects capped Sudden Death before Bladestorm, but non-capped Executioner/pre-Bladestorm Execute checks no longer beat a ready `Mortal Strike`.
### 0.1.135 arms Slayer MS/Rend uptime

- Raised active Slayer ST `Mortal Strike` priority to directly address low MS cast count compared with the reference log.
- Added `Mortal Strike` to the ST combat opener before Cleave/cooldown setup, while capped Sudden Death can still override it.
- Moved Cleave/Rend refresh at less than 5 seconds above Heroic Strike, normal Sudden Death, Executioner, cooldowns, and generic Execute.
- Left capped Sudden Death above Mortal Strike; normal Execute and generic Execute should no longer starve MS or Rend maintenance.
- Scope remains Slayer ST/opener only; AOE and Colossus priorities were not changed.
### 0.1.136 arms Slayer execute SD range

- Raised `Sudden Death` Execute inside the active Slayer execute-phase path to address analyzer reports about skipped Execute below 35% HP with Sudden Death active.
- Capped Sudden Death now wins first in execute range.
- `Mortal Strike` with 2 `Executioner's Precision` remains above normal Sudden Death Execute.
- Normal Sudden Death Execute now beats Heroic Strike and Opportunist Overpower in execute range.
- Scope is Slayer execute-phase only; normal ST, AOE, and Colossus were not changed.
### 0.1.137 arms Slayer Opportunist bump

- ST Slayer only: raised 2-stack Opportunist Overpower to immediately after Mortal Strike.
- Capped Sudden Death Execute still wins before Mortal Strike.
- Cleave/Rend upkeep, Heroic Strike, execute-phase ordering, AOE, and Colossus were not changed.
### 0.1.138 arms opener Cleave/CS/Avatar/Execute

- ST combat opener test order changed to: Cleave setup, Colossus Smash/Warbreaker, Avatar, Execute if usable, then Bladestorm.
- Removed the opener-only early Mortal Strike and capped Sudden Death shortcuts from the ST opener window for this test.
- AOE opener fallback remains Avatar, Colossus Smash/Warbreaker, then Bladestorm.
### 0.1.139 arms opener no Execute

- Removed the ST opener Execute step from the previous test order.
- ST combat opener is now Cleave setup, Colossus Smash/Warbreaker, Avatar, then Bladestorm if the Colossus window is up.
- Normal ST and execute-phase Execute handling outside the opener window were not changed.
## Current Arms ST Priority Shape

The intended current Slayer ST shape is approximately:

1. Capped Sudden Death Execute.
2. Mortal Strike.
3. Opportunist Overpower with 2 stacks.
4. Cleave/Rend refresh under 5 seconds.
5. Heroic Strike when actually usable.
6. Execute with 4+ Executioner stacks or normal Sudden Death.
7. Major cooldown package:
   - Avatar
   - Colossus Smash / Warbreaker
   - Bladestorm while Colossus Smash is active
8. Execute setup / Bladestorm special cases.
9. Overpower.
10. Cleave/Rend fallback refresh under 10 seconds.
11. Execute when WoW reports it directly usable.
12. Slam filler.

Execute phase paths still prioritize:

1. Capped Sudden Death Execute.
2. Mortal Strike with 2 Executioner's Precision.
3. Normal Sudden Death Execute.
4. Heroic Strike when actually usable.
5. Opportunist Overpower with 2 stacks.
6. Execute at 40+ rage.
7. Cooldowns.
8. Overpower / Mortal Strike / Execute fallback / Slam.

## Files Touched

Main files:

- `MidnightRotationArmsLab/Engine.lua`
- `MidnightRotationArmsLab/Core.lua`
- `MidnightRotationArmsLab/MidnightRotationArmsLab.toc`

Notes file:

- `MidnightRotationArmsLab/ARMS_TUNING_NOTES.md`

## Validation Notes

Lua syntax validation was not run because `lua` is not installed in the PowerShell environment:

```text
lua : The term 'lua' is not recognized as the name of a cmdlet, function, script file, or operable program.
```

The edited sections were checked by reading the relevant Lua function bodies after patching.

## Next Things To Check

After the next boss ST test:

- Confirm whether `Heroic Strike` recommendations increased further.
- Check if the `Heroic Strike when Master of Warfare present` analyzer complaint drops.
- Check if the `Execute usable / Sudden Death active` analyzer complaint drops after `0.1.127`.
- Watch whether Mortal Strike complaints rise or fall after moving cooldowns below MS again.
- If Execute is still skipped for Slam/Overpower, inspect trace rows where recommendation is `Slam` or `Overpower` and fields show:
  - `sdUp = true`
  - `ready.execute = true`
  - `executePhase = true`

If those rows exist, the Execute branch is still ordered or gated incorrectly.

### 0.1.140 arms Wowhead priority cleanup

- ST combat opener now follows the current Wowhead order more closely: Rend/Cleave setup when Colossus is ready, Avatar, Colossus Smash/Warbreaker, capped Sudden Death Execute, pre-Bladestorm Execute, then Bladestorm during Colossus.
- Colossus ST was reordered around the current Wowhead Colossus list: Mortal Strike for Colossal Might, Rend refresh before Colossus, Ravager, Avatar, Colossus, Demolish during Colossus, Heroic Strike, capped Sudden Death, Mortal Strike, normal Sudden Death, Overpower, late Rend refresh, Slam.
- Colossus execute was aligned to Ravager/Avatar/Colossus first, then Heroic Strike, Demolish, Mortal Strike, Execute at Sudden Death or 75+ rage, Overpower, Deep Wounds Execute, Slam.
- Arms execute branches now also activate when target health is hidden but Execute is strictly usable, reducing missed execute-phase behavior under Midnight secret-health rules.
- TOC version bumped to `0.1.140-arms-wowhead-priority` and `120500` added to Interface compatibility.

### 0.1.141 arms Slayer Bladestorm lift

- Fixed Slayer Arms holding Bladestorm too long by moving the Bladestorm-during-Colossus check above Mortal Strike, generic Execute, Overpower, and late filler in Slayer ST/execute paths.
- Changed pre-Bladestorm Execute checks so they require a real Arms proc reason: Sudden Death or 4+ Slayer Executioner stacks. This prevents generic Execute usability from repeatedly blocking Bladestorm while it is ready.
- Cooldown helper calls in Slayer ST/execute now pass `includeBladestorm=false` so Bladestorm placement is controlled explicitly in those priority lists.

## 0.1.142 fury Wowhead priority cleanup
- Fury Slayer now starts Recklessness/Avatar before spending Bladestorm, then performs the intended Rampage prep into Bladestorm during the cooldown window.
- Fury Slayer Bladestorm can still fire outside active cooldowns when Recklessness/Avatar are not ready soon, preventing long idle holds.
- Fury Mountain Thane now spends high-priority Thunder Blast before Bloodbath in cooldown windows, and its AoE cooldown ordering better matches the Midnight guide shape.

## 0.1.143 cooldown macro toggle
- `/midrotlab cooldowns` now toggles major cooldown recommendations on/off for a one-button macro.
- `/midrotlab cooldowns on`, `/midrotlab cooldowns off`, and `/midrotlab cooldowns toggle` are also supported.

## 0.1.144 fury Slayer priority order
- Fury Slayer ST cooldowns now follow the Wowhead order more closely after Bladestorm: Sudden Death Execute, Rampage, Crushing Blow, Odyn's Fury, Execute, then Bloodbath/fillers.
- Fury Slayer AoE cooldowns now puts Sudden Death Execute and Odyn's Fury ahead of generic Rampage after Bladestorm, matching the listed cooldown priority more closely.
- Retained the existing Bladestorm sync guard so it can wait briefly for Recklessness/Avatar without being held indefinitely.

## 0.1.145 safety fixes
- Aura remaining time and stack reads now fall back to zero if Midnight returns a protected value.
- The major cooldown toggle now also gates Bladestorm and burst-window Recklessness/Avatar suggestions.
- Target debuff tracking no longer accepts an unrestricted spell-ID match or a name match without a verified player/pet/vehicle source.
- Fury Slayer's Execute phase now uses 35% health only with Massacre; otherwise it uses 20%. Execute priority was not changed. Use `/midrotlab dump` while Execute appears stuck to inspect Sudden Death, Execute usability, execute phase, and target health signals.

## 0.1.146 Fury Execute proc detection
- A Fury Slayer dump showed `HP=?`, `ExecuteUsable=yes`, `SD=no`, and `SDGlow=no` while the action button visibly glowed. With hidden health, that missed proc signal prevented Execute recommendations.
- Sudden Death now checks whether its aura exists without requiring a readable expiration time.
- Fury Execute proc detection also checks overlay, action count, and button glow for spell IDs 280735 and 280849, which appear in local Fury Execute cast traces.
- `/midrotlab dump` now includes `SDOverlayFury` for follow-up diagnosis.

## 0.1.147 overlay API
- A follow-up Fury Slayer dump still showed `SD=no`, `SDGlow=no`, and `SDOverlayFury=no` while the action bar button glowed.
- The installed EllesmereUI Action Bars renders proc glows using `C_SpellActivationOverlay.IsSpellOverlayed`, while ArmsLab used the older global `IsSpellOverlayed`. ArmsLab now checks the same API first and falls back to the global function.

## 0.1.148 Ellesmere action bar integration
- The shared action bar scan now indexes occupied Ellesmere action slots for spell IDs and proc counts, without reading protected button action fields in combat.
- The shared button glow helper now checks `C_SpellActivationOverlay.IsSpellOverlayed`, matching Ellesmere's custom glow source. This reaches Arms, Fury, and Retribution proc checks; Beast Mastery already uses the shared overlay helper.
- Ellesmere's custom Bars 9 and 10 now contribute their saved spell and item keybinds to ArmsLab's display.

## 0.1.158 Fury Mountain Thane ST filler

- A 101-second ST trace recorded ten in-combat `none` recommendations while Whirlwind was the only usable tracked action.
- Added Whirlwind as the final Mountain Thane ST fallback in both normal and cooldown-window priority lists.
- The same trace validated Odyn's Fury ST placement: it was recommended 17 times and only yielded while ready to pre-combat Charge or a high/expiring-enrage Rampage.

## 0.1.159 Fury Mountain Thane Whirlwind reference fix

- A follow-up trace still produced six in-combat `none` gaps with only Whirlwind ready.
- Fixed the `0.1.158` fallback to use `state.spell.whirlwind`; the previous undefined `WHIRLWIND_SPELL_ID` reference always resolved to nil.
- Validated with a 59-second ST trace: Whirlwind appeared in the filler slot and no `none` recommendation had a usable tracked action. Two initial `none` samples had an empty ready set and were not rotation stalls.

## 0.1.159 Arms Slayer ST validation

- A 395-second trace produced 603 ST recommendations with strong Mortal Strike, Execute, Cleave, Heroic Strike, and Overpower coverage.
- Rend maintenance was healthy: Cleave dominated recommendations at five seconds or less, and both active zero-Rend samples recommended Cleave.
- Confirmed Sudden Death and Master of Warfare signals produced the intended Execute and Heroic Strike behavior while still yielding to deliberate higher priorities.
- Bladestorm-only `none` samples occurred outside Colossus Smash and matched the intentional cooldown hold. No code change was needed.

## 0.1.159 Arms Slayer five-target AoE validation

- A 139-second trace held AoE mode at five targets for all 165 recommendations.
- The opener correctly used Sweeping Strikes, Cleave/Rend setup, Avatar, Colossus Smash, and Bladestorm.
- Sustained priority was Execute-heavy because Execute remained usable on the low-health targets; Cleave remained the other dominant recommendation.
- Every `none` sample had an empty ready set during target/dummy downtime. No code change was needed.

## 0.1.160 Arms Slayer ST opening Mortal Strike

- The ST opener previously started with Cleave/Rend setup and omitted the guide's opening Mortal Strike.
- Added one Mortal Strike before Cleave/Rend, Avatar, Colossus Smash, proc Execute, and Bladestorm.
- A per-combat cast flag prevents Mortal Strike from being repeatedly forced during the eight-second opener helper.
- Pull potions remain controlled by burst mode. Current guide advice is to save the combat potion for Execute unless the encounter is long enough for two uses; on-pull potion use is appropriate when Bloodlust or encounter timing makes the pull the chosen potion window.

## 0.1.161 Fury Slayer AoE Odyn's Fury priority

- A five-target trace showed Odyn's Fury continuously ready but never recommended.
- The global Whirlwind cleave-refresh check was pre-empting the complete AoE list.
- Moved Whirlwind maintenance below the post-Bladestorm Sudden Death and Odyn's Fury slots in both cooldown and normal AoE branches.
- Validated in a follow-up five-target trace: Odyn's Fury was recommended four times, Whirlwind maintenance remained active, and no `none` sample had a usable tracked action.
- A separate 111-recommendation ST trace validated sustained ordering: Rampage/Enrage, Bladestorm, Odyn's Fury, Execute, and core fillers behaved normally. The trace started mid-combat and therefore did not validate the initial opener.

## 0.1.165 Arms Slayer ST analyzer priority

- Reordered the Slayer execute-range ST branch to match the supplied single-target analyzer: Heroic Strike; Mortal Strike at 2 Executioner's Precision; Overpower at 2 Opportunist; Sudden Death Execute; Execute at 40+ rage; then Overpower.
- In normal ST, moved 2-stack Opportunist Overpower ahead of Mortal Strike, matching the analyzer's general priority.
- Moved Avatar/Colossus Smash and Bladestorm below those execute-range rotational checks so cooldown recommendations do not repeatedly displace the analyzer's core actions.
- Moved the ordinary Mortal Strike fallback above ordinary Execute, matching the general ST portion of the analyzer list.
- Scope is Arms Slayer single target only. Arms AoE and Arms Colossus priorities were not changed.
- This change requires an in-game reload and a fresh ST log/trace for validation.

## 0.1.166 Cast-confirmed recommendations and Cleave-only Rend handling

- Spell recommendations are now latched rotation-wide: once shown, the recommendation remains displayed until `UNIT_SPELLCAST_SUCCEEDED` confirms that the player cast the matching spell.
- After the matching successful cast, the latch clears and the rotation recalculates immediately. Unrelated spellcasts do not advance the recommendation.
- The latch clears on target changes, combat start/end, specialization changes, spellbook changes, and talent changes to prevent stale recommendations across major state transitions.
- Item and potion recommendations remain dynamic because they do not reliably provide the same spell-success event.
- Removed all direct Rend returns from Arms rotation helpers. When a priority asks to apply or refresh Rend, the addon now recommends Cleave only; if Cleave is unavailable, that maintenance helper yields no recommendation and the rotation continues.
- Requires `/reload` and live validation across the supported rotations.

## 0.1.167 Restore live recommendations

- Removed the rotation-wide hold-until-cast latch from `0.1.166` at user request.
- Recommendations once again recalculate live at 20 Hz and may change before the displayed spell is cast.
- Preserved the Cleave-only Rend maintenance rule introduced alongside the latch.
- Preserved the Arms Slayer ST analyzer priority changes from `0.1.165`.

## 0.1.168 Arms Slayer ST core priority and hidden-state signals

- Raised normal-ST Heroic Strike, 2-stack Opportunist Overpower, Mortal Strike, and directly usable Execute above Cleave maintenance, cooldown setup, and Bladestorm special cases.
- A visible Opportunist proc/overlay can now satisfy the 2-stack priority when Midnight does not expose a readable aura stack count.
- Arms Execute-at-rage now trusts strict spell usability when rage is protected. The previous helper rejected the 40-rage priority whenever `rageKnown` was false, even if WoW reported Execute usable.
- Execute-range ordering remains Heroic Strike, 2-stack Executioner's Precision Mortal Strike, 2-stack Opportunist Overpower, Sudden Death Execute, 40+ rage Execute, then Overpower.
- Scope is Arms Slayer ST. Cleave remains the exclusive replacement for Rend recommendations.

## 0.1.169 Arms Executioner's Precision tracking

- The execute-range priority already placed Mortal Strike immediately after Heroic Strike at 2 Executioner's Precision stacks; the remaining analyzer complaint therefore indicated missed stack detection.
- Executioner's Precision now combines aura ID `386633`, an aura-name lookup, and a local successful-cast tracker.
- Each successful Arms Execute increments the assumed stack count to a maximum of two for 30 seconds. A successful Mortal Strike clears it because Mortal Strike consumes the buff.
- Recommendation traces now persist the detected/assumed count in the `ep` field for direct validation after the next ST test.
- Arms Slayer execute-range priority remains unchanged: Heroic Strike can still precede the 2-stack Mortal Strike, matching the supplied analyzer list.

## 0.1.170 Arms Slayer ST Bladestorm release

- A five-minute ST trace contained 282 recommendation samples with Bladestorm ready, but only three Bladestorm recommendations and four actual channel clusters. SimC averaged about 9.7 uses over five minutes.
- Added the broader SimC release conditions to both Slayer ST paths: recommend Bladestorm when Colossus Smash is active, Avatar is active, Colossus Smash is more than 25 seconds away, or Executioner's Precision is capped at two stacks.
- Two-stack Executioner's Precision Mortal Strike remains above Bladestorm. If Mortal Strike is ready, it consumes the capped buff first; the EP condition releases Bladestorm only when that Mortal Strike cannot currently be used.
- Removed the older later checks that allowed Bladestorm only during a detected Colossus Smash window.
- Scope is Arms Slayer single target. AOE and Arms Colossus were not changed.

## 0.1.171 Arms Bladestorm utility

- Added Storm Bolt spell resolution and explicit Bladestorm aura-presence tracking.
- While Arms Slayer is channeling Bladestorm, recommend Storm Bolt first when usable, then Wrecking Throw when usable. This check runs before opener, ST, execute, and AOE priority branches.
- Added Wrecking Throw as a late fallback before Slam in both Slayer normal-ST and execute-range lists so it is used more often outside Bladestorm as well.
- Bladestorm detection checks the aura by name, resolved spell ID, and known Arms/base IDs without depending on a readable expiration time.

## 0.1.172 Arms Storm Bolt during Bladestorm

- Storm Bolt/Wrecking Throw channel utility now runs before Arms Slayer opener logic, so opener recommendations cannot displace Storm Bolt during Bladestorm.
- A successful Arms Bladestorm cast now supplies a six-second fallback active window when Midnight does not expose the Bladestorm aura reliably.
- Storm Bolt remains the first recommendation during Bladestorm; Wrecking Throw is used only when Storm Bolt is unavailable.

## 0.1.173 Half-second recommendation refresh

- Slowed the main recommendation ticker from 0.05 seconds (20 Hz) to 0.50 seconds (2 Hz).
- The separate action-bar scan remains at its existing one-second interval.

## 0.1.174 Arms opener Cleave persistence

- A clean trace showed the first opener skipping Cleave while Rend was missing: Cleave was briefly unavailable during the opening GCD, Avatar and Colossus Smash advanced, and the old Colossus-ready requirement then prevented opener Cleave from returning.
- Removed the Colossus-ready requirement from the eight-second opener Cleave setup.
- Cleave now remains eligible throughout the opener whenever Rend is missing or within the ten-second setup threshold, including after Avatar or Colossus Smash has already fired.

## 0.1.175 Arms raid cadence

- Adjusted the main recommendation ticker from 0.50 seconds to 0.25 seconds. This retains more visual stability than the former 0.05-second ticker while responding faster to Mortal Strike, Execute, and proc windows.
- Delayed routine Arms Slayer normal-ST Cleave/Rend maintenance from five seconds remaining to two seconds remaining.
- Opener Cleave and the deliberate pre-Colossus setup refresh remain unchanged; only ordinary maintenance is later, reducing unnecessary early Cleave refreshes while preserving Rend uptime.

## 0.1.176 Arms Mortal Strike priority

- Moved ready Mortal Strike above two-stack Opportunist Overpower in normal Arms Slayer ST.
- Added ready Mortal Strike above Opportunist Overpower in the Arms Slayer execute-range list. Heroic Strike remains first, and the existing two-stack Executioner's Precision Mortal Strike check remains protected.
- Removed the now-redundant late execute-range Mortal Strike slot.
- This intentionally favors more Mortal Strike casts and fewer Overpower casts for comparison with the current top Vashnik damage profile.

## 0.1.177 Arms Cleave efficiency

- The supplied Mythic Vashnik log recorded 47 Cleaves in about 406 seconds (roughly 6.9 per minute) while Rend uptime was already 99.33%.
- Tightened the normal-ST pre-Colossus Cleave/Rend setup threshold from ten seconds remaining to five seconds.
- Routine maintenance still waits until two seconds, while opener Cleave still applies Rend promptly when missing. This should release additional globals for Mortal Strike without materially reducing Rend uptime.

## 0.1.178 Arms Vashnik opener

- Reconstructed the opening cast sequence from the saved Warcraft Logs timeline for Mythic Vashnik source 418: Charge, Cleave, Liquid Luster, Colossus Smash, Avatar/Voracious Heart, conditional Execute, Bladestorm, then Storm Bolt during Bladestorm.
- Reconstructed the user's source 5 Mythic Vashnik opener for comparison: Avatar/Voracious Heart, Colossus Smash, Cleave, Execute, Mortal Strike, Overpower, Cleave, Overpower, Heroic Strike, Execute, Overpower, Mortal Strike, then Bladestorm. This placed eight intervening rotational casts between the first Execute and Bladestorm compared with source 418.
- Removed the forced opening Mortal Strike from Slayer single target.
- Moved Colossus Smash ahead of Avatar after Cleave/Rend setup. The opener now recommends Cleave, Colossus Smash, Avatar, a usable proc/setup Execute, and Bladestorm.
- Trinket recommendations remain handled by the addon's existing item/burst system rather than being embedded in the spell opener.


## 0.4.1 Slayer priority, cleanup and Midnight API workarounds (2026-10-29)

Backups: `*.bak-v041-cleanup-reorder-20261029`.

Housekeeping
- TOC Interface now `120000,120001,120005,120007,120100,120105,120107` (live 12.1.5 = 120105, PTR 12.1.7 = 120107). Removed the invalid `120500`. Author set to Reece; Notes reflect the multi-spec scope.
- Removed 12 overridden duplicate definitions (RecommendArmsSlayer x3, RecommendArmsColossus x3, RecommendFurySlayer x2, RecommendFuryMountainThane x2, RecommendFuryOpener x2) plus 41 helpers only those copies used (old Arms Method/Live paths, old Ret helpers, Twin Fangs, etc.). Engine.lua 8,169 -> ~6,760 lines. Live behaviour of those specs is unchanged because Lua only kept the last definition.
- Removed the dead COMBAT_LOG_EVENT_UNFILTERED handler and RecordRecentDamageTarget (12.x blocks CLEU). The recent-damage target count is now documented as always 0.

Arms Slayer priorities (Method Midnight 12.1.5)
- Normal ST: Cleave at <=2s Rend > Avatar > Colossus Smash/Warbreaker > Execute (2 SD or 4 Executioner) > Heroic Strike > Mortal Strike > Bladestorm (release rules) > Execute (1 SD / usable) > 2-stack Opportunist Overpower > pre-Colossus Cleave at 5s > Overpower > Wrecking Throw > Slam.
- Execute range: Cleave at <=2s > Heroic Strike > Avatar > Colossus Smash > Execute (2 SD or 4 Executioner) > Mortal Strike at 2 Executioner's Precision > Bladestorm > Execute (1 SD or 40+ rage) > Overpower > any usable Execute > Mortal Strike (late filler) > Wrecking Throw > Slam. Plain Mortal Strike no longer beats Execute in execute range (reverts 0.1.176 there).
- ARMS_COOLDOWN_SYNC_WINDOW 10s -> 3s, because Avatar can now see estimated Colossus cooldowns in combat.
- Opener, AoE and Colossus branches unchanged.

API workarounds
- Cast-based cooldown estimates: every successful player cast is timestamped (ID, base ID, name). When Midnight hides cooldown times but `isActive` is true, remaining = last cast + learned duration (read out of combat) or base cooldown, minimum 0.25s. Previously this returned math.huge, so "Colossus ready soon" and the ">25s away" Bladestorm release could never fire in combat.
- Real GCD: read from spell 61304 (never secret) instead of a fixed 1.5s.
- Rage band: when rage is hidden, C_Spell.IsSpellUsable's not-enough-resource flag across known rage spells gives `rage >= low` and `rage < high`. "Execute at 40+ rage" now returns false when a <=40 cost spell is short on rage (enables Overpower under 40 rage).
- C_AssistedCombat.GetNextCastSpell: recorded every tick; confirms a Sudden Death proc when target health is readable and outside execute range; fills in-combat `none` recommendations when usable (`/midrotlab assist on|off`, default on).
- SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE now tracked as an extra proc signal (15s staleness cap).

New trace fields: `bliz`, `blizMatch`, `blizFallback`, `blizSd`, `rageLo`, `rageHi`, `gcd`, `csCd`/`csCdEst`, `avatarCd`/`avatarCdEst`, `bsCd`/`bsCdEst`, `sdGlowEvt`. `/midrotlab dump` prints a second "API:" line with the same data (`~` marks an estimated cooldown).

Validation so far: syntax-checked; smoke-tested with stubbed WoW APIs (cooldown estimate, rage band, GCD, fallback, trace and dump all executed). Not yet tested in game.

Next check
1. `/reload`; confirm no Lua errors. If `bliz` is always nil, enable Assisted Highlight in Blizzard's combat options and retest.
2. Clean Arms Slayer ST trace: check Avatar/Colossus Smash are cast on cooldown, `csCdEst=true` values count down sensibly, `rageLo/rageHi` populate in combat, and execute-range Overpower appears when `rageHi <= 40`.
3. Run `/midrotlab dump` during a Sudden Death proc: compare SDGlowEvt, overlay and BlizSD.
4. Compare `blizMatch` rate as a rough sanity metric (Blizzard's list is simpler, so 100% is not the goal).


## 0.5.0 All DPS specs via data-driven SpecEngine (2026-10-29)

Backups: `*.bak-v050-all-dps-specs-20261029`.

Architecture
- New `SpecEngine.lua` plus one profile file per class in `Specs\` (DeathKnight, DemonHunter, Druid, Evoker, Hunter, Mage, Monk, Priest, Rogue, Shaman, Warlock). Loaded after Engine.lua.
- The hand-written engines still own Arms, Fury, Retribution, Beast Mastery, Frost DK and Subtlety. Every other DPS spec falls through to SpecEngine.
- Engine.lua exposes its helpers as `addon.EngineInternals`. It also calls SpecEngine from the state builders, GetRecommendationForState, GetProfileLabel, UNIT_SPELLCAST_SUCCEEDED, PLAYER_TARGET_CHANGED and PLAYER_REGEN_ENABLED.
- Spells are resolved by name (with override detection through C_Spell.GetOverrideSpell), not hard-coded IDs.
- Profile entry format: `{ "spellKey", when = function(s) ... end, hero = "...", talent = "...", aoe/cleave/st flags, note = "..." }`. Lists are `precombat`, `st`, `aoe` and optional `fallback`. Entries with `major = true` spells obey `/midrotlab cooldowns`.
- Signals available to conditions:
  - `s:ready()`, `s:cd()` (cast-estimated), `s:charges()` (out of combat only), `s:castCount()` (button counts)
  - `s:proc()` (aura, overlay glow or glow event), `s:buff()`/`s:dot()`/`s:refreshable()` (inferred from your casts per target GUID, pandemic-aware)
  - `s:counter()` (cast-counted stacks), `s:auraStacks()` (never-secret auras: Maelstrom Weapon, Tip of the Spear, Icicles)
  - `s:resource*()` (readable secondary power), `s:powerAtLeast()` (primary power or usability band), `s:hpBelow()`, `s:hero()`, `s:talent()`, `s:lastCast()`, `s:since()`
- Windwalker uses `comboStrikes = true`, which stops the same ability being recommended twice in a row.

Specs and sources (12.1.5 unless noted)
- Method: Havoc, Devourer, Balance, Feral, Devastation, Augmentation, Marksmanship, Survival, Arcane, Fire, Frost, Windwalker, Shadow, Assassination, Elemental, Enhancement, Affliction, Destruction.
- Icy Veins: Unholy (12.0.5), Outlaw (Season 1), Demonology (Season 1).

Known limits
- These lists start from the guides and have not been tuned in game. Expect per-spec tuning from traces, as was done for Arms.
- Hidden state, approximated:
  - Fire's Heating Up has no glow.
  - Arcane Salvo / Cumulative Power stacks use button counts if shown.
  - Unholy Lesser Ghouls and Demonology Wild Imps are counted from casts.
  - Outlaw Roll the Bones stage is unknown.
  - Most charge counts are hidden in combat.
- DoT timers only cover the current target; multi-dotting still needs manual target swaps.
- Devourer spec ID 1480 is unverified; the profile also matches by spec name "Devourer".

Debugging
- `/midrotlab dump` prints a "Spec:" line with the profile key and the exact priority entry that fired (`Why=st#7 putrefy`), plus any Lua error from a condition.
- Traces record `spec`, `specWhy` and `specErr`.

Next check
1. `/reload` on each class you play; confirm the profile label shows (for example "Shadow - Archon") and there are no Lua errors.
2. Run a short ST and AoE trace per spec, then tune the priority entries using `specWhy`.


## 0.5.1 Fury hidden-rage Rampage fix (2026-10-31)

- WoWAnalyzer (Fury Slayer ST, 55.6% accuracy) flagged two mistakes: skipped Rampage above 100 rage during Recklessness (57%) and skipped Rampage above 100 rage outside it (33%).
- Cause: rage is hidden in combat, and `ShouldFuryRampageAtHighRage` only had a slow fallback that needed 2 generators during Recklessness. Outside Recklessness it never fired.
- Fix: Rampage turns usable at exactly 80 rage. The addon now tracks when that happens (resource-only usability, so range does not reset it) and treats rage as 100+ once either of these is true:
  - one rage generator has been cast since then, or
  - Rampage has sat usable for 0.75s in Recklessness/Avatar, or 1.5s otherwise.
- Slayer ST order now matches the analyzer list:
  - Cooldown window: Enrage-missing Rampage now comes first.
  - Outside cooldowns: Enrage Rampage > capped Sudden Death > Crushing Blow > Rampage 100+ > Odyn's Fury > Execute > Raging Blow > Rampage > Bloodthirst.
- Mountain Thane also benefits, because it shares `ShouldFuryRampageHighOrExpiring`.
- New trace fields: `rampageUsableFor`, `rampageGenSinceUsable`.
- Next: rerun the same Fury Slayer ST log and compare the analyzer's accuracy and the two Rampage mistakes.


## 0.5.2-0.5.3 Rage probe and running rage estimate (2026-10-31)

Rage probe results on live 12.1.5 (Fury, 15s of combat):
- UnitPower and UnitPowerPercent for rage are hidden, even out of combat. Attack speed is hidden too.
- UNIT_POWER_FREQUENT still fires on every rage change (~3.5/s, power type readable). About 1/3 of those were not near a cast, so they are auto-attacks.
- Spell rage costs and the IsSpellUsable "not enough resource" flag stay readable in combat.
- GetSpellPowerCost reported 50 for Rampage; the user confirms Rampage costs 80. RageModel overrides it to 80.
- Assisted Highlight suggested Whirlwind 60/60 times and Rampage never, so it is useless as a rage signal.

RageModel.lua (0.5.3) keeps a running rage estimate:
- Adds known generator amounts on casts (doubled during Recklessness) and subtracts exact costs on spenders.
- Treats unexplained rage-change events as auto-attacks.
- Snaps to a known value whenever a spender's "not enough rage" flag flips or contradicts the estimate, and learns the auto-attack gain from those corrections.
- In simulation: mean error 5-8 rage.

Wiring:
- Fury's Rampage-at-100 check and Arms' Execute-at-rage check use the estimate.
- `/midrotlab rage` toggles a draggable readout showing real rage (displayed only, never read) next to the estimate.
- `/midrotlab rage status` prints the model's numbers.
- Traces record `rageEst` and `rageAutoGain`; the dump API line shows `RageEst`.

Next: compare the readout's two numbers during a pull. If the estimate drifts, tune the GENERATION table in RageModel.lua.


## 0.5.4 Fury Slayer rebuilt from top Mythic raid logs (2026-10-31)

Source: Archon, Mythic Vashnik, 11 top parses on 12.1.5 (412K-361K DPS). I read the cast timelines of the top four.

Findings:
- Rampage is spent every time it is usable: 22.3 CPM on the boss and the top damage ability.
- Inside Recklessness, top players strictly alternate Rampage and Crushing Blow, with Execute dropped in.
- Recklessness lasts 24s (the addon assumed 12s) and is recast roughly every 40s.
- Recklessness goes out at 7-11s, after the first Rampage. It is not used on the first GCD.
- Opener: Charge, Raging Blow x1-2, Bloodthirst, (Whirlwind with adds), Rampage, then Recklessness with potion/trinket.
- Odyn's Fury and Bladestorm are pressed together in the back half of Recklessness (about 5-10s left), roughly every 23-25s.
- No Avatar casts. Bloodthirst is low (2.8 CPM) and Bloodbath is 5.0. Raging Blow (10.2) and Crushing Blow (8.5) are the main builders.

Changes:
- FURY_RECKLESSNESS_DURATION 12 -> 24; RageModel's Recklessness window is also 24s.
- New Slayer opener (Mountain Thane keeps the old shared one): Charge > Rampage if usable > Raging Blow > Bloodthirst until the first Rampage, then Recklessness.
- New Slayer ST priority:
  - Recklessness (outside the window), then Avatar if talented.
  - Rampage whenever usable.
  - Odyn's Fury and Bladestorm: inside Recklessness only with 10s or less left; outside it on cooldown, unless Recklessness is about to come back.
  - Then Crushing Blow > Execute > Raging Blow > Bloodbath > Bloodthirst > Whirlwind.
- Slayer AoE and Mountain Thane are unchanged.

Next: rerun the same pull and compare against the WoWAnalyzer result (55.6% accuracy) and the top-log CPM: Rampage ~22, RB+CB ~19, Execute ~6.
