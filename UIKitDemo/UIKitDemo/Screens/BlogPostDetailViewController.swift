import ContentfulOptimization
import UIKit

final class BlogPostDetailViewController: UIViewController {

    private let client: OptimizationClient
    private let postId: String
    private let postTitle: String

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let loadingContainer = UIView()
    private let errorContainer = UIView()

    private var post: [String: Any]?
    private var isLoading = true
    private var errorMessage: String?

    // MARK: - Init

    init(client: OptimizationClient, postId: String, postTitle: String) {
        self.client = client
        self.postId = postId
        self.postTitle = postTitle
        super.init(nibName: nil, bundle: nil)
        title = postTitle
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        navigationItem.largeTitleDisplayMode = .never
        setupScrollView()
        setupLoadingView()
        setupErrorView()
        Task { await fetchPost() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { try? await client.screen(name: "BlogPostDetail") }
    }

    // MARK: - Setup

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isHidden = true
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    private func setupLoadingView() {
        loadingContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingContainer)

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = UIColor(hex: "#0070F3")
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Loading \(postTitle)\u{2026}"
        label.font = .systemFont(ofSize: 16)
        label.textColor = UIColor(hex: "#6b7280")
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        loadingContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            loadingContainer.topAnchor.constraint(equalTo: view.topAnchor),
            loadingContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: loadingContainer.centerYAnchor),
        ])
    }

    private func setupErrorView() {
        errorContainer.isHidden = true
        errorContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorContainer)

        let emoji = UILabel()
        emoji.text = "\u{26A0}\u{FE0F}"
        emoji.font = .systemFont(ofSize: 48)
        emoji.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.tag = 100
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textColor = UIColor(hex: "#ef4444")
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [emoji, messageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            errorContainer.topAnchor.constraint(equalTo: view.topAnchor),
            errorContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            errorContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.centerXAnchor.constraint(equalTo: errorContainer.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: errorContainer.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: errorContainer.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: errorContainer.trailingAnchor, constant: -24),
        ])
    }

    // MARK: - Data

    private func fetchPost() async {
        do {
            errorMessage = nil
            post = try await ContentfulService.fetchEntry(id: postId, include: 10)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        updateUI()
    }

    private func updateUI() {
        loadingContainer.isHidden = !isLoading
        errorContainer.isHidden = errorMessage == nil || isLoading
        scrollView.isHidden = isLoading || errorMessage != nil

        if let message = errorMessage {
            if let label = errorContainer.viewWithTag(100) as? UILabel {
                label.text = message
            }
        }

        guard let post, !scrollView.isHidden else { return }
        buildContent(post)
    }

    private func buildContent(_ post: [String: Any]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let fields = post["fields"] as? [String: Any] ?? [:]

        // Title
        let titleLabel = UILabel()
        titleLabel.text = fields["title"] as? String ?? postTitle
        titleLabel.font = .systemFont(ofSize: 28, weight: .heavy)
        titleLabel.textColor = UIColor(hex: "#111827")
        titleLabel.numberOfLines = 0

        let titleWrapper = wrapWithPadding(titleLabel, insets: UIEdgeInsets(top: 16, left: 20, bottom: 0, right: 20))
        stackView.addArrangedSubview(titleWrapper)

        // Teaser
        if let teaser = fields["teaser"] as? String {
            let teaserLabel = UILabel()
            teaserLabel.text = teaser
            teaserLabel.font = .systemFont(ofSize: 16)
            teaserLabel.textColor = UIColor(hex: "#6b7280")
            teaserLabel.numberOfLines = 0

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 3
            teaserLabel.attributedText = NSAttributedString(string: teaser, attributes: [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor(hex: "#6b7280"),
                .paragraphStyle: paragraphStyle,
            ])

            let teaserWrapper = wrapWithPadding(teaserLabel, insets: UIEdgeInsets(top: 8, left: 20, bottom: 0, right: 20))
            stackView.addArrangedSubview(teaserWrapper)
        }

        // Divider
        let divider = UIView()
        divider.backgroundColor = UIColor(hex: "#f3f4f6")
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let dividerWrapper = wrapWithPadding(divider, insets: UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0))
        stackView.addArrangedSubview(dividerWrapper)

        // Body
        if let bodyDoc = fields["body"] as? [String: Any] {
            let bodyTextView = UITextView()
            bodyTextView.isEditable = false
            bodyTextView.isScrollEnabled = false
            bodyTextView.attributedText = RichTextRenderer.render(bodyDoc)
            bodyTextView.backgroundColor = .clear
            bodyTextView.textContainerInset = .zero
            bodyTextView.textContainer.lineFragmentPadding = 0

            let bodyWrapper = wrapWithPadding(bodyTextView, insets: UIEdgeInsets(top: 0, left: 20, bottom: 60, right: 20))
            stackView.addArrangedSubview(bodyWrapper)
        } else {
            // Empty state
            let emoji = UILabel()
            emoji.text = "\u{1F4ED}"
            emoji.font = .systemFont(ofSize: 48)
            emoji.textAlignment = .center

            let message = UILabel()
            message.text = "No content for this post."
            message.font = .systemFont(ofSize: 16)
            message.textColor = UIColor(hex: "#9ca3af")
            message.textAlignment = .center

            let emptyStack = UIStackView(arrangedSubviews: [emoji, message])
            emptyStack.axis = .vertical
            emptyStack.alignment = .center
            emptyStack.spacing = 12

            let emptyWrapper = wrapWithPadding(emptyStack, insets: UIEdgeInsets(top: 40, left: 20, bottom: 40, right: 20))
            stackView.addArrangedSubview(emptyWrapper)
        }
    }

    private func wrapWithPadding(_ view: UIView, insets: UIEdgeInsets) -> UIView {
        let wrapper = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: insets.top),
            view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -insets.bottom),
            view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: insets.left),
            view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -insets.right),
        ])
        return wrapper
    }
}
