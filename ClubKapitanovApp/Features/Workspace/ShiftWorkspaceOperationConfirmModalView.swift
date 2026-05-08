import UIKit

/// Overlay подтверждения добавления сувенирки или штрафа.
///
/// Пользователь сначала выбирает товар/штраф, затем в этой модалке подтверждает
/// количество и способ оплаты. Только после confirm операция попадает в state смены.
final class ShiftWorkspaceOperationConfirmModalView: UIView {
    var onDismiss: (() -> Void)?
    var onConfirm: ((Int, PaymentMethod) -> Void)?

    private let viewModel: ShiftWorkspace.ActionButtonViewModel
    private let actionColor: UIColor
    private let moneyFormatter = RubleMoneyFormatter()
    private var quantity = 1

    private let quantityLabel = UILabel()
    private let totalLabel = UILabel()
    private let decrementButton = UIButton(type: .system)
    private let paymentSelector: ShiftWorkspacePaymentMethodSelectorView

    init(viewModel: ShiftWorkspace.ActionButtonViewModel, tintColor: UIColor) {
        self.viewModel = viewModel
        self.actionColor = tintColor
        self.paymentSelector = ShiftWorkspacePaymentMethodSelectorView(tintColor: tintColor)
        super.init(frame: .zero)
        configureUI()
        updateQuantityText()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI() {
        // Модалка переиспользуется для сувенирки и штрафов: тексты, цвет действия,
        // счетчик и выбор оплаты работают одинаково для обеих операций.
        let dialogView = UIView()
        let stackView = UIStackView()
        let titleLabel = UILabel()
        let itemLabel = UILabel()
        let priceLabel = UILabel()
        let quantityStackView = UIStackView()
        let incrementButton = UIButton(type: .system)
        let buttonsStackView = UIStackView()
        let cancelButton = UIButton(type: .system)
        let confirmButton = UIButton(type: .system)

        backgroundColor = BrandColor.modalOverlay

        dialogView.backgroundColor = BrandColor.surface
        dialogView.layer.cornerRadius = 24
        dialogView.layer.cornerCurve = .continuous
        applySoftShadow(to: dialogView)

        stackView.axis = .vertical
        stackView.spacing = 18

        titleLabel.text = viewModel.confirmationTitle
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.bold(24)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        itemLabel.text = viewModel.itemTitle
        itemLabel.textColor = BrandColor.textPrimary
        itemLabel.font = BrandFont.demiBold(18)
        itemLabel.textAlignment = .center
        itemLabel.numberOfLines = 0

        priceLabel.text = "\(moneyText(viewModel.unitPrice)) за 1 шт."
        priceLabel.textColor = BrandColor.textSecondary
        priceLabel.font = BrandFont.regular(15)
        priceLabel.textAlignment = .center
        priceLabel.numberOfLines = 0

        quantityStackView.axis = .horizontal
        quantityStackView.alignment = .center
        quantityStackView.distribution = .equalSpacing
        quantityStackView.spacing = 16

        configureQuantityButton(decrementButton, systemName: "minus")
        configureQuantityButton(incrementButton, systemName: "plus")
        decrementButton.addTarget(self, action: #selector(didTapDecrement), for: .touchUpInside)
        incrementButton.addTarget(self, action: #selector(didTapIncrement), for: .touchUpInside)

        quantityLabel.textColor = BrandColor.textPrimary
        quantityLabel.font = BrandFont.demiBold(22)
        quantityLabel.textAlignment = .center
        quantityLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        totalLabel.textColor = BrandColor.textPrimary
        totalLabel.font = BrandFont.bold(18)
        totalLabel.textAlignment = .center
        totalLabel.numberOfLines = 0

        buttonsStackView.axis = .horizontal
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.spacing = 12

        configureActionButton(
            cancelButton,
            title: "Отмена",
            color: BrandColor.surfaceMuted,
            textColor: BrandColor.textPrimary
        )
        configureActionButton(
            confirmButton,
            title: viewModel.confirmButtonTitle,
            color: actionColor,
            textColor: BrandColor.onPrimary
        )

        cancelButton.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)

        addSubview(dialogView)
        dialogView.addSubview(stackView)

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(itemLabel)
        stackView.setCustomSpacing(6, after: itemLabel)
        stackView.addArrangedSubview(priceLabel)
        stackView.addArrangedSubview(quantityStackView)
        stackView.addArrangedSubview(totalLabel)
        stackView.addArrangedSubview(paymentSelector)
        stackView.addArrangedSubview(buttonsStackView)

        quantityStackView.addArrangedSubview(decrementButton)
        quantityStackView.addArrangedSubview(quantityLabel)
        quantityStackView.addArrangedSubview(incrementButton)
        buttonsStackView.addArrangedSubview(cancelButton)
        buttonsStackView.addArrangedSubview(confirmButton)

        dialogView.pinCenter(to: self)
        dialogView.setWidth(380)

        stackView.pin(to: dialogView, 24)
    }

    private func configureQuantityButton(_ button: UIButton, systemName: String) {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: systemName)
        configuration.baseBackgroundColor = BrandColor.surfaceMuted
        configuration.baseForegroundColor = BrandColor.textPrimary
        configuration.cornerStyle = .capsule
        configuration.contentInsets = .init(top: 10, leading: 10, bottom: 10, trailing: 10)

        button.configuration = configuration
        button.tintColor = BrandColor.textPrimary
        button.setWidth(48)
        button.setHeight(48)
    }

    private func configureActionButton(_ button: UIButton, title: String, color: UIColor, textColor: UIColor) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = color
        configuration.baseForegroundColor = textColor
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)

        button.configuration = configuration
        button.titleLabel?.font = BrandFont.demiBold(15)
        button.setHeight(50)
    }

    private func updateQuantityText() {
        // Количество не может быть меньше 1, поэтому minus блокируется на единице.
        // Total пересчитывается сразу, чтобы пользователь видел сумму до подтверждения.
        quantityLabel.text = "\(quantity) шт."
        totalLabel.text = "Итого: \(moneyText(totalAmount))"
        decrementButton.isEnabled = quantity > 1
        decrementButton.alpha = quantity > 1 ? 1 : 0.45
    }

    private var totalAmount: Money {
        viewModel.unitPrice.multiplied(by: quantity)
    }

    private func moneyText(_ money: Money) -> String {
        moneyFormatter.string(from: money, includesCurrencySymbol: true)
    }

    private func applySoftShadow(to view: UIView) {
        view.layer.shadowColor = BrandColor.cgColor(BrandColor.shadow, compatibleWith: traitCollection)
        view.layer.shadowOpacity = 0.12
        view.layer.shadowRadius = 24
        view.layer.shadowOffset = CGSize(width: 0, height: 14)
    }

    @objc
    private func didTapDecrement() {
        quantity = max(1, quantity - 1)
        updateQuantityText()
    }

    @objc
    private func didTapIncrement() {
        quantity += 1
        updateQuantityText()
    }

    @objc
    private func didTapDismiss() {
        onDismiss?()
    }

    @objc
    private func didTapConfirm() {
        onConfirm?(quantity, paymentSelector.selectedPaymentMethod)
    }
}

final class ShiftWorkspacePaymentMethodSelectorView: UIView {
    private let accentColor: UIColor
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private var buttonsByMethod: [PaymentMethod: UIButton] = [:]

    private(set) var selectedPaymentMethod: PaymentMethod = .card {
        didSet {
            updateButtons()
        }
    }

    init(tintColor: UIColor) {
        self.accentColor = tintColor
        super.init(frame: .zero)
        configureUI()
        updateButtons()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI() {
        let buttonsStackView = UIStackView()

        stackView.axis = .vertical
        stackView.spacing = 8

        titleLabel.text = "Способ оплаты"
        titleLabel.textColor = BrandColor.textSecondary
        titleLabel.font = BrandFont.demiBold(13)
        titleLabel.numberOfLines = 0

        buttonsStackView.axis = .horizontal
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.spacing = 8

        addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(buttonsStackView)

        PaymentMethod.workspaceSelectionOrder.forEach { method in
            let button = UIButton(type: .system)
            button.tag = PaymentMethod.workspaceSelectionOrder.firstIndex(of: method) ?? 0
            button.addTarget(self, action: #selector(didTapPaymentButton(_:)), for: .touchUpInside)
            button.setHeight(42)
            buttonsByMethod[method] = button
            buttonsStackView.addArrangedSubview(button)
        }

        stackView.pin(to: self)
    }

    private func updateButtons() {
        PaymentMethod.workspaceSelectionOrder.forEach { method in
            guard let button = buttonsByMethod[method] else { return }
            let isSelected = method == selectedPaymentMethod
            let titleFont = BrandFont.demiBold(14)
            var configuration = UIButton.Configuration.filled()
            configuration.title = method.workspaceTitle
            configuration.baseBackgroundColor = isSelected ? accentColor : BrandColor.surfaceMuted
            configuration.baseForegroundColor = isSelected ? BrandColor.onPrimary : BrandColor.textPrimary
            configuration.cornerStyle = .large
            configuration.contentInsets = .init(top: 10, leading: 10, bottom: 10, trailing: 10)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = titleFont
                return outgoing
            }
            button.configuration = configuration
        }
    }

    @objc
    private func didTapPaymentButton(_ sender: UIButton) {
        guard PaymentMethod.workspaceSelectionOrder.indices.contains(sender.tag) else { return }
        selectedPaymentMethod = PaymentMethod.workspaceSelectionOrder[sender.tag]
    }
}
