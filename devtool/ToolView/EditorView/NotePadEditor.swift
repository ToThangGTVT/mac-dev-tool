import SwiftUI
import AppKit

struct NotePadEditor: View {
    @State private var viewModel = NotepadViewModel()
    @State private var isShowingSettings = false
    
    enum SavingState { case idle, saving, saved, error }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            if let idx = viewModel.activeIndex {
                HStack(spacing: 0) {
                    EditorRepresentable(
                        text: Binding(get: { viewModel.tabs[idx].text },
                                      set: { viewModel.tabs[idx].text = $0 }),
                        fontSize: $viewModel.fontSize,
                        autosaveEnabled: $viewModel.autosaveEnabled,
                        fileURL: Binding(get: { viewModel.tabs[idx].fileURL },
                                         set: { viewModel.tabs[idx].fileURL = $0 }),
                        savingState: Binding(get: { viewModel.tabs[idx].savingState },
                                             set: { viewModel.tabs[idx].savingState = $0 }),
                        lastError: Binding(get: { viewModel.tabs[idx].lastError },
                                           set: { viewModel.tabs[idx].lastError = $0 }),
                        isTextWrapped: $viewModel.isTextWrapped,
                        tabID: viewModel.tabs[idx].id
                    )
                    MiniMapRepresentable(
                        text: Binding(get: { viewModel.tabs[idx].text },
                                      set: { viewModel.tabs[idx].text = $0 }),
                        fontSize: $viewModel.fontSize,
                        scaleFactor: $viewModel.miniMapScale,
                        opacity: $viewModel.miniMapOpacity,
                        onScroll: { ratio in
                            EditorScrollProxy.shared.scroll(toRatio: ratio, tabID: viewModel.tabs[idx].id)
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
                    Button("New Tab") { viewModel.addTab() }.padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar { toolbarContent }
        .onAppear { if viewModel.tabs.isEmpty { viewModel.initOpen() } }
        .alert("Do you want to remove it", isPresented: $viewModel.showPopupRemoveFIle) {
            Button("Cancel", role: .cancel) {}
            if #available(macOS 26.0, *) {
                Button("OK", role: .confirm) {
                    viewModel.closeTab(viewModel.tabNeedToRemove)
                }
            } else {
                Button("OK", role: .destructive) {
                    viewModel.closeTab(viewModel.tabNeedToRemove)
                }
            }
        }
    }
    
    // MARK: - Tab Bar
    private var tabBar: some View {
        HorizontalScrollWheelView {
            HStack(spacing: 0) {
                ForEach(viewModel.tabs) { tab in tabButton(tab) }
                Button { viewModel.addTab() } label: {
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
        let isActive = tab.id == viewModel.activeTabID
        HStack(spacing: 4) {
            Circle()
                .fill(savingColor(tab.savingState))
                .frame(width: 7, height: 7)
            Spacer()
                .frame(width: 2)
            Text(tab.title)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: 200)
                .truncationMode(.middle)
                .foregroundColor(isActive ? .accentColor : .secondary)
            Button { viewModel.confirmCloseTab(tab) } label: {
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
                    ? Color(NSColor.selectedControlColor)
                    : Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle().frame(height: 2).foregroundColor(.accentColor)
            }
        }
        .overlay {
            MiddleClickView {
                viewModel.confirmCloseTab(tab)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.activeTabID = tab.id
            EditorScrollProxy.shared.invalidateRuler(for: tab.id)
        }
        .contextMenu {
            Button("Close Tab") { viewModel.closeTab(tab) }
            Button("Close Other Tabs") { viewModel.closeOtherTabs(tab.id) }
            Divider()
            Button("New Tab") { viewModel.addTab() }
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    
    private func savingColor(_ state: NotePadEditor.SavingState) -> Color {
        switch state {
        case .idle: return .gray.opacity(0.4)
        case .saving: return .blue
        case .saved: return .green
        case .error: return .red
        }
    }
    
    // MARK: - Status Bar
    private func statusBar(for idx: Int) -> some View {
        HStack {
            if let e = viewModel.tabs[idx].lastError {
                Label(e, systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
            } else {
                Text("Line numbers • MiniMap • Auto-save 500ms").foregroundColor(.secondary)
            }
            Spacer()
            Text(viewModel.fileLabel(for: viewModel.tabs[idx]))
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
            Button { viewModel.openDoc() } label: {
                Label("Open", systemImage: "folder.badge.plus")
            }.help("Open file")
            
            Button { viewModel.saveAsDoc() } label: {
                Label("Save As", systemImage: "square.and.arrow.down")
            }.help("Save As")
            
            Button { viewModel.addTab() } label: {
                Label("New Tab", systemImage: "doc.badge.plus")
            }.help("New Tab")
            
            Button {
                isShowingSettings.toggle()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .help("Editor Settings")
            .popover(isPresented: $isShowingSettings, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $viewModel.autosaveEnabled) {
                        Label("Auto-save",
                              systemImage: viewModel.autosaveEnabled ? "clock.badge.checkmark" : "clock.badge.xmark")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .toggleStyle(.switch)
                    
                    Toggle(isOn: $viewModel.isTextWrapped) {
                        Label("Wrap Text",
                              systemImage: viewModel.isTextWrapped ? "text.badge.minus" : "text.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .toggleStyle(.switch)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Font Size: \(Int(viewModel.fontSize))pt")
                        Slider(value: Binding(
                            get: { Double(viewModel.fontSize) },
                            set: { viewModel.fontSize = CGFloat($0) }
                        ), in: 10...28)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: "Map Scale: %.2f×", viewModel.miniMapScale))
                        Slider(value: Binding(
                            get: { Double(viewModel.miniMapScale) },
                            set: { viewModel.miniMapScale = CGFloat($0) }
                        ), in: 0.08...0.4)
                    }
                }
                .padding()
                .frame(width: 220)
            }
        }
    }
}
