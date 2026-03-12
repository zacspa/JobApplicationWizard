import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    @Bindable var store: StoreOf<AppFeature>
    @State private var apiKey = ""
    @State private var showKey = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    store.send(.saveSettingsKey(apiKey))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)

            Divider()

            Form {
                Section("Claude AI") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Claude API Key")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Used for resume tailoring, cover letters, and interview prep. Your key is stored in the system Keychain.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Group {
                                if showKey {
                                    TextField("sk-ant-...", text: $apiKey)
                                } else {
                                    SecureField("sk-ant-...", text: $apiKey)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            Button {
                                showKey.toggle()
                            } label: {
                                Image(systemName: showKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 16)
        }
        .frame(width: 480)
        .onAppear { apiKey = store.claudeAPIKey }
    }
}
