import UIKit
import NetworkKit

// Rehearsal-only consumer. No network traffic starts on launch.
@main final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var client: APIClient?
    // Retain the public file-operation reference; never invoke it on launch.
    private var downloadOperation: ((URLRequest, Int64, DownloadOptions) async throws -> NetworkResponse<DownloadedFile>)?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        do {
            let instance = try APIClient(configuration: .init(baseURL: URL(string: "https://example.invalid")!))
            client = instance
            downloadOperation = instance.download
        }
        catch { return false }
        let window = UIWindow(frame: UIScreen.main.bounds)
        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground
        let label = UILabel(frame: controller.view.bounds)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.textAlignment = .center
        label.text = "NetworkKit consumer rehearsal"
        controller.view.addSubview(label)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
    func applicationWillTerminate(_ application: UIApplication) {
        let client = client
        Task { await client?.shutdown() }
    }
}
