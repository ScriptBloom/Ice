//
//  CGEventMonitor.swift
//  Ice
//

import Cocoa
import OSLog

class CGEventMonitor {
    private let label: String

    private let runLoop: CFRunLoop

    private let mode: CFRunLoopMode

    private let handler: (CGEvent) -> Unmanaged<CGEvent>?

    private var eventTap: CFMachPort?

    private var source: CFRunLoopSource?

    private(set) var isEnabled = false

    init(
        label: String,
        tap: CGEventTapLocation,
        place: CGEventTapPlacement,
        runLoop: CFRunLoop,
        mode: CFRunLoopMode,
        options: CGEventTapOptions,
        types: [CGEventType],
        handler: @escaping (_ event: CGEvent) -> CGEvent?
    ) {
        self.label = label
        self.runLoop = runLoop
        self.mode = mode
        self.handler = { handler($0).map(Unmanaged.passRetained) }
        guard
            let eventTap = CGEvent.tapCreate(
                tap: tap,
                place: place,
                options: options,
                eventsOfInterest: types.reduce(into: 0) { $0 |= 1 << $1.rawValue },
                callback: { _, _, event, refcon in
                    guard let refcon else {
                        return Unmanaged.passRetained(event)
                    }
                    let monitor = Unmanaged<CGEventMonitor>.fromOpaque(refcon).takeUnretainedValue()
                    return monitor.handler(event)
                },
                userInfo: Unmanaged.passRetained(self).toOpaque()
            ),
            let source = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
        else {
            Logger.cgEventMonitor.error("Error creating event monitor \(label)")
            return
        }
        self.eventTap = eventTap
        self.source = source
    }

    deinit {
        stop()
        CFMachPortInvalidate(eventTap)
    }

    private func withUnwrappedEventTap(do body: (CFMachPort) -> Void) {
        guard let eventTap else {
            Logger.cgEventMonitor.error("Monitor \(self.label) has no event tap")
            return
        }
        body(eventTap)
    }

    func start() {
        withUnwrappedEventTap { eventTap in
            CFRunLoopAddSource(runLoop, source, mode)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            isEnabled = true
        }
    }

    func stop() {
        withUnwrappedEventTap { eventTap in
            CFRunLoopRemoveSource(runLoop, source, mode)
            CGEvent.tapEnable(tap: eventTap, enable: false)
            isEnabled = false
        }
    }
}

// MARK: - Logger
private extension Logger {
    static let cgEventMonitor = Logger(category: "CGEventMonitor")
}
