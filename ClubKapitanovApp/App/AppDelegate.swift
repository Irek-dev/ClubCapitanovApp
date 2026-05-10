import FirebaseCore
import UIKit

/// Точка входа жизненного цикла приложения на уровне UIKit.
///
/// В проекте используется scene-based запуск, поэтому большая часть сборки UI живет
/// в `SceneDelegate`. `AppDelegate` остается минимальным и нужен системе iOS как
/// стандартный delegate приложения.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .landscape
    }
}
