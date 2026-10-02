import AppKit
import SwiftUI

@MainActor
final class DictationIndicator {
    private static let panelSize = NSSize(width: 136, height: 88)
    private var panel: NSPanel?
    private var activation: Task<Void, Never>?
    private var dismissal: Task<Void, Never>?
    private let state = IndicatorState()

    func show() {
        activation?.cancel()
        dismissal?.cancel()
        if panel == nil {
            let panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.panelSize),
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
            panel.setFrameOrigin(NSPoint(x: frame.midX - Self.panelSize.width / 2,
                                         y: frame.maxY - frame.height * 0.2 - Self.panelSize.height / 2))
            panel.orderFrontRegardless()
        }
        // Let the raised, unlit face render before depressing it, including on first use.
        activation = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(30))
            guard !Task.isCancelled, let self else { return }
            let animation: Animation? = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                ? nil : .spring(response: 0.18, dampingFraction: 0.88)
            withAnimation(animation) { self.state.pressed = true }
        }
    }

    func release() {
        activation?.cancel()
        let animation: Animation? = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? nil : .spring(response: 0.3, dampingFraction: 0.72)
        withAnimation(animation) { state.pressed = false }
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let state: IndicatorState

    // The system recording/privacy indicator's amber, rather than a red record light.
    private let amber = Color(red: 1, green: 0.584, blue: 0)

    var body: some View {
        ZStack {
            // A narrow, satin rim and dark socket ground the floating glass in hardware.
            Capsule()
                .fill(.black.opacity(0.22))
                .frame(width: 98, height: 46)
                .overlay {
                    Capsule().strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.42), .black.opacity(0.28), .white.opacity(0.16)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 7, y: 5)

            Capsule()
                .fill(amber.opacity(state.pressed ? 0.24 : 0))
                .frame(width: 80, height: 28)
                .blur(radius: 10)
                .offset(y: 2)

            buttonFace
                .overlay {
                    // A fine specular edge, not an opaque chrome bezel.
                    Capsule().strokeBorder(
                        LinearGradient(colors: [.white.opacity(state.pressed ? 0.65 : 0.48),
                                                .white.opacity(0.06), amber.opacity(0.38)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(state.pressed ? 0.18 : 0.35),
                        radius: state.pressed ? 1 : 3, y: state.pressed ? 1 : 5)
                .scaleEffect(state.pressed ? 0.97 : 1)
                .offset(y: state.pressed ? 2 : -3)
        }
        .frame(width: 136, height: 88)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.pressed ? "Dictation recording" : "Dictation stopped")
    }

    private var buttonFace: some View {
        ZStack {
            // A full-width emitter sits beneath the glass cap, leaving a 4 pt lip.
            // Soft edges and a brighter center read as light inside the button,
            // rather than a symbol or paint applied to its surface.
            Capsule()
                .fill(LinearGradient(
                    colors: [Color(red: 1, green: 0.72, blue: 0.24), amber,
                             Color(red: 0.94, green: 0.40, blue: 0.02)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 80, height: 28)
                .blur(radius: 1.5)
                .opacity(state.pressed ? 0.95 : 0.12)
                .shadow(color: amber.opacity(state.pressed ? 0.65 : 0), radius: 5)

            glassCap
        }
        .frame(width: 88, height: 36)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var glassCap: some View {
        if reduceTransparency {
            Capsule()
                .fill(LinearGradient(colors: [state.pressed ? amber : Color(red: 0.76, green: 0.48, blue: 0.19),
                                              Color(red: 0.65, green: 0.34, blue: 0.08)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 88, height: 36)
        } else {
            Capsule()
                .fill(amber.opacity(state.pressed ? 0.06 : 0.03))
                .frame(width: 88, height: 36)
                .glassEffect(.regular.tint(amber.opacity(state.pressed ? 0.28 : 0.12)), in: .capsule)
        }
    }
}
