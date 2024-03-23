//
//  LayoutBarContainer.swift
//  Ice
//

import Cocoa
import Combine

/// A container for the items in the menu bar layout interface.
///
/// The purpose of a container view is to hold visual representations of
/// the menu bar items in the menu bar. As an implementation detail, container
/// views also manage the layout of those representations on behalf of a
/// parent view.
///
/// As the container updates the layout of its arranged menu bar item views,
/// it automatically resizes itself using constraints that it maintains
/// internally. The container view is displayed inside of a parent view (an
/// instance of ``LayoutBarCocoaView``), and is never presented as a
/// standalone view. The parent view provides space for the container view
/// to "float" in as it grows and shrinks according to the number of arranged
/// views it holds. The width of the parent view is constrained to be greater
/// than or equal to that of the container. To mimic the appearance of the
/// system menu bar, the parent view pins the trailing edge of the container
/// view to its own trailing edge. This ensures that any aforementioned
/// "floating" occurs on the container's leading edge.
class LayoutBarContainer: NSView {
    /// Phases for a dragging session.
    enum DraggingPhase {
        case entered
        case exited
        case updated
        case ended
    }

    /// Cached width constraint for the container view.
    private lazy var widthConstraint: NSLayoutConstraint = {
        let constraint = widthAnchor.constraint(equalToConstant: 0)
        constraint.isActive = true
        return constraint
    }()

    /// Cached height constraint for the container view.
    private lazy var heightConstraint: NSLayoutConstraint = {
        let constraint = heightAnchor.constraint(equalToConstant: 0)
        constraint.isActive = true
        return constraint
    }()

    /// The shared menu bar item manager instance.
    let itemManager: MenuBarItemManager

    /// The section whose items are represented.
    let section: MenuBarSection

    /// A Boolean value that indicates whether the container should
    /// animate its next layout pass.
    ///
    /// After each layout pass, this value is reset to `true`.
    var shouldAnimateNextLayoutPass = true

    /// A Boolean value that indicates whether the container can
    /// set its arranged views.
    var canSetArrangedViews = true

    /// The amount of space between each arranged view.
    var spacing: CGFloat {
        didSet {
            layoutArrangedViews()
        }
    }

    /// The contaner's arranged views.
    ///
    /// The views are laid out from left to right in the order that they
    /// appear in the array. The ``spacing`` property determines the amount
    /// of space between each view.
    var arrangedViews = [LayoutBarItemView]() {
        didSet {
            layoutArrangedViews(oldViews: oldValue)
        }
    }

    private var cancellables = Set<AnyCancellable>()

    /// Creates a container view with the given menu bar item manager,
    /// section, and spacing.
    ///
    /// - Parameters:
    ///   - itemManager: The shared menu bar item manager instance.
    ///   - section: The section whose items are represented.
    ///   - spacing: The amount of space between each arranged view.
    init(itemManager: MenuBarItemManager, section: MenuBarSection, spacing: CGFloat) {
        self.itemManager = itemManager
        self.section = section
        self.spacing = spacing
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        unregisterDraggedTypes()
        configureCancellables()
        setArrangedViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        section.$menuBarItems
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setArrangedViews()
            }
            .store(in: &c)

        itemManager.$cachedItemImages
            .throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.setArrangedViews()
            }
            .store(in: &c)

        cancellables = c
    }

    /// Performs layout of the container's arranged views.
    ///
    /// The container removes from its subviews the views that are included
    /// in the `oldViews` array but not in the the current ``arrangedViews``
    /// array. Views that are found in both arrays, but at different indices
    /// are animated from their old index to their new index.
    ///
    /// - Parameter oldViews: The old value of the container's arranged views.
    ///   Pass `nil` to use the current ``arrangedViews`` array.
    private func layoutArrangedViews(oldViews: [LayoutBarItemView]? = nil) {
        defer {
            shouldAnimateNextLayoutPass = true
        }

        let oldViews = oldViews ?? arrangedViews

        // remove views that are no longer part of the arranged views
        for view in oldViews where !arrangedViews.contains(view) {
            view.removeFromSuperview()
            view.hasContainer = false
        }

        // retain the previous view on each iteration; use its frame
        // to calculate the x coordinate of the next view's origin
        var previous: NSView?

        // get the max height of all arranged views to calculate the
        // y coordinate of each view's origin
        let maxHeight = arrangedViews.lazy
            .map { $0.bounds.height }
            .max() ?? 0

        for var view in arrangedViews {
            if subviews.contains(view) {
                // view already exists inside the layout view, but may
                // have moved from its previous location;
                if shouldAnimateNextLayoutPass {
                    // replace the view with its animator proxy
                    view = view.animator()
                }
            } else {
                // view does not already exist inside the layout view;
                // add it as a subview
                addSubview(view)
                view.hasContainer = true
            }

            // set the view's origin; if the view is an animator proxy,
            // it will animate to the new position; otherwise, it must
            // be a newly added view
            view.setFrameOrigin(
                CGPoint(
                    x: previous.map { $0.frame.maxX + spacing } ?? 0,
                    y: (maxHeight / 2) - view.bounds.midY
                )
            )

            previous = view // retain the view
        }

        // update the width and height constraints using the information
        // collected while iterating
        widthConstraint.constant = previous?.frame.maxX ?? 0
        heightConstraint.constant = maxHeight
    }

    /// Sets the container's arranged views its section's menu bar items.
    ///
    /// - Note: If the value of the container's ``canSetArrangedViews``
    ///   property is `false`, this function returns early.
    func setArrangedViews() {
        guard
            canSetArrangedViews,
            let menuBarManager = itemManager.menuBarManager,
            let profile = menuBarManager.activeProfile,
            let display = DisplayInfo.main
        else {
            return
        }

        var itemInfo = profile.itemInfoForSection(withName: section.name)

        if case .visible = section.name {
            // get the stationary items (i.e. Clock, Siri, Control Center)
            // and prepend them to the item info
            let stationaryInfo = MenuBarProfile.stationaryItemInfo(menuBarManager: menuBarManager)
            itemInfo.insert(contentsOf: stationaryInfo, at: 0)
        }

        // we need to reverse the item info, as profiles represent items
        // in reverse order from how they are displayed
        itemInfo.reverse()

        arrangedViews = itemInfo.compactMap { info in
            if info.isSpecial {
                switch info {
                case .newItems:
                    SpecialLayoutBarItemView(kind: .newItems)
                default:
                    nil
                }
            } else if let item = section.menuBarItems.first(where: { $0.matches(info) }) {
                StandardLayoutBarItemView(item: item, display: display, itemManager: itemManager)
            } else {
                nil
            }
        }
    }

    /// Updates the positions of the container's arranged views using the
    /// specified dragging information and phase.
    ///
    /// - Parameters:
    ///   - draggingInfo: The dragging information to use to update the
    ///     container's arranged views.
    ///   - phase: The current dragging phase of the container.
    /// - Returns: A dragging operation.
    @discardableResult
    func updateArrangedViewsForDrag(with draggingInfo: NSDraggingInfo, phase: DraggingPhase) -> NSDragOperation {
        guard let sourceView = draggingInfo.draggingSource as? LayoutBarItemView else {
            return []
        }
        switch phase {
        case .entered:
            if !arrangedViews.contains(sourceView) {
                shouldAnimateNextLayoutPass = false
            }
            return updateArrangedViewsForDrag(with: draggingInfo, phase: .updated)
        case .exited:
            if let sourceIndex = arrangedViews.firstIndex(of: sourceView) {
                shouldAnimateNextLayoutPass = false
                arrangedViews.remove(at: sourceIndex)
            }
            return .move
        case .updated:
            if
                sourceView.oldContainerInfo == nil,
                let sourceIndex = arrangedViews.firstIndex(of: sourceView)
            {
                sourceView.oldContainerInfo = (self, sourceIndex)
            }
            // updating normally relies on the presence of other arranged views,
            // but if the container is empty, it needs to be handled separately
            guard !arrangedViews.isEmpty else {
                arrangedViews.append(sourceView)
                return .move
            }
            // convert dragging location from window coordinates
            let draggingLocation = convert(draggingInfo.draggingLocation, from: nil)
            guard
                let destinationView = arrangedView(nearestTo: draggingLocation.x),
                destinationView !== sourceView,
                // don't rearrange if destination is disabled
                destinationView.isEnabled,
                // don't rearrange if in the middle of an animation
                destinationView.layer?.animationKeys() == nil,
                let destinationIndex = arrangedViews.firstIndex(of: destinationView)
            else {
                return .move
            }
            // drag must be near the horizontal center of the destination
            // view to trigger a swap
            let midX = destinationView.frame.midX
            let offset = destinationView.frame.width / 2
            if !((midX - offset)...(midX + offset)).contains(draggingLocation.x) {
                if sourceView.oldContainerInfo?.container === self {
                    return .move
                }
            }
            if let sourceIndex = arrangedViews.firstIndex(of: sourceView) {
                // source view is already inside this container, so move
                // it from its old index to the new one
                var targetIndex = destinationIndex
                if destinationIndex > sourceIndex {
                    targetIndex += 1
                }
                arrangedViews.move(fromOffsets: [sourceIndex], toOffset: targetIndex)
            } else {
                // source view is being dragged from another container,
                // so just insert it
                arrangedViews.insert(sourceView, at: destinationIndex)
            }
            return .move
        case .ended:
            return .move
        }
    }

    /// Returns the nearest arranged view to the given X position within
    /// the coordinate system of the container view.
    ///
    /// The nearest arranged view is defined as the arranged view whose
    /// horizontal center is closest to `xPosition`.
    ///
    /// - Parameter xPosition: A floating point value representing an X
    ///   position within the coordinate system of the container view.
    func arrangedView(nearestTo xPosition: CGFloat) -> LayoutBarItemView? {
        arrangedViews.min { view1, view2 in
            let distance1 = abs(view1.frame.midX - xPosition)
            let distance2 = abs(view2.frame.midX - xPosition)
            return distance1 < distance2
        }
    }

    /// Returns the arranged view at the given index.
    ///
    /// - Parameter index: The index of the arranged view to return.
    func arrangedView(atIndex index: Int) -> LayoutBarItemView? {
        guard arrangedViews.indices.contains(index) else {
            return nil
        }
        return arrangedViews[index]
    }

    /// Returns the index of the given arranged view.
    ///
    /// - Parameter arrangedView: The arranged view to search for.
    func index(of arrangedView: LayoutBarItemView) -> Int? {
        arrangedViews.firstIndex(of: arrangedView)
    }
}
