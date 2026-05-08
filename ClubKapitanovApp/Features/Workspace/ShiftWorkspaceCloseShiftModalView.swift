import UIKit

/// Overlay подтверждения закрытия смены.
///
/// Модалка показывает итоговый отчет, собирает ручные остатки оборудования и батареек,
/// а затем передает готовый `ShiftCloseReportManualInput` во внешний VIP-flow.
final class ShiftWorkspaceCloseShiftModalView: UIView {
    var onDismiss: (() -> Void)?
    var onConfirm: ((ShiftCloseReportManualInput) -> Void)?

    private var equipmentInputRows: [CloseShiftCountInputRowView] = []
    private var batteryInputRows: [CloseShiftCountInputRowView] = []

    init(viewModel: ShiftWorkspace.CloseShiftModalViewModel) {
        super.init(frame: .zero)
        configureUI(viewModel: viewModel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI(viewModel: ShiftWorkspace.CloseShiftModalViewModel) {
        let dialogView = UIView()
        let titleLabel = UILabel()
        let scrollView = UIScrollView()
        let stackView = UIStackView()
        let buttonsStackView = UIStackView()
        let cancelButton = UIButton(type: .system)
        let closeButton = UIButton(type: .system)

        backgroundColor = BrandColor.modalOverlay

        dialogView.backgroundColor = BrandColor.surface
        dialogView.layer.cornerRadius = 26
        dialogView.layer.cornerCurve = .continuous
        applySoftShadow(to: dialogView)

        titleLabel.text = "Итоговый отчет"
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.demiBold(14)
        titleLabel.textAlignment = .center

        stackView.axis = .vertical
        stackView.spacing = 16

        buttonsStackView.axis = .horizontal
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.spacing = 12

        configureButton(
            cancelButton,
            title: viewModel.dismissButtonTitle,
            color: BrandColor.surfaceMuted,
            textColor: BrandColor.textPrimary
        )
        configureButton(
            closeButton,
            title: viewModel.confirmButtonTitle,
            color: BrandColor.error,
            textColor: BrandColor.onPrimary
        )

        cancelButton.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)

        addSubview(dialogView)
        dialogView.addSubview(titleLabel)
        dialogView.addSubview(scrollView)
        scrollView.addSubview(stackView)

        stackView.addArrangedSubview(makeDateBlock(viewModel.reportDateText))
        stackView.addArrangedSubview(makeReportTextBlock(lines: viewModel.totalsLines))
        stackView.addArrangedSubview(makeManualInputCard(
            title: "Рабочее оборудование",
            rows: viewModel.equipmentRows,
            storage: &equipmentInputRows
        ))
        stackView.addArrangedSubview(makeManualInputCard(
            title: "Батарейки",
            rows: viewModel.batteryRows,
            storage: &batteryInputRows
        ))
        stackView.addArrangedSubview(buttonsStackView)
        buttonsStackView.addArrangedSubview(cancelButton)
        buttonsStackView.addArrangedSubview(closeButton)

        dialogView.pinCenter(to: self)
        dialogView.setWidth(620)
        dialogView.setHeight(720)

        titleLabel.pinTop(to: dialogView.topAnchor, 16)
        titleLabel.pinLeft(to: dialogView.leadingAnchor, 16)
        titleLabel.pinRight(to: dialogView.trailingAnchor, 16)

        scrollView.pinTop(to: titleLabel.bottomAnchor, 18)
        scrollView.pinLeft(to: dialogView.leadingAnchor, 24)
        scrollView.pinRight(to: dialogView.trailingAnchor, 24)
        scrollView.pinBottom(to: dialogView.bottomAnchor, 18)

        stackView.pinTop(to: scrollView.contentLayoutGuide.topAnchor)
        stackView.pinLeft(to: scrollView.contentLayoutGuide.leadingAnchor)
        stackView.pinRight(to: scrollView.contentLayoutGuide.trailingAnchor)
        stackView.pinBottom(to: scrollView.contentLayoutGuide.bottomAnchor)
        stackView.pinWidth(to: scrollView.frameLayoutGuide.widthAnchor)
    }

    private func makeReportTextBlock(lines: [String]) -> UIView {
        let containerView = UIView()
        let bodyLabel = UILabel()

        containerView.backgroundColor = BrandColor.surfaceMuted
        containerView.layer.cornerRadius = 18
        containerView.layer.cornerCurve = .continuous
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = BrandColor.cgColor(BrandColor.fieldBorder, compatibleWith: traitCollection)

        bodyLabel.text = lines.joined(separator: "\n")
        bodyLabel.textColor = BrandColor.textPrimary
        bodyLabel.font = BrandFont.regular(15)
        bodyLabel.numberOfLines = 0

        containerView.addSubview(bodyLabel)
        bodyLabel.pin(to: containerView, 16)

        return containerView
    }

    private func makeDateBlock(_ text: String) -> UIView {
        let containerView = UIView()
        let label = UILabel()

        containerView.backgroundColor = BrandColor.surfaceMuted
        containerView.layer.cornerRadius = 14
        containerView.layer.cornerCurve = .continuous
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = BrandColor.cgColor(BrandColor.fieldBorder, compatibleWith: traitCollection)

        label.text = text
        label.textColor = BrandColor.textPrimary
        label.font = BrandFont.demiBold(15)
        label.numberOfLines = 0

        containerView.addSubview(label)
        label.pin(to: containerView, 14)

        return containerView
    }

    private func makeManualInputCard(
        title: String,
        rows: [ShiftWorkspace.CloseShiftManualRowViewModel],
        storage: inout [CloseShiftCountInputRowView]
    ) -> UIView {
        let cardView = UIView()
        let stackView = UIStackView()
        let titleLabel = UILabel()

        cardView.backgroundColor = BrandColor.surfaceMuted
        cardView.layer.cornerRadius = 18
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = BrandColor.cgColor(BrandColor.fieldBorder, compatibleWith: traitCollection)

        stackView.axis = .vertical
        stackView.spacing = 10

        titleLabel.text = title
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.bold(18)
        titleLabel.numberOfLines = 0

        stackView.addArrangedSubview(titleLabel)
        rows.forEach { row in
            let rowView = CloseShiftCountInputRowView(viewModel: row)
            storage.append(rowView)
            stackView.addArrangedSubview(rowView)
        }

        cardView.addSubview(stackView)
        stackView.pin(to: cardView, 16)

        return cardView
    }

    private func configureButton(_ button: UIButton, title: String, color: UIColor, textColor: UIColor) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = color
        configuration.baseForegroundColor = textColor
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 12, leading: 14, bottom: 12, trailing: 14)
        button.configuration = configuration
        button.titleLabel?.font = BrandFont.demiBold(14)
        button.setHeight(44)
    }

    private func applySoftShadow(to view: UIView) {
        view.layer.shadowColor = BrandColor.cgColor(BrandColor.shadow, compatibleWith: traitCollection)
        view.layer.shadowOpacity = 0.10
        view.layer.shadowRadius = 18
        view.layer.shadowOffset = CGSize(width: 0, height: 10)
    }

    @objc
    private func didTapDismiss() {
        onDismiss?()
    }

    @objc
    private func didTapConfirm() {
        onConfirm?(makeManualInput())
    }

    private func makeManualInput() -> ShiftCloseReportManualInput {
        let equipmentRows = equipmentInputRows.map {
            ShiftEquipmentCountRow(title: $0.title, count: $0.count)
        }
        let batteryRows = batteryInputRows.map {
            ShiftBatteryCountRow(title: $0.title, count: $0.count)
        }
        let hasBatteryInput = batteryInputRows.contains { $0.hasEnteredValue }
        let batteryTotal = batteryRows.reduce(0) { $0 + $1.count }

        return ShiftCloseReportManualInput(
            equipmentSnapshot: ShiftEquipmentSnapshot(
                workingRows: equipmentRows,
                discardedRows: [],
                notes: nil
            ),
            batterySnapshot: ShiftBatterySnapshot(
                workingTotal: hasBatteryInput ? batteryTotal : nil,
                workingRows: batteryRows,
                discardedRows: [],
                notes: nil
            )
        )
    }
}

private final class CloseShiftCountInputRowView: UIView, UITextFieldDelegate {
    let title: String

    private let textField = UITextField()

    var count: Int {
        Int(textField.text ?? "") ?? 0
    }

    var hasEnteredValue: Bool {
        guard let text = textField.text else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(viewModel: ShiftWorkspace.CloseShiftManualRowViewModel) {
        self.title = viewModel.title
        super.init(frame: .zero)
        configureUI(viewModel: viewModel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI(viewModel: ShiftWorkspace.CloseShiftManualRowViewModel) {
        let titleLabel = UILabel()

        titleLabel.text = viewModel.title
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.demiBold(15)
        titleLabel.numberOfLines = 0

        textField.placeholder = viewModel.placeholder
        textField.keyboardType = .numberPad
        textField.textAlignment = .center
        textField.textColor = BrandColor.textPrimary
        textField.tintColor = BrandColor.accentOrange
        textField.font = BrandFont.demiBold(16)
        textField.backgroundColor = BrandColor.surface
        textField.layer.cornerRadius = 10
        textField.layer.cornerCurve = .continuous
        textField.layer.borderWidth = 1
        textField.layer.borderColor = BrandColor.cgColor(BrandColor.fieldBorder, compatibleWith: traitCollection)
        textField.delegate = self

        addSubview(titleLabel)
        addSubview(textField)

        titleLabel.pinTop(to: topAnchor)
        titleLabel.pinLeft(to: leadingAnchor)
        titleLabel.pinRight(to: textField.leadingAnchor, 12)
        titleLabel.pinBottom(to: bottomAnchor)

        textField.pinTop(to: topAnchor)
        textField.pinRight(to: trailingAnchor)
        textField.pinBottom(to: bottomAnchor)
        textField.setWidth(96)
        textField.setHeight(42)
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
        return newText.count <= 3 && newText.allSatisfy(\.isNumber)
    }
}
