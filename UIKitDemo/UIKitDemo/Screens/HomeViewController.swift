import Combine
import ContentfulOptimization
import UIKit

final class HomeViewController: UIViewController {

    private let client: OptimizationClient
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let loadingContainer = UIView()
    private let errorContainer = UIView()

    private var cta: [String: Any]?
    private var posts: [[String: Any]] = []
    private var errorMessage: String?
    private var isLoading = true

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Row model

    private enum Row {
        case header
        case post(index: Int)
        case cta
    }

    private var rows: [Row] = []

    // MARK: - Init

    init(client: OptimizationClient) {
        self.client = client
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupTableView()
        setupLoadingView()
        setupErrorView()
        observePersonalizationChanges()
        Task { await fetchData() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { try? await client.screen(name: "Home") }
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(BlogPostCardCell.self, forCellReuseIdentifier: BlogPostCardCell.reuseIdentifier)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HeaderCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CTACell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = .white
        tableView.sectionHeaderHeight = 0
        tableView.sectionFooterHeight = 0
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.isHidden = true

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
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
        label.text = "Loading content\u{2026}"
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

        let retryButton = UIButton(type: .system)
        retryButton.setTitle("Retry", for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.backgroundColor = UIColor(hex: "#0070F3")
        retryButton.layer.cornerRadius = 8
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 24, bottom: 10, right: 24)
        retryButton.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [emoji, messageLabel, retryButton])
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

    // MARK: - Actions

    private func observePersonalizationChanges() {
        client.$selectedPersonalizations
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, !self.tableView.isHidden else { return }
                self.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    @objc private func handleRefresh() {
        Task {
            await fetchData()
            tableView.refreshControl?.endRefreshing()
        }
    }

    @objc private func handleRetry() {
        isLoading = true
        updateUI()
        Task { await fetchData() }
    }

    // MARK: - Data

    private func fetchData() async {
        do {
            errorMessage = nil
            async let ctaResult = ContentfulService.fetchEntry(id: AppConfig.ctaEntryId, include: 10)
            async let postsResult = ContentfulService.fetchEntries(
                contentType: "blogPost",
                order: "-fields.title",
                include: 2
            )
            cta = try await ctaResult
            posts = try await postsResult
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        buildRows()
        updateUI()
    }

    private func buildRows() {
        rows = [.header]
        for i in posts.indices {
            rows.append(.post(index: i))
            if i == 0 && cta != nil {
                rows.append(.cta)
            }
        }
    }

    private func updateUI() {
        loadingContainer.isHidden = !isLoading
        errorContainer.isHidden = errorMessage == nil || isLoading
        tableView.isHidden = isLoading || errorMessage != nil

        if let message = errorMessage {
            if let label = errorContainer.viewWithTag(100) as? UILabel {
                label.text = message
            }
        }

        if !tableView.isHidden {
            tableView.reloadData()
        }
    }
}

// MARK: - UITableViewDataSource

extension HomeViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case .header:
            let cell = tableView.dequeueReusableCell(withIdentifier: "HeaderCell", for: indexPath)
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }

            let titleLabel = UILabel()
            titleLabel.text = "Blog Posts"
            titleLabel.font = .systemFont(ofSize: 28, weight: .heavy)
            titleLabel.textColor = UIColor(hex: "#111827")

            let subtitleLabel = UILabel()
            subtitleLabel.text = "\(posts.count) post\(posts.count != 1 ? "s" : "") available"
            subtitleLabel.font = .systemFont(ofSize: 14)
            subtitleLabel.textColor = UIColor(hex: "#9ca3af")

            let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
            stack.axis = .vertical
            stack.spacing = 4
            stack.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 24),
                stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
                stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
                stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
            ])
            return cell

        case .post(let index):
            let cell = tableView.dequeueReusableCell(withIdentifier: BlogPostCardCell.reuseIdentifier, for: indexPath) as! BlogPostCardCell
            let resolved = client.personalizeEntry(baseline: posts[index], personalizations: client.selectedPersonalizations)
            cell.configure(with: resolved.entry)
            return cell

        case .cta:
            let cell = tableView.dequeueReusableCell(withIdentifier: "CTACell", for: indexPath)
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }

            let ctaView = CTAHeaderView()
            if let cta {
                let resolved = client.personalizeEntry(baseline: cta, personalizations: client.selectedPersonalizations)
                ctaView.configure(with: resolved.entry)
                ctaView.onButtonTap = { [weak self] in
                    guard let self else { return }
                    let sys = cta["sys"] as? [String: Any] ?? [:]
                    let componentId = sys["id"] as? String ?? ""
                    Task {
                        try? await self.client.trackClick(TrackClickPayload(
                            componentId: componentId,
                            variantIndex: resolved.personalization != nil ? 1 : 0
                        ))
                    }
                }
            }
            ctaView.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(ctaView)

            NSLayoutConstraint.activate([
                ctaView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                ctaView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
                ctaView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
                ctaView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
            ])
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if case .post(let index) = rows[indexPath.row] {
            let post = posts[index]
            let sys = post["sys"] as? [String: Any] ?? [:]
            let fields = post["fields"] as? [String: Any] ?? [:]
            let detailVC = BlogPostDetailViewController(
                client: client,
                postId: sys["id"] as? String ?? "",
                postTitle: fields["title"] as? String ?? "Blog Post"
            )
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 0 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 0 }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { nil }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { nil }
}
