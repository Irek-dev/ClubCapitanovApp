import UIKit

/// Создает окно приложения и стартовый navigation stack.
///
/// Здесь начинается рабочий flow: создается DI-контейнер, корнем ставится Login-модуль,
/// а остальные экраны дальше открываются через Router + Assembly.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // DI-контейнер создается один раз на сцену, чтобы все модули использовали
        // одни и те же in-memory репозитории. Так открытая смена не теряется при
        // переходах между экранами.
        let container = AppDIContainer()
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = BrandColor.background
        let rootViewController = LoginAssembly.makeModule(container: container)
        window.rootViewController = UINavigationController(rootViewController: rootViewController)
        self.window = window
        window.makeKeyAndVisible()
    }
}
