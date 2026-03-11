//
//  Base64ToolView.swift
//  devtool
//
//  Created by GOLFZON on 11/3/26.
//

import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

struct Base64ToolView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case encode = "Encode"
        case decode = "Decode"
        var id: String { rawValue }
    }
    
    enum Wrap: String, CaseIterable, Identifiable {
        case none = "None"
        case w64  = "64"
        case w76  = "76"
        var id: String { rawValue }
    }
    
    enum LineEnding: String, CaseIterable, Identifiable {
        case lf   = "LF (\\n)"
        case crlf = "CRLF (\\r\\n)"
        var id: String { rawValue }
    }
    
    enum TextEncoding: String, CaseIterable, Identifiable {
        case utf8 = "UTF-8"
        case ascii = "ASCII"
        case utf16 = "UTF-16"
        
        var id: String { rawValue }
        
        var nsEncoding: String.Encoding {
            switch self {
            case .utf8:  return .utf8
            case .ascii: return .ascii
            case .utf16: return .utf16LittleEndian
            }
        }
    }
    
    @AppStorage("base64.mode") private var mode: Mode = .encode
    @AppStorage("base64.wrap") private var wrap: Wrap = .none
    @AppStorage("base64.lineEnding") private var lineEnding: LineEnding = .lf
    @AppStorage("base64.encoding") private var stringEncoding: TextEncoding = .utf8
    
    @State private var input: String = ""
    @State private var output: String = ""
    @State private var errorMessage: String?
    @State private var isTargeted: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            bodyEditors
            Divider()
            footer
        }
        .navigationTitle("Base64")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    performMainAction()
                } label: {
                    Label(mode == .encode ? "Encode" : "Decode",
                          systemImage: mode == .encode ? "arrow.up.square" : "arrow.down.square")
                }
                .keyboardShortcut(.return)
                
                Button {
                    swapMode()
                } label: {
                    Label("Swap", systemImage: "arrow.left.arrow.right")
                }
                
                Button {
                    copyOutput()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(output.isEmpty)
                
                Button {
                    pasteToInput()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                
                Button(role: .destructive) {
                    clearAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .keyboardShortcut("k", modifiers: [.command])
            }
        }
        .padding(.bottom, 4)
        .onChange(of: input) { _ in
            autoDetectModeIfNeeded()
        }
        .onAppear {
            autoDetectModeIfNeeded()
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack(spacing: 16) {
            Picker("Chế độ", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            
            Divider().frame(height: 22)
            
            Picker("Wrap", selection: $wrap) {
                ForEach(Wrap.allCases) { w in
                    Text(w.rawValue).tag(w)
                }
            }
            .frame(width: 120)
            
            Picker("Line Ending", selection: $lineEnding) {
                ForEach(LineEnding.allCases) { le in
                    Text(le.rawValue).tag(le)
                }
            }
            .frame(width: 180)
            
            Picker("Encoding", selection: $stringEncoding) {
                ForEach(TextEncoding.allCases) { enc in
                    Text(enc.rawValue).tag(enc)
                }
            }
            .frame(width: 140)
            
            Spacer()
        }
        .padding(12)
    }
    
    // MARK: - Editors
    private var bodyEditors: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Input")
                        .font(.headline)
                    Spacer()
                    Button {
                        input = ""
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear input")
                }
                
                TextEditor(text: $input)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .onDrop(of: [.fileURL, .utf8PlainText], isTargeted: $isTargeted) { providers in
                        handleDrop(providers: providers)
                    }
                
                HStack(spacing: 8) {
                    Button(mode == .encode ? "Encode" : "Decode", action: performMainAction)
                        .buttonStyle(.borderedProminent)
                    Button("Swap Mode", action: swapMode)
                    Button("Paste", action: pasteToInput)
                    Spacer()
                    Button("Clear", role: .destructive, action: clearAll)
                }
            }
            .padding(12)
            .frame(minWidth: 420)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Output")
                        .font(.headline)
                    Spacer()
                    Button {
                        copyOutput()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(output.isEmpty)
                }
                
                TextEditor(text: .constant(output))
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .disabled(true)
                
                if let error = errorMessage, !error.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text(error)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityIdentifier("ErrorMessage")
                } else {
                    Text(" ")
                        .hidden()
                }
                
                HStack(spacing: 8) {
                    Button("Copy Output", action: copyOutput)
                        .buttonStyle(.borderedProminent)
                        .disabled(output.isEmpty)
                    Spacer()
                }
            }
            .padding(12)
            .frame(minWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer
    private var footer: some View {
        HStack(spacing: 12) {
            Text(helpText)
                .foregroundColor(.secondary)
                .font(.callout)
            Spacer()
        }
        .padding(8)
    }
    
    private var helpText: String {
        switch mode {
        case .encode:
            return "Encode: chuyển chuỗi sang Base64. Có thể chọn wrap 64/76 và kiểu xuống dòng."
        case .decode:
            return "Decode: giải Base64 về chuỗi văn bản theo encoding đã chọn."
        }
    }
    
    // MARK: - Actions
    private func performMainAction() {
        errorMessage = nil
        output = ""
        
        switch mode {
        case .encode:
            guard let data = input.data(using: stringEncoding.nsEncoding) else {
                errorMessage = "Không thể chuyển input sang dữ liệu với encoding \(stringEncoding.rawValue)."
                return
            }
            var options: Data.Base64EncodingOptions = []
            switch wrap {
            case .w64: options.insert(.lineLength64Characters)
            case .w76: options.insert(.lineLength76Characters)
            case .none: break
            }
            switch lineEnding {
            case .lf:   options.insert(.endLineWithLineFeed)
            case .crlf: options.insert(.endLineWithCarriageReturn) // (CR) – gần CRLF nhất trong Foundation
            }
            output = data.base64EncodedString(options: options)
            
        case .decode:
            // Ignore unknown characters để dễ dán chuỗi có khoảng trắng/newline
            guard let data = Data(base64Encoded: input, options: .ignoreUnknownCharacters) else {
                errorMessage = "Input không phải Base64 hợp lệ."
                return
            }
            if let str = String(data: data, encoding: stringEncoding.nsEncoding) {
                output = str
            } else if let utf8 = String(data: data, encoding: .utf8) {
                output = utf8
                errorMessage = "Không decode được với \(stringEncoding.rawValue). Đã fallback UTF‑8."
            } else {
                errorMessage = "Không thể chuyển dữ liệu đã decode thành chuỗi văn bản."
            }
        }
    }
    
    private func swapMode() {
        mode = (mode == .encode) ? .decode : .encode
        output = ""
        errorMessage = nil
    }
    
    private func copyOutput() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(output, forType: .string)
    }
    
    private func pasteToInput() {
        let pb = NSPasteboard.general
        if let str = pb.string(forType: .string) {
            input = str
        }
    }
    
    private func clearAll() {
        input = ""
        output = ""
        errorMessage = nil
    }
    
    private func autoDetectModeIfNeeded() {
        // Nếu input có vẻ là Base64, gợi ý chuyển sang Decode (không cưỡng bức)
        if isLikelyBase64(input) && mode == .encode {
            // Không tự đổi mode; chỉ set errorMessage như gợi ý nhẹ
            errorMessage = "Phát hiện chuỗi có vẻ là Base64. Bạn có muốn chuyển sang Decode?"
        } else if !isLikelyBase64(input) && mode == .decode {
            errorMessage = nil // tránh báo sai
        }
    }
    
    private func isLikelyBase64(_ s: String) -> Bool {
        // Heuristic: chỉ chứa A-Z a-z 0-9 + / = và độ dài bội số 4 (cho bản tiêu chuẩn, không xét URL-safe)
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        if trimmed.rangeOfCharacter(from: allowed.inverted) != nil { return false }
        if trimmed.count % 4 != 0 { return false }
        return true
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        // Nhận text hoặc file .txt
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.utf8-plain-text") {
                _ = provider.loadObject(ofClass: NSString.self) { item, _ in
                    if let text = item as? String {
                        DispatchQueue.main.async { self.input = text }
                    }
                }
                return true
            } else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                _ = provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, _) in
                    guard
                        let urlData,
                        let url = URL(dataRepresentation: urlData as! Data, relativeTo: nil)
                    else { return }
                    if let content = try? String(contentsOf: url) {
                        DispatchQueue.main.async { self.input = content }
                    }
                }
                return true
            }
        }
        return false
    }
}

