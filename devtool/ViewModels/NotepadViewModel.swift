import SwiftUI
import AppKit
internal import UniformTypeIdentifiers
internal import Combine

@Observable
class NotepadViewModel {
    var showPopupRemoveFIle = false
    var tabNeedToRemove: EditorTab?
    
    var tabs: [EditorTab] = [] {
        didSet {
            saveTabs()
        }
    }
    var activeTabID: UUID? = nil {
        didSet {
            saveTabs()
        }
    }
    
    // Editor settings
    var fontSize: CGFloat {
        get { CGFloat(UserDefaults.standard.double(forKey: "fontSize")) != 0 ? CGFloat(UserDefaults.standard.double(forKey: "fontSize")) : 14 }
        set { UserDefaults.standard.set(Double(newValue), forKey: "fontSize") }
    }
    var miniMapScale: CGFloat {
        get { CGFloat(UserDefaults.standard.double(forKey: "miniMapScale")) != 0 ? CGFloat(UserDefaults.standard.double(forKey: "miniMapScale")) : 0.18 }
        set { UserDefaults.standard.set(Double(newValue), forKey: "miniMapScale") }
    }
    var miniMapOpacity: Double {
        get { UserDefaults.standard.object(forKey: "miniMapOpacity") != nil ? UserDefaults.standard.double(forKey: "miniMapOpacity") : 0.35 }
        set { UserDefaults.standard.set(newValue, forKey: "miniMapOpacity") }
    }
    @ObservationIgnored
    private var _autosaveEnabled: Bool?
    var autosaveEnabled: Bool {
        get { _autosaveEnabled ?? UserDefaults.standard.bool(forKey: "autosaveEnabled") }
        set {
            _autosaveEnabled = newValue
            UserDefaults.standard.set(newValue, forKey: "autosaveEnabled")
        }
    }
    var isTextWrapped: Bool {
        get { UserDefaults.standard.object(forKey: "isTextWrapped") != nil ? UserDefaults.standard.bool(forKey: "isTextWrapped") : true }
        set { UserDefaults.standard.set(newValue, forKey: "isTextWrapped") }
    }
    
    // Note: The above manual getters/setters are because standard @AppStorage doesn't work inside @Observable classes as easily as in Views.
    // However, since we are using @Observable, we can just use property observers to save.
    
    private let TABS_KEY = "NotePadEditor_Tabs"
    private let ACTIVE_TAB_KEY = "NotePadEditor_ActiveTabID"
    
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
            activeTabID = (tabs.count > 1) ? tabs[idx == tabs.count - 1 ? idx - 1 : idx + 1].id : nil
        }
        tabs.remove(at: idx)
        guard let fileURL = tab.fileURL else { return }
        if fileURL.path.contains("/Drafts/") {
            removeFile(at: fileURL)
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
                    self.saveTabs()
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
        if loadTabs() {
            return
        }
        
        getAllDraftFiles().forEach { [weak self] url in
            guard let self = self else { return }
            if let content = try? self.readTextFile(from: url) {
                self.addTab(text: content, fileURL: url)
            }
        }
    }
    
    private func saveTabs() {
        do {
            let data = try JSONEncoder().encode(tabs)
            UserDefaults.standard.set(data, forKey: TABS_KEY)
            if let activeTabID = activeTabID {
                UserDefaults.standard.set(activeTabID.uuidString, forKey: ACTIVE_TAB_KEY)
            } else {
                UserDefaults.standard.removeObject(forKey: ACTIVE_TAB_KEY)
            }
        } catch {
            print("Failed to save tabs: \(error)")
        }
    }
    
    private func loadTabs() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: TABS_KEY) else { return false }
        do {
            let decoder = JSONDecoder()
            let savedTabs = try decoder.decode([EditorTab].self, from: data)
            if savedTabs.isEmpty { return false }
            
            // Re-load text for each tab
            var loadedTabs: [EditorTab] = []
            for var tab in savedTabs {
                if let url = tab.fileURL {
                    if let content = try? readTextFile(from: url) {
                        tab.text = content
                        loadedTabs.append(tab)
                    }
                }
            }
            
            if loadedTabs.isEmpty { return false }
            
            self.tabs = loadedTabs
            if let activeIDString = UserDefaults.standard.string(forKey: ACTIVE_TAB_KEY),
               let activeID = UUID(uuidString: activeIDString) {
                self.activeTabID = activeID
            } else {
                self.activeTabID = loadedTabs.first?.id
            }
            return true
        } catch {
            print("Failed to load tabs: \(error)")
            return false
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
