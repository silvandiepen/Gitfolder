import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appModel = AppModel()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(appModel: appModel)
        appModel.load()
    }
}
