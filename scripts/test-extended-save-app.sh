#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 1 ]]; then echo "Usage: $0 rerelease-directory" >&2; exit 2; fi
OUT="$PROJECT_DIR/build/save-app-test"
mkdir -p "$OUT"
bash "$PROJECT_DIR/scripts/build-engine.sh" "$OUT/engine"
python3 - "$PROJECT_DIR" "$OUT" <<'PY'
from pathlib import Path
import sys
root,out=map(Path,sys.argv[1:])
main=(root/'Sources/main.swift').read_text().split('\nlet app = NSApplication.shared\n')[0]
(out/'main.swift').write_text(main+'\n'+(root/'Tests/ExtendedSaveAppValidation.swift').read_text())
s=(root/'Sources/ExtendedPreviewApp.swift').read_text().replace('let paths=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}','let paths=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}+[URL(fileURLWithPath:ProcessInfo.processInfo.environment["LIFECYCLE_FIXTURE"]!)]')
s=s.replace('Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/MetalDooMWorker")','URL(fileURLWithPath:ProcessInfo.processInfo.environment["LIFECYCLE_WORKER"]!)')
s+='''
extension ExtendedPreviewApp {
    var validationUI:ExtendedUI? {levelUI}
    var validationStatus:String {status.stringValue}
    var validationSaveEnabled:Bool {saveButton.isEnabled}
    func validationSave(_ url:URL) {save(to:url)}
    func validationLoad(_ url:URL) {restore(from:url)}
    var validationFailure:String? {stopped ? status.stringValue:nil}
    var validationPaused:Bool {!clock.busy && !changingLevel}
    var validationMusic:String? {musicPlayer?.trackName}
    var validationBoundaryControls:Bool {!clock.busy && (campaign != nil || !runButton.isEnabled) && restartButton.isEnabled}
    var validationCampaign:ExtendedCampaignSequence? {campaign}
    var validationCampaignRunning:Bool {campaignRunning}
    var validationCampaignSounds:Int {campaignSound?.scheduledSounds ?? 0}
    func validationPause() {pause()}
    func validationPress() {continueLevel()}
    var validationText:String {completion.stringValue}
    func validationRun() {toggleRunning()}
    func validationUse() {view.useQueued=true}
    func validationStep() {let button=NSButton();button.tag=5;step(button)}
    func validationAdvance(restart:Bool) {changeLevel(restart:restart)}
    func validationClose() {shutdown();queue.sync{worker.close()}}
}
'''
(out/'ExtendedPreviewApp.swift').write_text(s)
PY
SOURCES=()
for source in "$PROJECT_DIR"/Sources/*.swift; do
 case "$(basename "$source")" in
 main.swift|ExtendedPreviewApp.swift) SOURCES+=("$OUT/$(basename "$source")");;
 *) SOURCES+=("$source");;
 esac
done
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$PROJECT_DIR/build/module-cache" \
 -framework AppKit -framework Metal -framework MetalKit -framework QuartzCore -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
 "${SOURCES[@]}" "$OUT/engine/libDoom.a" -Xlinker -dead_strip -o "$OUT/validate"
for scenario in normal:1; do
 fixture="${scenario%:*}"
 map="${scenario#*:}"
 LIFECYCLE_FIXTURE="$PROJECT_DIR/build/extended/fixtures/lifecycle-$fixture.wad" LIFECYCLE_WORKER="$PROJECT_DIR/build/extended/MetalDooMWorker" MTL_DEBUG_LAYER=1 \
 "$OUT/validate" --rust-preview "$1" --map "$map"
done
