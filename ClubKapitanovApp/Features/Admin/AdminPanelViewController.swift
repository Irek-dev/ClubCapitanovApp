import UIKit

final class AdminPanelViewController: UIViewController {
    private enum Section: Int {
        case employees
        case souvenirs
        case fines
        case rentals
        case batteries
    }

    private let point: Point
    private let userRepository: AdminUserRepository
    private let adminPointCatalogRepository: AdminPointCatalogRepository
    private let moneyFormatter = RubleMoneyFormatter()

    private let pointLabel = UILabel()
    private let segmentedControl = UISegmentedControl(items: ["Сотрудники", "Сувенирка", "Штрафы", "Прокат", "Батарейки"])
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    init(
        point: Point,
        userRepository: AdminUserRepository,
        adminPointCatalogRepository: AdminPointCatalogRepository
    ) {
        self.point = point
        self.userRepository = userRepository
        self.adminPointCatalogRepository = adminPointCatalogRepository
        super.init(nibName: nil, bundle: nil)
        adminPointCatalogRepository.configurePointContext(point)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        setupConstraints()
        render()
        refreshDataIfNeeded()
    }

    private func configureUI() {
        title = "Админ-панель"
        view.backgroundColor = BrandColor.background

        pointLabel.text = "Точка: \(point.name)"
        pointLabel.textColor = BrandColor.textPrimary
        pointLabel.font = BrandFont.bold(24)
        pointLabel.numberOfLines = 0

        segmentedControl.selectedSegmentIndex = Section.employees.rawValue
        segmentedControl.selectedSegmentTintColor = BrandColor.primaryBlue
        segmentedControl.setTitleTextAttributes(
            [.foregroundColor: BrandColor.onPrimary, .font: BrandFont.demiBold(14)],
            for: .selected
        )
        segmentedControl.setTitleTextAttributes(
            [.foregroundColor: BrandColor.textPrimary, .font: BrandFont.demiBold(14)],
            for: .normal
        )
        segmentedControl.addTarget(self, action: #selector(didChangeSection), for: .valueChanged)

        scrollView.backgroundColor = BrandColor.clear
        scrollView.alwaysBounceVertical = true

        stackView.axis = .vertical
        stackView.spacing = 16

        view.addSubview(pointLabel)
        view.addSubview(segmentedControl)
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
    }

    private func setupConstraints() {
        pointLabel.pinTop(to: view.safeAreaLayoutGuide.topAnchor, 24)
        pointLabel.pinLeft(to: view.layoutMarginsGuide.leadingAnchor)
        pointLabel.pinRight(to: view.layoutMarginsGuide.trailingAnchor)

        segmentedControl.pinTop(to: pointLabel.bottomAnchor, 18)
        segmentedControl.pinLeft(to: pointLabel.leadingAnchor)
        segmentedControl.pinRight(to: pointLabel.trailingAnchor)
        segmentedControl.setHeight(42)

        scrollView.pinTop(to: segmentedControl.bottomAnchor, 22)
        scrollView.pinLeft(to: view.leadingAnchor)
        scrollView.pinRight(to: view.trailingAnchor)
        scrollView.pinBottom(to: view.bottomAnchor)

        stackView.pinTop(to: scrollView.contentLayoutGuide.topAnchor)
        stackView.pinLeft(to: scrollView.contentLayoutGuide.leadingAnchor, 24)
        stackView.pinRight(to: scrollView.contentLayoutGuide.trailingAnchor, 24)
        stackView.pinBottom(to: scrollView.contentLayoutGuide.bottomAnchor, 24)
        stackView.pinWidth(to: scrollView.frameLayoutGuide.widthAnchor, constant: -48)
    }

    private func render() {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        switch Section(rawValue: segmentedControl.selectedSegmentIndex) ?? .employees {
        case .employees:
            renderEmployees()
        case .souvenirs:
            renderSouvenirs()
        case .fines:
            renderFines()
        case .rentals:
            renderRentals()
        case .batteries:
            renderBatteries()
        }
    }

    private func refreshDataIfNeeded() {
        userRepository.refreshUsers { [weak self] in
            self?.render()
        }

        adminPointCatalogRepository.refreshSouvenirs(pointID: point.id) { [weak self] in
            self?.render()
        }
        adminPointCatalogRepository.refreshRentalTypes(pointID: point.id) { [weak self] in
            self?.render()
        }
        adminPointCatalogRepository.refreshFineTemplates(pointID: point.id) { [weak self] in
            self?.render()
        }
        adminPointCatalogRepository.refreshBatteryTypes(pointID: point.id) { [weak self] in
            self?.render()
        }
    }

    private func renderEmployees() {
        let employees = userRepository
            .getAllUsers(includeArchived: false)
            .filter { $0.role != .admin }

        stackView.addArrangedSubview(makeIntroLabel("Глобальный список сотрудников. PIN генерируется случайно и хранится в Firebase."))
        stackView.addArrangedSubview(
            makeActionButton(
                title: "Добавить сотрудника",
                systemName: "person.badge.plus",
                color: BrandColor.primaryBlue,
                action: #selector(didTapAddEmployee)
            )
        )

        let cardStack = makeCardStack(title: "Сотрудники")
        if userRepository.lastLoadError != nil {
            cardStack.addArrangedSubview(makeSecondaryLabel("Не удалось загрузить сотрудников. Проверьте интернет и попробуйте снова."))
            cardStack.addArrangedSubview(
                makeActionButton(
                    title: "Повторить загрузку",
                    systemName: "arrow.clockwise",
                    color: BrandColor.primaryBlue,
                    action: #selector(didTapRetryEmployees)
                )
            )
        } else if employees.isEmpty {
            cardStack.addArrangedSubview(makeSecondaryLabel("Сотрудников пока нет"))
        } else {
            employees.forEach { user in
                cardStack.addArrangedSubview(makeEmployeeRow(user))
            }
        }
        stackView.addArrangedSubview(makeShadowCard(containing: cardStack))
    }

    private func renderSouvenirs() {
        let products = adminPointCatalogRepository.getSouvenirProducts(pointID: point.id)

        stackView.addArrangedSubview(makeIntroLabel("Каталог сувенирки для выбранной точки. Изменения не затрагивают другие точки."))
        stackView.addArrangedSubview(
            makeActionButton(
                title: "Добавить сувенир",
                systemName: "plus",
                color: BrandColor.accentOrange,
                action: #selector(didTapAddSouvenir)
            )
        )

        let cardStack = makeCardStack(title: "Сувенирка \(point.name)")
        if adminPointCatalogRepository.lastSouvenirsLoadError != nil {
            cardStack.addArrangedSubview(makeSecondaryLabel("Не удалось загрузить сувенирку. Проверьте интернет и попробуйте снова."))
            cardStack.addArrangedSubview(
                makeActionButton(
                    title: "Повторить загрузку",
                    systemName: "arrow.clockwise",
                    color: BrandColor.accentOrange,
                    action: #selector(didTapRetrySouvenirs)
                )
            )
        } else if products.isEmpty {
            cardStack.addArrangedSubview(makeSecondaryLabel("Сувенирки пока нет"))
        } else {
            products.forEach { product in
                cardStack.addArrangedSubview(makeSouvenirRow(product))
            }
        }
        stackView.addArrangedSubview(makeShadowCard(containing: cardStack))
    }

    private func renderFines() {
        let templates = adminPointCatalogRepository.getFineTemplates(pointID: point.id)

        stackView.addArrangedSubview(makeIntroLabel("Штрафы выбранной точки. Сотрудники увидят этот список в рабочей смене."))
        stackView.addArrangedSubview(
            makeActionButton(
                title: "Добавить штраф",
                systemName: "exclamationmark.triangle",
                color: BrandColor.error,
                action: #selector(didTapAddFine)
            )
        )

        let cardStack = makeCardStack(title: "Штрафы \(point.name)")
        if adminPointCatalogRepository.lastFineTemplatesLoadError != nil {
            cardStack.addArrangedSubview(makeSecondaryLabel("Не удалось загрузить штрафы. Проверьте интернет и попробуйте снова."))
            cardStack.addArrangedSubview(
                makeActionButton(
                    title: "Повторить загрузку",
                    systemName: "arrow.clockwise",
                    color: BrandColor.error,
                    action: #selector(didTapRetryFines)
                )
            )
        } else if templates.isEmpty {
            cardStack.addArrangedSubview(makeSecondaryLabel("Штрафов пока нет"))
        } else {
            templates.forEach { template in
                cardStack.addArrangedSubview(makeFineRow(template))
            }
        }
        stackView.addArrangedSubview(makeShadowCard(containing: cardStack))
    }

    private func renderRentals() {
        let rentalTypes = adminPointCatalogRepository.getRentalTypes(pointID: point.id)

        stackView.addArrangedSubview(makeIntroLabel("Кораблики точки: цена, базовый период, ставка ЗП и количество доступных штук."))

        let rentalTypeButton = makeActionButton(
            title: "Добавить кораблик",
            systemName: "sailboat",
            color: BrandColor.primaryBlue,
            action: #selector(didTapAddRentalType)
        )
        stackView.addArrangedSubview(rentalTypeButton)

        let typeCardStack = makeCardStack(title: "Кораблики")
        if adminPointCatalogRepository.lastRentalTypesLoadError != nil {
            typeCardStack.addArrangedSubview(makeSecondaryLabel("Не удалось загрузить прокат. Проверьте интернет и попробуйте снова."))
            typeCardStack.addArrangedSubview(
                makeActionButton(
                    title: "Повторить загрузку",
                    systemName: "arrow.clockwise",
                    color: BrandColor.primaryBlue,
                    action: #selector(didTapRetryRentals)
                )
            )
        } else if rentalTypes.isEmpty {
            typeCardStack.addArrangedSubview(makeSecondaryLabel("Корабликов пока нет"))
        } else {
            rentalTypes.forEach { rentalType in
                typeCardStack.addArrangedSubview(makeRentalTypeRow(rentalType))
            }
        }
        stackView.addArrangedSubview(makeShadowCard(containing: typeCardStack))
    }

    private func renderBatteries() {
        let batteries = adminPointCatalogRepository.getBatteryItems(pointID: point.id)

        stackView.addArrangedSubview(makeIntroLabel("Батарейки выбранной точки и текущий учетный остаток."))
        stackView.addArrangedSubview(
            makeActionButton(
                title: "Добавить батарейку",
                systemName: "battery.100percent",
                color: BrandColor.primaryBlue,
                action: #selector(didTapAddBattery)
            )
        )

        let cardStack = makeCardStack(title: "Батарейки \(point.name)")
        if adminPointCatalogRepository.lastBatteryTypesLoadError != nil {
            cardStack.addArrangedSubview(makeSecondaryLabel("Не удалось загрузить батарейки. Проверьте интернет и попробуйте снова."))
            cardStack.addArrangedSubview(
                makeActionButton(
                    title: "Повторить загрузку",
                    systemName: "arrow.clockwise",
                    color: BrandColor.primaryBlue,
                    action: #selector(didTapRetryBatteries)
                )
            )
        } else if batteries.isEmpty {
            cardStack.addArrangedSubview(makeSecondaryLabel("Батареек пока нет"))
        } else {
            batteries.forEach { battery in
                cardStack.addArrangedSubview(makeBatteryRow(battery))
            }
        }
        stackView.addArrangedSubview(makeShadowCard(containing: cardStack))
    }

    private func makeEmployeeRow(_ user: User) -> UIView {
        let rowView = UIView()
        let labelsStackView = UIStackView()
        let actionsStackView = UIStackView()
        let nameLabel = makePrimaryLabel(user.fullName)
        let detailLabel = makeSecondaryLabel("PIN \(user.pinCode) · \(roleTitle(user.role))")
        let editButton = makeIconButton(systemName: "pencil", color: BrandColor.primaryBlue)
        let deleteButton = makeIconButton(systemName: "trash", color: BrandColor.error)

        labelsStackView.axis = .vertical
        labelsStackView.spacing = 3
        labelsStackView.addArrangedSubview(nameLabel)
        labelsStackView.addArrangedSubview(detailLabel)

        actionsStackView.axis = .horizontal
        actionsStackView.spacing = 8
        actionsStackView.addArrangedSubview(editButton)
        actionsStackView.addArrangedSubview(deleteButton)

        editButton.addAction(UIAction { [weak self] _ in self?.showEmployeeForm(user: user) }, for: .touchUpInside)
        deleteButton.addAction(UIAction { [weak self] _ in self?.confirmDelete(user: user) }, for: .touchUpInside)

        rowView.addSubview(labelsStackView)
        rowView.addSubview(actionsStackView)

        labelsStackView.pinTop(to: rowView.topAnchor, 4)
        labelsStackView.pinLeft(to: rowView.leadingAnchor)
        labelsStackView.pinRight(to: actionsStackView.leadingAnchor, 14)
        labelsStackView.pinBottom(to: rowView.bottomAnchor, 4)

        actionsStackView.pinRight(to: rowView.trailingAnchor)
        actionsStackView.pinCenterY(to: rowView)
        rowView.setHeight(mode: .grOE, 52)
        return rowView
    }

    private func makeSouvenirRow(_ product: SouvenirProduct) -> UIView {
        let rowView = UIView()
        let labelsStackView = UIStackView()
        let actionsStackView = UIStackView()
        let titleLabel = makePrimaryLabel(product.name)
        let quantity = adminPointCatalogRepository.getSouvenirQuantity(productID: product.id, pointID: point.id)
        let detailLabel = makeSecondaryLabel("\(moneyFormatter.string(from: product.price, includesCurrencySymbol: true)) · \(quantity) шт.")
        let editButton = makeIconButton(systemName: "pencil", color: BrandColor.primaryBlue)
        let deleteButton = makeIconButton(systemName: "trash", color: BrandColor.error)

        labelsStackView.axis = .vertical
        labelsStackView.spacing = 3
        labelsStackView.addArrangedSubview(titleLabel)
        labelsStackView.addArrangedSubview(detailLabel)

        actionsStackView.axis = .horizontal
        actionsStackView.spacing = 8
        actionsStackView.addArrangedSubview(editButton)
        actionsStackView.addArrangedSubview(deleteButton)

        editButton.addAction(UIAction { [weak self] _ in self?.showSouvenirForm(product: product) }, for: .touchUpInside)
        deleteButton.addAction(UIAction { [weak self] _ in self?.confirmDelete(product: product) }, for: .touchUpInside)

        rowView.addSubview(labelsStackView)
        rowView.addSubview(actionsStackView)

        labelsStackView.pinTop(to: rowView.topAnchor, 4)
        labelsStackView.pinLeft(to: rowView.leadingAnchor)
        labelsStackView.pinRight(to: actionsStackView.leadingAnchor, 14)
        labelsStackView.pinBottom(to: rowView.bottomAnchor, 4)

        actionsStackView.pinRight(to: rowView.trailingAnchor)
        actionsStackView.pinCenterY(to: rowView)
        rowView.setHeight(mode: .grOE, 52)
        return rowView
    }

    private func makeFineRow(_ template: FineTemplate) -> UIView {
        makeEditableRow(
            title: template.title,
            detail: moneyFormatter.string(from: template.amount, includesCurrencySymbol: true),
            editColor: BrandColor.primaryBlue,
            deleteColor: BrandColor.error,
            onEdit: { [weak self] in self?.showFineForm(template: template) },
            onDelete: { [weak self] in self?.confirmDelete(template: template) }
        )
    }

    private func makeRentalTypeRow(_ rentalType: RentalType) -> UIView {
        let tariff = rentalType.defaultTariff
        let price = tariff.map { moneyFormatter.string(from: $0.price, includesCurrencySymbol: true) } ?? "нет цены"
        let duration = tariff.map { "\($0.durationMinutes) мин" } ?? "нет периода"
        return makeEditableRow(
            title: rentalType.name,
            detail: "\(price) · \(duration) · \(rentalType.availableQuantity) шт. · ЗП \(moneyFormatter.string(from: rentalType.payrollRate, includesCurrencySymbol: true))",
            editColor: BrandColor.primaryBlue,
            deleteColor: BrandColor.error,
            onEdit: { [weak self] in self?.showRentalTypeForm(rentalType: rentalType) },
            onDelete: { [weak self] in self?.confirmDelete(rentalType: rentalType) }
        )
    }

    private func makeBatteryRow(_ item: BatteryItem) -> UIView {
        makeEditableRow(
            title: item.title,
            detail: "\(item.quantity) шт.",
            editColor: BrandColor.primaryBlue,
            deleteColor: BrandColor.error,
            onEdit: { [weak self] in self?.showBatteryForm(item: item) },
            onDelete: { [weak self] in self?.confirmDelete(battery: item) }
        )
    }

    private func makeEditableRow(
        title: String,
        detail: String,
        editColor: UIColor,
        deleteColor: UIColor,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> UIView {
        let rowView = UIView()
        let labelsStackView = UIStackView()
        let actionsStackView = UIStackView()
        let titleLabel = makePrimaryLabel(title)
        let detailLabel = makeSecondaryLabel(detail)
        let editButton = makeIconButton(systemName: "pencil", color: editColor)
        let deleteButton = makeIconButton(systemName: "trash", color: deleteColor)

        labelsStackView.axis = .vertical
        labelsStackView.spacing = 3
        labelsStackView.addArrangedSubview(titleLabel)
        labelsStackView.addArrangedSubview(detailLabel)

        actionsStackView.axis = .horizontal
        actionsStackView.spacing = 8
        actionsStackView.addArrangedSubview(editButton)
        actionsStackView.addArrangedSubview(deleteButton)

        editButton.addAction(UIAction { _ in onEdit() }, for: .touchUpInside)
        deleteButton.addAction(UIAction { _ in onDelete() }, for: .touchUpInside)

        rowView.addSubview(labelsStackView)
        rowView.addSubview(actionsStackView)

        labelsStackView.pinTop(to: rowView.topAnchor, 4)
        labelsStackView.pinLeft(to: rowView.leadingAnchor)
        labelsStackView.pinRight(to: actionsStackView.leadingAnchor, 14)
        labelsStackView.pinBottom(to: rowView.bottomAnchor, 4)

        actionsStackView.pinRight(to: rowView.trailingAnchor)
        actionsStackView.pinCenterY(to: rowView)
        rowView.setHeight(mode: .grOE, 52)
        return rowView
    }

    private func makeCardStack(title: String) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.addArrangedSubview(makeTitleLabel(title))
        return stack
    }

    private func makeShadowCard(containing contentView: UIView) -> UIView {
        let cardView = ShiftWorkspaceShadowCardView()
        cardView.addSubview(contentView)
        contentView.pin(to: cardView, 18)
        return cardView
    }

    private func makeActionButton(
        title: String,
        systemName: String,
        color: UIColor,
        action: Selector
    ) -> UIButton {
        let titleFont = BrandFont.demiBold(16)
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: systemName)
        configuration.imagePadding = 8
        configuration.baseBackgroundColor = color
        configuration.baseForegroundColor = BrandColor.onPrimary
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 14, leading: 18, bottom: 14, trailing: 18)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = titleFont
            return outgoing
        }

        let button = UIButton(type: .system)
        button.configuration = configuration
        button.addTarget(self, action: action, for: .touchUpInside)
        button.setHeight(52)
        return button
    }

    private func makeIconButton(systemName: String, color: UIColor) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: systemName)
        configuration.baseBackgroundColor = BrandColor.surfaceMuted
        configuration.baseForegroundColor = color
        configuration.cornerStyle = .capsule
        configuration.contentInsets = .init(top: 9, leading: 9, bottom: 9, trailing: 9)

        let button = UIButton(type: .system)
        button.configuration = configuration
        button.setWidth(40)
        button.setHeight(40)
        return button
    }

    private func makeIntroLabel(_ text: String) -> UILabel {
        makeLabel(text, color: BrandColor.textSecondary, font: BrandFont.regular(16))
    }

    private func makeTitleLabel(_ text: String) -> UILabel {
        makeLabel(text, color: BrandColor.textPrimary, font: BrandFont.bold(18))
    }

    private func makePrimaryLabel(_ text: String) -> UILabel {
        makeLabel(text, color: BrandColor.textPrimary, font: BrandFont.demiBold(16))
    }

    private func makeSecondaryLabel(_ text: String) -> UILabel {
        makeLabel(text, color: BrandColor.textSecondary, font: BrandFont.regular(14))
    }

    private func makeLabel(_ text: String, color: UIColor, font: UIFont) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = font
        label.numberOfLines = 0
        return label
    }

    private func roleTitle(_ role: UserRole) -> String {
        switch role {
        case .staff:
            return "сотрудник"
        case .manager:
            return "менеджер"
        case .admin:
            return "администратор"
        }
    }

    private func parseRubles(_ text: String?) -> Money? {
        guard let text else { return nil }
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let decimal = Decimal(string: normalized), decimal >= 0 else {
            return nil
        }
        return Money(amount: decimal)
    }

    @objc
    private func didChangeSection() {
        render()
    }

    @objc
    private func didTapAddEmployee() {
        showEmployeeForm(user: nil)
    }

    @objc
    private func didTapRetryEmployees() {
        userRepository.refreshUsers { [weak self] in
            self?.render()
        }
    }

    @objc
    private func didTapRetrySouvenirs() {
        adminPointCatalogRepository.refreshSouvenirs(pointID: point.id) { [weak self] in
            self?.render()
        }
    }

    @objc
    private func didTapRetryFines() {
        adminPointCatalogRepository.refreshFineTemplates(pointID: point.id) { [weak self] in
            self?.render()
        }
    }

    @objc
    private func didTapRetryRentals() {
        adminPointCatalogRepository.refreshRentalTypes(pointID: point.id) { [weak self] in
            self?.render()
        }
    }

    @objc
    private func didTapRetryBatteries() {
        adminPointCatalogRepository.refreshBatteryTypes(pointID: point.id) { [weak self] in
            self?.render()
        }
    }

    @objc
    private func didTapAddSouvenir() {
        showSouvenirForm(product: nil)
    }

    @objc
    private func didTapAddFine() {
        showFineForm(template: nil)
    }

    @objc
    private func didTapAddRentalType() {
        showRentalTypeForm(rentalType: nil)
    }

    @objc
    private func didTapAddBattery() {
        showBatteryForm(item: nil)
    }
}

private extension AdminPanelViewController {
    func showEmployeeForm(user: User?) {
        let form = AdminFormViewController(
            title: user == nil ? "Новый сотрудник" : "Редактировать сотрудника",
            subtitle: user == nil ? "PIN будет создан случайно." : "PIN сотрудника не меняется.",
            fields: [
                .init(key: "lastName", placeholder: "Фамилия", text: user?.lastName),
                .init(key: "firstName", placeholder: "Имя", text: user?.firstName)
            ],
            submitTitle: user == nil ? "Добавить" : "Сохранить",
            submitColor: BrandColor.primaryBlue
        ) { [weak self] values in
                guard let self else { return }
                let lastName = values["lastName"] ?? ""
                let firstName = values["firstName"] ?? ""
                guard !lastName.isEmpty, !firstName.isEmpty else {
                    self.showMessage(title: "Не сохранено", message: "Заполните имя и фамилию.")
                    return
                }

                if let user {
                    let updatedUser = User(
                        id: user.id,
                        pinCode: user.pinCode,
                        firstName: firstName,
                        lastName: lastName,
                        role: user.role,
                        accountStatus: user.accountStatus,
                        managedPointID: user.managedPointID
                    )
                    self.userRepository.updateUser(updatedUser) { [weak self] result in
                        guard let self else { return }
                        switch result {
                        case .success:
                            self.render()
                        case let .failure(error):
                            self.showMessage(title: "Не сохранено", message: error.localizedDescription)
                        }
                    }
                } else {
                    self.userRepository.createUser(
                        firstName: firstName,
                        lastName: lastName,
                        role: .staff
                    ) { [weak self] result in
                        guard let self else { return }
                        switch result {
                        case let .success(createdUser):
                            self.render()
                            self.showMessage(
                                title: "Сотрудник добавлен",
                                message: "PIN: \(createdUser.pinCode)"
                            )
                        case let .failure(error):
                            self.showMessage(title: "Не сохранено", message: error.localizedDescription)
                        }
                    }
                }
        }

        present(form, animated: true)
    }

    func confirmDelete(user: User) {
        let alert = UIAlertController(
            title: "Удалить сотрудника?",
            message: "\(user.fullName) будет полностью удален и больше не сможет войти по PIN \(user.pinCode).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
                guard let self else { return }
                self.userRepository.deleteUser(id: user.id) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.render()
                    case let .failure(error):
                        self.showMessage(title: "Не удалено", message: error.localizedDescription)
                    }
                }
            }
        )
        present(alert, animated: true)
    }

    func showSouvenirForm(product: SouvenirProduct?) {
        let quantity = product.map {
            adminPointCatalogRepository.getSouvenirQuantity(productID: $0.id, pointID: point.id)
        } ?? 0
        let form = AdminFormViewController(
            title: product == nil ? "Новый сувенир" : "Редактировать сувенир",
            subtitle: "Точка: \(point.name)",
            fields: [
                .init(key: "name", placeholder: "Название", text: product?.name),
                .init(key: "price", placeholder: "Цена, ₽", text: product.map { moneyFormatter.string(from: $0.price) }, keyboardType: .decimalPad),
                .init(key: "quantity", placeholder: "Количество", text: "\(quantity)", keyboardType: .numberPad)
            ],
            submitTitle: product == nil ? "Добавить" : "Сохранить",
            submitColor: BrandColor.accentOrange
        ) { [weak self] values in
                guard let self else { return }
                let name = values["name"] ?? ""
                let price = self.parseRubles(values["price"])
                let quantity = Int(values["quantity"] ?? "") ?? -1
                guard !name.isEmpty, let price, quantity >= 0 else {
                    self.showMessage(title: "Не сохранено", message: "Проверьте название, цену и количество.")
                    return
                }

                if let product {
                    self.adminPointCatalogRepository.updateSouvenirProduct(
                        SouvenirProduct(
                            id: product.id,
                            pointID: product.pointID,
                            name: name,
                            price: price,
                            isActive: product.isActive,
                            sortOrder: product.sortOrder
                        ),
                        quantity: quantity
                    ) { [weak self] result in
                        guard let self else { return }
                        switch result {
                        case .success:
                            self.render()
                        case let .failure(error):
                            self.showMessage(title: "Не сохранено", message: error.localizedDescription)
                        }
                    }
                } else {
                    self.adminPointCatalogRepository.createSouvenirProduct(
                        pointID: self.point.id,
                        name: name,
                        price: price,
                        quantity: quantity
                    ) { [weak self] result in
                        guard let self else { return }
                        switch result {
                        case .success:
                            self.render()
                        case let .failure(error):
                            self.showMessage(title: "Не сохранено", message: error.localizedDescription)
                        }
                    }
                }
        }

        present(form, animated: true)
    }

    func confirmDelete(product: SouvenirProduct) {
        let alert = UIAlertController(
            title: "Удалить сувенир?",
            message: "\(product.name) будет полностью удален из каталога точки \(point.name).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
                guard let self else { return }
                self.adminPointCatalogRepository.deleteSouvenirProduct(id: product.id, pointID: self.point.id) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.render()
                    case let .failure(error):
                        self.showMessage(title: "Не удалено", message: error.localizedDescription)
                    }
                }
            }
        )
        present(alert, animated: true)
    }

    func showFineForm(template: FineTemplate?) {
        let form = AdminFormViewController(
            title: template == nil ? "Новый штраф" : "Редактировать штраф",
            subtitle: "Точка: \(point.name)",
            fields: [
                .init(key: "title", placeholder: "Название штрафа", text: template?.title),
                .init(key: "amount", placeholder: "Сумма, ₽", text: template.map { moneyFormatter.string(from: $0.amount) }, keyboardType: .decimalPad)
            ],
            submitTitle: template == nil ? "Добавить" : "Сохранить",
            submitColor: BrandColor.error
        ) { [weak self] values in
                guard let self else { return }
                let title = values["title"] ?? ""
                let amount = self.parseRubles(values["amount"])
                guard !title.isEmpty, let amount else {
                    self.showMessage(title: "Не сохранено", message: "Проверьте название и сумму штрафа.")
                    return
                }

                if let template {
                    self.adminPointCatalogRepository.updateFineTemplate(
                        FineTemplate(
                            id: template.id,
                            pointID: template.pointID,
                            title: title,
                            amount: amount,
                            isActive: template.isActive,
                            sortOrder: template.sortOrder
                        )
                    ) { [weak self] result in
                        guard let self else { return }
                        switch result {
                        case .success:
                            self.render()
                        case let .failure(error):
                            self.showMessage(title: "Не сохранено", message: error.localizedDescription)
                        }
                    }
                } else {
                    self.adminPointCatalogRepository.createFineTemplate(
                        pointID: self.point.id,
                        title: title,
                        amount: amount
                    ) { [weak self] result in
                        guard let self else { return }
                        switch result {
                        case .success:
                            self.render()
                        case let .failure(error):
                            self.showMessage(title: "Не сохранено", message: error.localizedDescription)
                        }
                    }
                }
        }

        present(form, animated: true)
    }

    func confirmDelete(template: FineTemplate) {
        let alert = UIAlertController(
            title: "Удалить штраф?",
            message: "\(template.title) будет полностью удален из списка штрафов точки \(point.name).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
                guard let self else { return }
                self.adminPointCatalogRepository.deleteFineTemplate(id: template.id, pointID: self.point.id) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.render()
                    case let .failure(error):
                        self.showMessage(title: "Не удалено", message: error.localizedDescription)
                    }
                }
            }
        )
        present(alert, animated: true)
    }

    func showRentalTypeForm(rentalType: RentalType?) {
        let defaultTariff = rentalType?.defaultTariff
        let form = AdminFormViewController(
            title: rentalType == nil ? "Новый кораблик" : "Редактировать кораблик",
            subtitle: "Цена, период, ЗП и количество используются для рабочего каталога точки.",
            fields: [
                .init(key: "name", placeholder: "Название, например Утка", text: rentalType?.name),
                .init(key: "code", placeholder: "Короткий код, например duck", text: rentalType?.code, autocapitalizationType: .none),
                .init(key: "price", placeholder: "Цена за период, ₽", text: defaultTariff.map { moneyFormatter.string(from: $0.price) }, keyboardType: .decimalPad),
                .init(key: "duration", placeholder: "Длительность периода, минут", text: defaultTariff.map { "\($0.durationMinutes)" } ?? "20", keyboardType: .numberPad),
                .init(key: "payroll", placeholder: "Ставка ЗП, ₽", text: rentalType.map { moneyFormatter.string(from: $0.payrollRate) } ?? "50", keyboardType: .decimalPad),
                .init(key: "quantity", placeholder: "Количество доступных штук", text: rentalType.map { "\($0.availableQuantity)" } ?? "1", keyboardType: .numberPad)
            ],
            submitTitle: rentalType == nil ? "Добавить" : "Сохранить",
            submitColor: BrandColor.primaryBlue
        ) { [weak self] values in
                guard let self else { return }
                let name = values["name"] ?? ""
                let code = self.normalizedCode(values["code"], fallbackName: name)
                let price = self.parseRubles(values["price"])
                let duration = Int(values["duration"] ?? "") ?? 0
                let payrollRate = self.parseRubles(values["payroll"])
                let quantity = Int(values["quantity"] ?? "") ?? -1

                guard !name.isEmpty, !code.isEmpty, let price, duration > 0, let payrollRate, quantity >= 0 else {
                    self.showMessage(title: "Не сохранено", message: "Проверьте название, код, цену, период, ставку ЗП и количество.")
                    return
                }

                if let rentalType {
                    let oldTariff = rentalType.defaultTariff
                    let updatedTariff = RentalTariff(
                        id: oldTariff?.id ?? UUID(),
                        title: "\(duration) минут",
                        durationMinutes: duration,
                        price: price,
                        sortOrder: oldTariff?.sortOrder ?? 0,
                        isActive: oldTariff?.isActive ?? true
                    )
                    self.adminPointCatalogRepository.updateRentalType(
                        RentalType(
                            id: rentalType.id,
                            pointID: rentalType.pointID,
                            name: name,
                            code: code,
                            tariffs: [updatedTariff],
                            payrollRate: payrollRate,
                            availableQuantity: quantity,
                            isActive: rentalType.isActive
                        )
                    ) { [weak self] result in
                        guard let self else { return }
                        switch result {
                        case .success:
                            self.render()
                        case let .failure(error):
                            self.showMessage(title: "Не сохранено", message: error.localizedDescription)
                        }
                    }
                } else {
                    self.adminPointCatalogRepository.createRentalType(
                        pointID: self.point.id,
                        name: name,
                        code: code,
                        durationMinutes: duration,
                        price: price,
                        payrollRate: payrollRate,
                        quantity: quantity
                    ) { [weak self] result in
                        guard let self else { return }
                        switch result {
                        case .success:
                            self.render()
                        case let .failure(error):
                            self.showMessage(title: "Не сохранено", message: error.localizedDescription)
                        }
                    }
                }
        }

        present(form, animated: true)
    }

    func confirmDelete(rentalType: RentalType) {
        let alert = UIAlertController(
            title: "Удалить кораблик?",
            message: "\(rentalType.name) будет полностью удален из проката точки \(point.name).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
                guard let self else { return }
                self.adminPointCatalogRepository.deleteRentalType(id: rentalType.id, pointID: self.point.id) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.render()
                    case let .failure(error):
                        self.showMessage(title: "Не удалено", message: error.localizedDescription)
                    }
                }
            }
        )
        present(alert, animated: true)
    }

    func showBatteryForm(item: BatteryItem?) {
        let form = AdminFormViewController(
            title: item == nil ? "Новая батарейка" : "Редактировать батарейку",
            subtitle: "Точка: \(point.name)",
            fields: [
                .init(key: "title", placeholder: "Название батарейки", text: item?.title),
                .init(key: "quantity", placeholder: "Количество", text: item.map { "\($0.quantity)" } ?? "0", keyboardType: .numberPad)
            ],
            submitTitle: item == nil ? "Добавить" : "Сохранить",
            submitColor: BrandColor.primaryBlue
        ) { [weak self] values in
            guard let self else { return }
            let title = values["title"] ?? ""
            let quantity = Int(values["quantity"] ?? "") ?? -1
            guard !title.isEmpty, quantity >= 0 else {
                self.showMessage(title: "Не сохранено", message: "Проверьте название и количество.")
                return
            }

            if let item {
                self.adminPointCatalogRepository.updateBatteryItem(
                    BatteryItem(
                        id: item.id,
                        pointID: item.pointID,
                        title: title,
                        quantity: quantity
                    )
                ) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.render()
                    case let .failure(error):
                        self.showMessage(title: "Не сохранено", message: error.localizedDescription)
                    }
                }
            } else {
                self.adminPointCatalogRepository.createBatteryItem(
                    pointID: self.point.id,
                    title: title,
                    quantity: quantity
                ) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.render()
                    case let .failure(error):
                        self.showMessage(title: "Не сохранено", message: error.localizedDescription)
                    }
                }
            }
        }

        present(form, animated: true)
    }

    func confirmDelete(battery: BatteryItem) {
        let alert = UIAlertController(
            title: "Удалить батарейку?",
            message: "\(battery.title) будет полностью удалена из списка точки \(point.name).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
                guard let self else { return }
                self.adminPointCatalogRepository.deleteBatteryItem(id: battery.id, pointID: self.point.id) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.render()
                    case let .failure(error):
                        self.showMessage(title: "Не удалено", message: error.localizedDescription)
                    }
                }
            }
        )
        present(alert, animated: true)
    }

    func normalizedCode(_ text: String?, fallbackName: String) -> String {
        let rawText = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let source = rawText.isEmpty ? fallbackName : rawText
        return source
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
