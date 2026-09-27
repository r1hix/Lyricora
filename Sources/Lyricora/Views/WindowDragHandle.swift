import SwiftUI
import AppKit

public struct WindowDragHandle: NSViewRepresentable {
    public init() {}
    
    public func makeNSView(context: Context) -> DragNSView {
        DragNSView()
    }
    
    public func updateNSView(_ nsView: DragNSView, context: Context) {}
    
    public final class DragNSView: NSView {
        public override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

public struct WindowDragPill: View {
    public init() {}
    
    public var body: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 36, height: 4)
                .padding(.vertical, 6)
            Spacer()
        }
        .contentShape(Rectangle())
        .background(WindowDragHandle())
    }
}
