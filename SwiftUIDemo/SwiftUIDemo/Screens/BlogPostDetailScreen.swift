import ContentfulOptimization
import SwiftUI

struct BlogPostDetailScreen: View {
    let postId: String
    let postTitle: String

    @State private var post: [String: Any]?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading {
                loadingView
            } else if let error {
                errorView(error)
            } else if let post {
                contentView(post)
            }
        }
        .navigationTitle(postTitle)
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen(name: "BlogPostDetail")
        .task {
            await fetchPost()
        }
    }

    // MARK: - Content

    private func contentView(_ post: [String: Any]) -> some View {
        OptimizationScrollView {
            OptimizedEntry(entry: post) { _ in
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        let fields = post["fields"] as? [String: Any] ?? [:]

                        Text(fields["title"] as? String ?? postTitle)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(Color(hex: "#111827"))
                            .tracking(-0.5)

                        if let teaser = fields["teaser"] as? String {
                            Text(teaser)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#6b7280"))
                                .lineSpacing(3)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    // Divider
                    Divider()
                        .padding(.bottom, 20)

                    // Body
                    let fields = post["fields"] as? [String: Any] ?? [:]
                    if let bodyDoc = fields["body"] as? [String: Any] {
                        RichTextView(document: bodyDoc)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 60)
                    } else {
                        emptyBodyView
                    }
                }
            }
        }
        .background(Color.white)
    }

    private var emptyBodyView: some View {
        VStack(spacing: 12) {
            Text("\u{1F4ED}")
                .font(.system(size: 48))
            Text("No content for this post.")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#9ca3af"))
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading & Error States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(Color(hex: "#0070F3"))
            Text("Loading \(postTitle)\u{2026}")
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
            // "Go Back" button — in context this just navigates back
            // The navigation back is handled by the nav bar back button
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    // MARK: - Data Fetching

    private func fetchPost() async {
        do {
            error = nil
            post = try await ContentfulService.fetchEntry(id: postId, include: 10)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
