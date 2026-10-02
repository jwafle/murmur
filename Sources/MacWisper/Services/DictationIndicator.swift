import AppKit
import SwiftUI

@MainActor
final class DictationIndicator {
    private var panel: NSPanel?
    private var dismissal: Task<Void, Never>?
    private let state = IndicatorState()

    func show() {
        dismissal?.cancel()
        if panel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 144, height: 144),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.contentView = NSHostingView(rootView: IndicatorLamp(state: state))
            self.panel = panel
        }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let screen, let panel {
            let frame = screen.frame
            panel.setFrameOrigin(NSPoint(x: frame.midX - 72, y: frame.maxY - frame.height * 0.2 - 72))
            panel.orderFrontRegardless()
        }
        withAnimation(.easeOut(duration: 0.12)) { state.pressed = true }
    }

    func release() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) { state.pressed = false }
        dismissal?.cancel()
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            self?.panel?.orderOut(nil)
        }
    }
}

@Observable
private final class IndicatorState {
    var pressed = false
}

private struct IndicatorLamp: View {
    let state: IndicatorState

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.25))
                .frame(width: 106, height: 106)
                .blur(radius: 7).offset(y: 7)
            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.58), Color(white: 0.16), Color(white: 0.42)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 104, height: 104)
                .overlay(Circle().stroke(Color.black.opacity(0.8), lineWidth: 2))
            Circle().fill(Color(white: 0.08)).frame(width: 88, height: 88)
            Circle()
                .fill(LinearGradient(colors: state.pressed
                    ? [Color(red: 1, green: 0.67, blue: 0.16), Color(red: 1, green: 0.32, blue: 0.02)]
                    : [Color(red: 0.88, green: 0.43, blue: 0.12), Color(red: 0.48, green: 0.17, blue: 0.03)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: state.pressed ? 76 : 80, height: state.pressed ? 76 : 80)
                .overlay(Circle().stroke(Color.orange.opacity(0.7), lineWidth: 2))
                .overlay {
                    Circle().trim(from: 0.56, to: 0.91).stroke(.white.opacity(state.pressed ? 0.55 : 0.3), lineWidth: 3)
                        .padding(7).blur(radius: 1)
                }
                .shadow(color: state.pressed ? .orange.opacity(0.65) : .black.opacity(0.8), radius: state.pressed ? 14 : 2, y: state.pressed ? 0 : 5)
                .offset(y: state.pressed ? 3 : -3)
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color(red: 0.28, green: 0.10, blue: 0.02).opacity(0.8))
                .offset(y: state.pressed ? 3 : -3)
        }
        .frame(width: 144, height: 144)
        .accessibilityLabel(state.pressed ? "Dictation recording" : "Dictation stopped")
    }
}
