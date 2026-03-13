//
//  MiddleClickView.swift
//  devtool
//
//  Created by GOLFZON on 13/3/26.
//

import SwiftUI
import AppKit

struct MiddleClickView: NSViewRepresentable {
    var onMiddleClick: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        let gesture = NSClickGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.clicked(_:)))
        gesture.buttonMask = 0x4 // middle mouse
        view.addGestureRecognizer(gesture)

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onMiddleClick: onMiddleClick)
    }

    class Coordinator: NSObject {
        let onMiddleClick: () -> Void

        init(onMiddleClick: @escaping () -> Void) {
            self.onMiddleClick = onMiddleClick
        }

        @objc func clicked(_ sender: NSClickGestureRecognizer) {
            if sender.state == .ended {
                onMiddleClick()
            }
        }
    }
}
