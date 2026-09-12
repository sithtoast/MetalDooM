# Rust native intermissions and finales — 0.10.0

The explicit Rust preview presents the campaign's original XWINTER0/1 episode
maps, counting statistics, visited splats and blinking destination arrows. Continue
(or E, Space, Return or F) first fills the totals, then opens the entering screen.
The entering screen lasts four seconds or can be skipped with another press.
The engine-selected normal/secret destination loads with carried inventory, paused.

MAP07 and MAP14 show their UMAPINFO stories with original tiled backgrounds and
D_SHORES. A press reveals the full text; another opens MAP07's CREDIT artwork or
MAP14's XFINALE1 cast. The custom cast uses the original seven actors, explicit
alive/death frames, flips, patched labels and sound IDs. Fire triggers the current
actor's death; its last frame advances to the next actor. Alive frames loop until
fired upon. After the hero, the cast repeats. D_DEJAVU is nonlooping, as declared.
Restart level remains available throughout. There is no automatic episode switch.

## Ownership and copied data

The worker still owns completion, visited levels, inventory and routes. ABI2 adds
`ME_CopyCampaign`, the fifteenth private export. MEQ1 operation 5 has an empty
request body and returns UTF-8 JSON in the existing MER1 sequence/status envelope.
It is valid only at a completed level, bounded to 1 MiB. Size queries and short
buffers do not write, and copies neither tick the world nor drain sound events.
MUI2/MVW5 and existing structures stay unchanged.

Version 1 metadata carries map/tic/next map, par tics, selected map names/pictures,
exit/enter animation names, story/music/flat/end artwork/finale, visited maps,
patched sound identities and cast labels. The parent verifies map/tic/next against
its last copied UI. `DSDH_SoundLookup` reads the existing external-to-internal sound
mapping without allocating IDs. IDs 1–4095 are exported when their linked, static,
nonlooping sound definition resolves to an existing lump. Missing or unsupported
cast sounds reject the presentation explicitly. The captured gameplay FIFO and RNG
are untouched. Unknown cast labels are likewise rejected.

The native parser accepts the installed interlevel/finale 1.0.0 schemas with bounded
arrays, names and finite durations. This covers fixed/infinite interlevel frames
and conditions None, MapNumGreater, MapNumEqual, MapVisited, IsExiting and IsEntering.
Random frames, secret classification conditions, translations/translucency and
other custom finale types are outside this implementation and reject. This is
Rust campaign presentation, not general ID24 conformance.

## Presentation and pause behavior

`ExtendedCampaignSequence` owns presentation state at 35 Hz. Delayed UI wakes
advance one presentation tic; they do not accumulate simulation or presentation
catch-up work. Pause/Escape/focus loss stop its timer and music/effects. Resume
starts a new timer while retaining the exact frame and counters. Music/Sound remain
independent. An in-flight completion reply after pause opens a paused presentation.

Interlevel durations truncate seconds × 35, matching the pinned implementations;
the Rust arrow is visible for 23 tics and blank for 11. TNT1A0 denotes a transparent
frame. Conditions use the worker's visited list and the entering target map.
The AppKit overlay caches palette-decoded art, respects patch offsets and sprite
namespace precedence, and draws nearest-neighbor at 320×200 with 1.2 vertical pixel
aspect correction and letterboxing. Cast flips reflect their anchor. The Metal
world is frozen underneath. Restart/Continue remove the overlay, stop its timer,
clear presentation audio/music state, and load fresh native world resources.

## Validation

With the matching worker built, run on a logged-in native macOS host:

```sh
bash scripts/test-extended-campaign.sh /path/to/rerelease
bash scripts/test-extended-lifecycle-app.sh /path/to/rerelease
```

The first uses small original exit rooms with unchanged campaign metadata to check
all sixteen normal and two secret routes, metadata copy canaries, artwork decoding,
statistics, visited markers, 23/11 arrow timing, four-second entering, both stories,
credits, all seven alive/death cast cycles and malformed boundary data. PNG
readbacks stay under ignored `build/campaign-test`. The second runs the actual app
controller with injected fixture resources, native controls, pause/resume,
MIDI/effects, both endings, restarts and close during a pending level replacement.

These route and presentation fixtures are not full campaign or boss playthroughs.
Save/restore, full death-camera playback, episode selection and full gameplay
acceptance remain ahead; ordinary picker acceptance is still guarded. Demos,
speedrunning mode and external uploads remain a future aside.
