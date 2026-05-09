import UIKit

/// Overlay создания одного активного заказа проката.
final class ShiftWorkspaceRentalOrderModalView: UIView {
    var onDismiss: (() -> Void)?
    var onConfirm: (([ShiftWorkspace.RentalOrderItemInput]) -> Void)?

    private let rentalTypes: [ShiftWorkspace.RentalOrderItemTypeViewModel]
    private let dialogView = ShiftWorkspaceShadowCardView(
        cornerRadius: 18,
        shadowOpacity: 0.16,
        shadowRadius: 28,
        shadowOffset: CGSize(width: 0, height: 16)
    )
    private let rowsStackView = UIStackView()
    private let messageLabel = UILabel()
    private var rowViews: [RentalOrderItemRowView] = []

    init(rentalTypes: [ShiftWorkspace.RentalOrderItemTypeViewModel]) {
        self.rentalTypes = rentalTypes
        super.init(frame: .zero)
        configureUI()
        addOrderItemRow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI() {
        let titleLabel = UILabel()
        let closeButton = UIButton(type: .system)
        let topSeparatorView = UIView()
        let bottomSeparatorView = UIView()
        let addRowButton = UIButton(type: .system)
        let buttonsStackView = UIStackView()
        let cancelButton = UIButton(type: .system)
        let submitButton = UIButton(type: .system)

        backgroundColor = BrandColor.modalOverlay

        dialogView.clipsToBounds = true

        titleLabel.text = "Новый заказ"
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.bold(24)
        titleLabel.textAlignment = .center

        configureIconButton(closeButton, systemName: "xmark", accessibilityLabel: "Закрыть")
        closeButton.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)

        topSeparatorView.backgroundColor = BrandColor.fieldBorder
        bottomSeparatorView.backgroundColor = BrandColor.fieldBorder

        rowsStackView.axis = .vertical
        rowsStackView.spacing = 10

        configureAddRowButton(addRowButton)
        addRowButton.addTarget(self, action: #selector(didTapAddRow), for: .touchUpInside)

        messageLabel.textColor = BrandColor.error
        messageLabel.font = BrandFont.medium(13)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.isHidden = true

        buttonsStackView.axis = .horizontal
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.spacing = 170

        configureActionButton(
            cancelButton,
            title: "Отмена",
            color: BrandColor.surfaceMuted,
            textColor: BrandColor.textPrimary
        )
        configureActionButton(
            submitButton,
            title: "Создать",
            color: ShiftWorkspaceSection.ducks.tintColor,
            textColor: BrandColor.onPrimary
        )

        cancelButton.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)
        submitButton.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)

        addSubview(dialogView)
        dialogView.addSubview(titleLabel)
        dialogView.addSubview(closeButton)
        dialogView.addSubview(topSeparatorView)
        dialogView.addSubview(rowsStackView)
        dialogView.addSubview(addRowButton)
        dialogView.addSubview(messageLabel)
        dialogView.addSubview(bottomSeparatorView)
        dialogView.addSubview(buttonsStackView)

        buttonsStackView.addArrangedSubview(cancelButton)
        buttonsStackView.addArrangedSubview(submitButton)

        dialogView.pinCenter(to: self)
        dialogView.setWidth(540)
        dialogView.pinLeft(to: leadingAnchor, 26, .grOE)
        dialogView.pinRight(to: trailingAnchor, 26, .lsOE)

        titleLabel.pinTop(to: dialogView.topAnchor, 22)
        titleLabel.pinLeft(to: dialogView.leadingAnchor, 70)
        titleLabel.pinRight(to: dialogView.trailingAnchor, 70)

        closeButton.pinCenterY(to: titleLabel.centerYAnchor)
        closeButton.pinRight(to: dialogView.trailingAnchor, 22)

        topSeparatorView.pinTop(to: titleLabel.bottomAnchor, 22)
        topSeparatorView.pinLeft(to: dialogView.leadingAnchor)
        topSeparatorView.pinRight(to: dialogView.trailingAnchor)
        topSeparatorView.setHeight(1)

        rowsStackView.pinTop(to: topSeparatorView.bottomAnchor, 16)
        rowsStackView.pinLeft(to: dialogView.leadingAnchor, 24)
        rowsStackView.pinRight(to: dialogView.trailingAnchor, 24)

        addRowButton.pinTop(to: rowsStackView.bottomAnchor, 16)
        addRowButton.pinLeft(to: rowsStackView.leadingAnchor)
        addRowButton.pinRight(to: rowsStackView.trailingAnchor)

        messageLabel.pinTop(to: addRowButton.bottomAnchor, 10)
        messageLabel.pinLeft(to: rowsStackView.leadingAnchor)
        messageLabel.pinRight(to: rowsStackView.trailingAnchor)

        bottomSeparatorView.pinTop(to: messageLabel.bottomAnchor, 16)
        bottomSeparatorView.pinLeft(to: dialogView.leadingAnchor)
        bottomSeparatorView.pinRight(to: dialogView.trailingAnchor)
        bottomSeparatorView.setHeight(1)

        buttonsStackView.pinTop(to: bottomSeparatorView.bottomAnchor, 18)
        buttonsStackView.pinLeft(to: dialogView.leadingAnchor, 24)
        buttonsStackView.pinRight(to: dialogView.trailingAnchor, 24)
        buttonsStackView.pinBottom(to: dialogView.bottomAnchor, 20)
    }

    private func addOrderItemRow() {
        guard let firstType = rentalTypes.first else { return }

        let rowView = RentalOrderItemRowView(
            rentalTypes: rentalTypes,
            initialTypeIndex: firstType.index
        )
        rowViews.append(rowView)
        rowsStackView.addArrangedSubview(rowView)
    }

    private func configureIconButton(_ button: UIButton, systemName: String, accessibilityLabel: String) {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: systemName)
        configuration.baseForegroundColor = BrandColor.textSecondary
        configuration.contentInsets = .init(top: 8, leading: 8, bottom: 8, trailing: 8)
        button.configuration = configuration
        button.accessibilityLabel = accessibilityLabel
        button.setWidth(38)
        button.setHeight(38)
    }

    private func configureAddRowButton(_ button: UIButton) {
        let titleFont = BrandFont.demiBold(16)
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Добавить еще"
        configuration.image = UIImage(systemName: "plus")
        configuration.imagePadding = 10
        configuration.imagePlacement = .leading
        configuration.baseBackgroundColor = BrandColor.surfaceMuted
        configuration.baseForegroundColor = ShiftWorkspaceSection.ducks.tintColor
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 13, leading: 20, bottom: 13, trailing: 20)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = titleFont
            return outgoing
        }

        button.configuration = configuration
        button.contentHorizontalAlignment = .left
        button.setHeight(52)
    }

    private func configureActionButton(_ button: UIButton, title: String, color: UIColor, textColor: UIColor) {
        let titleFont = BrandFont.demiBold(17)
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = color
        configuration.baseForegroundColor = textColor
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 16, leading: 18, bottom: 16, trailing: 18)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = titleFont
            return outgoing
        }

        button.configuration = configuration
        button.setHeight(56)
    }

    @objc
    private func didTapAddRow() {
        addOrderItemRow()
    }

    @objc
    private func didTapDismiss() {
        onDismiss?()
    }

    @objc
    private func didTapSubmit() {
        var selections: [ShiftWorkspace.RentalOrderItemInput] = []
        var seenKeys = Set<String>()

        guard !rowViews.isEmpty else {
            showError("Каталог проката пуст: нечего добавить в заказ.")
            return
        }

        for rowView in rowViews {
            guard let number = rowView.enteredNumber else {
                showError("Введите номер объекта от 1 до 99.")
                return
            }

            guard (1...99).contains(number) else {
                showError("Номер объекта должен быть от 1 до 99.")
                return
            }

            guard let selectedType = rowView.selectedRentalType else {
                showError("Каталог проката пуст: нечего добавить в заказ.")
                return
            }

            let key = "\(selectedType.index)-\(number)"

            guard !seenKeys.contains(key) else {
                showError("Объект \(selectedType.title) №\(number) уже добавлен в этот заказ.")
                return
            }
            seenKeys.insert(key)

            guard !selectedType.floatingNumbers.contains(number) else {
                showError(alreadyFloatingText(typeTitle: selectedType.title, number: number))
                return
            }

            selections.append(.init(rentalTypeIndex: selectedType.index, number: number))
        }

        guard !selections.isEmpty else {
            showError("Добавьте хотя бы один объект.")
            return
        }

        onConfirm?(selections)
    }

    private func showError(_ text: String) {
        messageLabel.text = text
        messageLabel.isHidden = false
    }

    private func alreadyFloatingText(typeTitle: String, number: Int) -> String {
        let title = typeTitle.lowercased()
        let pronoun = title.hasSuffix("а") || title.hasSuffix("я") ? "она" : "он"
        return "Нельзя сдать \(title) №\(number), так как \(pronoun) уже плавает."
    }
}

private final class RentalOrderItemRowView: UIView, UITextFieldDelegate {
    private let rentalTypes: [ShiftWorkspace.RentalOrderItemTypeViewModel]
    private var selectedTypeIndex: Int
    private let selectTypeButton = UIButton(type: .system)
    private let numberField = UITextField()

    var selectedRentalType: ShiftWorkspace.RentalOrderItemTypeViewModel? {
        rentalTypes.first { $0.index == selectedTypeIndex } ?? rentalTypes.first
    }

    var enteredNumber: Int? {
        guard let numberText = numberField.text, !numberText.isEmpty else {
            return nil
        }

        return Int(numberText)
    }

    init(
        rentalTypes: [ShiftWorkspace.RentalOrderItemTypeViewModel],
        initialTypeIndex: Int
    ) {
        self.rentalTypes = rentalTypes
        self.selectedTypeIndex = initialTypeIndex
        super.init(frame: .zero)
        configureUI()
        updateSelectedType()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyContainerStyle()
        applyNumberFieldStyle()
    }

    private func configureUI() {
        let stackView = UIStackView()

        applyContainerStyle()

        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .center

        configureSelectTypeButton()
        configureNumberField()

        addSubview(stackView)
        stackView.addArrangedSubview(selectTypeButton)
        stackView.addArrangedSubview(numberField)

        stackView.pinTop(to: topAnchor, 6)
        stackView.pinLeft(to: leadingAnchor, 12)
        stackView.pinRight(to: trailingAnchor, 8)
        stackView.pinBottom(to: bottomAnchor, 6)

        setHeight(54)
    }

    private func configureSelectTypeButton() {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = BrandColor.textPrimary
        configuration.contentInsets = .init(top: 10, leading: 8, bottom: 10, trailing: 8)
        configuration.image = UIImage(systemName: "chevron.down")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 8
        selectTypeButton.configuration = configuration
        selectTypeButton.contentHorizontalAlignment = .left
        selectTypeButton.showsMenuAsPrimaryAction = true
        selectTypeButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func configureNumberField() {
        numberField.placeholder = "№"
        numberField.keyboardType = .numberPad
        numberField.textAlignment = .center
        numberField.font = BrandFont.demiBold(18)
        numberField.textColor = BrandColor.textPrimary
        numberField.tintColor = BrandColor.accentOrange
        applyNumberFieldStyle()
        numberField.delegate = self
        numberField.setWidth(104)
        numberField.setHeight(42)
    }

    private func applyContainerStyle() {
        ShiftWorkspaceLayerStyling.applyBorderedSurface(
            to: self,
            compatibleWith: traitCollection,
            cornerRadius: 12,
            fillColor: BrandColor.surfaceMuted
        )
    }

    private func applyNumberFieldStyle() {
        ShiftWorkspaceLayerStyling.applyBorderedSurface(
            to: numberField,
            compatibleWith: traitCollection,
            cornerRadius: 8,
            fillColor: BrandColor.surface
        )
    }

    private func updateSelectedType() {
        guard let selectedType = selectedRentalType else {
            selectTypeButton.configuration?.title = "Нет доступных объектов"
            selectTypeButton.isEnabled = false
            selectTypeButton.menu = nil
            return
        }

        let titleFont = BrandFont.demiBold(17)
        var configuration = selectTypeButton.configuration ?? UIButton.Configuration.plain()
        configuration.title = "\(selectedType.iconText)  \(selectedType.title) — \(selectedType.tariffText)"
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = titleFont
            return outgoing
        }
        selectTypeButton.configuration = configuration
        selectTypeButton.menu = makeTypeMenu()
    }

    private func makeTypeMenu() -> UIMenu {
        let actions = rentalTypes.map { type in
            UIAction(
                title: "\(type.iconText)  \(type.title) — \(type.tariffText)",
                state: type.index == selectedTypeIndex ? .on : .off
            ) { [weak self] _ in
                self?.selectedTypeIndex = type.index
                self?.updateSelectedType()
            }
        }

        return UIMenu(children: actions)
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let currentText = textField.text else {
            return false
        }

        guard let swiftRange = Range(range, in: currentText) else {
            return false
        }

        let newText = currentText.replacingCharacters(in: swiftRange, with: string)
        return newText.count <= 2 && newText.allSatisfy(\.isNumber)
    }
}
