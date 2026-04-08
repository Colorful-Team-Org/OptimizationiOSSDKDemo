import ContentfulOptimization
import SwiftUI

@main
struct SwiftUIDemoApp: App {
    private let contentfulClient = ContentfulHTTPPreviewClient(
        spaceId: AppConfig.contentfulSpaceId,
        accessToken: AppConfig.contentfulAccessToken,
        environment: AppConfig.contentfulEnvironment
    )

    var body: some Scene {
        WindowGroup {
            OptimizationRoot(
                config: OptimizationConfig(
                    clientId: AppConfig.optimizationClientId,
                    environment: AppConfig.optimizationEnvironment,
                    defaults: StorageDefaults(consent: true),
                    debug: true
                ),
                trackViews: true,
                trackTaps: false,
                liveUpdates: true
            ) {
                PreviewPanelOverlay(contentfulClient: contentfulClient) {
                    NavigationStack {
                        HomeScreen()
                            .navigationDestination(for: BlogPostRoute.self) { route in
                                BlogPostDetailScreen(
                                    postId: route.postId,
                                    postTitle: route.postTitle
                                )
                            }
                    }
                    .tint(Color(hex: "#0070F3"))
                }
            }
        }
    }
}
