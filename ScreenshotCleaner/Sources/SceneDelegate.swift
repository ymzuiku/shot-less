import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        L10n.refreshBundle()
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = SceneDelegate.makeRootViewController()
        window.makeKeyAndVisible()
        self.window = window
    }

    // MARK: - Factory (also used by LanguageSelectionViewController to rebuild after language change)

    static func makeRootViewController() -> UIViewController {
        let listNav = UINavigationController(rootViewController: ScreenshotListViewController())
        listNav.tabBarItem = UITabBarItem(
            title: L10n.str("tab.library"),
            image: UIImage(systemName: "photo.stack"),
            selectedImage: UIImage(systemName: "photo.stack.fill")
        )

        let keepNav = UINavigationController(rootViewController: KeptLibraryViewController())
        keepNav.tabBarItem = UITabBarItem(
            title: L10n.str("tab.keep"),
            image: UIImage(systemName: "bookmark"),
            selectedImage: UIImage(systemName: "bookmark.fill")
        )

        let settingsNav = UINavigationController(rootViewController: SettingsViewController(style: .insetGrouped))
        settingsNav.tabBarItem = UITabBarItem(
            title: L10n.str("tab.settings"),
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )

        let tab = UITabBarController()
        tab.viewControllers = [listNav, keepNav, settingsNav]
        return tab
    }
}
