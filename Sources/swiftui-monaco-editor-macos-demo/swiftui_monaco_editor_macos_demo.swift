import AppKit
import Foundation
import SwiftUI
import WebKit

private let sampleCode = """
import Foundation

struct Greeter {
    let name: String

    func greet() -> String {
        "Hello, \\(name)"
    }
}

let summary = ["Monaco", "Editor", "SwiftUI"]
    .map { Greeter(name: $0).greet() }
    .filter { $0.contains("o") }
    .joined(separator: " | ")
    .uppercased()

print(summary)
"""

@main
struct MonacoEditorDemoApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1100, height: 760)
    }
}

private struct ContentView: View {
    @State private var code = sampleCode
    @State private var status = "等待 Monaco 初始化"
    @State private var bridge = MonacoEditorBridge()

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("加载示例") {
                    code = sampleCode
                }

                Button("Duplicate 当前行 (⌘D)") {
                    bridge.duplicateCurrentLine()
                }
                .keyboardShortcut("d", modifiers: [.command])

                Button("扩选父节点 (⌘E)") {
                    bridge.expandSelection()
                }
                .keyboardShortcut("e", modifiers: [.command])

                Text(status)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            MonacoEditorView(text: $code, status: $status, bridge: bridge)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
    }
}

private struct MonacoEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var status: String
    let bridge: MonacoEditorBridge

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> MonacoContainerView {
        let view = MonacoContainerView()
        context.coordinator.attach(webView: view.webView)
        return view
    }

    func updateNSView(_ nsView: MonacoContainerView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.pushTextIfNeeded(text)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: MonacoEditorView
        weak var webView: WKWebView?
        private var isReady = false
        private var lastPushedText = ""

        init(_ parent: MonacoEditorView) {
            self.parent = parent
        }

        func attach(webView: WKWebView) {
            self.webView = webView
            parent.bridge.webView = webView
            webView.configuration.userContentController.add(self, name: "editor")
        }

        func pushTextIfNeeded(_ text: String) {
            guard isReady, text != lastPushedText, let webView else {
                return
            }

            guard let payload = try? JSONEncoder().encode(text),
                  let json = String(data: payload, encoding: .utf8)
            else {
                return
            }

            lastPushedText = text
            webView.evaluateJavaScript("window.setEditorValue(\(json));")
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String
            else {
                return
            }

            switch type {
            case "ready":
                isReady = true
                DispatchQueue.main.async {
                    self.parent.status = "Monaco 已就绪"
                }
                pushTextIfNeeded(parent.text)
            case "change":
                let value = body["value"] as? String ?? ""
                lastPushedText = value
                DispatchQueue.main.async {
                    self.parent.text = value
                    self.parent.status = "已同步 \(value.count) 字符"
                }
            default:
                break
            }
        }
    }
}

@MainActor
private final class MonacoEditorBridge {
    weak var webView: WKWebView?

    func duplicateCurrentLine() {
        webView?.evaluateJavaScript("window.duplicateCurrentLine();")
    }

    func expandSelection() {
        webView?.evaluateJavaScript("window.expandSelection();")
    }
}

private final class MonacoContainerView: NSView {
    let webView: WKWebView

    override init(frame frameRect: NSRect) {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frameRect)
        setUpLayout()
        loadEditor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpLayout() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func loadEditor() {
        guard let htmlURL = Bundle.module.url(forResource: "editor", withExtension: "html") else {
            return
        }

        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }
}
