import SwiftUI

struct LogTextView: View {
    let text: String

    private enum Constants {
        static let bottomAnchor = "log-bottom-anchor"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if text.isEmpty {
                        Text("暂无日志")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(text)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .transition(.opacity)
                    }

                    Color.clear
                        .frame(height: 0)
                        .id(Constants.bottomAnchor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: text) { _, newValue in
                guard !newValue.isEmpty else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(Constants.bottomAnchor, anchor: .bottom)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.3))
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    LogTextView(text: "[09:45:12] 🚀 正在向 开发环境 发送推送…\n[09:45:13] ❌ 发送失败：HTTP 403，原因：InvalidProviderToken")
        .frame(width: 480, height: 200)
}
