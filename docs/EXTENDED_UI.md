# Rust HUD and level music — 0.10.0 build 140

The explicit Rust preview now draws a native minimal HUD from copied extended
player state and plays the worker-selected level track through Apple's MIDI
synth. The two simulation engines continue sharing Swift/AppKit/Metal presentation.
No classic engine queries are used to populate Rust's HUD or choose its music.

## Visible behavior

Health and armor appear at the lower left; the current weapon, ammo type and count
appear at the lower right. Owned cards and skulls appear above the weapon label.
Melee weapons hide the ammo group. Rust's plasma/BFG replacements are labelled
Incinerator and Calamity Blade, and cell ammo is labelled Fuel. Labels and numbers
use the supplied WAD's original font and HUD patches. The preview loads HUD art
without decoding every actor sprite; copied actor/weapon frames retain their lazy
upload path. The classic renderer keeps its existing labels, portrait and layout.

Music starts with Run or a finite step, pauses when that action finishes, and
resumes from its position on the next action. Pause, Escape, focus loss, minimizing,
errors and shutdown stop playback. The Music checkbox starts enabled and pauses
or resumes music independently of the Sound checkbox. An already pending worker
reply after Pause cannot restart playback. These preview toggles are per session.

The worker selects UMAPINFO's level music when present, otherwise the commercial
Doom II map track through the initialized BEX music names. It copies the actual
resource name, looping flag and a generation changed only by a different name or
looping flag. The parent resolves that name against the verified ordered resources;
it does not infer Rust's map-to-track mapping. S_ChangeMusInfoMusic also captures
names when invoked, but in-level MUSINFO trigger behavior is not yet accepted.

Native playback reuses MusicPlayer's MUS/MIDI decoder, sequencer and DLS synth,
with an instance-local Apple backend override. It does not change the user's
classic Apple/OPL preference or synchronously prerender an entire OPL song during
a scene update. Rust OPL selection, alternate audio formats, intermission/finale
music routing and full JSON presentation remain future work. Music runs in real
time while simulation is active; slow simulation does not time-stretch the score.
Nonlooping MIDI stops at the end; this supports the copied flag but does not imply
that Rust's finale state machine is implemented.

## Copy and wire contract

ABI 2 adds `ME_CopyUI` as its thirteenth private export. Existing C structures and
MGE1/MSP1/MMT1/MSA1 layouts are unchanged. It returns zero before initialization or
after failure. NULL or insufficient capacity returns the required 92 bytes without
writing; a full copy writes exactly 92 bytes and never drains state or ticks the
simulation. One initialized session per worker remains the lifetime rule.

All integers in MUI1 are little-endian 32-bit values:

| Offset | Value |
| ---: | --- |
| 0 | Magic MUI1 |
| 4 | Version 1 |
| 8 | Simulation tic |
| 12, 16 | Signed health and armor |
| 20, 24 | Ready weapon index and ready ammo count; -1 for no ammo |
| 28, 32 | Six key bits and nine owned-weapon bits |
| 36 | Four ammo counts: bullets, shells, cells/fuel, rockets |
| 52 | Four maximum ammo counts in the same order |
| 68 | Eight-byte zero-padded music resource name |
| 76, 80 | Loop flag 0/1 and positive music generation |
| 84, 88 | Ammo type -1..3, reserved zero |

MVW5 extends the outer header to 56 bytes, adding UI byte count at offset 52.
Payload order is optional MGE1, then required MSP1, MMT1, MSA1 and MUI1. All tics
must agree; HUD health must agree with the view and ready weapon/ammo with MSP1.
The Swift decoder also checks sizes, version, reserved bytes, bit ranges, inventory
values, ammo-type/count agreement, and printable padded music names. Old outer
versions reject. Aggregate payload remains bounded at 160 MiB, excluding header.

The copied inventory is the campaign's existing nine-weapon/four-ammo replacement
model. This is not support for arbitrary ID24 inventory IDs or SBARDEF JSON.
Full power-up palette/portrait/stats/messages, campaign flow and save acceptance
remain separate milestones.

## Validation

First run `scripts/test-extended-worker.sh original-doom2.wad rerelease-directory`,
then `scripts/test-extended-ui.sh original-doom2.wad rerelease-directory` with native
Core Audio access. Tests cover all sixteen authoritative map tracks and MIDI
durations, stable selection after 35 tics, initial HUD state, armor/two-key pickups,
complete-copy canaries, sixteen malformed MUI1 packets and inconsistent view tics.
A short original MIDI fixture exercises real mixer PCM, nonloop/loop completion,
pause/resume, independent enablement and unchanged classic backend preference.
PCM proves generated output; physical speaker audibility is unverified.

The native Metal suite compares HUD-visible/hidden/restored frames and existing
optimized/reference geometry. The classic resolution/HUD suite checks original
and minimal layouts, all six keys, portraits and resolution independence. Shared
classic music tests check 35 tracks, native PCM, controller reset, pause/resume,
mute and natural looping. See VALIDATION.md for logs and running-build evidence.
