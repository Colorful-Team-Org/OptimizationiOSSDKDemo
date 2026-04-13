import UIKit

final class BlogPostCardCell: UITableViewCell {
    static let reuseIdentifier = "BlogPostCardCell"

    private let cardView = UIView()
    private let iconContainer = UIView()
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let teaserLabel = UILabel()
    private let chevronLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // Card container
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 14
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.06
        cardView.layer.shadowRadius = 8
        cardView.layer.shadowOffset = CGSize(width: 0, height: 1)
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor(hex: "#f3f4f6").cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        // Icon container
        iconContainer.backgroundColor = UIColor(hex: "#EBF5FF")
        iconContainer.layer.cornerRadius = 12
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(iconContainer)

        iconLabel.text = "\u{1F4DD}"
        iconLabel.font = .systemFont(ofSize: 20)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconLabel)

        // Title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = UIColor(hex: "#111827")
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        // Teaser
        teaserLabel.font = .systemFont(ofSize: 13)
        teaserLabel.textColor = UIColor(hex: "#6b7280")
        teaserLabel.numberOfLines = 2
        teaserLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(teaserLabel)

        // Chevron
        chevronLabel.text = "\u{203A}"
        chevronLabel.font = .systemFont(ofSize: 28, weight: .light)
        chevronLabel.textColor = UIColor(hex: "#d1d5db")
        chevronLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(chevronLabel)

        // Text stack container for title + teaser
        let textStack = UIStackView(arrangedSubviews: [titleLabel, teaserLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(textStack)

        NSLayoutConstraint.activate([
            // Card inset from edges
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // Icon container
            iconContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),

            // Icon label centered in container
            iconLabel.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            // Text stack
            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: chevronLabel.leadingAnchor, constant: -8),
            textStack.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: cardView.topAnchor, constant: 16),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -16),

            // Chevron
            chevronLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            chevronLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
        ])
    }

    func configure(with post: [String: Any]) {
        let fields = post["fields"] as? [String: Any] ?? [:]
        titleLabel.text = fields["title"] as? String ?? ""
        teaserLabel.text = fields["teaser"] as? String
        teaserLabel.isHidden = (fields["teaser"] as? String) == nil
    }
}
