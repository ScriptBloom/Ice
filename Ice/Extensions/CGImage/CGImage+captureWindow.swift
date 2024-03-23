//
//  CGImage+captureWindow.swift
//  Ice
//

import CoreGraphics

/// Returns a composite image of the specified windows.
///
/// This function links to a deprecated CoreGraphics function. We link to it this way to
/// silence the deprecation warning. Once ScreenCaptureKit can reliably capture offscreen
/// windows, this function should be removed.
///
/// See the documentation for the deprecated function here:
///
/// https://developer.apple.com/documentation/coregraphics/1455730-cgwindowlistcreateimagefromarray
@_silgen_name("CGWindowListCreateImageFromArray")
private func _CGWindowListCreateImageFromArray(
    _ screenBounds: CGRect,
    _ windowArray: CFArray,
    _ imageOption: CGWindowImageOption
) -> CGImage?

extension CGImage {
    static func captureWindow(with windowID: CGWindowID) -> CGImage? {
        var pointer = UnsafeRawPointer(bitPattern: Int(windowID))
        guard
            let windowArray = CFArrayCreate(kCFAllocatorDefault, &pointer, 1, nil),
            let image = _CGWindowListCreateImageFromArray(.null, windowArray, .boundsIgnoreFraming)
        else {
            return nil
        }
        return image
    }
}
