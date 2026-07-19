import GitPontCore
import SwiftUI
import UIKit

/// Provider-agnostic connect: sign in to GitHub with OAuth (device flow), or paste a
/// personal access token for any provider (GitHub, GitLab.com, self-hosted GitLab).
struct ConnectView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

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

            if let device = model.deviceAuth {
                deviceCodeSection(device)
            } else {
                providerSection
                if choice == .github { oauthSection }
                tokenSection
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

    // MARK: Provider

    private var providerSection: some View {
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
    }

    // MARK: OAuth

    private var oauthSection: some View {
        Section {
            Button {
                Task { await model.startGitHubOAuth() }
            } label: {
                HStack {
                    Image(systemName: "person.badge.key.fill")
                    Text("Sign in with GitHub")
                    Spacer()
                    if model.isConnecting { ProgressView() }
                }
            }
            .disabled(model.isConnecting)
        } footer: {
            Text("Opens github.com to authorise — no token to create.")
        }
    }

    /// Device-flow UI: show the user code, open the verification page, and wait.
    private func deviceCodeSection(_ device: GitOAuthDeviceSession) -> some View {
        Section("Sign in with GitHub") {
            VStack(spacing: 12) {
                Text("Enter this code at GitHub to authorise GitFolder:")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(device.userCode)
                    .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                HStack {
                    Button {
                        UIPasteboard.general.string = device.userCode
                    } label: { Label("Copy Code", systemImage: "doc.on.doc") }
                        .buttonStyle(.borderless)
                    Spacer()
                    Button {
                        openURL(device.verificationURI)
                    } label: { Label("Open GitHub", systemImage: "safari") }
                        .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for authorisation…").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel", role: .cancel) { model.cancelOAuth() }
                        .buttonStyle(.borderless)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
            .onAppear { openURL(device.verificationURI) }
        }
    }

    // MARK: Token

    private var tokenSection: some View {
        Section {
            SecureField("Personal access token", text: $token)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button {
                Task { await model.connect(choice: choice, serverURL: serverURL, token: token) }
            } label: {
                if model.isConnecting && model.deviceAuth == nil {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Connect with Token").frame(maxWidth: .infinity)
                }
            }
            .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty || model.isConnecting)
        } header: {
            Text(choice == .github ? "Or use a token" : "Personal access token")
        } footer: {
            Text("Create a token with repository read/write scope in your provider's settings.")
        }
    }
}
