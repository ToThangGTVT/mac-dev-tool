//
//  MiniMapEditorView.swift
//  devtool
//

import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

struct MiniMapEditorView: View {

    enum SavingState { case idle, saving, saved, error }

    @State private var tabs: [EditorTab]  = []
    @State private var activeTabID: UUID? = nil

    @State private var fontSize: CGFloat      = 14
    @State private var miniMapScale: CGFloat  = 0.18
    @State private var miniMapOpacity: Double = 0.35
    @State private var autosaveEnabled        = true

    private var activeIndex: Int? { tabs.firstIndex(where: { $0.id == activeTabID }) }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()

            if let idx = activeIndex {
                HStack(spacing: 0) {
                    EditorRepresentable(
                        text:            Binding(get: { tabs[idx].text },
                                                 set: { tabs[idx].text = $0 }),
                        fontSize:        $fontSize,
                        autosaveEnabled: $autosaveEnabled,
                        fileURL:         Binding(get: { tabs[idx].fileURL },
                                                 set: { tabs[idx].fileURL = $0 }),
                        savingState:     Binding(get: { tabs[idx].savingState },
                                                 set: { tabs[idx].savingState = $0 }),
                        lastError:       Binding(get: { tabs[idx].lastError },
                                                 set: { tabs[idx].lastError = $0 }),
                        tabID:           tabs[idx].id
                    )
                    MiniMapRepresentable(
                        text:        Binding(get: { tabs[idx].text },
                                             set: { tabs[idx].text = $0 }),
                        fontSize:    $fontSize,
                        scaleFactor: $miniMapScale,
                        opacity:     $miniMapOpacity,
                        onScroll:    { ratio in
                            EditorScrollProxy.shared.scroll(toRatio: ratio, tabID: tabs[idx].id)
                        }
                    )
                    .frame(width: 140)
                    .border(Color.gray.opacity(0.2), width: 1)
                }

                Divider()
                statusBar(for: idx)

            } else {
                VStack {
                    Spacer()
                    Text("No file open").foregroundColor(.secondary)
                    Button("New Tab") { addTab() }.padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar { toolbarContent }
        .onAppear { if tabs.isEmpty { addTab() } }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabs) { tab in tabButton(tab) }
                Button { addTab() } label: {
                    Image(systemName: "plus").frame(width: 28, height: 32)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }
        }
        .frame(height: 34)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func tabButton(_ tab: EditorTab) -> some View {
        let isActive = tab.id == activeTabID
        HStack(spacing: 4) {
            Circle()
                .fill(savingColor(tab.savingState))
                .frame(width: 7, height: 7)
            Text(tab.title)
                .lineLimit(1)
                .frame(maxWidth: 140)
                .truncationMode(.middle)
            Button { closeTab(tab.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(isActive ? 1 : 0.4)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(isActive
            ? Color(NSColor.controlBackgroundColor)
            : Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle().frame(height: 2).foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { activeTabID = tab.id }
        .contextMenu {
            Button("Close Tab")        { closeTab(tab.id) }
            Button("Close Other Tabs") { closeOtherTabs(tab.id) }
            Divider()
            Button("New Tab")          { addTab() }
        }
    }

    private func savingColor(_ state: SavingState) -> Color {
        switch state {
        case .idle:   return .gray.opacity(0.4)
        case .saving: return .blue
        case .saved:  return .green
        case .error:  return .red
        }
    }

    // MARK: - Status Bar

    private func statusBar(for idx: Int) -> some View {
        HStack {
            if let e = tabs[idx].lastError {
                Label(e, systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
            } else {
                Text("Line numbers • MiniMap • Auto-save 500ms").foregroundColor(.secondary)
            }
            Spacer()
            Text(fileLabel(for: tabs[idx]))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 300)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button { openDoc() } label: {
                Label("Open", systemImage: "folder.badge.plus")
            }.help("Open file")

            Button { saveAsDoc() } label: {
                Label("Save As", systemImage: "square.and.arrow.down")
            }.help("Save As")

            Button { addTab() } label: {
                Label("New Tab", systemImage: "doc.badge.plus")
            }.help("New Tab")

            Divider()

            Toggle(isOn: $autosaveEnabled) {
                Label("Auto-save",
                      systemImage: autosaveEnabled ? "clock.badge.checkmark" : "clock.badge.xmark")
            }.help("Toggle Auto-save")

            Divider()

            HStack {
                Text("Font:")
                Slider(value: $fontSize, in: 10...28).frame(width: 80)
                Text("\(Int(fontSize))pt").frame(width: 32)
            }

            HStack {
                Text("Map:")
                Slider(value: $miniMapScale, in: 0.08...0.4).frame(width: 80)
                Text(String(format: "%.2f×", miniMapScale)).frame(width: 42)
            }

            Divider()

            if let idx = activeIndex {
                statusIcon(for: tabs[idx].savingState)
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for state: SavingState) -> some View {
        switch state {
        case .idle:
            Label("Idle",    systemImage: "pause.circle").foregroundColor(.secondary)
        case .saving:
            Label("Saving…", systemImage: "arrow.triangle.2.circlepath.circle").foregroundColor(.blue)
        case .saved:
            Label("Saved",   systemImage: "checkmark.circle").foregroundColor(.green)
        case .error:
            Label("Error",   systemImage: "xmark.octagon").foregroundColor(.red)
        }
    }

    // MARK: - Tab Management

    private func addTab(text: String = "", fileURL: URL? = nil) {
        let tab = EditorTab(text: text, fileURL: fileURL ?? draftURL())
        tabs.append(tab)
        activeTabID = tab.id
    }

    private func closeTab(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: idx)
        if activeTabID == id {
            activeTabID = tabs.isEmpty ? nil : tabs[min(idx, tabs.count - 1)].id
        }
    }

    private func closeOtherTabs(_ id: UUID) {
        tabs = tabs.filter { $0.id == id }
        activeTabID = id
    }

    // MARK: - File Actions

    private func openDoc() {
        DispatchQueue.main.async {
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
    }

    private func saveAsDoc() {
        guard let idx = activeIndex else { return }
        DispatchQueue.main.async {
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
    }

    private func draftURL() -> URL {
        let fm  = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "MiniMapEditor")
            .appendingPathComponent("Drafts")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("untitled-\(UUID().uuidString.prefix(8)).txt")
    }

    private func fileLabel(for tab: EditorTab) -> String {
        guard let u = tab.fileURL else { return "Draft" }
        return u.path.contains("/Drafts/") ? "Draft → \(u.lastPathComponent)" : u.path
    }
}
