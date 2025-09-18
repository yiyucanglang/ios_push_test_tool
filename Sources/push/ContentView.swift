import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: PushViewModel

    @State private var selectedTab: Tab = .send

    var body: some View {
        VStack(spacing: 0) {
            Picker("视图", selection: $selectedTab) {
                Text("发送推送").tag(Tab.send)
                Text("发送记录").tag(Tab.history)
            }
            .pickerStyle(.segmented)
            .padding(16)

            Divider()

            Group {
                switch selectedTab {
                case .send:
                    sendForm
                case .history:
                    HistoryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if selectedTab == .send {
                Divider()
                bottomBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
        }
    }

    private var sendForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                credentialsSection
                payloadSection
                logSection
            }
            .padding(20)
        }
    }

    private var credentialsSection: some View {
        GroupBox("APNs Credentials") {
            VStack(alignment: .leading, spacing: 12) {
                FormRow(label: "Key ID") {
                    TextField("ABCD123456", text: $viewModel.keyID)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                }

                FormRow(label: "Team ID") {
                    TextField("ABCDE12345", text: $viewModel.teamID)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                }

                FormRow(label: "Bundle ID (Topic)") {
                    TextField("com.example.app", text: $viewModel.bundleID)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                }

                FormRow(label: "Device Token") {
                    TextField("<64-character token>", text: $viewModel.deviceToken)
                        .textFieldStyle(.roundedBorder)
                }

                FormRow(label: "Environment") {
                    Picker("Environment", selection: $viewModel.environment) {
                        ForEach(APNsEnvironment.allCases) { env in
                            Text(env.displayName).tag(env)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }

                FormRow(label: "Auth Key (.p8)") {
                    HStack {
                        Text(viewModel.privateKeyFileName.isEmpty ? "未选择" : viewModel.privateKeyFileName)
                            .font(.callout)
                            .foregroundStyle(viewModel.privateKeyFileName.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("选择文件…") {
                            viewModel.selectPrivateKey()
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    private var payloadSection: some View {
        GroupBox("Payload") {
            VStack(alignment: .leading, spacing: 8) {
                Text("JSON Body (必须包含 aps 字段)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                PayloadTextView(text: $viewModel.payload)
                    .frame(minHeight: 160)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .textBackgroundColor))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3))
                            .allowsHitTesting(false)
                    }
            }
            .padding(14)
        }
    }

    private var logSection: some View {
        GroupBox("日志输出") {
            ZStack(alignment: .topTrailing) {
                LogTextView(text: viewModel.logOutput)
                    .frame(minHeight: 140)
                Button("复制全部") {
                    viewModel.copyLogsToPasteboard()
                }
                .buttonStyle(.borderless)
                .padding(10)
            }
            .padding(14)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if viewModel.isSending {
                ProgressView()
                    .progressViewStyle(.circular)
            }
            Text(viewModel.statusLine)
                .foregroundStyle(.secondary)
                .font(.callout)
            Spacer()
            Button("发送推送") {
                viewModel.triggerSend()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSend)
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 720, height: 640)
        .environmentObject(PushViewModel())
}

private struct FormRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .frame(width: 150, alignment: .leading)
            content()
        }
    }
}

private enum Tab: Hashable {
    case send
    case history
}
