//
//  HorizontalScrollWheelView.swift
//  devtool
//
//  Created by GOLFZON on 12/3/26.
//

import SwiftUI

struct HorizontalScrollWheelView<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> ScrollCaptureView {
        let container = ScrollCaptureView()

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        container.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        container.hostingView = hostingView
        return container
    }
    func updateNSView(_ nsView: ScrollCaptureView, context: Context) {
        (nsView.hostingView as? NSHostingView<Content>)?.rootView = content
    }
}

class ScrollCaptureView: NSView {
    var hostingView: NSView?
    var scrollOffset: CGFloat = 0
    
    override func scrollWheel(with event: NSEvent) {
        let delta: CGFloat
        if event.hasPreciseScrollingDeltas {
            // Trackpad — đã precise, dùng thẳng
            delta = event.scrollingDeltaX != 0 ? event.scrollingDeltaX : event.scrollingDeltaY
        } else {
            // Chuột thường — nhân hệ số cho nhanh
            let raw = event.scrollingDeltaX != 0 ? event.scrollingDeltaX : event.scrollingDeltaY
            delta = raw * 8
        }
        
        scrollOffset -= delta
        
        guard let hostingView else { return }
        let maxOffset = max(0, hostingView.fittingSize.width - bounds.width)
        scrollOffset = max(0, min(scrollOffset, maxOffset))
        hostingView.setFrameOrigin(NSPoint(x: -scrollOffset, y: 0))
    }
    
    override func layout() {
        super.layout()
        guard let hostingView else { return }
        let fittingWidth = hostingView.fittingSize.width
        hostingView.frame = CGRect(
            x: -scrollOffset,
            y: 0,
            width: fittingWidth,
            height: bounds.height
        )
    }
}
