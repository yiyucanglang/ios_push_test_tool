import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var viewModel: PushViewModel

    var body: some View {
        Group {
            if viewModel.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("暂无发送记录")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.history) { record in
                        HistoryRow(record: record)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct HistoryRow: View {
    let record: SendRecord
    @EnvironmentObject private var viewModel: PushViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(record.statusDescription, systemImage: record.status == .success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(record.status == .success ? Color.green : Color.red)
                Spacer()
                Text(record.timestampText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(record.environment.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(record.detailedStatus)
                .font(.subheadline)

            if let apnsID = record.apnsID, !apnsID.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("APNs ID")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(apnsID)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            if let response = record.responseBody, !response.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("APNs 返回")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(response)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            if let error = record.errorDescription, !error.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("错误信息")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Payload")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView {
                    Text(record.payload)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 120)
            }

            HStack {
                Button {
                    viewModel.copyPayloadToPasteboard(record.payload)
                } label: {
                    Label("复制 Payload", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)

                if let response = record.responseBody, !response.isEmpty {
                    Button {
                        viewModel.copyResponseToPasteboard(response)
                    } label: {
                        Label("复制响应", systemImage: "arrowshape.turn.up.right")
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()
            }
        }
        .padding(.vertical, 8)
    }
}
