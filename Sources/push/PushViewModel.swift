import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class PushViewModel: ObservableObject {
    @Published var keyID = UserDefaults.standard.string(forKey: UserDefaultsKeys.keyID) ?? "" {
        didSet { persist(key: UserDefaultsKeys.keyID, value: keyID) }
    }
    @Published var teamID = UserDefaults.standard.string(forKey: UserDefaultsKeys.teamID) ?? "" {
        didSet { persist(key: UserDefaultsKeys.teamID, value: teamID) }
    }
    @Published var bundleID = UserDefaults.standard.string(forKey: UserDefaultsKeys.bundleID) ?? "" {
        didSet { persist(key: UserDefaultsKeys.bundleID, value: bundleID) }
    }
    @Published var deviceToken = UserDefaults.standard.string(forKey: UserDefaultsKeys.deviceToken) ?? "" {
        didSet { persist(key: UserDefaultsKeys.deviceToken, value: deviceToken) }
    }
    @Published var environment: APNsEnvironment = .sandbox
    @Published var payload: String = PushViewModel.defaultPayload

    @Published private(set) var privateKeyFileName: String = UserDefaults.standard.string(forKey: UserDefaultsKeys.privateKeyFileName) ?? ""
    @Published private(set) var isSending = false
    @Published private(set) var logOutput: String = ""
    @Published private(set) var statusLine: String = ""
    @Published private(set) var history: [SendRecord] = []

    private var privateKeyPem: String?
    private var logEntries: [String] = []
    
    var canSend: Bool {
        let hasPrivateKey = (privateKeyPem ?? UserDefaults.standard.string(forKey: UserDefaultsKeys.privateKeyData))?.isEmpty == false

        return !isSending &&
            !keyID.trimmingCharacters(in: .whitespaces).isEmpty &&
            !teamID.trimmingCharacters(in: .whitespaces).isEmpty &&
            !bundleID.trimmingCharacters(in: .whitespaces).isEmpty &&
            !deviceToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            hasPrivateKey &&
            !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func selectPrivateKey() {
        let panel = NSOpenPanel()
        if #available(macOS 12.0, *) {
            if let p8Type = UTType(filenameExtension: "p8") {
                panel.allowedContentTypes = [p8Type]
            }
        } else {
            panel.allowedFileTypes = ["p8"]
        }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let contents = try String(contentsOf: url, encoding: .utf8)
                guard contents.contains("PRIVATE KEY") else {
                    appendLog("❌ 选中的文件不是合法的 .p8 私钥")
                    return
                }
                cachePrivateKey(contents: contents, fileName: url.lastPathComponent)
                appendLog("✅ 已加载私钥：\(url.path)")
            } catch {
                appendLog("❌ 读取私钥失败：\(error.localizedDescription)")
            }
        }
    }

    func triggerSend() {
        guard canSend else {
            appendLog("⚠️ 请填写完整信息并选择私钥后再发送")
            return
        }

        guard let pem = privateKeyPem ?? loadCachedPrivateKey() else {
            appendLog("⚠️ 尚未加载 .p8 私钥")
            return
        }

        let sanitizedToken = deviceToken
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()

        guard let payloadData = payload.data(using: .utf8) else {
            appendLog("❌ 无法将 payload 转为 UTF-8 数据")
            presentAlert(message: "无法将 Payload 转为 UTF-8，请检查文本内容")
            return
        }

        do {
            _ = try JSONSerialization.jsonObject(with: payloadData)
        } catch {
            appendLog("⚠️ payload 不是合法的 JSON：\(error.localizedDescription)")
            presentAlert(message: "Payload 不是合法 JSON，\(error.localizedDescription)")
            return
        }

        isSending = true
        statusLine = "正在发送…"
        appendLog("🚀 正在向 \(environment.displayName) 发送推送…")

        let request = APNsRequest(
            keyID: keyID.trimmingCharacters(in: .whitespacesAndNewlines),
            teamID: teamID.trimmingCharacters(in: .whitespacesAndNewlines),
            bundleID: bundleID.trimmingCharacters(in: .whitespacesAndNewlines),
            deviceToken: sanitizedToken,
            payload: payloadData,
            privateKeyPem: pem,
            environment: environment
        )

        Task {
            do {
                let response = try await APNsClient().send(request: request)
                await MainActor.run {
                    isSending = false
                    statusLine = "HTTP \(response.statusCode)"
                    appendLog("✅ 推送成功，状态码：\(response.statusCode)")
                    if !response.body.isEmpty {
                        appendLog("📥 返回：\(response.body)")
                    }
                    appendHistory(
                        SendRecord(
                            timestamp: Date(),
                            environment: environment,
                            payload: payload,
                            status: .success,
                            statusCode: response.statusCode,
                            responseBody: response.body.isEmpty ? nil : response.body,
                            errorDescription: nil
                        )
                    )
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    if let apnsError = error as? APNsClientError,
                       case let .response(status, body) = apnsError {
                        statusLine = "HTTP \(status)"
                        appendLog("❌ 发送失败：HTTP \(status) - \(body.isEmpty ? "无返回体" : body)")
                        appendHistory(
                            SendRecord(
                                timestamp: Date(),
                                environment: environment,
                                payload: payload,
                                status: .failure,
                                statusCode: status,
                                responseBody: body.isEmpty ? nil : body,
                                errorDescription: nil
                            )
                        )
                    } else {
                        statusLine = "发送失败"
                        appendLog("❌ 发送失败：\(error.localizedDescription)")
                        appendHistory(
                            SendRecord(
                                timestamp: Date(),
                                environment: environment,
                                payload: payload,
                                status: .failure,
                                statusCode: nil,
                                responseBody: nil,
                                errorDescription: error.localizedDescription
                            )
                        )
                    }
                }
            }
        }
    }

    private func appendLog(_ text: String) {
        let timestamp = Self.timestampFormatter.string(from: Date())
        logEntries.append("[\(timestamp)] \(text)")
        if logEntries.count > 200 {
            logEntries.removeFirst(logEntries.count - 200)
        }
        logOutput = logEntries.joined(separator: "\n")
    }

    func copyLogsToPasteboard() {
        copyToPasteboard(logOutput, status: "日志已复制")
    }

    func copyPayloadToPasteboard(_ payload: String) {
        copyToPasteboard(payload, status: "Payload 已复制")
    }

    func copyResponseToPasteboard(_ text: String) {
        copyToPasteboard(text, status: "响应已复制")
    }

    private func persist(key: String, value: String) {
        UserDefaults.standard.setValue(value, forKey: key)
    }

    private func cachePrivateKey(contents: String, fileName: String) {
        privateKeyPem = contents
        privateKeyFileName = fileName
        UserDefaults.standard.set(contents, forKey: UserDefaultsKeys.privateKeyData)
        UserDefaults.standard.set(fileName, forKey: UserDefaultsKeys.privateKeyFileName)
    }

    private func loadCachedPrivateKey() -> String? {
        if let existing = privateKeyPem, !existing.isEmpty {
            return existing
        }

        guard let data = UserDefaults.standard.string(forKey: UserDefaultsKeys.privateKeyData) else {
            return nil
        }

        guard data.contains("PRIVATE KEY") else {
            appendLog("⚠️ 缓存的私钥数据无效，请重新选择 .p8 文件")
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.privateKeyData)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.privateKeyFileName)
            return nil
        }

        privateKeyPem = data
        privateKeyFileName = UserDefaults.standard.string(forKey: UserDefaultsKeys.privateKeyFileName) ?? ""
        appendLog("✅ 已加载缓存私钥内容")
        return data
    }

    private func appendHistory(_ record: SendRecord) {
        history.insert(record, at: 0)
        if history.count > 200 {
            history.removeLast(history.count - 200)
        }
    }

    private func presentAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")

        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    private func copyToPasteboard(_ text: String, status: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        statusLine = status
    }
}

private extension PushViewModel {
    static let defaultPayload: String = """
    {
      \"aps\": {
        \"alert\": {
          \"title\": \"Test Title\",
          \"body\": \"Hello from macOS tool\"
        },
        \"sound\": \"default\"
      }
    }
    """

    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

struct SendRecord: Identifiable {
    enum Status {
        case success
        case failure
    }

    let id = UUID()
    let timestamp: Date
    let environment: APNsEnvironment
    let payload: String
    let status: Status
    let statusCode: Int?
    let responseBody: String?
    let errorDescription: String?

    var statusDescription: String {
        switch status {
        case .success:
            return "APNs 已接受"
        case .failure:
            return "推送失败"
        }
    }

    var detailedStatus: String {
        switch status {
        case .success:
            if let code = statusCode {
                return "HTTP \(code)"
            }
            return "成功"
        case .failure:
            if let code = statusCode {
                return "HTTP \(code)"
            }
            return errorDescription ?? "失败"
        }
    }

    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    var timestampText: String {
        SendRecord.displayFormatter.string(from: timestamp)
    }
}
