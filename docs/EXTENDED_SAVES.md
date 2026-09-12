# Rust preview save/restore — 0.10.0 build 145

The explicit Rust preview has Save… and Load… controls. Save pauses a live level
and writes a `.mdrust` file. Load pauses, validates the file against the current
resource stack and engine, then restores into a new worker. The restored game
starts paused at the saved tic. Files may move; their WAD bytes/order/roles must
match. These are private preview saves, separate from classic `.mdsave` files.

## State and compatibility

The pinned Woof `kf_file.c` JSON serializer preserves players, inventory, weapon
states, actors and their references, RNG, moving sector thinkers, buttons, map
changes and visited-level history. Native additions preserve game/level clocks,
counters, brain targets, MUSINFO references, selected music and material animation
translations. Save copies do not tick, consume RNG or drain the audio event queue.
Recently removed arena objects can be present outside the active thinker list.

The MRS1 envelope uses little-endian integers:

| Offset | Value |
| --- | --- |
| 0 | `MRS1` |
| 4 | Version 1 (u32) |
| 8 | JSON byte count (u32, 1–64 MiB) |
| 12 | Reserved zero (u32) |
| 16 | SHA-256 of the packaged extended engine dylib (32 bytes) |
| 48 | SHA-256 of the JSON payload (32 bytes) |
| 80 | UTF-8 JSON payload |

The JSON carries native version 1 and the existing ordered resource fingerprint.
The engine fingerprint deliberately requires the same library bytes; rebuilding
or signing a different engine may invalidate older preview saves. This is not an
upstream Woof save format or a cross-version migration promise. The checksum
detects corruption, not authorship. No WAD data is embedded or uploaded.

MEQ1 operation 6 takes an empty body and returns JSON only while the player is
alive in a level. Operation 7 takes that JSON once in an untouched initial worker
and returns a full MVW5 state. `ME_CopySave` and `ME_RestoreSave` bring the private
ABI2 export count to 17. Existing packet layouts and classic exports are unchanged.
The JSON reader bounds depth/nodes/counts, rejects duplicate keys and bad scalar
values, and checks resource indices, actor types and thinker-list topology. Fatal
engine validation discards the candidate process; it never loads into the current
worker. The parent retains its normal timeout/cancellation boundary.

## Native lifecycle and limits

The parent prepares the candidate scene, renderer, audio and music before swapping
workers. File validation, candidate restore or preparation failures leave the
current paused game available. File writes use atomic replacement. A failure of
the current worker while producing a snapshot stops the preview with its error.
Closing cancels both workers and reaps them through the serial queue.

Restoring clears input, sample tails, old sound channels and presentation caches.
The selected music track restarts; its playback position is not saved. Music and
Sound checkbox choices stay local. Native audio starts its consecutive-tic cursor
at the restored tic, so the next gameplay tic can play normally.

Saving during death, intermission or finale is unavailable. Loading a live-level
save remains available in those phases. There are no autosaves, quick-save
shortcuts, Finder double-click launching, episode picker, demos or uploads here.
Full campaign/boss playthrough acceptance and ordinary Rust picker support remain
pending. This milestone's automated exit rooms are not complete playthroughs.

## Validation

Run after building the matching worker and generating the existing Rust/lifecycle
fixtures under `build/extended/fixtures`:

```sh
bash scripts/test-extended-save.sh /path/to/rerelease
bash scripts/test-extended-save-app.sh /path/to/rerelease
```

The first compares initial full geometry/material/actor/UI state and 140 future
tics on all sixteen maps, both Rust weapon fixtures and a Use sequence. Five
post-transition cases cover pickups, visited levels, normal and secret routes,
and differing level/global clocks. It also checks repeated copy canaries, RNG and
audio nonmutation, malformed JSON, restore boundaries, envelope corruption,
resource/engine mismatches and atomic file replacement.

The native harness exercises actual app code with an exit-room fixture: repeated
worker replacements, restored audio and music, paused controls, corrupt input,
write failure and close during restore. Hardware speaker output and complete
campaign playthroughs are separate acceptance work. See VALIDATION.md for final
bundle and real dialog evidence.
