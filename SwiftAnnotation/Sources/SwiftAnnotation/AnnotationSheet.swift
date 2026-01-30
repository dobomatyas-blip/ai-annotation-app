import SwiftUI

#if canImport(UIKit)
import UIKit

/// Sheet view for adding feedback to an annotated element (iOS)
struct AnnotationSheet: View {
    let element: ElementInfo
    let onDismiss: () -> Void
    let onCopy: (String) -> Void

    @State private var feedbackText: String = ""
    @State private var showCopiedConfirmation = false
    @FocusState private var isTextFieldFocused: Bool

    private let formatter = MarkdownFormatter()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    elementInfoSection
                    Divider()
                    feedbackSection
                    previewSection
                }
                .padding()
            }
            .navigationTitle("Annotate Element")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Copy") {
                        copyToClipboard()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
        .overlay(alignment: .bottom) {
            if showCopiedConfirmation {
                copiedConfirmationBanner
            }
        }
    }

    private var elementInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Element Details", systemImage: "square.on.square.dashed")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Type", value: element.typeName)
                InfoRow(label: "Hierarchy", value: element.hierarchyPath, isCode: true)

                if let accessibilityId = element.accessibilityIdentifier, !accessibilityId.isEmpty {
                    InfoRow(label: "Accessibility ID", value: accessibilityId, isCode: true)
                }

                if let accessibilityLabel = element.accessibilityLabel, !accessibilityLabel.isEmpty {
                    InfoRow(label: "Label", value: "\"\(accessibilityLabel)\"")
                }

                InfoRow(label: "Frame", value: element.frameString, isCode: true)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Feedback", systemImage: "text.bubble")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField("Describe the issue or change needed...", text: $feedbackText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                .lineLimit(3...10)
                .focused($isTextFieldFocused)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Markdown Preview", systemImage: "doc.plaintext")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(generatedMarkdown)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .tertiarySystemBackground))
                .cornerRadius(12)
        }
    }

    private var copiedConfirmationBanner: some View {
        Text("Copied to clipboard!")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(25)
            .shadow(radius: 10)
            .padding(.bottom, 30)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var generatedMarkdown: String {
        formatter.formatForClipboard(
            element: element,
            feedback: feedbackText,
            appName: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        )
    }

    private func copyToClipboard() {
        let markdown = generatedMarkdown
        UIPasteboard.general.string = markdown
        onCopy(markdown)

        withAnimation(.spring(response: 0.3)) {
            showCopiedConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3)) {
                showCopiedConfirmation = false
            }
            onDismiss()
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var isCode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if isCode {
                Text(value)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.primary)
            } else {
                Text(value)
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }
        }
    }
}

#elseif canImport(AppKit)
import AppKit

/// Sheet view for adding feedback to an annotated element (macOS)
struct AnnotationSheetMac: View {
    let element: ElementInfo
    let onDismiss: () -> Void
    let onCopy: (String) -> Void

    @State private var feedbackText: String = ""
    @State private var showCopiedConfirmation = false

    private let formatter = MarkdownFormatter()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Annotate Element")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
                Button("Copy") {
                    copyToClipboard()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    elementInfoSection
                    Divider()
                    feedbackSection
                    previewSection
                }
                .padding()
            }
        }
        .overlay(alignment: .bottom) {
            if showCopiedConfirmation {
                copiedConfirmationBanner
            }
        }
    }

    private var elementInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Element Details", systemImage: "square.on.square.dashed")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                InfoRowMac(label: "Type", value: element.typeName)
                InfoRowMac(label: "Hierarchy", value: element.hierarchyPath, isCode: true)

                if let accessibilityId = element.accessibilityIdentifier, !accessibilityId.isEmpty {
                    InfoRowMac(label: "Accessibility ID", value: accessibilityId, isCode: true)
                }

                if let accessibilityLabel = element.accessibilityLabel, !accessibilityLabel.isEmpty {
                    InfoRowMac(label: "Label", value: "\"\(accessibilityLabel)\"")
                }

                InfoRowMac(label: "Frame", value: element.frameString, isCode: true)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Feedback", systemImage: "text.bubble")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextEditor(text: $feedbackText)
                .font(.body)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Markdown Preview", systemImage: "doc.plaintext")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(generatedMarkdown)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
        }
    }

    private var copiedConfirmationBanner: some View {
        Text("Copied to clipboard!")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(25)
            .shadow(radius: 10)
            .padding(.bottom, 30)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var generatedMarkdown: String {
        formatter.formatForClipboard(
            element: element,
            feedback: feedbackText,
            appName: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        )
    }

    private func copyToClipboard() {
        let markdown = generatedMarkdown
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        onCopy(markdown)

        withAnimation(.spring(response: 0.3)) {
            showCopiedConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3)) {
                showCopiedConfirmation = false
            }
            onDismiss()
        }
    }
}

private struct InfoRowMac: View {
    let label: String
    let value: String
    var isCode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if isCode {
                Text(value)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.primary)
            } else {
                Text(value)
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }
        }
    }
}

#endif
