//
//  CheckedEvent.swift
//  Ice
//

import CoreGraphics

class CheckedEvent {
    enum EventError: Error {
        case timeout
    }

    let event: CGEvent

    let fallbackEvent: CGEvent

    private let location = CGEventTapLocation.cghidEventTap

    private var monitor: CGEventMonitor?

    init?(
        mouseEventSource source: CGEventSource?,
        mouseType: CGEventType,
        fallbackMouseType: CGEventType,
        mouseCursorPosition: CGPoint,
        mouseButton: CGMouseButton,
        flags: CGEventFlags
    ) {
        guard
            let event = CGEvent(
                mouseEventSource: source,
                mouseType: mouseType,
                mouseCursorPosition: mouseCursorPosition,
                mouseButton: mouseButton
            ),
            let fallbackEvent = CGEvent(
                mouseEventSource: source,
                mouseType: fallbackMouseType,
                mouseCursorPosition: mouseCursorPosition,
                mouseButton: mouseButton
            )
        else {
            return nil
        }
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.flags = flags
        fallbackEvent.flags = flags
        self.event = event
        self.fallbackEvent = fallbackEvent
    }

    private func postEvent(_ event: CGEvent) {
        event.post(tap: location)
    }

    func post(timeout: Duration) async throws {
        try await withCheckedThrowingContinuation { continuation in
            monitor = CGEventMonitor(
                label: String(describing: Self.self),
                tap: location,
                place: .tailAppendEventTap,
                runLoop: CFRunLoopGetMain(),
                mode: .commonModes,
                options: .listenOnly,
                types: [event.type]
            ) { [weak self] event in
                self?.monitor?.stop()
                self?.monitor = nil
                continuation.resume()
                return event
            }
            monitor?.start()
            Task(priority: .high) {
                postEvent(event)
                do {
                    try await Task.sleep(for: timeout)
                    if monitor != nil {
                        throw EventError.timeout
                    }
                } catch {
                    monitor?.stop()
                    monitor = nil
                    postEvent(fallbackEvent)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
