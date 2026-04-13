import ContentfulOptimization
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let client = OptimizationClient()
    let contentfulClient = ContentfulHTTPPreviewClient(
        spaceId: AppConfig.contentfulSpaceId,
        accessToken: AppConfig.contentfulAccessToken,
        environment: AppConfig.contentfulEnvironment
    )

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        try? client.initialize(config: OptimizationConfig(
            clientId: AppConfig.optimizationClientId,
            environment: AppConfig.optimizationEnvironment,
            defaults: StorageDefaults(consent: true),
            debug: true
        ))

        let homeVC = HomeViewController(client: client)
        let nav = UINavigationController(rootViewController: homeVC)
        nav.navigationBar.tintColor = UIColor(hex: "#0070F3")

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = nav
        window?.makeKeyAndVisible()

        PreviewPanelViewController.addFloatingButton(
            to: homeVC,
            client: client,
            contentfulClient: contentfulClient
        )
    }
}
