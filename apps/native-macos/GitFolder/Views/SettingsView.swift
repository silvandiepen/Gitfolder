import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Form {
            Section("GitFolder") {
                Toggle(
                    "Pause all syncing",
                    isOn: Binding(
                        get: { appModel.config.app.pauseAllSyncing },
                        set: { newValue in
                            appModel.config.app.pauseAllSyncing = newValue
                            appModel.save()
                        }
                    )
                )
                Text("Default interval: \(appModel.config.app.defaultSyncIntervalMinutes) minutes")
                Text("Folders: \(appModel.config.folders.count)")
            }
            Section("Purchase") {
                Text("€5 lifetime Mac App Store purchase")
                Text("No subscription")
            }
        }
        .padding()
        .frame(width: 420)
    }
}
