import Foundation
@main struct ConsoleValidation {
    static func main() throws {
        if case .map("E1M2") = try ConsoleCommand.parse("  MAP e1m2  ") {} else { fatalError("map normalization") }
        for text in ["fps 0","fps nan","volume inf","volume -1","music maybe","map","map E1M1 junk","restart junk","unknown","render_scale 99"] {
            do { _ = try ConsoleCommand.parse(text); fatalError("Accepted: \(text)") } catch {}
        }
        for text in ["fps 35","fps 120","volume 0","volume 1","musicvolume 0.5","render_scale 75","fullscreen off","music on","status","clear"] { _ = try ConsoleCommand.parse(text) }
        print("PASS: console parsing, map normalization, strict argument counts, supported settings and nonfinite/range rejection")
    }
}
