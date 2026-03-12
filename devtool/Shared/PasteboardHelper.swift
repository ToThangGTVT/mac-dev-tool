import AppKit

struct PasteboardHelper {
    static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
    
    static func paste() -> String? {
        let pb = NSPasteboard.general
        return pb.string(forType: .string)
    }
}
