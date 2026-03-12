import SwiftUI
import AppKit
internal import UniformTypeIdentifiers
internal import Combine

@Observable
class NotepadViewModel {
    var showPopupRemoveFIle = false
    var tabNeedToRemove: EditorTab?
    
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
    
    func confirmCloseTab(_ tab: EditorTab) {
        showPopupRemoveFIle = true
        tabNeedToRemove = tab
    }
    
    func closeTab(_ tab: EditorTab?) {
        guard let tab = tab else { return }
        let id = tab.id
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        if activeTabID == id {
            activeTabID = tabs.isEmpty ? nil : tabs[min(idx, tabs.count - 1)].id
        }
        tabs.remove(at: idx)
        guard let fileURL = tab.fileURL else { return }
        removeFile(at: fileURL)
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
                    if let content = try? self.readTextFile(from: url) {
                        self.addTab(text: content, fileURL: url)
                    }
                }
            }
        }
    }
    
    private func readTextFile(from url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return String(decoding: data, as: UTF8.self)
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
    
    private func removeFile(at url: URL) {
        let fileManager = FileManager.default
        
        // Kiểm tra file có tồn tại hay không trước khi xóa
        if fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
                print("Đã xóa file thành công tại: \(url.path)")
            } catch {
                print("Lỗi khi xóa file: \(error.localizedDescription)")
            }
        } else {
            print("File không tồn tại tại đường dẫn này.")
        }
    }
    
    func initOpen() {
        getAllDraftFiles().forEach { [weak self] url in
            guard let self = self else { return }
            if let content = try? self.readTextFile(from: url) {
                self.addTab(text: content, fileURL: url)
            }
        }
    }
    
    private func getAllDraftFiles() -> [URL] {
        let fm = FileManager.default
        
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "MiniMapEditor")
            .appendingPathComponent("Drafts")
        
        guard let files = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        return files.filter { $0.pathExtension == "txt" }
    }
}
