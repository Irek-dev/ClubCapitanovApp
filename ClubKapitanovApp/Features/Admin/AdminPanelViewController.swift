import UIKit

final class AdminPanelViewController: UIViewController {
    private enum Section: Int {
        case employees
        case souvenirs
        case fines
        case rentals
    }

    private let point: Point
    private let authRepository: AuthRepository
    private let catalogRepository: CatalogRepository
    private let moneyFormatter = RubleMoneyFormatter()

    private let pointLabel = UILabel()
    private let segmentedControl = UISegmentedControl(items: ["Сотрудники", "Сувенирка", "Штрафы", "Прокат"])
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    init(
        point: Point,
        authRepository: AuthRepository,
        catalogRepository: CatalogRepository
    ) {
        self.point = point
        self.authRepository = authRepository
        self.catalogRepository = catalogRepository
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
        }
    }

    private func refreshDataIfNeeded() {
        if let authRepository = authRepository as? AuthRepositoryCacheRefreshing {
            authRepository.refreshUsers { [weak self] in
                self?.render()
            }
        }

        if let catalogRepository = catalogRepository as? CatalogRepositoryCacheRefreshing {
            catalogRepository.refreshCatalog(pointID: point.id) { [weak self] in
                self?.render()
            }
        }
    }

    private func renderEmployees() {
        let employees = authRepository
            .getAllUsers(includeArchived: false)
            .filter { $0.role != .admin }

        stackView.addArrangedSubview(makeIntroLabel("Глобальный список сотрудников. PIN генерируется автоматически и проверяется в общем AuthRepository."))
        stackView.addArrangedSubview(
            makeActionButton(
                title: "Добавить сотрудника",
                systemName: "person.badge.plus",
                color: BrandColor.primaryBlue,
                action: #selector(didTapAddEmployee)
            )
        )

        let cardStack = makeCardStack(title: "Сотрудники")
        if employees.isEmpty {
            cardStack.addArrangedSubview(makeSecondaryLabel("Сотрудников пока нет"))
        } else {
            employees.forEach { user in
                cardStack.addArrangedSubview(makeEmployeeRow(user))
            }
        }
        stackView.addArrangedSubview(makeShadowCard(containing: cardStack))
    }

    private func renderSouvenirs() {
        let products = catalogRepository.getSouvenirProducts(pointID: point.id)

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
        if products.isEmpty {
            cardStack.addArrangedSubview(makeSecondaryLabel("Сувенирка на этой точке пока не создана"))
        } else {
            products.forEach { product in
                cardStack.addArrangedSubview(makeSouvenirRow(product))
            }
        }
        stackView.addArrangedSubview(makeShadowCard(containing: cardStack))
    }

    private func renderFines() {
        let templates = catalogRepository.getFineTemplates(pointID: point.id)

        stackView.addArrangedSubview(makeIntroLabel("Шаблоны штрафов для выбранной точки. Сотрудники будут видеть только активные шаблоны."))
        stackView.addArrangedSubview(
            makeActionButton(
                title: "Добавить штраф",
                systemName: "exclamationmark.triangle",
                color: BrandColor.error,
                action: #selector(didTapAddFine)
            )
        )

        let cardStack = makeCardStack(title: "Штрафы \(point.name)")
        if templates.isEmpty {
            cardStack.addArrangedSubview(makeSecondaryLabel("Штрафы на этой точке пока не настроены"))
        } else {
            templates.forEach { template in
                cardStack.addArrangedSubview(makeFineRow(template))
            }
        }
        stackView.addArrangedSubview(makeShadowCard(containing: cardStack))
    }

    private func renderRentals() {
        let rentalTypes = catalogRepository.getRentalTypes(pointID: point.id)
        let rentalAssets = catalogRepository.getRentalAssets(pointID: point.id)

        stackView.addArrangedSubview(makeIntroLabel("Каталог проката точки: типы корабликов, цена за базовый период и конкретные номера объектов."))

        let rentalTypeButton = makeActionButton(
            title: "Добавить тип проката",
            systemName: "sailboat",
            color: BrandColor.primaryBlue,
            action: #selector(didTapAddRentalType)
        )
        let rentalAssetButton = makeActionButton(
            title: "Добавить объект",
            systemName: "plus",
            color: BrandColor.accentOrange,
            action: #selector(didTapAddRentalAsset)
        )
        stackView.addArrangedSubview(rentalTypeButton)
        stackView.addArrangedSubview(rentalAssetButton)

        let typeCardStack = makeCardStack(title: "Типы проката")
        if rentalTypes.isEmpty {
            typeCardStack.addArrangedSubview(makeSecondaryLabel("Типы проката пока не настроены"))
        } else {
            rentalTypes.forEach { rentalType in
                let assetsCount = rentalAssets.filter { $0.rentalTypeID == rentalType.id }.count
                typeCardStack.addArrangedSubview(makeRentalTypeRow(rentalType, assetsCount: assetsCount))
            }
        }
        stackView.addArrangedSubview(makeShadowCard(containing: typeCardStack))

        let assetsCardStack = makeCardStack(title: "Объекты проката")
        if rentalAssets.isEmpty {
            assetsCardStack.addArrangedSubview(makeSecondaryLabel("Объекты проката пока не добавлены"))
        } else {
            rentalAssets.forEach { asset in
                let rentalType = rentalTypes.first { $0.id == asset.rentalTypeID }
                assetsCardStack.addArrangedSubview(makeRentalAssetRow(asset, rentalType: rentalType))
            }
        }
        stackView.addArrangedSubview(makeShadowCard(containing: assetsCardStack))
    }

    private func makeEmployeeRow(_ user: User) -> UIView {
        let rowView = UIView()
        let labelsStackView = UIStackView()
        let actionsStackView = UIStackView()
        let nameLabel = makePrimaryLabel(user.fullName)
        let detailLabel = makeSecondaryLabel("PIN \(user.pinCode) · \(roleTitle(user.role))")
        let editButton = makeIconButton(systemName: "pencil", color: BrandColor.primaryBlue)
        let archiveButton = makeIconButton(systemName: "archivebox", color: BrandColor.error)

        labelsStackView.axis = .vertical
        labelsStackView.spacing = 3
        labelsStackView.addArrangedSubview(nameLabel)
        labelsStackView.addArrangedSubview(detailLabel)

        actionsStackView.axis = .horizontal
        actionsStackView.spacing = 8
        actionsStackView.addArrangedSubview(editButton)
        actionsStackView.addArrangedSubview(archiveButton)

        editButton.addAction(UIAction { [weak self] _ in self?.showEmployeeForm(user: user) }, for: .touchUpInside)
        archiveButton.addAction(UIAction { [weak self] _ in self?.confirmArchive(user: user) }, for: .touchUpInside)

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
        let quantity = catalogRepository.getSouvenirQuantity(productID: product.id, pointID: point.id)
        let detailLabel = makeSecondaryLabel("\(moneyFormatter.string(from: product.price, includesCurrencySymbol: true)) · \(quantity) шт.")
        let editButton = makeIconButton(systemName: "pencil", color: BrandColor.primaryBlue)
        let hideButton = makeIconButton(systemName: "eye.slash", color: BrandColor.error)

        labelsStackView.axis = .vertical
        labelsStackView.spacing = 3
        labelsStackView.addArrangedSubview(titleLabel)
        labelsStackView.addArrangedSubview(detailLabel)

        actionsStackView.axis = .horizontal
        actionsStackView.spacing = 8
        actionsStackView.addArrangedSubview(editButton)
        actionsStackView.addArrangedSubview(hideButton)

        editButton.addAction(UIAction { [weak self] _ in self?.showSouvenirForm(product: product) }, for: .touchUpInside)
        hideButton.addAction(UIAction { [weak self] _ in self?.confirmHide(product: product) }, for: .touchUpInside)

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
            onDelete: { [weak self] in self?.confirmHide(template: template) }
        )
    }

    private func makeRentalTypeRow(_ rentalType: RentalType, assetsCount: Int) -> UIView {
        let tariff = rentalType.defaultTariff
        let price = tariff.map { moneyFormatter.string(from: $0.price, includesCurrencySymbol: true) } ?? "нет цены"
        let duration = tariff.map { "\($0.durationMinutes) мин" } ?? "нет периода"
        return makeEditableRow(
            title: rentalType.name,
            detail: "\(price) · \(duration) · \(assetsCount) шт.",
            editColor: BrandColor.primaryBlue,
            deleteColor: BrandColor.error,
            onEdit: { [weak self] in self?.showRentalTypeForm(rentalType: rentalType) },
            onDelete: { [weak self] in self?.confirmHide(rentalType: rentalType) }
        )
    }

    private func makeRentalAssetRow(_ asset: RentalAsset, rentalType: RentalType?) -> UIView {
        let title = [rentalType?.name, asset.displayNumber]
            .compactMap { $0 }
            .joined(separator: " ")
        return makeEditableRow(
            title: title,
            detail: "Объект проката",
            editColor: BrandColor.primaryBlue,
            deleteColor: BrandColor.error,
            onEdit: { [weak self] in self?.showRentalAssetForm(asset: asset, rentalTypeID: asset.rentalTypeID) },
            onDelete: { [weak self] in self?.confirmHide(asset: asset, rentalType: rentalType) }
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
        let deleteButton = makeIconButton(systemName: "eye.slash", color: deleteColor)

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
    private func didTapAddRentalAsset() {
        showRentalAssetTypePicker()
    }
}

private extension AdminPanelViewController {
    func showEmployeeForm(user: User?) {
        let alert = UIAlertController(
            title: user == nil ? "Новый сотрудник" : "Редактировать сотрудника",
            message: user == nil ? "PIN будет создан автоматически." : "PIN сотрудника не меняется.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Фамилия"
            textField.text = user?.lastName
        }
        alert.addTextField { textField in
            textField.placeholder = "Имя"
            textField.text = user?.firstName
        }

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: user == nil ? "Добавить" : "Сохранить", style: .default) { [weak self, weak alert] _ in
                guard let self else { return }
                let lastName = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let firstName = alert?.textFields?.dropFirst().first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !lastName.isEmpty, !firstName.isEmpty else {
                    self.showMessage(title: "Не сохранено", message: "Заполните имя и фамилию.")
                    return
                }

                if let user {
                    _ = self.authRepository.updateUser(
                        User(
                            id: user.id,
                            pinCode: user.pinCode,
                            firstName: firstName,
                            lastName: lastName,
                            role: user.role,
                            accountStatus: user.accountStatus,
                            managedPointID: user.managedPointID
                        )
                    )
                    self.render()
                } else {
                    let createdUser = self.authRepository.createUser(
                        firstName: firstName,
                        lastName: lastName,
                        role: .staff
                    )
                    self.render()
                    self.showMessage(
                        title: "Сотрудник добавлен",
                        message: "PIN: \(createdUser.pinCode)"
                    )
                }
            }
        )

        present(alert, animated: true)
    }

    func confirmArchive(user: User) {
        let alert = UIAlertController(
            title: "Архивировать сотрудника?",
            message: "\(user.fullName) больше не сможет войти по PIN \(user.pinCode).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Архивировать", style: .destructive) { [weak self] _ in
                self?.authRepository.archiveUser(id: user.id)
                self?.render()
            }
        )
        present(alert, animated: true)
    }

    func showSouvenirForm(product: SouvenirProduct?) {
        let quantity = product.map {
            catalogRepository.getSouvenirQuantity(productID: $0.id, pointID: point.id)
        } ?? 0
        let alert = UIAlertController(
            title: product == nil ? "Новый сувенир" : "Редактировать сувенир",
            message: "Каталог точки: \(point.name)",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Название"
            textField.text = product?.name
        }
        alert.addTextField { textField in
            textField.placeholder = "Цена, ₽"
            textField.keyboardType = .decimalPad
            textField.text = product.map { self.moneyFormatter.string(from: $0.price) }
        }
        alert.addTextField { textField in
            textField.placeholder = "Количество"
            textField.keyboardType = .numberPad
            textField.text = "\(quantity)"
        }

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: product == nil ? "Добавить" : "Сохранить", style: .default) { [weak self, weak alert] _ in
                guard let self else { return }
                let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let price = self.parseRubles(alert?.textFields?.dropFirst().first?.text)
                let quantityText = alert?.textFields?.dropFirst(2).first?.text ?? "0"
                let quantity = Int(quantityText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
                guard !name.isEmpty, let price, quantity >= 0 else {
                    self.showMessage(title: "Не сохранено", message: "Проверьте название, цену и количество.")
                    return
                }

                if let product {
                    _ = self.catalogRepository.updateSouvenirProduct(
                        SouvenirProduct(
                            id: product.id,
                            pointID: product.pointID,
                            name: name,
                            price: price,
                            isActive: product.isActive,
                            sortOrder: product.sortOrder
                        ),
                        quantity: quantity
                    )
                } else {
                    _ = self.catalogRepository.createSouvenirProduct(
                        pointID: self.point.id,
                        name: name,
                        price: price,
                        quantity: quantity
                    )
                }
                self.render()
            }
        )

        present(alert, animated: true)
    }

    func confirmHide(product: SouvenirProduct) {
        let alert = UIAlertController(
            title: "Скрыть сувенир?",
            message: "\(product.name) исчезнет из каталога точки \(point.name).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Скрыть", style: .destructive) { [weak self] _ in
                guard let self else { return }
                self.catalogRepository.hideSouvenirProduct(id: product.id, pointID: self.point.id)
                self.render()
            }
        )
        present(alert, animated: true)
    }

    func showFineForm(template: FineTemplate?) {
        let alert = UIAlertController(
            title: template == nil ? "Новый штраф" : "Редактировать штраф",
            message: "Шаблон для точки: \(point.name)",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Название"
            textField.text = template?.title
        }
        alert.addTextField { textField in
            textField.placeholder = "Сумма, ₽"
            textField.keyboardType = .decimalPad
            textField.text = template.map { self.moneyFormatter.string(from: $0.amount) }
        }

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: template == nil ? "Добавить" : "Сохранить", style: .default) { [weak self, weak alert] _ in
                guard let self else { return }
                let title = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let amount = self.parseRubles(alert?.textFields?.dropFirst().first?.text)
                guard !title.isEmpty, let amount else {
                    self.showMessage(title: "Не сохранено", message: "Проверьте название и сумму штрафа.")
                    return
                }

                if let template {
                    _ = self.catalogRepository.updateFineTemplate(
                        FineTemplate(
                            id: template.id,
                            pointID: template.pointID,
                            title: title,
                            amount: amount,
                            isActive: template.isActive,
                            sortOrder: template.sortOrder
                        )
                    )
                } else {
                    _ = self.catalogRepository.createFineTemplate(
                        pointID: self.point.id,
                        title: title,
                        amount: amount
                    )
                }
                self.render()
            }
        )

        present(alert, animated: true)
    }

    func confirmHide(template: FineTemplate) {
        let alert = UIAlertController(
            title: "Скрыть штраф?",
            message: "\(template.title) исчезнет из списка штрафов точки \(point.name).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Скрыть", style: .destructive) { [weak self] _ in
                guard let self else { return }
                self.catalogRepository.hideFineTemplate(id: template.id, pointID: self.point.id)
                self.render()
            }
        )
        present(alert, animated: true)
    }

    func showRentalTypeForm(rentalType: RentalType?) {
        let defaultTariff = rentalType?.defaultTariff
        let alert = UIAlertController(
            title: rentalType == nil ? "Новый тип проката" : "Редактировать тип",
            message: "Цена и период используются для новых заказов и продлений.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Название, например Утка"
            textField.text = rentalType?.name
        }
        alert.addTextField { textField in
            textField.placeholder = "Код, например duck"
            textField.text = rentalType?.code
            textField.autocapitalizationType = .none
        }
        alert.addTextField { textField in
            textField.placeholder = "Период, минут"
            textField.keyboardType = .numberPad
            textField.text = defaultTariff.map { "\($0.durationMinutes)" } ?? "20"
        }
        alert.addTextField { textField in
            textField.placeholder = "Цена, ₽"
            textField.keyboardType = .decimalPad
            textField.text = defaultTariff.map { self.moneyFormatter.string(from: $0.price) }
        }

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: rentalType == nil ? "Добавить" : "Сохранить", style: .default) { [weak self, weak alert] _ in
                guard let self else { return }
                let fields = alert?.textFields ?? []
                let name = fields[safe: 0]?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let code = self.normalizedCode(fields[safe: 1]?.text, fallbackName: name)
                let duration = Int(fields[safe: 2]?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0
                let price = self.parseRubles(fields[safe: 3]?.text)

                guard !name.isEmpty, !code.isEmpty, duration > 0, let price else {
                    self.showMessage(title: "Не сохранено", message: "Проверьте название, код, период и цену.")
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
                    _ = self.catalogRepository.updateRentalType(
                        RentalType(
                            id: rentalType.id,
                            pointID: rentalType.pointID,
                            name: name,
                            code: code,
                            tariffs: [updatedTariff],
                            isActive: rentalType.isActive
                        )
                    )
                } else {
                    _ = self.catalogRepository.createRentalType(
                        pointID: self.point.id,
                        name: name,
                        code: code,
                        durationMinutes: duration,
                        price: price
                    )
                }
                self.render()
            }
        )

        present(alert, animated: true)
    }

    func confirmHide(rentalType: RentalType) {
        let alert = UIAlertController(
            title: "Скрыть тип проката?",
            message: "\(rentalType.name) и его объекты исчезнут из рабочего каталога точки \(point.name).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Скрыть", style: .destructive) { [weak self] _ in
                guard let self else { return }
                self.catalogRepository.hideRentalType(id: rentalType.id, pointID: self.point.id)
                self.render()
            }
        )
        present(alert, animated: true)
    }

    func showRentalAssetTypePicker() {
        let rentalTypes = catalogRepository.getRentalTypes(pointID: point.id)
        guard !rentalTypes.isEmpty else {
            showMessage(title: "Нет типов проката", message: "Сначала добавьте тип проката.")
            return
        }

        let alert = UIAlertController(
            title: "Выберите тип",
            message: "К какому типу относится новый объект?",
            preferredStyle: .alert
        )
        rentalTypes.forEach { rentalType in
            alert.addAction(
                UIAlertAction(title: rentalType.name, style: .default) { [weak self] _ in
                    self?.showRentalAssetForm(asset: nil, rentalTypeID: rentalType.id)
                }
            )
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    func showRentalAssetForm(asset: RentalAsset?, rentalTypeID: UUID) {
        let rentalType = catalogRepository.getRentalTypes(pointID: point.id).first { $0.id == rentalTypeID }
        let alert = UIAlertController(
            title: asset == nil ? "Новый объект" : "Редактировать объект",
            message: rentalType.map { "Тип: \($0.name)" },
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Номер, например 12 или У-12"
            textField.keyboardType = .numbersAndPunctuation
            textField.text = asset?.displayNumber
        }

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: asset == nil ? "Добавить" : "Сохранить", style: .default) { [weak self, weak alert] _ in
                guard let self else { return }
                let number = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !number.isEmpty else {
                    self.showMessage(title: "Не сохранено", message: "Введите номер объекта.")
                    return
                }

                if let asset {
                    _ = self.catalogRepository.updateRentalAsset(
                        RentalAsset(
                            id: asset.id,
                            pointID: asset.pointID,
                            rentalTypeID: rentalTypeID,
                            displayNumber: number,
                            isActive: asset.isActive
                        )
                    )
                } else {
                    _ = self.catalogRepository.createRentalAsset(
                        pointID: self.point.id,
                        rentalTypeID: rentalTypeID,
                        displayNumber: number
                    )
                }
                self.render()
            }
        )

        present(alert, animated: true)
    }

    func confirmHide(asset: RentalAsset, rentalType: RentalType?) {
        let title = [rentalType?.name, asset.displayNumber]
            .compactMap { $0 }
            .joined(separator: " ")
        let alert = UIAlertController(
            title: "Скрыть объект?",
            message: "\(title) исчезнет из рабочего каталога точки \(point.name).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Скрыть", style: .destructive) { [weak self] _ in
                guard let self else { return }
                self.catalogRepository.hideRentalAsset(id: asset.id, pointID: self.point.id)
                self.render()
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
