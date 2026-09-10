// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
import UniformTypeIdentifiers

// Read only the signature while browsing; full validation happens when Play loads the stack.
enum WADPickerFiles {
    static func kind(_ url: URL) -> String? {
        guard url.pathExtension.lowercased() == "wad",
              let file=try? FileHandle(forReadingFrom:url) else { return nil }
        defer { try? file.close() }
        guard let data=try? file.read(upToCount:4) else { return nil }
        let signature=String(decoding:data,as:UTF8.self)
        return ["IWAD","PWAD"].contains(signature) ? signature : nil
    }
    static func displayName(_ url:URL)->String {
        guard let wad=try? WAD(url:url) else { return url.lastPathComponent }
        if wad.signature == "IWAD" { return wad.displayName }
        if wad.maps.contains("E5M1"),wad.lump("E5TEXT") != nil,wad.lump("SIGILINT") != nil { return "SIGIL" }
        if let bytes=wad.lump("GAMECONF"),bytes.count<=65536,
           let json=(try? JSONSerialization.jsonObject(with:bytes.data)) as? [String:Any],
           json["type"] as? String == "gameconf",let data=json["data"] as? [String:Any],
           let title=data["title"] as? String {
            let clean=title.components(separatedBy:.controlCharacters).joined(separator:" ").trimmingCharacters(in:.whitespacesAndNewlines)
            if !clean.isEmpty,clean.count<=128 { return clean }
        }
        return url.lastPathComponent
    }
    static func contents(of folder:URL, kind signature:String) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil,options:[.skipsHiddenFiles])
            .map { $0.standardizedFileURL.resolvingSymlinksInPath() }
            .filter { kind($0) == signature }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
    static func isDirectory(_ url:URL) -> Bool {
        (try? url.resourceValues(forKeys:[.isDirectoryKey]).isDirectory) == true
    }
}

private final class WADDropArea: NSView {
    var onDrop: (([URL])->Bool)?
    private var highlighted=false { didSet { needsDisplay=true } }
    init(frame:NSRect, title:String) {
        super.init(frame:frame)
        registerForDraggedTypes([.fileURL])
        let label=NSTextField(labelWithString:title)
        label.frame=bounds.insetBy(dx:10,dy:13);label.alignment = .center
        label.textColor = .secondaryLabelColor;label.font = .systemFont(ofSize:12)
        label.isSelectable=false;addSubview(label)
        setAccessibilityLabel(title)
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) unavailable") }
    private func urls(_ sender:NSDraggingInfo) -> [URL] {
        sender.draggingPasteboard.readObjects(forClasses:[NSURL.self],options:[.urlReadingFileURLsOnly:true]) as? [URL] ?? []
    }
    override func draggingEntered(_ sender:NSDraggingInfo)->NSDragOperation {
        highlighted = !urls(sender).isEmpty
        return highlighted ? .copy : []
    }
    override func draggingExited(_ sender:NSDraggingInfo?) { highlighted=false }
    override func prepareForDragOperation(_ sender:NSDraggingInfo)->Bool { !urls(sender).isEmpty }
    override func performDragOperation(_ sender:NSDraggingInfo)->Bool {
        highlighted=false;return onDrop?(urls(sender)) ?? false
    }
    override func draw(_ dirtyRect:NSRect) {
        let path=NSBezierPath(roundedRect:bounds.insetBy(dx:1,dy:1),xRadius:8,yRadius:8)
        (highlighted ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill();path.fill()
        (highlighted ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth=highlighted ? 2 : 1;path.stroke()
    }
}

// One main game on the left; explicit, ordered add-ons on the right.
final class WADStackPanel: NSPanel, NSTableViewDataSource, NSTableViewDelegate {
    var onCancel: (()->Void)?
    var onPlay: ((URL,[URL])->Void)?
    private var names:[URL:String]=[:]
    private func name(_ url:URL)->String {
        if let cached=names[url] { return cached }
        let title=WADPickerFiles.displayName(url);names[url]=title;return title
    }
    private var refreshing=false
    private var base:URL?
    private var folder:URL?
    private var mainFiles:[URL]=[]
    private var addOns:[URL]
    private let mainTable=NSTableView(), extrasTable=NSTableView()
    private let folderLabel=NSTextField(labelWithString:"Choose a folder or drop a main WAD below.")
    private let selectedLabel=NSTextField(labelWithString:"No main WAD selected")
    private let notice=NSTextField(labelWithString:"")
    private var playButton:NSButton!
    private var removeButton:NSButton!, upButton:NSButton!, downButton:NSButton!

    init(base:URL? = nil, addOns:[URL] = [], replacingGame:Bool = false) {
        self.base=base?.standardizedFileURL.resolvingSymlinksInPath();self.addOns=addOns.map { $0.standardizedFileURL.resolvingSymlinksInPath() }
        super.init(contentRect:NSRect(x:0,y:0,width:840,height:540),styleMask:[.titled],backing:.buffered,defer:false)
        title="Choose WADs";isReleasedWhenClosed=false
        let root=contentView!
        func label(_ text:String,_ rect:NSRect, bold:Bool=false) {
            let field=NSTextField(labelWithString:text);field.frame=rect
            field.font = .systemFont(ofSize:bold ? 15 : 12,weight:bold ? .semibold : .regular)
            field.textColor=bold ? .labelColor : .secondaryLabelColor;root.addSubview(field)
        }
        func button(_ title:String,_ rect:NSRect,_ action:Selector)->NSButton {
            let b=NSButton(title:title,target:self,action:action);b.bezelStyle = .rounded;b.frame=rect;root.addSubview(b);return b
        }
        label("Main game",NSRect(x:20,y:500,width:390,height:24),bold:true)
        label("Extra WADs",NSRect(x:430,y:500,width:390,height:24),bold:true)
        label("Choose one IWAD from your folder.",NSRect(x:20,y:475,width:390,height:20))
        label("Optional PWADs. Later files take priority.",NSRect(x:430,y:475,width:390,height:20))
        folderLabel.frame=NSRect(x:20,y:446,width:390,height:22);folderLabel.font = .systemFont(ofSize:11)
        folderLabel.lineBreakMode = .byTruncatingMiddle;root.addSubview(folderLabel)
        label("Load order",NSRect(x:430,y:446,width:390,height:22))
        for (table,x,name) in [(mainTable,CGFloat(20),"Main WADs"),(extrasTable,CGFloat(430),"Extra WAD load order")] {
            let column=NSTableColumn(identifier:NSUserInterfaceItemIdentifier(name));column.width=366
            table.addTableColumn(column);table.headerView=nil;table.rowHeight=44
            table.dataSource=self;table.delegate=self;table.allowsEmptySelection=true
            table.setAccessibilityLabel(name)
            let scroll=NSScrollView(frame:NSRect(x:x,y:225,width:390,height:215))
            scroll.documentView=table;scroll.hasVerticalScroller=true;scroll.borderType = .bezelBorder;root.addSubview(scroll)
        }
        selectedLabel.frame=NSRect(x:20,y:197,width:390,height:22)
        selectedLabel.lineBreakMode = .byTruncatingMiddle;selectedLabel.font = .systemFont(ofSize:11);root.addSubview(selectedLabel)
        _ = button("Choose Folder…",NSRect(x:20,y:155,width:150,height:32),#selector(chooseFolder))
        _ = button("Choose IWAD…",NSRect(x:175,y:155,width:145,height:32),#selector(chooseBase))
        _ = button("Add PWAD…",NSRect(x:430,y:185,width:130,height:32),#selector(addFiles))
        removeButton=button("Remove",NSRect(x:565,y:185,width:85,height:32),#selector(removeFile))
        upButton=button("Move Up",NSRect(x:650,y:185,width:80,height:32),#selector(moveEarlier))
        downButton=button("Move Down",NSRect(x:730,y:185,width:90,height:32),#selector(moveLater))
        let mainDrop=WADDropArea(frame:NSRect(x:20,y:95,width:390,height:50),title:"Drop a main WAD or folder here")
        let extraDrop=WADDropArea(frame:NSRect(x:430,y:95,width:390,height:70),title:"Drop extra WADs or a folder here")
        mainDrop.onDrop={ [weak self] urls in self?.receiveMain(urls) ?? false }
        extraDrop.onDrop={ [weak self] urls in self?.receiveExtras(urls) ?? false }
        root.addSubview(mainDrop);root.addSubview(extraDrop)
        notice.frame=NSRect(x:20,y:60,width:800,height:26);notice.font = .systemFont(ofSize:11)
        notice.lineBreakMode = .byTruncatingTail;root.addSubview(notice)
        if replacingGame { label("Play ends the current game. Cancel to go back and save first.",NSRect(x:20,y:21,width:590,height:22)) }
        let cancelButton=button("Cancel",NSRect(x:620,y:15,width:95,height:32),#selector(cancel));cancelButton.keyEquivalent="\u{1b}"
        playButton=button("Play",NSRect(x:725,y:15,width:95,height:32),#selector(play));playButton.keyEquivalent="\r"
        let remembered=UserDefaults.standard.string(forKey:"wadPickerFolder").map { URL(fileURLWithPath:$0,isDirectory:true) }
        if let initial=base?.deletingLastPathComponent() ?? remembered { browse(initial) }
        refresh()
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) unavailable") }
    private func refresh() {
        refreshing=true
        mainTable.reloadData();extrasTable.reloadData()
        if let base,let i=mainFiles.firstIndex(of:base) { mainTable.selectRowIndexes(IndexSet(integer:i),byExtendingSelection:false) }
        refreshing=false
        selectedLabel.stringValue=base.map { "Selected: " + name($0) } ?? "No main WAD selected"
        selectedLabel.toolTip=base?.path;playButton.isEnabled=base != nil
        updateButtons()
    }
    private func updateButtons() {
        let i=extrasTable.selectedRow
        removeButton.isEnabled=addOns.indices.contains(i);upButton.isEnabled=i>0
        downButton.isEnabled=i>=0 && i+1<addOns.count
    }
    private func browse(_ url:URL) {
        let url=url.standardizedFileURL.resolvingSymlinksInPath()
        do {
            let files=try WADPickerFiles.contents(of:url,kind:"IWAD")
            names.removeAll();folder=url;mainFiles=files;folderLabel.stringValue=url.path;folderLabel.toolTip=url.path
            UserDefaults.standard.set(url.path,forKey:"wadPickerFolder")
            if let base,!files.contains(base) { self.base=nil }
            notice.stringValue=files.isEmpty ? "No main IWADs found in this folder. Extra PWADs belong on the right." : "\(files.count) main WAD\(files.count == 1 ? "" : "s") found. Select one to play."
            refresh()
        } catch { notice.stringValue="Cannot read folder: \(error.localizedDescription)" }
    }
    @discardableResult private func receiveMain(_ urls:[URL])->Bool {
        guard urls.count == 1,let original=urls.first else { notice.stringValue="Choose one main WAD or one folder.";return false }
        let url=original.standardizedFileURL.resolvingSymlinksInPath()
        if WADPickerFiles.isDirectory(url) { browse(url);return true }
        guard WADPickerFiles.kind(url) == "IWAD" else { notice.stringValue="The main game must be an IWAD. Drop extra PWADs on the right.";return false }
        browse(url.deletingLastPathComponent());base=url;refresh();return true
    }
    @discardableResult private func receiveExtras(_ urls:[URL])->Bool {
        do {
            var candidates:[URL]=[]
            for original in urls {
                let url=original.standardizedFileURL.resolvingSymlinksInPath()
                if WADPickerFiles.isDirectory(url) { candidates += try WADPickerFiles.contents(of:url,kind:"PWAD") }
                else {
                    guard WADPickerFiles.kind(url) == "PWAD" else { notice.stringValue="Extras must be PWAD files. Main IWADs belong on the left.";return false }
                    candidates.append(url)
                }
            }
            let previous=addOns.count
            for url in candidates where !addOns.contains(url) { addOns.append(url) }
            extrasTable.reloadData();updateButtons()
            notice.stringValue="Added \(addOns.count-previous) extra WAD(s). Review their order before playing."
            return true
        } catch { notice.stringValue="Cannot read extras: \(error.localizedDescription)";return false }
    }
    func numberOfRows(in tableView:NSTableView)->Int { tableView === mainTable ? mainFiles.count : addOns.count }
    func tableView(_ tableView:NSTableView,viewFor column:NSTableColumn?,row:Int)->NSView? {
        let url=(tableView === mainTable ? mainFiles : addOns)[row]
        let cell=NSView(frame:NSRect(x:0,y:0,width:366,height:44))
        let title=NSTextField(labelWithString:(tableView === mainTable ? "" : "\(row+1). ") + name(url))
        title.font = .systemFont(ofSize:13,weight:.medium)
        title.frame=NSRect(x:0,y:21,width:366,height:20)
        let filename=NSTextField(labelWithString:url.lastPathComponent)
        filename.font = .systemFont(ofSize:11);filename.textColor = .secondaryLabelColor
        filename.frame=NSRect(x:0,y:3,width:366,height:16)
        for field in [title,filename] {
            field.lineBreakMode = .byTruncatingMiddle;field.autoresizingMask=[.width]
            field.toolTip=name(url) + "\n" + url.path;cell.addSubview(field)
        }
        return cell
    }
    func tableViewSelectionDidChange(_ notification:Notification) {
        guard !refreshing else { return }
        if notification.object as? NSTableView === mainTable,mainFiles.indices.contains(mainTable.selectedRow) {
            base=mainFiles[mainTable.selectedRow]
            selectedLabel.stringValue="Selected: " + name(base!);selectedLabel.toolTip=base?.path;playButton.isEnabled=true
        }
        updateButtons()
    }
    @objc private func chooseFolder() {
        let panel=NSOpenPanel();panel.canChooseFiles=false;panel.canChooseDirectories=true;panel.directoryURL=folder
        panel.beginSheetModal(for:self) { [weak self] result in if result == .OK,let url=panel.url { self?.browse(url) } }
    }
    @objc private func chooseBase() {
        let panel=NSOpenPanel();panel.allowedContentTypes=[UTType(filenameExtension:"wad") ?? .data];panel.directoryURL=folder
        panel.beginSheetModal(for:self) { [weak self] result in if result == .OK { self?.receiveMain(panel.urls) } }
    }
    @objc private func addFiles() {
        let panel=NSOpenPanel();panel.allowedContentTypes=[UTType(filenameExtension:"wad") ?? .data]
        panel.allowsMultipleSelection=true;panel.canChooseDirectories=false;panel.directoryURL=folder
        panel.beginSheetModal(for:self) { [weak self] result in if result == .OK { self?.receiveExtras(panel.urls) } }
    }
    @objc private func removeFile() { let i=extrasTable.selectedRow;guard addOns.indices.contains(i) else { return };addOns.remove(at:i);extrasTable.reloadData();updateButtons() }
    private func move(_ delta:Int) {
        let i=extrasTable.selectedRow,j=i+delta
        guard addOns.indices.contains(i),addOns.indices.contains(j) else { return }
        addOns.swapAt(i,j);extrasTable.reloadData();extrasTable.selectRowIndexes(IndexSet(integer:j),byExtendingSelection:false);updateButtons()
    }
    @objc private func moveEarlier() { move(-1) }
    @objc private func moveLater() { move(1) }
    @objc private func cancel() { sheetParent?.endSheet(self);orderOut(nil);onCancel?() }
    @objc private func play() { guard let base else { return };sheetParent?.endSheet(self);orderOut(nil);onPlay?(base,addOns) }
}
