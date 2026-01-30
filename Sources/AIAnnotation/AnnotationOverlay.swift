import SwiftUI

#if canImport(UIKit)
import UIKit

/// A transparent overlay that captures taps and highlights selected elements
struct AnnotationOverlay: View {
    @Binding var isEnabled: Bool
    let onAnnotationCopied: ((String) -> Void)?

    @State private var selectedElement: ElementInfo?
    @State private var highlightFrame: CGRect = .zero
    @State private var showSheet = false
    @State private var showTooltip = false

    private let inspector = ElementInspector()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background when element is selected
                if selectedElement != nil {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                // Highlight rectangle for selected element
                if selectedElement != nil && highlightFrame != .zero {
                    highlightView
                }

                // Tooltip showing element info
                if showTooltip, let element = selectedElement {
                    tooltipView(for: element, in: geometry)
                }

                // Invisible tap capture layer
                TapCaptureView { point in
                    handleTap(at: point)
                }
                .ignoresSafeArea()

                // Control bar at bottom
                VStack {
                    Spacer()
                    controlBar
                }
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showSheet) {
            if let element = selectedElement {
                AnnotationSheet(
                    element: element,
                    onDismiss: {
                        showSheet = false
                        clearSelection()
                    },
                    onCopy: { markdown in
                        onAnnotationCopied?(markdown)
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .animation(.spring(response: 0.3), value: selectedElement?.id)
        .animation(.spring(response: 0.3), value: highlightFrame)
    }

    // MARK: - Views

    private var highlightView: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.blue, lineWidth: 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.1))
            )
            .frame(width: highlightFrame.width, height: highlightFrame.height)
            .position(
                x: highlightFrame.midX,
                y: highlightFrame.midY
            )
            .allowsHitTesting(false)
    }

    private func tooltipView(for element: ElementInfo, in geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(element.typeName)
                .font(.headline)
                .foregroundStyle(.white)

            if let accessibilityId = element.accessibilityIdentifier, !accessibilityId.isEmpty {
                Text("id: \(accessibilityId)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Text(element.hierarchyPath)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(2)
        }
        .padding(12)
        .background(Color.black.opacity(0.85))
        .cornerRadius(10)
        .shadow(radius: 10)
        .frame(maxWidth: 280)
        .position(tooltipPosition(for: highlightFrame, in: geometry))
        .allowsHitTesting(false)
    }

    private var controlBar: some View {
        HStack(spacing: 16) {
            if selectedElement != nil {
                Button {
                    clearSelection()
                } label: {
                    Label("Clear", systemImage: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(25)
                }

                Button {
                    showSheet = true
                } label: {
                    Label("Annotate", systemImage: "square.and.pencil")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(25)
                }
            }

            Button {
                isEnabled = false
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.gray.opacity(0.8))
                    .clipShape(Circle())
            }
        }
        .shadow(radius: 10)
    }

    // MARK: - Helpers

    private func handleTap(at point: CGPoint) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })
        else { return }

        if let element = inspector.findElement(at: point, in: window) {
            selectElement(element)
        }
    }

    private func selectElement(_ element: ElementInfo) {
        withAnimation(.spring(response: 0.25)) {
            selectedElement = element
            highlightFrame = element.frame
            showTooltip = true
        }
    }

    private func clearSelection() {
        withAnimation(.spring(response: 0.25)) {
            selectedElement = nil
            highlightFrame = .zero
            showTooltip = false
        }
    }

    private func tooltipPosition(for frame: CGRect, in geometry: GeometryProxy) -> CGPoint {
        let tooltipHeight: CGFloat = 80
        let padding: CGFloat = 12

        // Position above the element if there's room, otherwise below
        let yAbove = frame.minY - tooltipHeight / 2 - padding
        let yBelow = frame.maxY + tooltipHeight / 2 + padding

        let y = yAbove > geometry.safeAreaInsets.top + 20 ? yAbove : yBelow

        // Center horizontally, but keep within bounds
        let x = min(max(frame.midX, 150), geometry.size.width - 150)

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Tap Capture UIViewRepresentable

/// UIKit view that captures all taps and reports their location
private struct TapCaptureView: UIViewRepresentable {
    let onTap: (CGPoint) -> Void

    func makeUIView(context: Context) -> TapCaptureUIView {
        let view = TapCaptureUIView()
        view.onTap = onTap
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: TapCaptureUIView, context: Context) {
        uiView.onTap = onTap
    }
}

private class TapCaptureUIView: UIView {
    var onTap: ((CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGesture()
    }

    private func setupGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: window)
        onTap?(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self
    }
}

#elseif canImport(AppKit)
import AppKit

/// Stored annotation for history
struct AnnotationEntry: Identifiable {
    let id = UUID()
    let element: ElementInfo
    let feedback: String
    let timestamp: Date
    let markdown: String
}

/// Persistent storage for annotations that survives overlay hide/show
final class AnnotationStorage: ObservableObject {
    static let shared = AnnotationStorage()
    @Published var annotations: [AnnotationEntry] = []

    private init() {}

    func add(_ entry: AnnotationEntry) {
        annotations.append(entry)
    }

    func remove(_ entry: AnnotationEntry) {
        annotations.removeAll { $0.id == entry.id }
    }

    func clear() {
        annotations.removeAll()
    }
}

/// macOS implementation of annotation overlay with hover support and inline annotations
struct AnnotationOverlay: View {
    @Binding var isEnabled: Bool
    let onAnnotationCopied: ((String) -> Void)?

    // Element states
    @State private var hoveredElement: ElementInfo?
    @State private var hoveredFrame: CGRect = .zero
    @State private var selectedElement: ElementInfo?
    @State private var selectedFrame: CGRect = .zero

    // UI states
    @State private var showInlinePopup = false
    @State private var feedbackText: String = ""
    @State private var showHistory = false
    @State private var showCopiedBanner = false
    @FocusState private var isTextFieldFocused: Bool

    // Persistent annotation history (survives overlay hide/show)
    @ObservedObject private var storage = AnnotationStorage.shared

    private let inspector = ElementInspector()
    private let formatter = MarkdownFormatter()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Mouse tracking layer (transparent, captures events)
                MouseTrackingView(
                    onHover: { point in
                        handleHover(at: point, in: geometry)
                    },
                    onClick: { point in
                        handleClick(at: point, in: geometry)
                    },
                    onKeyDown: { event in
                        handleKeyDown(event)
                    }
                )

                // Inline annotation popup
                if showInlinePopup, let element = selectedElement {
                    inlinePopupView(for: element, in: geometry)
                }

                // History panel
                if showHistory {
                    historyPanel(in: geometry)
                }

                // Bottom controls
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        bottomControls
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }

                // Copied confirmation banner
                if showCopiedBanner {
                    VStack {
                        copiedBanner
                            .padding(.top, 20)
                        Spacer()
                    }
                }
            }
        }
        .onDisappear {
            // Clean up highlights when overlay is dismissed (but keep annotations!)
            inspector.clearAllHighlights()
        }
    }

    // MARK: - Keyboard Handling

    private func handleKeyDown(_ event: NSEvent) {
        // ESC key (keyCode 53)
        if event.keyCode == 53 {
            if showInlinePopup {
                // Close popup if showing
                clearSelection()
            } else if showHistory {
                // Close history panel if showing
                withAnimation(.spring(response: 0.25)) {
                    showHistory = false
                }
            } else {
                // Exit annotation mode if nothing is selected
                isEnabled = false
            }
        }
    }

    // MARK: - Inline Popup

    private func inlinePopupView(for element: ElementInfo, in geometry: GeometryProxy) -> some View {
        let popupPosition = popupPosition(for: selectedFrame, in: geometry)

        return VStack(alignment: .leading, spacing: 8) {
            // Element summary line
            HStack {
                Image(systemName: "square.dashed")
                    .foregroundStyle(.secondary)
                Text(element.typeName)
                    .fontWeight(.medium)
                if let accessibilityId = element.accessibilityIdentifier, !accessibilityId.isEmpty {
                    Text("(\(accessibilityId))")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Spacer()
                Button {
                    clearSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .font(.system(size: 12))

            // Feedback text field
            HStack(spacing: 8) {
                TextField("Add feedback...", text: $feedbackText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if !feedbackText.isEmpty {
                            submitAnnotation()
                        }
                    }

                Button {
                    submitAnnotation()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(feedbackText.isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(feedbackText.isEmpty)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(12)
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
        .position(popupPosition)
        .onAppear {
            // Auto-focus text field when popup appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }

    // MARK: - History Panel

    private func historyPanel(in geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Annotations")
                    .font(.headline)
                Spacer()
                if !storage.annotations.isEmpty {
                    Button("Copy All") {
                        copyAllAnnotations()
                    }
                    .font(.caption)
                    Button("Clear") {
                        storage.clear()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
            .padding(12)

            Divider()

            if storage.annotations.isEmpty {
                Text("No annotations yet.\nClick on elements and add feedback.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(storage.annotations) { annotation in
                            annotationRow(annotation)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 300, height: min(CGFloat(storage.annotations.count * 80 + 100), 400))
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
        .position(
            x: geometry.size.width - 170,
            y: geometry.size.height - 220
        )
    }

    private func annotationRow(_ annotation: AnnotationEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(annotation.element.typeName)
                    .font(.system(size: 11, weight: .medium))
                if let id = annotation.element.accessibilityIdentifier, !id.isEmpty {
                    Text(id)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    copyAnnotation(annotation)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                Button {
                    removeAnnotation(annotation)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            Text(annotation.feedback)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 12) {
            // History button
            Button {
                withAnimation(.spring(response: 0.25)) {
                    showHistory.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet.rectangle")
                    if !storage.annotations.isEmpty {
                        Text("\(storage.annotations.count)")
                            .font(.caption2)
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(showHistory ? Color.blue : Color.gray.opacity(0.8))
                .cornerRadius(20)
            }
            .buttonStyle(.plain)

            // Exit button
            Button {
                isEnabled = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.gray.opacity(0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .shadow(radius: 8)
    }

    private var copiedBanner: some View {
        Text("Copied to clipboard!")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green)
            .cornerRadius(20)
            .shadow(radius: 8)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Event Handlers

    private func handleHover(at windowPoint: CGPoint, in geometry: GeometryProxy) {
        // Don't update hover if we have a selection with popup
        guard !showInlinePopup else { return }

        guard let window = NSApp.keyWindow else { return }

        // Use inspector to highlight view directly (applies border to actual NSView)
        if let element = inspector.highlightElementOnHover(at: windowPoint, in: window) {
            hoveredElement = element
            hoveredFrame = element.frame
        } else {
            inspector.removeHoverHighlight()
            hoveredElement = nil
            hoveredFrame = .zero
        }
    }

    private func handleClick(at windowPoint: CGPoint, in geometry: GeometryProxy) {
        // Convert window point to SwiftUI coordinates for popup hit testing
        let swiftUIPoint = CGPoint(
            x: windowPoint.x,
            y: geometry.size.height - windowPoint.y
        )

        // If popup is showing, check if click is outside
        if showInlinePopup {
            let popupPos = popupPosition(for: selectedFrame, in: geometry)
            let popupRect = CGRect(
                x: popupPos.x - 160,
                y: popupPos.y - 60,
                width: 320,
                height: 120
            )
            if !popupRect.contains(swiftUIPoint) {
                clearSelection()
            }
            return
        }

        guard let window = NSApp.keyWindow else { return }

        // Use inspector to select and highlight view directly
        if let element = inspector.selectElement(at: windowPoint, in: window) {
            selectElement(element)
        }
    }

    private func selectElement(_ element: ElementInfo) {
        withAnimation(.spring(response: 0.25)) {
            selectedElement = element
            selectedFrame = element.frame
            hoveredElement = nil
            hoveredFrame = .zero
            showInlinePopup = true
            feedbackText = ""
        }
    }

    private func clearSelection() {
        // Remove highlight from actual view
        inspector.removeSelectionHighlight()

        withAnimation(.spring(response: 0.25)) {
            selectedElement = nil
            selectedFrame = .zero
            showInlinePopup = false
            feedbackText = ""
        }
    }

    private func submitAnnotation() {
        guard let element = selectedElement, !feedbackText.isEmpty else { return }

        let markdown = formatter.formatForClipboard(
            element: element,
            feedback: feedbackText,
            appName: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        )

        let entry = AnnotationEntry(
            element: element,
            feedback: feedbackText,
            timestamp: Date(),
            markdown: markdown
        )

        storage.add(entry)

        // Copy to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        onAnnotationCopied?(markdown)

        showCopiedFeedback()
        clearSelection()
    }

    private func copyAnnotation(_ annotation: AnnotationEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(annotation.markdown, forType: .string)
        onAnnotationCopied?(annotation.markdown)
        showCopiedFeedback()
    }

    private func copyAllAnnotations() {
        let combined = storage.annotations.map { $0.markdown }.joined(separator: "\n\n---\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(combined, forType: .string)
        onAnnotationCopied?(combined)
        showCopiedFeedback()
    }

    private func removeAnnotation(_ annotation: AnnotationEntry) {
        storage.remove(annotation)
    }

    private func showCopiedFeedback() {
        withAnimation(.spring(response: 0.3)) {
            showCopiedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3)) {
                showCopiedBanner = false
            }
        }
    }

    // MARK: - Position Helpers

    private func popupPosition(for frame: CGRect, in geometry: GeometryProxy) -> CGPoint {
        let popupHeight: CGFloat = 90
        let popupWidth: CGFloat = 320
        let padding: CGFloat = 12

        // Try to position below the element
        var y = frame.maxY + popupHeight / 2 + padding

        // If not enough room below, position above
        if y + popupHeight / 2 > geometry.size.height - 60 {
            y = frame.minY - popupHeight / 2 - padding
        }

        // Keep within horizontal bounds
        var x = frame.midX
        x = max(popupWidth / 2 + 10, x)
        x = min(geometry.size.width - popupWidth / 2 - 10, x)

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Mouse Tracking View

/// NSView wrapper that tracks mouse movement, clicks, and keyboard events
private struct MouseTrackingView: NSViewRepresentable {
    let onHover: (CGPoint) -> Void
    let onClick: (CGPoint) -> Void
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> MouseTrackingNSView {
        let view = MouseTrackingNSView()
        view.onHover = onHover
        view.onClick = onClick
        view.onKeyDown = onKeyDown

        // Make the view first responder after a short delay to ensure it's in the view hierarchy
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
        nsView.onHover = onHover
        nsView.onClick = onClick
        nsView.onKeyDown = onKeyDown
    }
}

private class MouseTrackingNSView: NSView {
    var onHover: ((CGPoint) -> Void)?
    var onClick: ((CGPoint) -> Void)?
    var onKeyDown: ((NSEvent) -> Void)?

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )

        if let area = trackingArea {
            addTrackingArea(area)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        // Pass window coordinates directly (bottom-left origin)
        // The inspector expects window coordinates
        let windowPoint = event.locationInWindow
        onHover?(windowPoint)
    }

    override func mouseDown(with event: NSEvent) {
        // Pass window coordinates directly (bottom-left origin)
        let windowPoint = event.locationInWindow
        onClick?(windowPoint)
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Accept all hits to capture events
        return frame.contains(point) ? self : nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        return true
    }
}

#endif
