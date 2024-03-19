//
//  LayoutBarItemView.swift
//  Ice
//

import Cocoa

// MARK: - LayoutBarItemView

/// A view that displays an image in a menu bar layout view.
class LayoutBarItemView: NSView {
    static let placeholderImage: CGImage = {
        let nsImage = NSImage(systemSymbolName: "questionmark.circle.fill", accessibilityDescription: "")!
        return nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    }()

    /// Temporary information that the item view retains when it is
    /// moved outside of a layout view.
    ///
    /// When the item view is dragged outside of a layout view, this
    /// property is set to hold the layout view's container view, as
    /// well as the index of the item view in relation to the container's
    /// other items. Upon being inserted into a new layout view, these
    /// values are removed. If the item is dropped outside of a layout
    /// view, these values are used to reinsert the item view in its
    /// original layout view.
    var oldContainerInfo: (container: LayoutBarContainer, index: Int)?

    /// A Boolean value that indicates whether the item view is
    /// currently inside a container.
    var hasContainer = false

    let item: MenuBarItem

    /// The image displayed inside the view.
    let image: NSImage

    /// A Boolean value that indicates whether the item view is a
    /// dragging placeholder.
    ///
    /// If this value is `true`, the item view does not draw its image.
    var isDraggingPlaceholder = false {
        didSet {
            needsDisplay = true
        }
    }

    /// A Boolean value that indicates whether the view is enabled.
    var isEnabled = true {
        didSet {
            needsDisplay = true
        }
    }

    /// Creates a view that displays the given menu bar item.
    init?(item: MenuBarItem, display: DisplayInfo, itemManager: MenuBarItemManager) {
        var image: CGImage?
        if let cachedImage = itemManager.cachedItemImages[item.cacheKey] {
            image = cachedImage
        } else if let capturedImage = CGImage.captureWindow(with: item.windowID) {
            image = capturedImage
            DispatchQueue.main.async {
                itemManager.cachedItemImages[item.cacheKey] = capturedImage
            }
        }
        guard let image else {
            return nil
        }
        self.item = item
        let trimmedImage: NSImage = {
            // only trim horizontal edges to maintain proper vertical centering
            // due to the status item shadow offsetting the trim
            let cgImage = image.trimmingTransparentPixels(edges: [.minXEdge, .maxXEdge]) ?? image
            return NSImage(cgImage: cgImage, size: item.frame.size)
        }()
        let centeredImage = NSImage(size: item.frame.size, flipped: false) { rect in
            let centeredRect = CGRect(
                x: rect.midX - (trimmedImage.size.width / 2),
                y: rect.midY - (trimmedImage.size.height / 2),
                width: trimmedImage.size.width,
                height: trimmedImage.size.height
            )
            trimmedImage.draw(in: centeredRect)
            return true
        }
        self.image = centeredImage
        // set the frame to the full item frame size; the trimmed image will
        // be centered within the full bounds when displayed
        super.init(frame: NSRect(origin: .zero, size: item.frame.size))
        self.toolTip = item.displayName
        self.isEnabled = item.acceptsMouseEvents
        unregisterDraggedTypes()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        if !isDraggingPlaceholder {
            image.draw(
                in: bounds,
                from: .zero,
                operation: .sourceOver,
                fraction: item.acceptsMouseEvents ? 1.0 : 0.67
            )
        }
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)

        guard item.acceptsMouseEvents else {
            let alert = NSAlert()
            alert.messageText = "Item is not movable."
            alert.informativeText = "macOS prohibits \"\(item.displayName)\" from being moved."
            alert.runModal()
            return
        }

        let pasteboardItem = NSPasteboardItem()
        // contents of the pasteboard item don't matter here, as all needed
        // information is available directly from the dragging session; what
        // matters is that the type is set to `layoutBarItem`, as that is
        // what the layout bar registers for
        pasteboardItem.setData(Data(), forType: .layoutBarItem)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: image)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
}

// MARK: LayoutBarItemView: NSDraggingSource
extension LayoutBarItemView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        // make sure the container doesn't update its arranged
        // views during a dragging session
        if let container = superview as? LayoutBarContainer {
            container.canUpdateArrangedViews = false
        }

        // prevent the dragging image from animating back to its
        // original location
        session.animatesToStartingPositionsOnCancelOrFail = false

        // async to prevent the view from disappearing before the
        // dragging image appears
        DispatchQueue.main.async {
            self.isDraggingPlaceholder = true
        }
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        defer {
            // always remove container info at the end of a session
            oldContainerInfo = nil
        }

        // since the session's `animatesToStartingPositionsOnCancelOrFail`
        // property was set to false when the session began (above), there
        // is no delay between the user releasing the dragging item and
        // this method being called; thus, `isDraggingPlaceholder` only
        // needs to be updated here; if we ever decide we want animation,
        // it may also need to be updated inside `performDragOperation(_:)`
        // on `LayoutBarCocoaView`
        isDraggingPlaceholder = false

        // if the drop occurs outside of a container, reinsert the view
        // into its original container at its original index
        if !hasContainer {
            guard let (container, index) = oldContainerInfo else {
                return
            }
            container.shouldAnimateNextLayoutPass = false
            container.arrangedViews.insert(self, at: index)
        }
    }
}

// MARK: Layout Bar Item Pasteboard Type
extension NSPasteboard.PasteboardType {
    static let layoutBarItem = Self("\(Constants.bundleIdentifier).layout-bar-item")
}
