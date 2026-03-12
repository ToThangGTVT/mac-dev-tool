import SwiftUI
import AppKit

struct NotePadEditor: View {
    @State private var vm = NotepadViewModel()
    
    enum SavingState { case idle, saving, saved, error }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()

            if let idx = vm.activeIndex {
                HStack(spacing: 0) {
                    EditorRepresentable(
                        text:            Binding(get: { vm.tabs[idx].text },
                                                 set: { vm.tabs[idx].text = $0 }),
                        fontSize:        $vm.fontSize,
                        autosaveEnabled: $vm.autosaveEnabled,
                        fileURL:         Binding(get: { vm.tabs[idx].fileURL },
                                                 set: { vm.tabs[idx].fileURL = $0 }),
                        savingState:     Binding(get: { vm.tabs[idx].savingState },
                                                 set: { vm.tabs[idx].savingState = $0 }),
                        lastError:       Binding(get: { vm.tabs[idx].lastError },
                                                 set: { vm.tabs[idx].lastError = $0 }),
                        tabID:           vm.tabs[idx].id
                    )
                    MiniMapRepresentable(
                        text:        Binding(get: { vm.tabs[idx].text },
                                             set: { vm.tabs[idx].text = $0 }),
                        fontSize:    $vm.fontSize,
                        scaleFactor: $vm.miniMapScale,
                        opacity:     $vm.miniMapOpacity,
                        onScroll:    { ratio in
                            EditorScrollProxy.shared.scroll(toRatio: ratio, tabID: vm.tabs[idx].id)
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
                    Button("New Tab") { vm.addTab() }.padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar { toolbarContent }
        .onAppear { if vm.tabs.isEmpty { vm.addTab() } }
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(vm.tabs) { tab in tabButton(tab) }
                Button { vm.addTab() } label: {
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
        let isActive = tab.id == vm.activeTabID
        HStack(spacing: 4) {
            Circle()
                .fill(savingColor(tab.savingState))
                .frame(width: 7, height: 7)
            Text(tab.title)
                .lineLimit(1)
                .frame(maxWidth: 140)
                .truncationMode(.middle)
            Button { vm.closeTab(tab.id) } label: {
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
        .onTapGesture { vm.activeTabID = tab.id }
        .contextMenu {
            Button("Close Tab")        { vm.closeTab(tab.id) }
            Button("Close Other Tabs") { vm.closeOtherTabs(tab.id) }
            Divider()
            Button("New Tab")          { vm.addTab() }
        }
    }

    private func savingColor(_ state: NotePadEditor.SavingState) -> Color {
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
            if let e = vm.tabs[idx].lastError {
                Label(e, systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
            } else {
                Text("Line numbers • MiniMap • Auto-save 500ms").foregroundColor(.secondary)
            }
            Spacer()
            Text(vm.fileLabel(for: vm.tabs[idx]))
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
            Button { vm.openDoc() } label: {
                Label("Open", systemImage: "folder.badge.plus")
            }.help("Open file")

            Button { vm.saveAsDoc() } label: {
                Label("Save As", systemImage: "square.and.arrow.down")
            }.help("Save As")

            Button { vm.addTab() } label: {
                Label("New Tab", systemImage: "doc.badge.plus")
            }.help("New Tab")

            Divider()

            Toggle(isOn: $vm.autosaveEnabled) {
                Label("Auto-save",
                      systemImage: vm.autosaveEnabled ? "clock.badge.checkmark" : "clock.badge.xmark")
            }.help("Toggle Auto-save")

            HStack {
                Text("Font:")
                Slider(value: Binding(
                    get: { Double(vm.fontSize) },
                    set: { vm.fontSize = CGFloat($0) }
                ), in: 10...28).frame(width: 80)
                Text("\(Int(vm.fontSize))pt").frame(width: 32)
            }
            HStack {
                Text("Map:")
                Slider(value: Binding(
                    get: { Double(vm.miniMapScale) },
                    set: { vm.miniMapScale = CGFloat($0) }
                ), in: 0.08...0.4).frame(width: 80)
                Text(String(format: "%.2f×", vm.miniMapScale)).frame(width: 42)
            }
        }
    }
}
