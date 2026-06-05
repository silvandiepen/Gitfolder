import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appModel = AppModel()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appModel.load()
        statusBarController = StatusBarController(appModel: appModel)
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.invalidate()
        appModel.invalidateScheduler()
    }
}
