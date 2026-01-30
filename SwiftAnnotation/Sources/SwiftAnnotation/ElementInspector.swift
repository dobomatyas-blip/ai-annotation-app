#if canImport(UIKit)
import UIKit

/// Inspects the UIKit view hierarchy to extract information about UI elements
public final class ElementInspector {

    public init() {}

    /// Find the element at a given point in the window
    /// - Parameters:
    ///   - point: The point in window coordinates
    ///   - window: The window to search in
    /// - Returns: ElementInfo for the deepest view at that point, or nil
    public func findElement(at point: CGPoint, in window: UIWindow) -> ElementInfo? {
        guard let hitView = window.hitTest(point, with: nil) else {
            return nil
        }

        return extractElementInfo(from: hitView, in: window)
    }

    /// Extract element information from a UIView
    /// - Parameters:
    ///   - view: The view to extract info from
    ///   - window: The window containing the view
    /// - Returns: ElementInfo for the view
    public func extractElementInfo(from view: UIView, in window: UIWindow) -> ElementInfo {
        let typeName = extractTypeName(from: view)
        let hierarchyPath = buildHierarchyPath(for: view)
        let frame = view.convert(view.bounds, to: window)
        let depth = calculateDepth(of: view)

        return ElementInfo(
            typeName: typeName,
            hierarchyPath: hierarchyPath,
            accessibilityIdentifier: view.accessibilityIdentifier,
            accessibilityLabel: view.accessibilityLabel,
            accessibilityHint: view.accessibilityHint,
            frame: frame,
            debugDescription: extractDebugDescription(from: view),
            depth: depth
        )
    }

    /// Find all elements at a given point (from deepest to shallowest)
    /// - Parameters:
    ///   - point: The point in window coordinates
    ///   - window: The window to search in
    /// - Returns: Array of ElementInfo, ordered from deepest to shallowest
    public func findAllElements(at point: CGPoint, in window: UIWindow) -> [ElementInfo] {
        var elements: [ElementInfo] = []
        var currentView: UIView? = window.hitTest(point, with: nil)

        while let view = currentView {
            let info = extractElementInfo(from: view, in: window)
            elements.append(info)
            currentView = view.superview
        }

        return elements
    }

    // MARK: - Private Helpers

    /// Extract a clean type name from the view
    private func extractTypeName(from view: UIView) -> String {
        let fullName = String(describing: type(of: view))

        // Try to extract SwiftUI type name from hosting view descriptions
        if let swiftUIName = extractSwiftUITypeName(from: view) {
            return swiftUIName
        }

        // Clean up common UIKit prefixes for readability
        let cleanedName = fullName
            .replacingOccurrences(of: "_UI", with: "")
            .replacingOccurrences(of: "UI", with: "")

        // If it's a hosting view, indicate it's SwiftUI content
        if fullName.contains("HostingView") || fullName.contains("_UIHostingView") {
            return "SwiftUI.View"
        }

        return cleanedName.isEmpty ? fullName : cleanedName
    }

    /// Attempt to extract SwiftUI view type name from the view's debug description
    private func extractSwiftUITypeName(from view: UIView) -> String? {
        let debugDesc = String(describing: view)

        // Look for SwiftUI type patterns in the debug description
        if let range = debugDesc.range(of: "SwiftUI\\.") {
            let startIndex = range.upperBound
            if let endRange = debugDesc[startIndex...].firstIndex(where: { !$0.isLetter && !$0.isNumber && $0 != "_" }) {
                let typeName = String(debugDesc[startIndex..<endRange])
                if !typeName.isEmpty {
                    return typeName
                }
            }
        }

        // Check for common SwiftUI container patterns
        let knownPatterns: [(pattern: String, name: String)] = [
            ("_UIHostingView", "HostingView"),
            ("UIHostingView", "HostingView"),
            ("_TtGC7SwiftUI", "SwiftUI"),
            ("ScrollView", "ScrollView"),
            ("_UIGraphicsView", "GraphicsView"),
        ]

        for (pattern, name) in knownPatterns {
            if debugDesc.contains(pattern) || String(describing: type(of: view)).contains(pattern) {
                if let label = view.accessibilityLabel, !label.isEmpty {
                    return "\(name) (\(label))"
                }
                return name
            }
        }

        return nil
    }

    /// Build a hierarchy path string from the view to its root
    private func buildHierarchyPath(for view: UIView) -> String {
        var pathComponents: [String] = []
        var currentView: UIView? = view

        while let v = currentView {
            let name = extractTypeName(from: v)

            // Skip internal views that don't add meaningful information
            if !shouldSkipInPath(viewName: name, view: v) {
                pathComponents.insert(name, at: 0)
            }

            currentView = v.superview
        }

        // Limit path length for readability
        let maxComponents = 6
        if pathComponents.count > maxComponents {
            let start = pathComponents.prefix(2)
            let end = pathComponents.suffix(maxComponents - 3)
            return (Array(start) + ["..."] + Array(end)).joined(separator: " > ")
        }

        return pathComponents.joined(separator: " > ")
    }

    /// Determine if a view should be skipped in the hierarchy path
    private func shouldSkipInPath(viewName: String, view: UIView) -> Bool {
        // Skip internal implementation views
        let skipPatterns = [
            "TransitionView",
            "ContentView",
            "ViewControllerWrapperView",
            "_UIParallaxDimmingView",
            "_UIBarBackground",
        ]

        for pattern in skipPatterns {
            if viewName.contains(pattern) {
                return true
            }
        }

        // Skip views with no meaningful content (very small or hidden)
        if view.frame.width < 1 || view.frame.height < 1 {
            return true
        }

        return false
    }

    /// Calculate the depth of a view in the hierarchy
    private func calculateDepth(of view: UIView) -> Int {
        var depth = 0
        var currentView = view.superview

        while currentView != nil {
            depth += 1
            currentView = currentView?.superview
        }

        return depth
    }

    /// Extract useful debug description from the view
    private func extractDebugDescription(from view: UIView) -> String? {
        let className = String(describing: type(of: view))
        let frame = view.frame

        var description = "\(className) frame=\(frame)"

        if !view.isUserInteractionEnabled {
            description += " (interaction disabled)"
        }

        if view.isHidden {
            description += " (hidden)"
        }

        return description
    }
}

#elseif canImport(AppKit)
import AppKit

/// macOS implementation of ElementInspector using AppKit
public final class ElementInspector {

    /// Currently highlighted view for hover effect
    private weak var currentHoverView: NSView?
    /// Currently selected view
    private weak var currentSelectedView: NSView?

    /// Original layer properties to restore
    private var originalHoverBorderWidth: CGFloat = 0
    private var originalHoverBorderColor: CGColor?
    private var originalSelectedBorderWidth: CGFloat = 0
    private var originalSelectedBorderColor: CGColor?

    public init() {}

    /// Find the element at a given point in the window
    public func findElement(at point: CGPoint, in window: NSWindow) -> ElementInfo? {
        guard let contentView = window.contentView else { return nil }

        // Find the deepest meaningful view at this point
        let deepestView = findDeepestView(at: point, in: contentView, windowHeight: contentView.bounds.height)

        return extractElementInfo(from: deepestView, in: window)
    }

    /// Find view at point and apply hover highlight directly to it
    public func highlightElementOnHover(at point: CGPoint, in window: NSWindow) -> ElementInfo? {
        guard let contentView = window.contentView else { return nil }

        let deepestView = findDeepestView(at: point, in: contentView, windowHeight: contentView.bounds.height)

        // Skip if same view already highlighted
        if deepestView === currentHoverView {
            return extractElementInfo(from: deepestView, in: window)
        }

        // Remove highlight from previous view
        removeHoverHighlight()

        // Apply highlight to new view
        applyHoverHighlight(to: deepestView)

        return extractElementInfo(from: deepestView, in: window)
    }

    /// Apply hover highlight (orange border) directly to the view
    private func applyHoverHighlight(to view: NSView) {
        view.wantsLayer = true
        guard let layer = view.layer else { return }

        // Store original values
        originalHoverBorderWidth = layer.borderWidth
        originalHoverBorderColor = layer.borderColor

        // Apply hover style
        layer.borderWidth = 2
        layer.borderColor = NSColor.orange.cgColor

        currentHoverView = view
    }

    /// Remove hover highlight from current view
    public func removeHoverHighlight() {
        guard let view = currentHoverView, let layer = view.layer else {
            currentHoverView = nil
            return
        }

        // Restore original values
        layer.borderWidth = originalHoverBorderWidth
        layer.borderColor = originalHoverBorderColor

        currentHoverView = nil
    }

    /// Apply selection highlight (blue border) directly to the view
    public func selectElement(at point: CGPoint, in window: NSWindow) -> ElementInfo? {
        guard let contentView = window.contentView else { return nil }

        let deepestView = findDeepestView(at: point, in: contentView, windowHeight: contentView.bounds.height)

        // Remove any hover highlight first
        removeHoverHighlight()

        // Remove previous selection
        removeSelectionHighlight()

        // Apply selection highlight
        applySelectionHighlight(to: deepestView)

        return extractElementInfo(from: deepestView, in: window)
    }

    /// Apply selection highlight (blue border) to view
    private func applySelectionHighlight(to view: NSView) {
        view.wantsLayer = true
        guard let layer = view.layer else { return }

        // Store original values
        originalSelectedBorderWidth = layer.borderWidth
        originalSelectedBorderColor = layer.borderColor

        // Apply selection style
        layer.borderWidth = 3
        layer.borderColor = NSColor.systemBlue.cgColor

        currentSelectedView = view
    }

    /// Remove selection highlight from current view
    public func removeSelectionHighlight() {
        guard let view = currentSelectedView, let layer = view.layer else {
            currentSelectedView = nil
            return
        }

        // Restore original values
        layer.borderWidth = originalSelectedBorderWidth
        layer.borderColor = originalSelectedBorderColor

        currentSelectedView = nil
    }

    /// Clear all highlights
    public func clearAllHighlights() {
        removeHoverHighlight()
        removeSelectionHighlight()
    }

    /// Find the deepest view containing the point - combines hitTest with manual search
    private func findDeepestView(at windowPoint: CGPoint, in view: NSView, windowHeight: CGFloat) -> NSView {
        // First, collect ALL views that contain this point
        var candidates: [(view: NSView, area: CGFloat, depth: Int, hasAccessibility: Bool)] = []
        collectViewsAtPoint(windowPoint, in: view, depth: 0, candidates: &candidates)

        // Filter out overlay views
        candidates = candidates.filter { candidate in
            let typeName = String(describing: type(of: candidate.view))
            return !shouldSkipView(typeName)
        }

        // Calculate the total window area to filter out very large containers
        let windowArea = view.bounds.width * view.bounds.height
        let maxAcceptableArea = windowArea * 0.7  // Don't select views larger than 70% of window

        // Filter out views that are too large (full-screen containers)
        let reasonableCandidates = candidates.filter { $0.area < maxAcceptableArea && $0.area > 10 }

        // If we have reasonable candidates, use them; otherwise fall back to all
        let workingCandidates = reasonableCandidates.isEmpty ? candidates : reasonableCandidates

        // Sort with priority:
        // 1. Has accessibility identifier (most specific)
        // 2. Deeper in hierarchy
        // 3. Smaller area
        var sorted = workingCandidates.sorted { a, b in
            // Prefer views with accessibility info
            if a.hasAccessibility != b.hasAccessibility {
                return a.hasAccessibility
            }
            // Then by depth (deepest first)
            if a.depth != b.depth {
                return a.depth > b.depth
            }
            // Then by area (smallest first)
            return a.area < b.area
        }

        // Return the best candidate (smallest with accessibility, or deepest smallest)
        for candidate in sorted {
            if candidate.area > 10 {
                return candidate.view
            }
        }

        // Fallback to first candidate or the root view
        return sorted.first?.view ?? view
    }

    /// Recursively collect all views that contain the given point
    private func collectViewsAtPoint(_ windowPoint: CGPoint, in view: NSView, depth: Int, candidates: inout [(view: NSView, area: CGFloat, depth: Int, hasAccessibility: Bool)]) {
        // Check if point is within this view
        let localPoint = view.convert(windowPoint, from: nil)
        guard view.bounds.contains(localPoint) else { return }

        // Skip hidden or transparent views
        guard !view.isHidden && view.alphaValue >= 0.01 else { return }

        // Check if view has meaningful accessibility info
        let hasAccessibilityId = !view.accessibilityIdentifier().isEmpty
        let hasAccessibilityLabel = view.accessibilityLabel() != nil && !view.accessibilityLabel()!.isEmpty
        let hasAccessibility = hasAccessibilityId || hasAccessibilityLabel

        // Add this view as a candidate
        let area = view.bounds.width * view.bounds.height
        candidates.append((view: view, area: area, depth: depth, hasAccessibility: hasAccessibility))

        // Recurse into subviews
        for subview in view.subviews {
            collectViewsAtPoint(windowPoint, in: subview, depth: depth + 1, candidates: &candidates)
        }
    }

    /// Check if a view should be skipped during traversal
    private func shouldSkipView(_ typeName: String) -> Bool {
        let skipPatterns = [
            "AnnotationOverlay",
            "TapCapture",
            "MouseTracking",
            "_NSThemeWidget",
            "NSTitlebarContainerView",
            "NSToolbarView",
        ]

        for pattern in skipPatterns {
            if typeName.contains(pattern) {
                return true
            }
        }
        return false
    }

    /// Extract element information from an NSView
    public func extractElementInfo(from view: NSView, in window: NSWindow) -> ElementInfo {
        var typeName = extractTypeName(from: view)
        let hierarchyPath = buildHierarchyPath(for: view)

        // Get frame in window coordinates
        let frameInWindow = view.convert(view.bounds, to: nil)

        // Flip Y for SwiftUI coordinate system (origin at top-left)
        let windowHeight = window.contentView?.bounds.height ?? window.frame.height
        let flippedFrame = CGRect(
            x: frameInWindow.origin.x,
            y: windowHeight - frameInWindow.maxY,
            width: frameInWindow.width,
            height: frameInWindow.height
        )

        let depth = calculateDepth(of: view)

        // Try to get more specific accessibility info
        var accessibilityId: String? = {
            let id = view.accessibilityIdentifier()
            return id.isEmpty ? nil : id
        }()

        var accessibilityLbl: String? = view.accessibilityLabel()
        var accessibilityHnt: String? = view.accessibilityHelp()

        // Check accessibility children for more specific info
        if let children = view.accessibilityChildren() {
            for child in children {
                // Check if child is NSView with accessibility
                if let childView = child as? NSView {
                    if let childLabel = childView.accessibilityLabel(), !childLabel.isEmpty {
                        if accessibilityLbl == nil || accessibilityLbl!.isEmpty {
                            accessibilityLbl = childLabel
                            // Update type name to include label
                            if !typeName.contains("\"") {
                                typeName = "\(typeName) \"\(childLabel)\""
                            }
                        }
                    }
                    let childId = childView.accessibilityIdentifier()
                    if !childId.isEmpty && accessibilityId == nil {
                        accessibilityId = childId
                    }
                }
            }
        }

        // Also check accessibilityRole for better type naming
        if let role = view.accessibilityRole() {
            if typeName == "View" || typeName == "SwiftUI.View" || typeName.contains("CGDrawingView") {
                switch role {
                case .button: typeName = "Button"
                case .staticText: typeName = "Text"
                case .image: typeName = "Image"
                case .textField: typeName = "TextField"
                case .checkBox: typeName = "Toggle"
                case .slider: typeName = "Slider"
                case .link: typeName = "Link"
                case .list: typeName = "List"
                case .table: typeName = "Table"
                case .scrollArea: typeName = "ScrollView"
                case .tabGroup: typeName = "TabView"
                default: break
                }

                // Add label to type name if we have one
                if let label = accessibilityLbl, !label.isEmpty, !typeName.contains("\"") {
                    typeName = "\(typeName) \"\(label)\""
                }
            }
        }

        return ElementInfo(
            typeName: typeName,
            hierarchyPath: hierarchyPath,
            accessibilityIdentifier: accessibilityId,
            accessibilityLabel: accessibilityLbl,
            accessibilityHint: accessibilityHnt,
            frame: flippedFrame,
            debugDescription: extractDebugDescription(from: view),
            depth: depth
        )
    }

    private func extractTypeName(from view: NSView) -> String {
        let fullName = String(describing: type(of: view))

        // Check for SwiftUI component patterns first
        if let swiftUIName = detectSwiftUIComponent(fullName, view: view) {
            return swiftUIName
        }

        // Check accessibility for better naming
        if let label = view.accessibilityLabel(), !label.isEmpty {
            let baseName = cleanTypeName(fullName)
            return "\(baseName) \"\(label)\""
        }

        let identifier = view.accessibilityIdentifier()
        if !identifier.isEmpty {
            let baseName = cleanTypeName(fullName)
            return "\(baseName) [\(identifier)]"
        }

        return cleanTypeName(fullName)
    }

    private func detectSwiftUIComponent(_ fullName: String, view: NSView) -> String? {
        // Map known SwiftUI internal class names to readable names
        // Order matters - more specific patterns first
        let componentPatterns: [(pattern: String, name: String)] = [
            // Text rendering views
            ("CGDrawingView", "Text/Image"),
            ("_NSTextLayoutView", "Text"),
            ("NSTextView", "Text"),
            ("AttributedString", "Text"),
            ("StyledText", "Text"),
            ("StaticText", "Text"),
            // Image views
            ("ImageView", "Image"),
            ("NSImageView", "Image"),
            ("CGImage", "Image"),
            // Buttons
            ("ButtonStyleConfiguration", "Button"),
            ("PressableButton", "Button"),
            ("AccessoryButton", "Button"),
            ("PlainButton", "Button"),
            ("Button", "Button"),
            // Text input
            ("SecureTextField", "SecureField"),
            ("TextFieldContent", "TextField"),
            ("TextField", "TextField"),
            ("SearchField", "SearchField"),
            // Controls
            ("Toggle", "Toggle"),
            ("CheckBox", "Toggle"),
            ("Switch", "Toggle"),
            ("Slider", "Slider"),
            ("Stepper", "Stepper"),
            ("Picker", "Picker"),
            ("DatePicker", "DatePicker"),
            ("ColorPicker", "ColorPicker"),
            ("ProgressView", "ProgressView"),
            // Labels
            ("Label", "Label"),
            ("Text", "Text"),
            ("Image", "Image"),
            // Containers
            ("List", "List"),
            ("Table", "Table"),
            ("ScrollView", "ScrollView"),
            ("TabView", "TabView"),
            ("NavigationStack", "NavigationStack"),
            ("NavigationView", "NavigationView"),
            ("SplitView", "SplitView"),
            // Stacks
            ("VStack", "VStack"),
            ("HStack", "HStack"),
            ("ZStack", "ZStack"),
            ("LazyVStack", "LazyVStack"),
            ("LazyHStack", "LazyHStack"),
            ("LazyVGrid", "LazyVGrid"),
            ("LazyHGrid", "LazyHGrid"),
            // Layout
            ("Form", "Form"),
            ("Section", "Section"),
            ("Group", "Group"),
            ("Divider", "Divider"),
            ("Spacer", "Spacer"),
            // Shape views
            ("RoundedRectangle", "RoundedRectangle"),
            ("Rectangle", "Rectangle"),
            ("Circle", "Circle"),
            ("Ellipse", "Ellipse"),
            ("Capsule", "Capsule"),
            // Generic SwiftUI
            ("DisplayList", "View"),
            ("PlatformGroupContainer", "Group"),
            ("LayoutContainer", "Container"),
        ]

        for (pattern, name) in componentPatterns {
            if fullName.contains(pattern) {
                // Add accessibility info if available
                if let label = view.accessibilityLabel(), !label.isEmpty {
                    return "\(name) \"\(label)\""
                }
                let id = view.accessibilityIdentifier()
                if !id.isEmpty {
                    return "\(name) [\(id)]"
                }
                return name
            }
        }

        if fullName.contains("HostingView") {
            return "SwiftUI.View"
        }

        return nil
    }

    private func cleanTypeName(_ fullName: String) -> String {
        var name = fullName

        // Handle mangled Swift generic names first
        if fullName.hasPrefix("_Tt") || fullName.contains("_Tt") {
            // Try to extract meaningful parts
            if fullName.contains("Text") { return "Text" }
            if fullName.contains("Image") { return "Image" }
            if fullName.contains("Button") { return "Button" }
            if fullName.contains("Stack") { return "Stack" }
            if fullName.contains("SwiftUI") { return "SwiftUI.View" }
            return "View"
        }

        // Remove common prefixes
        let prefixes = ["_NS", "NS", "SwiftUI.", "_"]
        for prefix in prefixes {
            if name.hasPrefix(prefix) {
                name = String(name.dropFirst(prefix.count))
                break  // Only remove one prefix
            }
        }

        // Clean up generic type parameters
        if let genericStart = name.firstIndex(of: "<") {
            name = String(name[..<genericStart])
        }

        return name.isEmpty ? fullName : name
    }

    private func buildHierarchyPath(for view: NSView) -> String {
        var pathComponents: [String] = []
        var currentView: NSView? = view

        while let v = currentView {
            let name = extractTypeName(from: v)

            // Skip internal wrapper views
            if !shouldSkipInPath(name) {
                pathComponents.insert(name, at: 0)
            }

            currentView = v.superview
        }

        // Limit path length
        let maxComponents = 6
        if pathComponents.count > maxComponents {
            let start = pathComponents.prefix(2)
            let end = pathComponents.suffix(maxComponents - 3)
            return (Array(start) + ["..."] + Array(end)).joined(separator: " > ")
        }

        return pathComponents.joined(separator: " > ")
    }

    private func shouldSkipInPath(_ name: String) -> Bool {
        let skipPatterns = [
            "ThemeFrame",
            "ClipView",
            "FlippedView",
            "_TtC",
            "LayoutHost",
            "PlatformView",
            "MouseTracking",
            "AnnotationOverlay",
            "TapCapture",
            "ContentView",
            "HostingView",
            "NSSplitView",
            "NSVisualEffect",
        ]

        for pattern in skipPatterns {
            if name.contains(pattern) {
                return true
            }
        }

        return false
    }

    private func calculateDepth(of view: NSView) -> Int {
        var depth = 0
        var currentView = view.superview

        while currentView != nil {
            depth += 1
            currentView = currentView?.superview
        }

        return depth
    }

    private func extractDebugDescription(from view: NSView) -> String? {
        let className = String(describing: type(of: view))
        let frame = view.frame
        var description = "\(className) frame=\(frame)"

        if view.isHidden {
            description += " (hidden)"
        }

        return description
    }
}

#endif
