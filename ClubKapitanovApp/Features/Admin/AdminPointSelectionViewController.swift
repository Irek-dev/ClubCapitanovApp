import UIKit

final class AdminPointSelectionViewController: UIViewController {
    private let adminUser: User
    private let pointRepository: AdminPointRepository
    private let container: AppDIContainer
    private var points: [Point] = []

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let stateContainerView = UIView()
    private let stateStackView = UIStackView()
    private let stateLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    init(
        adminUser: User,
        pointRepository: AdminPointRepository,
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
        loadPoints()
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

        stateStackView.axis = .vertical
        stateStackView.alignment = .center
        stateStackView.spacing = 12

        stateLabel.textColor = BrandColor.textSecondary
        stateLabel.font = BrandFont.regular(16)
        stateLabel.textAlignment = .center
        stateLabel.numberOfLines = 0

        retryButton.setTitle("Повторить загрузку", for: .normal)
        retryButton.titleLabel?.font = BrandFont.demiBold(16)
        retryButton.tintColor = BrandColor.primaryBlue
        retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)

        stateContainerView.backgroundColor = BrandColor.clear
        stateContainerView.addSubview(stateStackView)
        stateStackView.addArrangedSubview(stateLabel)
        stateStackView.addArrangedSubview(retryButton)
        tableView.backgroundView = stateContainerView

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

        stateStackView.pinCenterY(to: stateContainerView)
        stateStackView.pinLeft(to: stateContainerView.leadingAnchor, 24)
        stateStackView.pinRight(to: stateContainerView.trailingAnchor, 24)
    }

    private func loadPoints() {
        stateLabel.text = "Загрузка точек..."
        retryButton.isHidden = true
        tableView.backgroundView?.isHidden = false
        pointRepository.refreshPoints { [weak self] in
            guard let self else { return }
            self.points = self.pointRepository.getAvailablePoints(for: self.adminUser)
            self.renderState()
        }
    }

    private func renderState() {
        tableView.reloadData()

        if pointRepository.lastLoadError != nil {
            stateLabel.text = "Не удалось загрузить точки. Проверьте интернет и попробуйте снова."
            retryButton.isHidden = false
            tableView.backgroundView?.isHidden = false
        } else if points.isEmpty {
            stateLabel.text = "Точек пока нет"
            retryButton.isHidden = true
            tableView.backgroundView?.isHidden = false
        } else {
            tableView.backgroundView?.isHidden = true
        }
    }

    private func pushAdminPanel(point: Point) {
        let destination = AdminPanelViewController(
            point: point,
            userRepository: container.adminUserRepository,
            adminPointCatalogRepository: container.adminPointCatalogRepository
        )
        navigationController?.pushViewController(destination, animated: true)
    }

    private func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }

    @objc
    private func didTapRetry() {
        loadPoints()
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

        let point = points[indexPath.row]
        pointRepository.ensurePointDocument(point) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                self.pushAdminPanel(point: point)
            case let .failure(error):
                self.showMessage(title: "Точка недоступна", message: error.localizedDescription)
            }
        }
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
