import UIKit

final class ShiftWorkspaceRentalPaymentModalView: UIView {
    var onDismiss: (() -> Void)?
    var onConfirm: ((PaymentMethod) -> Void)?

    private let order: ShiftWorkspace.ActiveRentalOrderViewModel
    private let dialogView = ShiftWorkspaceShadowCardView(
        cornerRadius: 24,
        shadowOpacity: 0.12,
        shadowRadius: 24,
        shadowOffset: CGSize(width: 0, height: 14)
    )
    private let paymentSelector = ShiftWorkspacePaymentMethodSelectorView(
        tintColor: ShiftWorkspaceSection.ducks.tintColor
    )

    init(order: ShiftWorkspace.ActiveRentalOrderViewModel) {
        self.order = order
        super.init(frame: .zero)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI() {
        let stackView = UIStackView()
        let titleLabel = UILabel()
        let itemsLabel = UILabel()
        let amountLabel = UILabel()
        let buttonsStackView = UIStackView()
        let cancelButton = UIButton(type: .system)
        let confirmButton = UIButton(type: .system)

        backgroundColor = BrandColor.modalOverlay

        stackView.axis = .vertical
        stackView.spacing = 16

        titleLabel.text = "Завершить прокат"
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.bold(24)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        itemsLabel.text = order.itemsText
        itemsLabel.textColor = BrandColor.textPrimary
        itemsLabel.font = BrandFont.demiBold(16)
        itemsLabel.textAlignment = .center
        itemsLabel.numberOfLines = 0

        amountLabel.text = order.totalAmountText
        amountLabel.textColor = BrandColor.textPrimary
        amountLabel.font = BrandFont.bold(18)
        amountLabel.textAlignment = .center
        amountLabel.numberOfLines = 0

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
            title: "Списать оплату",
            color: ShiftWorkspaceSection.ducks.tintColor,
            textColor: BrandColor.onPrimary
        )

        cancelButton.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)

        addSubview(dialogView)
        dialogView.addSubview(stackView)

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(itemsLabel)
        stackView.addArrangedSubview(amountLabel)
        stackView.addArrangedSubview(paymentSelector)
        stackView.addArrangedSubview(buttonsStackView)

        buttonsStackView.addArrangedSubview(cancelButton)
        buttonsStackView.addArrangedSubview(confirmButton)

        dialogView.pinCenter(to: self)
        dialogView.setWidth(430)
        stackView.pin(to: dialogView, 24)
    }

    private func configureActionButton(_ button: UIButton, title: String, color: UIColor, textColor: UIColor) {
        let titleFont = BrandFont.demiBold(15)
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = color
        configuration.baseForegroundColor = textColor
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = titleFont
            return outgoing
        }

        button.configuration = configuration
        button.setHeight(50)
    }

    @objc
    private func didTapDismiss() {
        onDismiss?()
    }

    @objc
    private func didTapConfirm() {
        onConfirm?(paymentSelector.selectedPaymentMethod)
    }
}
