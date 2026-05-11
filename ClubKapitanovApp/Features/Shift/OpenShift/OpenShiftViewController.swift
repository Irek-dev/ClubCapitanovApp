import UIKit

/// UI подтверждения открытия смены.
///
/// Экран показывает выбранную точку, сотрудника и кнопку входа в рабочее пространство.
/// Вся логика открытия/переиспользования смены находится в Interactor.
protocol OpenShiftDisplayLogic: AnyObject {
    func display(viewModel: OpenShift.Load.ViewModel)
    func displayLoading(isLoading: Bool)
    func displayError(message: String)
}

final class OpenShiftViewController: UIViewController {
    private let interactor: OpenShiftBusinessLogic

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let pointLabel = UILabel()
    private let employeeLabel = UILabel()
    private let openShiftButton = UIButton(type: .system)
    private var defaultButtonTitle = "Открыть смену"

    init(interactor: OpenShiftBusinessLogic) {
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
        // Карточка центрируется и ограничивается по ширине, чтобы экран хорошо
        // выглядел на iPad в разных ориентациях.
        title = "Открытие смены"
        view.backgroundColor = BrandColor.background

        cardView.backgroundColor = BrandColor.surface
        cardView.layer.cornerRadius = 28
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = BrandColor.cgColor(BrandColor.shadow, compatibleWith: traitCollection)
        cardView.layer.shadowOpacity = 0.12
        cardView.layer.shadowRadius = 28
        cardView.layer.shadowOffset = CGSize(width: 0, height: 16)

        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.bold(30)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        pointLabel.textColor = BrandColor.textPrimary
        pointLabel.font = BrandFont.demiBold(20)
        pointLabel.textAlignment = .center
        pointLabel.numberOfLines = 0

        employeeLabel.textColor = BrandColor.textSecondary
        employeeLabel.font = BrandFont.regular(16)
        employeeLabel.textAlignment = .center
        employeeLabel.numberOfLines = 0

        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = BrandColor.primaryBlue
        configuration.baseForegroundColor = BrandColor.onPrimary
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 16, leading: 18, bottom: 16, trailing: 18)

        openShiftButton.configuration = configuration
        openShiftButton.titleLabel?.font = BrandFont.demiBold(17)
        openShiftButton.addTarget(self, action: #selector(didTapOpenShiftButton), for: .touchUpInside)

        view.addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(pointLabel)
        cardView.addSubview(employeeLabel)
        cardView.addSubview(openShiftButton)
    }

    private func setupConstraints() {
        let maxCardWidth: CGFloat = 460

        cardView.pinCenter(to: view)
        cardView.pinLeft(to: view.layoutMarginsGuide.leadingAnchor, 0, .grOE)
        cardView.pinRight(to: view.layoutMarginsGuide.trailingAnchor, 0, .lsOE)
        cardView.setWidth(mode: .lsOE, Double(maxCardWidth))
        cardView.pinWidth(to: view.widthAnchor, constant: -40, priority: .defaultHigh)

        titleLabel.pinTop(to: cardView.topAnchor, 32)
        titleLabel.pinLeft(to: cardView.leadingAnchor, 26)
        titleLabel.pinRight(to: cardView.trailingAnchor, 26)

        pointLabel.pinTop(to: titleLabel.bottomAnchor, 20)
        pointLabel.pinLeft(to: titleLabel.leadingAnchor)
        pointLabel.pinRight(to: titleLabel.trailingAnchor)

        employeeLabel.pinTop(to: pointLabel.bottomAnchor, 10)
        employeeLabel.pinLeft(to: titleLabel.leadingAnchor)
        employeeLabel.pinRight(to: titleLabel.trailingAnchor)

        openShiftButton.pinTop(to: employeeLabel.bottomAnchor, 32)
        openShiftButton.pinLeft(to: titleLabel.leadingAnchor)
        openShiftButton.pinRight(to: titleLabel.trailingAnchor)
        openShiftButton.pinBottom(to: cardView.bottomAnchor, 32)
        openShiftButton.setHeight(56)
    }

    @objc
    private func didTapOpenShiftButton() {
        // UI не создает смену напрямую, а отправляет пользовательское событие в
        // Interactor, где находятся бизнес-правила.
        interactor.openShift()
    }
}

extension OpenShiftViewController: OpenShiftDisplayLogic {
    func display(viewModel: OpenShift.Load.ViewModel) {
        // ViewModel содержит готовые тексты, поэтому экран просто раскладывает их
        // по UILabel/UIButton.
        titleLabel.text = viewModel.title
        pointLabel.text = viewModel.pointText
        employeeLabel.text = viewModel.employeeText
        defaultButtonTitle = viewModel.buttonTitle
        openShiftButton.configuration?.title = viewModel.buttonTitle
    }

    func displayLoading(isLoading: Bool) {
        openShiftButton.isEnabled = !isLoading
        openShiftButton.configuration?.title = isLoading ? "Загрузка каталогов..." : defaultButtonTitle
    }

    func displayError(message: String) {
        let alert = UIAlertController(
            title: "Смену нельзя открыть",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }
}
