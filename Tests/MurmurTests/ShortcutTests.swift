import XCTest
import AppKit
@testable import Murmur

final class ShortcutTests: XCTestCase {
    private func event(_ code: CGKeyCode, down: Bool, flags: CGEventFlags = []) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
        event.flags = flags
        return event
    }

    func testCapturedKeyRepeatsAndReleaseWithoutModifierAreConsumed() {
        let state = ShortcutTapState("Option + Space")
        XCTAssertTrue(state.matches(type: .keyDown, event: event(49, down: true, flags: .maskAlternate)))
        XCTAssertTrue(state.matches(type: .keyDown, event: event(49, down: true)))
        XCTAssertTrue(state.matches(type: .keyUp, event: event(49, down: false)))
        XCTAssertFalse(state.matches(type: .keyDown, event: event(49, down: true)))
    }

    func testUnrelatedKeysAndShortcutRecorderPassThrough() {
        let state = ShortcutTapState("Option + Space")
        XCTAssertFalse(state.matches(type: .keyDown, event: event(0, down: true, flags: .maskAlternate)))
        state.setSuspended(true)
        XCTAssertFalse(state.matches(type: .keyDown, event: event(49, down: true, flags: .maskAlternate)))
        state.setSuspended(false)
        XCTAssertTrue(state.matches(type: .keyDown, event: event(49, down: true, flags: .maskAlternate)))
    }
}
