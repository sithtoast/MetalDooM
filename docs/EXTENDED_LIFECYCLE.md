# Rust death, restart and map transitions — 0.10.0 build 143

The explicit Rust preview now pauses at death or level completion. Restart level
reloads the current map with fresh starting inventory. On death, E, Space or Return
also restart. A completed level shows kills, items, secrets, elapsed time and the
next map, with a Continue button. MAP07 and MAP14 show Episode complete and have
no Continue action. The normal picker remains guarded pending full campaign play.

The presentation is a native text summary over the final world view. It does not
implement XWINTER animations, narrative intertexts, CREDIT artwork, the XFINALE1
cast, automatic episode selection or complete boss-trigger acceptance. Death
freezes the death tic; camera-fall/death-animation playback remains future work.

## Engine-owned lifecycle

ABI 2 adds a fourteenth export, `ME_Advance(action)`: action 0 restarts, action 1
continues a completed non-ending map. One process still owns one initialized
resource session, but may now load multiple levels in that session. No second
ME_Init, new resource stack, DLL unload or save format is implied.

Small wrappers in pinned g_game.c call its existing G_DoCompleted, G_DoLoadLevel
and G_DoWorldDone. Upstream player cleanup clears keys/powers at exit, preserves
health/armor/weapons/ammo across Continue, resets map counters and builds the next
world. Restart marks the player reborn before the normal load routine, restoring
starting health, pistol and ammo. RNG remains owned by the same engine process;
no parent-side inventory serialization or seed reset implements transitions.

The bootstrap now initializes haswolflevels from MAP31 presence, matching upstream
d_main.c. Without this startup flag the commercial secret-exit routine incorrectly
fell back to a normal exit, even with valid Rust UMAPINFO secret routes. Continue
uses upstream wminfo next-map selection, then rejects targets outside the current
profile's range (Rust MAP01–16, baseline MAP01–32). MAP99 is not a route target.
Both standard end-game flags and Rust's custom endfinale flag terminate progression.

Autosaving defaults on upstream. The native Continue wrapper explicitly disables
it because no extended save format is accepted. The autosave hook fails if ever
called; it does not silently write classic or upstream save files. StatCopy and
WI_Start are presentation hooks owned by the native summary rather than software
intermission drawing or optional file statistics. G_Ticker's general demo/save/
rewind/UI dispatch remains excluded.

ME_Tick consumes only a playable level command. After P_Ticker requests completion,
the adapter runs G_DoCompleted at that boundary. Worker batches stop early on
actual death or completion, returning the last valid world instead of issuing
another command and invalidating the session. Invalid lifecycle actions fail.

## Copied state and transition transaction

MVW5's 56-byte header and payload order remain. Its required UI payload is now
MUI2/version 2, 144 bytes; old UI packets reject. Original HUD/music fields through
reserved offset 88 keep their offsets. New little-endian u32/i32 fields:

| Offset | Value |
| ---: | --- |
| 92 | Phase: 0 playing, 1 dead, 2 completed, 3 episode ended |
| 96, 100 | Current map, next map (zero unless phase 2) |
| 104, 108 | Player kills, total kills |
| 112, 116 | Player items, total items |
| 120, 124 | Player secrets, total secrets |
| 128 | Level tics, equal to the view tic |
| 132 | Secret-exit flag, zero before completion |
| 136, 140 | Reserved zeros |

The Swift decoder checks phases, map/next-map ranges, counters, reserved bytes,
phase/health agreement, tic consistency and copied geometry map identity.

MEQ1 operation 4 carries a four-byte action. Success forces complete MGE1 plus
all other presentation payloads at tic zero. Swift verifies the expected map,
playable phase, full geometry and stable resource identity. Existing C structures
and MGE1/MSP1/MMT1/MSA1 layouts do not change.

The native app pauses and clears input before enqueueing the action on its worker
queue. Restart is disabled while a tic or level action is in flight; Continue is
available only at a completed non-ending boundary. A fresh scene builder,
renderer and sound player replace old caches and audio tick sequencing. Music is
selected for the new map and prepared paused, with checkbox states retained.
The next Run or manual step starts from tic zero. No stale frame/voice/held command
is carried across the load. Closing cancels the worker; queued UI replies check
closed state before presentation. Boundary effects may finish naturally; music
pauses, and explicit Pause/restart/focus loss stops effects too.

## Validation and remaining acceptance

After building the matching worker, run:

```sh
bash scripts/test-extended-lifecycle.sh /path/to/doom2.wad /path/to/rerelease
bash scripts/test-extended-lifecycle-app.sh /path/to/rerelease
```

Original synthetic rooms trigger actual use switches and damaging floors; Rust's
unmodified UMAPINFO supplies all sixteen normal routes and both secret routes.
Tests cover episode endings, pickup inventory carryover, key cleanup, new-map
counters, complete new geometry, repeated restart and real death at tic129.
These prove routing and lifecycle mechanics, not complete playthroughs or actual
MAP13/MAP14 boss kills. The native app suite uses the same app source with injected
test resources/helper, exercising the panels, map/music changes, repeated
restart/step and close during replacement. See VALIDATION.md for final evidence.

Next: animated intermission/finale presentation, targeted combat/map-special and
boss exits, followed by versioned extended saves and full campaign acceptance.
