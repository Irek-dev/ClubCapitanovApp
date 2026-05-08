import UIKit

/// Overlay добавления сотрудника в текущую смену по PIN.
final class ShiftWorkspaceAddParticipantModalView: UIView {
    var onDismiss: (() -> Void)?
    var onConfirm: ((String) -> Void)?

    private let dialogView = UIView()
    private let pinField = UITextField()
    private let messageLabel = UILabel()
    private let confirmButton = UIButton(type: .system)
    private var dialogCenterYConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        observeKeyboard()
        updateConfirmButtonState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.pinField.becomeFirstResponder()
        }
    }

    private func configureUI() {
        let stackView = UIStackView()
        let titleLabel = UILabel()
        let subtitleLabel = UILabel()
        let buttonsStackView = UIStackView()
        let cancelButton = UIButton(type: .system)

        backgroundColor = BrandColor.modalOverlay

        dialogView.backgroundColor = BrandColor.surface
        dialogView.layer.cornerRadius = 24
        dialogView.layer.cornerCurve = .continuous
        applySoftShadow(to: dialogView)

        stackView.axis = .vertical
        stackView.spacing = 16

        titleLabel.text = "Добавить сотрудника"
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.bold(24)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        subtitleLabel.text = "PIN сотрудника"
        subtitleLabel.textColor = BrandColor.textSecondary
        subtitleLabel.font = BrandFont.regular(15)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        configurePINField()
        configureMessageLabel()

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
            title: "Добавить",
            color: BrandColor.primaryBlue,
            textColor: BrandColor.onPrimary
        )

        cancelButton.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)

        addSubview(dialogView)
        dialogView.addSubview(stackView)

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.setCustomSpacing(20, after: subtitleLabel)
        stackView.addArrangedSubview(pinField)
        stackView.addArrangedSubview(messageLabel)
        stackView.addArrangedSubview(buttonsStackView)
        buttonsStackView.addArrangedSubview(cancelButton)
        buttonsStackView.addArrangedSubview(confirmButton)

        dialogView.pinCenterX(to: centerXAnchor)
        dialogCenterYConstraint = dialogView.pinCenterY(to: centerYAnchor)
        dialogView.setWidth(380, priority: .defaultHigh)
        dialogView.pinLeft(to: leadingAnchor, 24, .grOE)
        dialogView.pinRight(to: trailingAnchor, 24, .lsOE)

        stackView.pin(to: dialogView, 24)
    }

    private func configurePINField() {
        pinField.keyboardType = .numberPad
        pinField.placeholder = "0000"
        pinField.textAlignment = .center
        pinField.font = BrandFont.demiBold(28)
        pinField.textColor = BrandColor.textPrimary
        pinField.tintColor = BrandColor.accentOrange
        pinField.backgroundColor = BrandColor.surfaceMuted
        pinField.layer.cornerRadius = 18
        pinField.layer.cornerCurve = .continuous
        pinField.layer.borderWidth = 1
        pinField.layer.borderColor = BrandColor.cgColor(BrandColor.fieldBorder, compatibleWith: traitCollection)
        pinField.delegate = self
        pinField.addTarget(self, action: #selector(didChangePINText), for: .editingChanged)
        pinField.setHeight(58)
    }

    private func configureMessageLabel() {
        messageLabel.textColor = BrandColor.error
        messageLabel.font = BrandFont.medium(13)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.isHidden = true
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

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc
    private func handleKeyboardWillChangeFrame(_ notification: Notification) {
        let keyboardHeight = keyboardOverlapHeight(from: notification)
        updateForKeyboard(height: keyboardHeight, notification: notification)
    }

    @objc
    private func handleKeyboardWillHide(_ notification: Notification) {
        updateForKeyboard(height: 0, notification: notification)
    }

    private func keyboardOverlapHeight(from notification: Notification) -> CGFloat {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return 0
        }

        let keyboardFrameInView = convert(keyboardFrame, from: nil)
        return max(0, bounds.maxY - keyboardFrameInView.minY)
    }

    private func updateForKeyboard(height: CGFloat, notification: Notification) {
        dialogCenterYConstraint?.constant = -min(120, height / 2)

        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        let rawCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        let options = UIView.AnimationOptions(rawValue: rawCurve << 16)

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: options,
            animations: { self.layoutIfNeeded() }
        )
    }

    private func updateConfirmButtonState() {
        let isReady = pinField.text?.count == 4
        confirmButton.isEnabled = isReady
        confirmButton.alpha = isReady ? 1 : 0.45

        if isReady {
            messageLabel.isHidden = true
        }
    }

    private func applySoftShadow(to view: UIView) {
        view.layer.shadowColor = BrandColor.cgColor(BrandColor.shadow, compatibleWith: traitCollection)
        view.layer.shadowOpacity = 0.12
        view.layer.shadowRadius = 24
        view.layer.shadowOffset = CGSize(width: 0, height: 14)
    }

    @objc
    private func didChangePINText() {
        updateConfirmButtonState()
    }

    @objc
    private func didTapDismiss() {
        onDismiss?()
    }

    @objc
    private func didTapConfirm() {
        let pinCode = pinField.text ?? ""

        guard pinCode.count == 4 else {
            messageLabel.text = "Введите 4 цифры."
            messageLabel.isHidden = false
            return
        }

        onConfirm?(pinCode)
    }
}

extension ShiftWorkspaceAddParticipantModalView: UITextFieldDelegate {
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
        return newText.count <= 4 && newText.allSatisfy(\.isNumber)
    }
}
