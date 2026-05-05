# SwiftUI + Monaco Editor

## 简介

这个 Demo 演示如何在 `SwiftUI` 里嵌入 `WKWebView`，再在 `WebView` 内加载 `Monaco Editor`。

它的目标很单一：

- Swift 原生窗口
- 内嵌 Monaco
- Swift 与 JS 双向同步文本

## 快速开始

### 环境要求

- macOS 14+
- Xcode.app 已安装
- 首次运行需要联网拉 CDN 上的 Monaco 资源

### 运行

```bash
cd /Volumes/SN550-2T/freewind-demos/swiftui-monaco-editor-macos-demo
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run
```

## 概念讲解

### 第一部分：SwiftUI 包 `WKWebView`

核心桥接是 `NSViewRepresentable`：

```swift
private struct MonacoEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var status: String
}
```

这样 `SwiftUI` 就能持有原生状态，同时把 `WKWebView` 放进布局。

### 第二部分：Swift 与 JS 通信

Swift 端通过 `evaluateJavaScript` 把文本送进 Monaco：

```swift
guard let payload = try? JSONEncoder().encode(text),
      let json = String(data: payload, encoding: .utf8)
else {
    return
}

webView.evaluateJavaScript("window.setEditorValue(\(json));")
```

JS 端通过 `window.webkit.messageHandlers.editor.postMessage(...)` 把改动回传给 Swift：

```js
editor.onDidChangeModelContent(() => {
  post("change", editor.getValue());
});
```

### 第三部分：HTML 里初始化 Monaco

这里直接用 CDN，最小代码如下：

```js
require.config({
  paths: {
    vs: "https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/min/vs",
  },
});

require(["vs/editor/editor.main"], () => {
  editor = monaco.editor.create(document.getElementById("editor"), {
    language: "swift",
    theme: "vs-dark",
    automaticLayout: true,
  });
});
```

## 完整示例

入口代码在 `Sources/swiftui-monaco-editor-macos-demo/swiftui_monaco_editor_macos_demo.swift`，HTML 在 `Sources/swiftui-monaco-editor-macos-demo/Resources/editor.html`。

运行后你会看到：

- 顶部一个“加载示例”按钮
- 中间整块 Monaco 编辑器
- Swift 改值会推给 JS
- JS 内编辑会同步回 Swift 状态

## 注意事项

- 这个 Demo 为了最小可跑，依赖 CDN，不是离线方案
- 若你要产品化，通常要把 Monaco 静态资源打进 app bundle
- 这里没接 LSP，只演示“嵌入 editor 内核”

## 完整讲解

这套方案本质上是“`SwiftUI` 负责原生窗口与业务状态，`WKWebView` 负责承载成熟 web editor”。  
优点很直接：Monaco 体验成熟，多语言支持强，跟 VS Code 同源感很重。  
缺点也直接：你要接受 WebView，接受 JS bridge，接受资源打包问题。

为什么这个 Demo 值得先做最小版？因为它能最快回答两个问题：

1. `SwiftUI` 宿主里能不能塞一个手感不错的 editor  
2. Swift 跟 editor 内容能不能稳定双向同步

这个 Demo 的答案是：能。  
而且代码量不大，结构也清楚：

- SwiftUI 页面只管状态
- `NSViewRepresentable` 只管桥接
- HTML 只管初始化 Monaco

如果你后面要继续做，下一步一般是三件事：

1. 把 Monaco 静态资源本地化
2. 接文件打开/保存
3. 接 LSP 或你自己的 completion/diagnostics 通道
