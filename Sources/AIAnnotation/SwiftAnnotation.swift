import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Public View Modifier

public extension View {
    /// Adds an annotation overlay to the view hierarchy
    ///
    /// When enabled, users can tap any UI element to select it, view its details,
    /// and copy a markdown annotation to the clipboard for use with AI agents.
    ///
    /// Usage:
    /// ```swift
    /// struct ContentView: View {
    ///     @State private var showAnnotations = false
    ///
    ///     var body: some View {
    ///         NavigationStack {
    ///             // Your content
    ///         }
    ///         .annotationOverlay(enabled: $showAnnotations)
    ///     }
    /// }
    /// ```
    func annotationOverlay(
        enabled: Binding<Bool>,
        onAnnotationCopied: ((String) -> Void)? = nil
    ) -> some View {
        modifier(AnnotationOverlayModifier(
            isEnabled: enabled,
            onAnnotationCopied: onAnnotationCopied
        ))
    }

    /// Adds an annotation overlay with simple boolean control
    func annotationOverlay(
        enabled: Bool,
        onAnnotationCopied: ((String) -> Void)? = nil
    ) -> some View {
        modifier(AnnotationOverlayModifier(
            isEnabled: .constant(enabled),
            onAnnotationCopied: onAnnotationCopied
        ))
    }
}

// MARK: - View Modifier

private struct AnnotationOverlayModifier: ViewModifier {
    @Binding var isEnabled: Bool
    let onAnnotationCopied: ((String) -> Void)?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isEnabled {
                    AnnotationOverlay(
                        isEnabled: $isEnabled,
                        onAnnotationCopied: onAnnotationCopied
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - Shake Gesture Support (iOS only)

#if canImport(UIKit)

public extension View {
    /// Enables annotation mode when the device is shaken
    func annotationOnShake(
        onAnnotationCopied: ((String) -> Void)? = nil
    ) -> some View {
        modifier(ShakeAnnotationModifier(onAnnotationCopied: onAnnotationCopied))
    }
}

private struct ShakeAnnotationModifier: ViewModifier {
    let onAnnotationCopied: ((String) -> Void)?
    @State private var isAnnotationEnabled = false

    func body(content: Content) -> some View {
        content
            .annotationOverlay(enabled: $isAnnotationEnabled, onAnnotationCopied: onAnnotationCopied)
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                withAnimation {
                    isAnnotationEnabled = true
                }
            }
    }
}

// Shake gesture detection
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

#endif

// MARK: - Debug Toggle Button

/// A floating button to toggle annotation mode
public struct AnnotationToggleButton: View {
    @Binding var isAnnotationEnabled: Bool

    public init(isAnnotationEnabled: Binding<Bool>) {
        self._isAnnotationEnabled = isAnnotationEnabled
    }

    public var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                isAnnotationEnabled.toggle()
            }
        } label: {
            Image(systemName: isAnnotationEnabled ? "xmark.circle.fill" : "hand.tap.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .padding(14)
                .background(isAnnotationEnabled ? Color.red : Color.blue)
                .clipShape(Circle())
                .shadow(radius: 5)
        }
        #if os(macOS)
        .buttonStyle(.plain)
        #endif
    }
}

// MARK: - Convenience Extensions

public extension View {
    /// Adds both the annotation overlay and a toggle button
    func withAnnotationButton(
        alignment: Alignment = .bottomTrailing,
        padding: CGFloat = 20,
        onAnnotationCopied: ((String) -> Void)? = nil
    ) -> some View {
        modifier(AnnotationButtonModifier(
            alignment: alignment,
            padding: padding,
            onAnnotationCopied: onAnnotationCopied
        ))
    }
}

private struct AnnotationButtonModifier: ViewModifier {
    let alignment: Alignment
    let padding: CGFloat
    let onAnnotationCopied: ((String) -> Void)?

    @State private var isAnnotationEnabled = false

    func body(content: Content) -> some View {
        content
            .annotationOverlay(enabled: $isAnnotationEnabled, onAnnotationCopied: onAnnotationCopied)
            .overlay(alignment: alignment) {
                if !isAnnotationEnabled {
                    AnnotationToggleButton(isAnnotationEnabled: $isAnnotationEnabled)
                        .padding(padding)
                }
            }
    }
}

// MARK: - Configuration

/// Configuration options for SwiftAnnotation
public struct AnnotationConfiguration {
    /// Whether to show the element's frame coordinates
    public var showFrame: Bool

    /// Whether to show the hierarchy path
    public var showHierarchy: Bool

    /// Whether to show accessibility information
    public var showAccessibility: Bool

    /// Maximum depth to show in hierarchy path
    public var maxHierarchyDepth: Int

    /// Default configuration
    public static let `default` = AnnotationConfiguration(
        showFrame: true,
        showHierarchy: true,
        showAccessibility: true,
        maxHierarchyDepth: 6
    )

    public init(
        showFrame: Bool = true,
        showHierarchy: Bool = true,
        showAccessibility: Bool = true,
        maxHierarchyDepth: Int = 6
    ) {
        self.showFrame = showFrame
        self.showHierarchy = showHierarchy
        self.showAccessibility = showAccessibility
        self.maxHierarchyDepth = maxHierarchyDepth
    }
}
