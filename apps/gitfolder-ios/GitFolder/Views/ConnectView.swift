import SwiftUI

/// Provider-agnostic connect: pick GitHub, GitLab.com, or a self-hosted GitLab, and
/// paste a personal access token. A token works against any instance without
/// per-server OAuth registration.
struct ConnectView: View {
    @Environment(AppModel.self) private var model

    @State private var choice: ProviderChoice = .github
    @State private var serverURL = ""
    @State private var token = ""

    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 44)).foregroundStyle(.tint)
                    Text("GitFolder").font(.title.bold())
                    Text("Your files, backed by git.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section("Provider") {
                Picker("Provider", selection: $choice) {
                    ForEach(ProviderChoice.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                if choice.needsServerURL {
                    TextField("GitLab server URL (e.g. git.acme.com)", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
            }

            Section {
                SecureField("Personal access token", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("Create a token with repository read/write scope in your provider's settings.")
            }

            Section {
                Button {
                    Task { await model.connect(choice: choice, serverURL: serverURL, token: token) }
                } label: {
                    if model.isConnecting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Connect").frame(maxWidth: .infinity)
                    }
                }
                .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty || model.isConnecting)
            }

            if let error = model.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red).font(.callout)
                }
            }
        }
        .navigationTitle("Connect")
    }
}
