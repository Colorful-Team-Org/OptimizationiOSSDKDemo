import UIKit

final class CTAHeaderView: UIView {

    private let containerView = UIView()
    private let imageView = UIImageView()
    private let contentContainer = UIView()
    private let headingLabel = UILabel()
    private let bodyTextView = UITextView()
    private let ctaButton = UIButton(type: .system)

    private var imageLoadTask: Task<Void, Never>?
    private var imageHeightConstraint: NSLayoutConstraint!

    var onButtonTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        imageLoadTask?.cancel()
    }

    private func setupViews() {
        // Container with rounded corners
        containerView.backgroundColor = UIColor(hex: "#0070F3")
        containerView.layer.cornerRadius = 14
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        // Hero image (height 0 until an image loads successfully)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isHidden = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)

        // Content area
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentContainer)

        // Heading
        headingLabel.font = .systemFont(ofSize: 22, weight: .heavy)
        headingLabel.textColor = .white
        headingLabel.numberOfLines = 0
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(headingLabel)

        // Body (rich text)
        bodyTextView.isEditable = false
        bodyTextView.isScrollEnabled = false
        bodyTextView.backgroundColor = .clear
        bodyTextView.textContainerInset = .zero
        bodyTextView.textContainer.lineFragmentPadding = 0
        bodyTextView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(bodyTextView)

        // CTA Button
        ctaButton.backgroundColor = .white
        ctaButton.setTitleColor(UIColor(hex: "#0070F3"), for: .normal)
        ctaButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        ctaButton.layer.cornerRadius = 8
        ctaButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        ctaButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(ctaButton)

        imageHeightConstraint = imageView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageHeightConstraint,

            contentContainer.topAnchor.constraint(equalTo: imageView.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            contentContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            contentContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),

            headingLabel.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 20),
            headingLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            headingLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),

            bodyTextView.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 8),
            bodyTextView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            bodyTextView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),

            ctaButton.topAnchor.constraint(equalTo: bodyTextView.bottomAnchor, constant: 14),
            ctaButton.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            ctaButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
    }

    @objc private func buttonTapped() {
        onButtonTap?()
    }

    func configure(with entry: [String: Any]) {
        let fields = entry["fields"] as? [String: Any] ?? [:]

        // Heading
        headingLabel.text = fields["heading"] as? String
        headingLabel.isHidden = headingLabel.text == nil

        // Body rich text
        if let bodyDoc = fields["body"] as? [String: Any] {
            bodyTextView.attributedText = RichTextRenderer.render(bodyDoc, textColor: UIColor(hex: "#dbeafe"))
            bodyTextView.isHidden = false
        } else {
            bodyTextView.isHidden = true
        }

        // Button label
        if let label = fields["label"] as? String {
            ctaButton.setTitle(label, for: .normal)
            ctaButton.isHidden = false
        } else {
            ctaButton.isHidden = true
        }

        // Hero image
        loadImage(from: fields)
    }

    private static let heroImageHeight: CGFloat = 200

    private func clearHeroImageLayout() {
        imageView.image = nil
        imageView.isHidden = true
        imageHeightConstraint.constant = 0
    }

    private func loadImage(from fields: [String: Any]) {
        imageLoadTask?.cancel()
        clearHeroImageLayout()

        guard let media = fields["media"] as? [String: Any],
              let mediaFields = media["fields"] as? [String: Any],
              let image = mediaFields["image"] as? [String: Any],
              let imageFields = image["fields"] as? [String: Any],
              let file = imageFields["file"] as? [String: Any],
              let urlString = file["url"] as? String
        else { return }

        let fullUrl = urlString.hasPrefix("//") ? "https:\(urlString)" : urlString
        guard let url = URL(string: fullUrl) else { return }

        imageLoadTask = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                guard let img = UIImage(data: data) else {
                    await MainActor.run { self?.clearHeroImageLayout() }
                    return
                }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.imageView.image = img
                    self.imageView.isHidden = false
                    self.imageHeightConstraint.constant = Self.heroImageHeight
                }
            } catch {
                await MainActor.run { self?.clearHeroImageLayout() }
            }
        }
    }
}
