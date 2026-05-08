import UIKit

/// UI экрана выбора рабочей точки.
///
/// Экран показывает заголовок, состояние пустого списка и таблицу активных точек.
/// Нажатие на строку передается в Interactor как индекс, без прямой навигации из UI.
protocol PointSelectionDisplayLogic: AnyObject {
    func display(viewModel: PointSelection.Load.ViewModel)
}

final class PointSelectionViewController: UIViewController {
    private let interactor: PointSelectionBusinessLogic
    private var points: [PointSelection.PointViewModel] = []

    private let headerLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let emptyLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(interactor: PointSelectionBusinessLogic) {
        self.interactor = interactor
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
        interactor.load()
    }

    private func configureUI() {
        // Таблица используется без storyboard: внешний вид ячейки описан ниже в
        // приватном `PointCell`, потому что она нужна только этому экрану.
        title = "Выбор точки"
        view.backgroundColor = BrandColor.background

        headerLabel.textColor = BrandColor.textPrimary
        headerLabel.font = BrandFont.bold(28)
        headerLabel.numberOfLines = 0

        subtitleLabel.textColor = BrandColor.textSecondary
        subtitleLabel.font = BrandFont.regular(16)
        subtitleLabel.numberOfLines = 0

        emptyLabel.textColor = BrandColor.textSecondary
        emptyLabel.font = BrandFont.regular(16)
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true

        tableView.backgroundColor = BrandColor.clear
        tableView.separatorStyle = .none
        tableView.rowHeight = 86
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(PointCell.self, forCellReuseIdentifier: PointCell.reuseIdentifier)

        view.addSubview(headerLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(emptyLabel)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        headerLabel.pinTop(to: view.safeAreaLayoutGuide.topAnchor, 32)
        headerLabel.pinLeft(to: view.layoutMarginsGuide.leadingAnchor)
        headerLabel.pinRight(to: view.layoutMarginsGuide.trailingAnchor)

        subtitleLabel.pinTop(to: headerLabel.bottomAnchor, 8)
        subtitleLabel.pinLeft(to: headerLabel.leadingAnchor)
        subtitleLabel.pinRight(to: headerLabel.trailingAnchor)

        emptyLabel.pinTop(to: subtitleLabel.bottomAnchor, 28)
        emptyLabel.pinLeft(to: headerLabel.leadingAnchor)
        emptyLabel.pinRight(to: headerLabel.trailingAnchor)

        tableView.pinTop(to: subtitleLabel.bottomAnchor, 24)
        tableView.pinLeft(to: view.leadingAnchor)
        tableView.pinRight(to: view.trailingAnchor)
        tableView.pinBottom(to: view.bottomAnchor)
    }
}

extension PointSelectionViewController: PointSelectionDisplayLogic {
    func display(viewModel: PointSelection.Load.ViewModel) {
        // ViewModel полностью описывает экран: заголовки, текст пустого состояния
        // и список ячеек. ViewController только применяет эти данные к UIKit.
        headerLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        emptyLabel.text = viewModel.emptyText
        points = viewModel.points

        emptyLabel.isHidden = !points.isEmpty
        tableView.isHidden = points.isEmpty
        tableView.reloadData()
    }
}

extension PointSelectionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        points.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PointCell.reuseIdentifier, for: indexPath)

        if let pointCell = cell as? PointCell {
            pointCell.configure(with: points[indexPath.row])
        }

        return cell
    }
}

extension PointSelectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        interactor.selectPoint(at: indexPath.row)
    }
}

private final class PointCell: UITableViewCell {
    /// Локальная ячейка точки.
    ///
    /// Она спрятана в этом файле, потому что не переиспользуется другими экранами.
    /// Если список точек появится еще где-то, ячейку стоит вынести в отдельный файл.
    static let reuseIdentifier = "PointCell"

    private let containerView = UIView()
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

    func configure(with point: PointSelection.PointViewModel) {
        titleLabel.text = point.title
        subtitleLabel.text = point.subtitle
    }

    private func configureUI() {
        backgroundColor = BrandColor.clear
        contentView.backgroundColor = BrandColor.clear
        selectionStyle = .none

        containerView.backgroundColor = BrandColor.surface
        containerView.layer.cornerRadius = 20
        containerView.layer.cornerCurve = .continuous
        containerView.layer.shadowColor = BrandColor.cgColor(BrandColor.shadow, compatibleWith: traitCollection)
        containerView.layer.shadowOpacity = 0.10
        containerView.layer.shadowRadius = 18
        containerView.layer.shadowOffset = CGSize(width: 0, height: 10)

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
        arrowImageView.setWidth(13)
        arrowImageView.setHeight(13)
    }
}
