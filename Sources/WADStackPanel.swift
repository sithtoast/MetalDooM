// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
import UniformTypeIdentifiers

// Reviewable load order. Base data remains external; later add-ons take priority.
final class WADStackPanel: NSPanel, NSTableViewDataSource, NSTableViewDelegate {
    var onPlay: (([URL])->Void)?
    private var addOns: [URL]=[]
    private let table=NSTableView()
    init(base: URL) {
        super.init(contentRect:NSRect(x:0,y:0,width:620,height:350),styleMask:[.titled],backing:.buffered,defer:false)
        title="WAD Load Order";isReleasedWhenClosed=false
        let root=contentView!
        func label(_ text:String,_ y:CGFloat) {
            let label=NSTextField(labelWithString:text);label.frame=NSRect(x:20,y:y,width:580,height:24);root.addSubview(label)
        }
        label("Base game: \(base.lastPathComponent)",310)
        label("Optional add-ons — later files override earlier files.",280)
        let column=NSTableColumn(identifier:NSUserInterfaceItemIdentifier("file"));column.title="Load order";column.width=570
        table.addTableColumn(column);table.dataSource=self;table.delegate=self;table.rowHeight=26
        let scroll=NSScrollView(frame:NSRect(x:20,y:100,width:580,height:170));scroll.documentView=table;scroll.hasVerticalScroller=true
        root.addSubview(scroll)
        func button(_ title:String,_ x:CGFloat,_ y:CGFloat,_ width:CGFloat,_ action:Selector) {
            let b=NSButton(title:title,target:self,action:action);b.bezelStyle = .rounded;b.frame=NSRect(x:x,y:y,width:width,height:32);root.addSubview(b)
            if title=="Play" { b.keyEquivalent="\r" }
        }
        button("Add PWAD…",20,60,130,#selector(addFiles))
        button("Remove",155,60,100,#selector(removeFile))
        button("Move Up",260,60,100,#selector(moveEarlier))
        button("Move Down",365,60,120,#selector(moveLater))
        button("Cancel",395,15,95,#selector(cancel))
        button("Play",500,15,100,#selector(play))
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) unavailable") }
    func numberOfRows(in tableView:NSTableView)->Int { addOns.count }
    func tableView(_ tableView:NSTableView,viewFor column:NSTableColumn?,row:Int)->NSView? {
        NSTextField(labelWithString:"\(row+1). \(addOns[row].lastPathComponent)")
    }
    @objc private func addFiles() {
        let panel=NSOpenPanel();panel.allowedContentTypes=[UTType(filenameExtension:"wad") ?? .data]
        panel.allowsMultipleSelection=true;panel.canChooseDirectories=false
        panel.beginSheetModal(for:self) { [weak self] result in
            guard let self,result == .OK else { return }
            for url in panel.urls where !self.addOns.contains(url) { self.addOns.append(url) }
            self.table.reloadData()
        }
    }
    @objc private func removeFile() { let i=table.selectedRow;guard addOns.indices.contains(i) else { return };addOns.remove(at:i);table.reloadData() }
    private func move(_ delta:Int) {
        let i=table.selectedRow,j=i+delta
        guard addOns.indices.contains(i),addOns.indices.contains(j) else { return }
        addOns.swapAt(i,j);table.reloadData();table.selectRowIndexes(IndexSet(integer:j),byExtendingSelection:false)
    }
    @objc private func moveEarlier() { move(-1) }
    @objc private func moveLater() { move(1) }
    @objc private func cancel() { sheetParent?.endSheet(self);orderOut(nil) }
    @objc private func play() { sheetParent?.endSheet(self);orderOut(nil);onPlay?(addOns) }
}
