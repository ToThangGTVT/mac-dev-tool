import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

@Observable
class NotepadViewModel {
    var tabs: [EditorTab] = []
    var activeTabID: UUID? = nil
    
    // Editor settings
    var fontSize: CGFloat = 14
    var miniMapScale: CGFloat = 0.18
    var miniMapOpacity: Double = 0.35
    var autosaveEnabled: Bool = true
    
    var activeIndex: Int? { tabs.firstIndex(where: { $0.id == activeTabID }) }
    
    // MARK: - Tab Management
    func addTab(text: String = "", fileURL: URL? = nil) {
        let tab = EditorTab(text: text, fileURL: fileURL ?? draftURL())
        tabs.append(tab)
        activeTabID = tab.id
    }
    
    func closeTab(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: idx)
        if activeTabID == id {
            activeTabID = tabs.isEmpty ? nil : tabs[min(idx, tabs.count - 1)].id
        }
    }
    
    func closeOtherTabs(_ id: UUID) {
        tabs = tabs.filter { $0.id == id }
        activeTabID = id
    }
    
    // MARK: - File Actions
    func openDoc() {
        let p = NSOpenPanel()
        if #available(macOS 12.0, *) {
            p.allowedContentTypes = [
                UTType.plainText, UTType.json, UTType.xml, UTType.sourceCode,
                UTType(filenameExtension: "md")   ?? .plainText,
                UTType(filenameExtension: "yaml") ?? .plainText,
                UTType(filenameExtension: "yml")  ?? .plainText,
                UTType(filenameExtension: "csv")  ?? .plainText,
                UTType(filenameExtension: "log")  ?? .plainText
            ]
        } else {
            p.allowedFileTypes = ["txt","md","json","xml","yaml","yml","log","swift","csv"]
        }
        p.allowsMultipleSelection = true
        p.begin { r in
            guard r == .OK else { return }
            DispatchQueue.main.async {
                for url in p.urls {
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        self.addTab(text: content, fileURL: url)
                    }
                }
            }
        }
    }
    
    func saveAsDoc() {
        guard let idx = activeIndex else { return }
        let p = NSSavePanel()
        if #available(macOS 12.0, *) {
            p.allowedContentTypes = [UTType.plainText]
        } else {
            p.allowedFileTypes = ["txt"]
        }
        p.nameFieldStringValue = self.tabs[idx].title.hasSuffix(".txt")
            ? self.tabs[idx].title : "Untitled.txt"
        p.begin { r in
            guard r == .OK, let url = p.url else { return }
            do {
                try self.tabs[idx].text.data(using: .utf8)?.write(to: url, options: .atomic)
                DispatchQueue.main.async {
                    self.tabs[idx].fileURL     = url
                    self.tabs[idx].savingState = .saved
                    self.tabs[idx].lastError   = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.tabs[idx].lastError   = "Save: \(error.localizedDescription)"
                    self.tabs[idx].savingState = .error
                }
            }
        }
    }
    
    func fileLabel(for tab: EditorTab) -> String {
        guard let u = tab.fileURL else { return "Draft" }
        return u.path.contains("/Drafts/") ? "Draft → \(u.lastPathComponent)" : u.path
    }
    
    private func draftURL() -> URL {
        let fm  = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "MiniMapEditor")
            .appendingPathComponent("Drafts")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("untitled-\(UUID().uuidString.prefix(8)).txt")
    }
}
