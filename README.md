# AI Annotation

A SwiftUI debug overlay tool that enables visual annotation of UI components, generating structured markdown output for AI coding assistants like Claude Code, Cursor, and GitHub Copilot.

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Overview

AI Annotation bridges the gap between visual UI feedback and AI-powered code generation. Instead of describing UI elements in text, simply:

1. **Activate** annotation mode in your app
2. **Click** on any UI element to select it
3. **Add** your feedback or change request
4. **Paste** the generated markdown into your AI assistant

The tool automatically captures element type, hierarchy path, accessibility identifiers, and frame coordinates - everything an AI needs to locate and modify the exact component.

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/dobomatyas-blip/ai-annotation-app.git", branch: "main")
]
```

Then add `AIAnnotation` to your target dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "AIAnnotation", package: "ai-annotation-app"),
    ]
)
```

Or in Xcode:
1. Go to **File > Add Package Dependencies...**
2. Enter: `https://github.com/dobomatyas-blip/ai-annotation-app.git`
3. Select "Branch" → `main`
4. Add to your target

## Quick Start

### 1. Import the Package

```swift
import SwiftUI
import AIAnnotation
```

### 2. Add the Annotation Overlay

Add `.withAnnotationButton()` to your root view:

```swift
struct ContentView: View {
    var body: some View {
        NavigationStack {
            // Your app content
            MyMainView()
        }
        .withAnnotationButton()  // Adds floating annotation button
    }
}
```

### 3. Use It

1. Run your app
2. Click the floating annotation button (bottom-right corner)
3. Hover over UI elements to see highlights
4. Click an element to select it
5. Type your feedback and press Enter
6. The markdown is copied to your clipboard automatically

### 4. Paste into AI Assistant

```markdown
## UI Annotation
**App:** MyApp
**Element:** Button [submitButton]
**Hierarchy:** `NavigationStack > Form > VStack > Button`
**Frame:** (16, 420, 343, 50)

### Feedback
Change the button color to orange and add a subtle shadow.
```

## Features

- **Visual Element Selection**: Hover highlights and click-to-select any UI element
- **Smart Element Detection**: Prioritizes elements with accessibility identifiers
- **Annotation History**: Accumulate multiple annotations before copying
- **Structured Markdown Output**: AI-optimized format with hierarchy paths
- **Keyboard Shortcuts**: Enter to submit, ESC to close/exit
- **Cross-Platform**: Works on macOS and iOS

## Best Practices

### Add Accessibility Identifiers

For best results, add `.accessibilityIdentifier()` to your important UI elements:

```swift
Button("Submit") {
    // action
}
.accessibilityIdentifier("submitButton")

TextField("Email", text: $email)
    .accessibilityIdentifier("emailField")
```

This helps the annotation tool (and AI assistants) precisely identify elements.

### Use Descriptive Feedback

Instead of: "Make it blue"

Write: "Change the background color to the app's primary blue (#007AFF) to match the navigation bar"

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Submit annotation | `Enter` |
| Close popup | `ESC` |
| Close history panel | `ESC` |
| Exit annotation mode | `ESC` (when nothing selected) |

## Output Format

The generated markdown includes:

- **App Name**: From your app's bundle
- **Element Type**: SwiftUI component type (Button, Text, TextField, etc.)
- **Accessibility ID**: If set via `.accessibilityIdentifier()`
- **Hierarchy Path**: Parent chain for precise location
- **Frame**: Position and size coordinates
- **Depth**: How deep in the view hierarchy
- **Your Feedback**: The change you want to make

## Requirements

- macOS 13.0+ / iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## Architecture

```
AIAnnotation/
├── Package.swift
├── Sources/AIAnnotation/
│   ├── SwiftAnnotation.swift      # Public API & view modifiers
│   ├── AnnotationOverlay.swift    # Main overlay UI
│   ├── AnnotationSheet.swift      # Feedback input sheet
│   ├── ElementInspector.swift     # View hierarchy traversal
│   ├── ElementInfo.swift          # Element data model
│   └── MarkdownFormatter.swift    # Output generation
```

## How It Works

1. **ElementInspector** traverses the underlying AppKit/UIKit view hierarchy
2. Collects all views at the tap/click point
3. Prioritizes views with accessibility identifiers
4. Extracts type names, frames, and accessibility info
5. **MarkdownFormatter** generates AI-friendly output

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - free to use, modify, and distribute with attribution. See [LICENSE](LICENSE) for details.

## Acknowledgments

Inspired by [Agentation.dev](https://agentation.dev) for web applications.

Built by [Endless Solutions](https://endlesssolutions.net)
