import UIKit

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

    init(tintColor: UIColor, selectedPaymentMethod: PaymentMethod = .card) {
        self.accentColor = tintColor
        self.selectedPaymentMethod = selectedPaymentMethod
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
            button.addAction(
                UIAction { [weak self] _ in
                    self?.selectedPaymentMethod = method
                },
                for: .touchUpInside
            )
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
}
