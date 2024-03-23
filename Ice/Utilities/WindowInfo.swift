//
//  WindowInfo.swift
//  Ice
//

import Cocoa

/// Information for a window.
struct WindowInfo {
    let windowID: CGWindowID
    let backingType: CGWindowBackingType
    let windowLayer: Int
    let frame: CGRect
    let sharingState: CGWindowSharingType
    let alpha: CGFloat
    let owningApplication: NSRunningApplication?
    let memoryUsage: Int
    let title: String?
    let isOnScreen: Bool
    let usesVideoMemory: Bool

    init?(info: CFDictionary) {
        guard
            let info = info as? [CFString: CFTypeRef],
            let windowID = info[kCGWindowNumber] as? CGWindowID,
            let backingType = (info[kCGWindowStoreType] as? UInt32).flatMap({ CGWindowBackingType(rawValue: $0) }),
            let windowLayer = info[kCGWindowLayer] as? Int,
            let frameRaw = info[kCGWindowBounds],
            CFGetTypeID(frameRaw) == CFDictionaryGetTypeID(),
            let frame = CGRect(dictionaryRepresentation: frameRaw as! CFDictionary), // swiftlint:disable:this force_cast
            let sharingState = (info[kCGWindowSharingState] as? UInt32).flatMap({ CGWindowSharingType(rawValue: $0) }),
            let alpha = info[kCGWindowAlpha] as? CGFloat,
            let ownerPID = info[kCGWindowOwnerPID] as? Int,
            let memoryUsage = info[kCGWindowMemoryUsage] as? Int
        else {
            return nil
        }
        self.windowID = windowID
        self.backingType = backingType
        self.windowLayer = windowLayer
        self.frame = frame
        self.sharingState = sharingState
        self.alpha = alpha
        self.owningApplication = NSRunningApplication(processIdentifier: pid_t(ownerPID))
        self.memoryUsage = memoryUsage
        self.title = info[kCGWindowName] as? String
        self.isOnScreen = info[kCGWindowIsOnscreen] as? Bool ?? false
        self.usesVideoMemory = info[kCGWindowBackingLocationVideoMemory] as? Bool ?? false
    }

    /// Gets an array of the current windows.
    static func getCurrent(option: CGWindowListOption, relativeTo windowID: CGWindowID? = nil) -> [WindowInfo] {
        guard let list = CGWindowListCopyWindowInfo(option, windowID ?? kCGNullWindowID) as? [CFDictionary] else {
            return []
        }
        return list.compactMap { info in
            WindowInfo(info: info)
        }
    }
}
