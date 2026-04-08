import SwiftUI

struct CTAHeader: View {
    let entry: [String: Any]

    private var fields: [String: Any] {
        entry["fields"] as? [String: Any] ?? [:]
    }

    private var heading: String? {
        fields["heading"] as? String
    }

    private var body_: [String: Any]? {
        fields["body"] as? [String: Any]
    }

    private var label: String? {
        fields["label"] as? String
    }

    private var imageUrl: URL? {
        // Navigate: fields.media.fields.image.fields.file.url
        guard let media = fields["media"] as? [String: Any],
              let mediaFields = media["fields"] as? [String: Any],
              let image = mediaFields["image"] as? [String: Any],
              let imageFields = image["fields"] as? [String: Any],
              let file = imageFields["file"] as? [String: Any],
              let urlString = file["url"] as? String
        else { return nil }
        // Contentful URLs are protocol-relative
        return URL(string: urlString.hasPrefix("//") ? "https:\(urlString)" : urlString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero image
            if let imageUrl {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    case .failure:
                        Color.gray.opacity(0.3)
                            .frame(height: 200)
                    default:
                        Color.gray.opacity(0.1)
                            .frame(height: 200)
                    }
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 0) {
                if let heading {
                    Text(heading)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                }

                if let body_ {
                    RichTextView(document: body_, textColor: Color(hex: "#dbeafe"))
                        .font(.system(size: 14))
                        .padding(.bottom, 14)
                }

                if let label {
                    Button(action: {}) {
                        Text(label)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "#0070F3"))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(Color(hex: "#0070F3"))
        .cornerRadius(14)
        .clipped()
    }
}
