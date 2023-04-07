import SwiftUI

/// A custom view that reports mouse and key events to SwiftUI, as
/// these are not available by default.
struct InputAwareView: NSViewRepresentable {
    /// The handler that will respond to the forwarded event.
    let onEvent: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        // Configure KeyView to respond to and report events
        let view = EventHandlerView()
        view.onEvent = onEvent
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// The core view that will forward key and mouse events to a handler function.
private class EventHandlerView: NSView {
    /// The handler that will respond to the forwarded event.
    var onEvent: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        onEvent?(event)
    }

    override func mouseDown(with event: NSEvent) {
        onEvent?(event)
    }
}

