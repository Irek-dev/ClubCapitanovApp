import UIKit

final class AdminPointSelectionViewController: UIViewController {
    private let adminUser: User
    private let pointRepository: PointRepository
    private let container: AppDIContainer
    private var points: [Point] = []

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(
        adminUser: User,
        pointRepository: PointRepository,
        container: AppDIContainer
    ) {
        self.adminUser = adminUser
        self.pointRepository = pointRepository
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        setupConstraints()
        points = pointRepository.getAvailablePoints(for: adminUser)
        tableView.reloadData()
    }

    private func configureUI() {
        title = "Админ-панель"
        view.backgroundColor = BrandColor.background

        titleLabel.text = "Выберите точку"
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.bold(28)
        titleLabel.numberOfLines = 0

        subtitleLabel.text = "Администратор: \(adminUser.fullName)"
        subtitleLabel.textColor = BrandColor.textSecondary
        subtitleLabel.font = BrandFont.regular(16)
        subtitleLabel.numberOfLines = 0

        tableView.backgroundColor = BrandColor.clear
        tableView.separatorStyle = .none
        tableView.rowHeight = 86
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(AdminPointCell.self, forCellReuseIdentifier: AdminPointCell.reuseIdentifier)

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        titleLabel.pinTop(to: view.safeAreaLayoutGuide.topAnchor, 32)
        titleLabel.pinLeft(to: view.layoutMarginsGuide.leadingAnchor)
        titleLabel.pinRight(to: view.layoutMarginsGuide.trailingAnchor)

        subtitleLabel.pinTop(to: titleLabel.bottomAnchor, 8)
        subtitleLabel.pinLeft(to: titleLabel.leadingAnchor)
        subtitleLabel.pinRight(to: titleLabel.trailingAnchor)

        tableView.pinTop(to: subtitleLabel.bottomAnchor, 24)
        tableView.pinLeft(to: view.leadingAnchor)
        tableView.pinRight(to: view.trailingAnchor)
        tableView.pinBottom(to: view.bottomAnchor)
    }
}

extension AdminPointSelectionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        points.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AdminPointCell.reuseIdentifier, for: indexPath)
        guard let pointCell = cell as? AdminPointCell, points.indices.contains(indexPath.row) else {
            return cell
        }

        pointCell.configure(point: points[indexPath.row])
        return pointCell
    }
}

extension AdminPointSelectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard points.indices.contains(indexPath.row) else { return }

        let destination = AdminPanelViewController(
            point: points[indexPath.row],
            authRepository: container.authRepository,
            catalogRepository: container.catalogRepository
        )
        navigationController?.pushViewController(destination, animated: true)
    }
}

private final class AdminPointCell: UITableViewCell {
    static let reuseIdentifier = "AdminPointCell"

    private let containerView = ShiftWorkspaceShadowCardView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let arrowImageView = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(point: Point) {
        titleLabel.text = point.name
        subtitleLabel.text = [point.city, point.address]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func configureUI() {
        backgroundColor = BrandColor.clear
        contentView.backgroundColor = BrandColor.clear
        selectionStyle = .none

        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.demiBold(20)

        subtitleLabel.textColor = BrandColor.textSecondary
        subtitleLabel.font = BrandFont.regular(15)

        arrowImageView.tintColor = BrandColor.textSecondary.withAlphaComponent(0.7)
        arrowImageView.contentMode = .scaleAspectFit

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(arrowImageView)
    }

    private func setupConstraints() {
        containerView.pinTop(to: contentView.topAnchor, 6)
        containerView.pinLeft(to: contentView.layoutMarginsGuide.leadingAnchor)
        containerView.pinRight(to: contentView.layoutMarginsGuide.trailingAnchor)
        containerView.pinBottom(to: contentView.bottomAnchor, 6)

        titleLabel.pinTop(to: containerView.topAnchor, 16)
        titleLabel.pinLeft(to: containerView.leadingAnchor, 18)
        titleLabel.pinRight(to: arrowImageView.leadingAnchor, 12)

        subtitleLabel.pinTop(to: titleLabel.bottomAnchor, 4)
        subtitleLabel.pinLeft(to: titleLabel.leadingAnchor)
        subtitleLabel.pinRight(to: titleLabel.trailingAnchor)

        arrowImageView.pinRight(to: containerView.trailingAnchor, 18)
        arrowImageView.pinCenterY(to: containerView)
        arrowImageView.setWidth(18)
        arrowImageView.setHeight(18)
    }
}
