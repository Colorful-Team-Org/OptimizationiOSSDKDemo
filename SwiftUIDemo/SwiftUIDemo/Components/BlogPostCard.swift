import SwiftUI

/// The visual content of a blog post card, used inside NavigationLink.
struct BlogPostCardContent: View {
    let post: [String: Any]

    private var fields: [String: Any] {
        post["fields"] as? [String: Any] ?? [:]
    }

    private var title: String {
        fields["title"] as? String ?? ""
    }

    private var teaser: String? {
        fields["teaser"] as? String
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#EBF5FF"))
                    .frame(width: 44, height: 44)
                Text("\u{1F4DD}")
                    .font(.system(size: 20))
            }

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "#111827"))
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)

                if let teaser {
                    Text(teaser)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#6b7280"))
                        .lineLimit(2)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Chevron
            Text("\u{203A}")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(Color(hex: "#d1d5db"))
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#f3f4f6"), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}
