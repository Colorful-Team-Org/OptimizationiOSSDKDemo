import ContentfulOptimization
import SwiftUI

struct BlogPostRoute: Hashable {
    let postId: String
    let postTitle: String
}

struct HomeScreen: View {
    @EnvironmentObject private var client: OptimizationClient
    @State private var cta: [String: Any]?
    @State private var posts: [[String: Any]] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading {
                loadingView
            } else if let error {
                errorView(error)
            } else {
                contentView
            }
        }
        .trackScreen(name: "Home")
        .task {
            await fetchData()
        }
    }

    // MARK: - Content

    private var contentView: some View {
        OptimizationScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blog Posts")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(Color(hex: "#111827"))
                        .tracking(-0.5)
                    Text("\(posts.count) post\(posts.count != 1 ? "s" : "") available")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#9ca3af"))
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 12)

                // Posts with CTA interleaved after first post
                ForEach(Array(posts.enumerated()), id: \.offset) { index, post in
                    let sys = post["sys"] as? [String: Any] ?? [:]
                    let fields = post["fields"] as? [String: Any] ?? [:]

                    // Blog post card wrapped in OptimizedEntry for view tracking
                    OptimizedEntry(entry: post) { _ in
                        NavigationLink(value: BlogPostRoute(
                            postId: sys["id"] as? String ?? "",
                            postTitle: fields["title"] as? String ?? "Blog Post"
                        )) {
                            BlogPostCardContent(post: post)
                        }
                        .buttonStyle(.plain)
                    }

                    // Insert CTA after first post
                    if index == 0, let cta {
                        OptimizedEntry(entry: cta, trackTaps: true) { resolvedEntry in
                            CTAHeader(entry: resolvedEntry)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .refreshable {
            await fetchData()
        }
        .background(Color.white)
    }

    // MARK: - Loading & Error States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(Color(hex: "#0070F3"))
            Text("Loading content\u{2026}")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#6b7280"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("\u{26A0}\u{FE0F}")
                .font(.system(size: 48))
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#ef4444"))
                .multilineTextAlignment(.center)
            Button {
                Task { await fetchData() }
            } label: {
                Text("Retry")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#0070F3"))
                    .cornerRadius(8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    // MARK: - Data Fetching

    private func fetchData() async {
        do {
            error = nil
            async let ctaResult = ContentfulService.fetchEntry(id: AppConfig.ctaEntryId, include: 10)
            async let postsResult = ContentfulService.fetchEntries(
                contentType: "blogPost",
                order: "-fields.title",
                include: 2
            )
            cta = try await ctaResult
            posts = try await postsResult
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
