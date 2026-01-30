import Foundation
import CoreGraphics

/// Represents information about a UI element captured during annotation
public struct ElementInfo: Identifiable, Equatable {
    public let id = UUID()

    /// The type name of the element (e.g., "Button", "Text", "VStack")
    public let typeName: String

    /// The hierarchy path from root to this element (e.g., "NavigationStack > VStack > Button")
    public let hierarchyPath: String

    /// The accessibility identifier if set by the developer
    public let accessibilityIdentifier: String?

    /// The accessibility label if set
    public let accessibilityLabel: String?

    /// The accessibility hint if set
    public let accessibilityHint: String?

    /// The frame of the element in screen coordinates
    public let frame: CGRect

    /// Additional debug description from the view
    public let debugDescription: String?

    /// The depth level in the view hierarchy (0 = root)
    public let depth: Int

    public init(
        typeName: String,
        hierarchyPath: String,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        frame: CGRect,
        debugDescription: String? = nil,
        depth: Int = 0
    ) {
        self.typeName = typeName
        self.hierarchyPath = hierarchyPath
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.frame = frame
        self.debugDescription = debugDescription
        self.depth = depth
    }

    /// A short summary of the element for display
    public var summary: String {
        var parts: [String] = [typeName]

        if let id = accessibilityIdentifier, !id.isEmpty {
            parts.append("(\(id))")
        } else if let label = accessibilityLabel, !label.isEmpty {
            parts.append("\"\(label)\"")
        }

        return parts.joined(separator: " ")
    }

    /// Frame formatted as a string
    public var frameString: String {
        String(format: "(%.0f, %.0f, %.0f, %.0f)",
               frame.origin.x, frame.origin.y,
               frame.size.width, frame.size.height)
    }

    public static func == (lhs: ElementInfo, rhs: ElementInfo) -> Bool {
        lhs.id == rhs.id
    }
}
