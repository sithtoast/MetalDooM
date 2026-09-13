import AppKit

// Exercise the actual destination callbacks with file-URL pasteboard data.
final class Drop: NSObject, NSDraggingInfo {
    let draggingPasteboard=NSPasteboard.withUniqueName()
    var draggingDestinationWindow:NSWindow? { nil }
    var draggingSourceOperationMask:NSDragOperation { .copy }
    var draggingLocation:NSPoint { .zero }
    var draggedImageLocation:NSPoint { .zero }
    var draggedImage:NSImage? { nil }
    var draggingSource:Any? { nil }
    var draggingSequenceNumber:Int { 1 }
    var draggingFormation:NSDraggingFormation = .none
    var animatesToDestination=false
    var numberOfValidItemsForDrop=0
    var springLoadingHighlight:NSSpringLoadingHighlight { .none }
    func slideDraggedImage(to:NSPoint) {}
    override func namesOfPromisedFilesDropped(atDestination:URL)->[String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(options:NSDraggingItemEnumerationOptions,for view:NSView?,classes:[AnyClass],searchOptions:[NSPasteboard.ReadingOptionKey:Any],using block:(NSDraggingItem,Int,UnsafeMutablePointer<ObjCBool>)->Void) {}
    init(_ urls:[URL]) { super.init();draggingPasteboard.writeObjects(urls.map { $0 as NSURL }) }
    deinit { draggingPasteboard.releaseGlobally() }
}

@main struct Validation {
    static func main() throws {
        _=NSApplication.shared
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:false)
        let old=UserDefaults.standard.object(forKey:"wadPickerFolder")
        defer {
            try? FileManager.default.removeItem(at:folder)
            if let old { UserDefaults.standard.set(old,forKey:"wadPickerFolder") }
            else { UserDefaults.standard.removeObject(forKey:"wadPickerFolder") }
        }
        func file(_ name:String,_ data:String) throws -> URL {
            let url=folder.appendingPathComponent(name).standardizedFileURL.resolvingSymlinksInPath();try Data(data.utf8).write(to:url);return url
        }
        let base=try file("main.WAD","IWAD"), a=try file("extra2.wad","PWAD"), b=try file("extra10.wad","PWAD")
        let bad=try file("broken.wad","oops")
        _=try file(".hidden.wad","IWAD");_=try file("short.wad","IW")
        let mains=try WADPickerFiles.contents(of:folder,kind:"IWAD"), extras=try WADPickerFiles.contents(of:folder,kind:"PWAD")
        precondition(mains.map(\.lastPathComponent) == [base.lastPathComponent] && extras.map(\.lastPathComponent) == [a.lastPathComponent,b.lastPathComponent])
        let panel=WADStackPanel()
        let drops=panel.contentView!.subviews.filter { $0.registeredDraggedTypes.contains(.fileURL) }.sorted { $0.frame.minX < $1.frame.minX }
        precondition(drops.count == 2)
        precondition(drops[0].draggingEntered(Drop([base])) == .copy)
        precondition(!drops[0].performDragOperation(Drop([a])))
        precondition(drops[0].performDragOperation(Drop([base])))
        precondition(drops[1].performDragOperation(Drop([folder])))
        precondition(drops[1].performDragOperation(Drop([a]))) // no duplicate
        precondition(!drops[1].performDragOperation(Drop([bad])))
        precondition(!drops[1].performDragOperation(Drop([base])))
        let buttons=panel.contentView!.subviews.compactMap { $0 as? NSButton }
        let tables=panel.contentView!.subviews.compactMap { ($0 as? NSScrollView)?.documentView as? NSTableView }
        tables[1].selectRowIndexes(IndexSet(integer:1),byExtendingSelection:false)
        buttons.first { $0.title == "Move Up" }!.performClick(nil)
        var received=false
        panel.onPlay={ main,extras in precondition(main == base && extras == [b,a]);received=true }
        buttons.first { $0.title == "Play" }!.performClick(nil)
        precondition(received)
        let doom=try file("doom2.wad","IWAD")
        for name in ["id24res.wad","id1.wad","id1-res.wad","id1-weap.wad","id1-tex.wad","id1-mus.wad","extras.wad"] {_=try file(name,"PWAD")}
        for (i,content) in BundledPreviewPlan.Content.allCases.enumerated() {
            let selection=WADStackPanel(base:doom,bundledAvailable:true)
            let menu=selection.contentView!.subviews.compactMap{$0 as? NSPopUpButton}.first!
            menu.selectItem(at:i+1);NSApp.sendAction(menu.action!,to:menu.target,from:menu)
            let extras=selection.contentView!.subviews.compactMap{$0 as? NSButton}.first{$0.title=="Include extras resources"}!
            extras.state = .on
            var chosen:BundledPreviewPlan?
            selection.onPlayBundled={chosen=$0}
            selection.contentView!.subviews.compactMap{$0 as? NSButton}.first{$0.title=="Play"}!.performClick(nil)
            precondition(chosen?.content==content && chosen?.base==2 && chosen?.paths.first?.lastPathComponent=="extras.wad")
        }
        let inferred=try BundledPreviewPlan.picker(base:doom,addOns:[folder.appendingPathComponent("id1.wad")])
        precondition(inferred?.content == .rust && inferred?.paths.count==3)
        for additions in [["id1.wad","id1-tex.wad"],["id1-weap.wad","extra2.wad"]] {
            var rejected=false;do{_=try BundledPreviewPlan.picker(base:doom,addOns:additions.map{folder.appendingPathComponent($0)})}catch{rejected=true};precondition(rejected)
        }
        let missing=folder.appendingPathComponent("id1.wad");try FileManager.default.removeItem(at:missing)
        var rejected=false;do{_=try BundledPreviewPlan.picker(base:doom,addOns:[],content:.rust)}catch{rejected=true};precondition(rejected)
        print("PASS all six bundled picker callbacks, extras/base order, automatic Rust add-on routing, conflicting stacks and missing resources")
        print("WAD picker passed: folder filtering, file URL drops, type rejection, duplicates, load order and Play handoff.")
    }
}
