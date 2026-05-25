import SwiftUI
import AppKit

private let sampleFilename = "hostflow-example.json"

private let sampleJSON = """
{
  "version": 1,
  "profiles": [
    {
      "name": "Development",
      "order": 0,
      "records": [
        { "ip": "127.0.0.1", "hostname": "dev.local", "isEnabled": true },
        { "ip": "192.168.1.10", "hostname": "api.dev", "isEnabled": false }
      ]
    }
  ]
}
"""

struct JSONFormatHelpButton: View {

    @State private var isShowing = false
    @State private var saveError: String?

    var body: some View {
        Button {
            isShowing = true
        } label: {
            Image(systemName: "questionmark.circle")
        }
        .buttonStyle(.borderless)
        .help("json_format.help.tooltip")
        .popover(isPresented: $isShowing, arrowEdge: .top) {
            popoverContent
        }
        .alert(
            "json_format.help.save_error.title",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            ),
            presenting: saveError
        ) { _ in
            Button("common.button.ok", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("json_format.help.title")
                .font(.headline)

            Text("json_format.help.description")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                Text(sampleJSON)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 200)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Spacer()
                Button("json_format.help.download_sample") {
                    downloadSample()
                }
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private func downloadSample() {
        let panel = NSSavePanel()
        panel.title = String(localized: "json_format.help.save_panel.title")
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = sampleFilename
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try sampleJSON.data(using: .utf8)?.write(to: url, options: .atomic)
                isShowing = false
            } catch {
                saveError = error.localizedDescription
            }
        }
    }
}
