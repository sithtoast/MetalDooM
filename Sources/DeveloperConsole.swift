import AppKit

/// A deliberately bounded in-game command language; commands never invoke a shell.
enum ConsoleCommand {
    static let names = ["help", "clear", "status", "maps", "map", "restart", "volume", "musicvolume", "music", "render_scale", "fps", "fullscreen", "close", "god", "noclip", "give"]
    case simple(String), map(String), number(String, Float), toggle(String, Bool)
    static func parse(_ text: String) throws -> ConsoleCommand {
        let words=text.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let name=words.first, names.contains(name) else { throw ConsoleError("Unknown command. Type help.") }
        let args=Array(words.dropFirst())
        if ["volume","musicvolume","render_scale","fps"].contains(name) {
            guard args.count==1, let value=Float(args[0]), value.isFinite else { throw ConsoleError("Usage: \(name) <number>") }
            let valid = name=="fps" ? [35,60,120].contains(value) : name=="render_scale" ? [50,75,100,150,200].contains(value) : (0...1).contains(value)
            guard valid else { throw ConsoleError(name=="fps" ? "FPS must be 35, 60 or 120." : name=="render_scale" ? "World scale must be 50, 75, 100, 150 or 200." : "Volume must be between 0 and 1.") }
            return .number(name,value)
        }
        if ["music","fullscreen"].contains(name) {
            guard args.count==1, ["on","off"].contains(args[0]) else { throw ConsoleError("Usage: \(name) on|off") }
            return .toggle(name,args[0]=="on")
        }
        if name=="map" {
            guard args.count==1 else { throw ConsoleError("Usage: map E1M1 (or MAP01)") }
            return .map(args[0].uppercased())
        }
        guard args.isEmpty else { throw ConsoleError("Usage: \(name)") }; return .simple(name)
    }
}
struct ConsoleError: Error, CustomStringConvertible { let description: String; init(_ message: String) { description=message } }

final class DeveloperConsole: NSView, NSTextFieldDelegate {
    let input=NSTextField(string:"")
    private let output=NSTextView()
    private var lines=[String](), history=[String](), historyIndex=0, draft=""
    var execute: ((String)->String)?
    var close: (()->Void)?
    override init(frame: NSRect) {
        super.init(frame:frame)
        wantsLayer=true; layer?.backgroundColor=NSColor(calibratedRed:0.08,green:0.025,blue:0.02,alpha:0.97).cgColor
        layer?.borderWidth=2; layer?.borderColor=NSColor.brown.cgColor
        let title=NSTextField(labelWithString:"METALDOOM CONSOLE     ~ / ESC CLOSE")
        title.font = .monospacedSystemFont(ofSize:13,weight:.bold); title.textColor = .orange
        let scroll=NSScrollView(); scroll.hasVerticalScroller=true; scroll.drawsBackground=false
        output.isEditable=false; output.isSelectable=true; output.drawsBackground=false
        output.font = .monospacedSystemFont(ofSize:13,weight:.regular); output.textColor = NSColor(calibratedRed:0.95,green:0.79,blue:0.55,alpha:1)
        output.isVerticallyResizable=true; output.autoresizingMask=[.width]
        output.textContainer?.widthTracksTextView=true; scroll.documentView=output
        output.setAccessibilityLabel("Console output")
        input.font = .monospacedSystemFont(ofSize:14,weight:.regular); input.textColor = .white
        input.backgroundColor = NSColor.black; input.focusRingType = .none
        input.placeholderString="Type help for commands"; input.delegate=self
        input.setAccessibilityLabel("Console command")
        for child in [title,scroll,input] { child.translatesAutoresizingMaskIntoConstraints=false; addSubview(child) }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo:topAnchor,constant:12),title.leadingAnchor.constraint(equalTo:leadingAnchor,constant:16),
            scroll.topAnchor.constraint(equalTo:title.bottomAnchor,constant:8),scroll.leadingAnchor.constraint(equalTo:leadingAnchor,constant:12),scroll.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-12),
            scroll.bottomAnchor.constraint(equalTo:input.topAnchor,constant:-8),input.leadingAnchor.constraint(equalTo:leadingAnchor,constant:16),input.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-16),input.bottomAnchor.constraint(equalTo:bottomAnchor,constant:-12)
        ])
        append("MetalDooM developer console. Gameplay pauses while open.\nType help. Up/Down: history. Tab: complete command.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    func append(_ text: String) {
        lines.append(contentsOf:text.components(separatedBy:"\n")); lines=Array(lines.suffix(400))
        output.string=lines.joined(separator:"\n"); output.scrollToEndOfDocument(nil)
    }
    func clear() { lines=[]; output.string="" }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            let command=input.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)
            guard !command.isEmpty else { return true }
            history.append(command); history=Array(history.suffix(100)); historyIndex=history.count; draft=""
            input.stringValue=""; append("> \(command)")
            if let result=execute?(command), !result.isEmpty { append(result) }; return true
        case #selector(NSResponder.moveUp(_:)), #selector(NSResponder.moveDown(_:)):
            if historyIndex==history.count { draft=input.stringValue }
            historyIndex=max(0,min(history.count,historyIndex+(selector == #selector(NSResponder.moveUp(_:)) ? -1 : 1)))
            input.stringValue=historyIndex==history.count ? draft : history[historyIndex]; return true
        case #selector(NSResponder.insertTab(_:)):
            let prefix=input.stringValue.lowercased()
            let matches=ConsoleCommand.names.filter { $0.hasPrefix(prefix) }
            if matches.count==1 { input.stringValue=matches[0]+" " } else if !matches.isEmpty { append(matches.joined(separator:"  ")) }; return true
        case #selector(NSResponder.cancelOperation(_:)): close?(); return true
        default: return false
        }
    }
}
