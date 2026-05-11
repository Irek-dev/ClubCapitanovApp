import UIKit

/// UI экрана PIN-входа.
///
/// ViewController отвечает только за UIKit: layout, клавиатуру, ввод PIN и отображение
/// ошибки. Валидация пользователя и навигация уходят в Interactor/Router.
protocol LoginDisplayLogic: AnyObject {
    func display(viewModel: Login.Submit.ViewModel)
}

final class LoginViewController: UIViewController {
    // MARK: - Dependencies

    private let interactor: LoginBusinessLogic

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let cardView = UIView()
    private let contentStackView = UIStackView()
    private let badgeContainerView = UIView()
    private let badgeView = UIView()
    private let badgeImageView = UIImageView(image: UIImage(named: "BrandLogo"))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let pinField = UITextField()
    private let passwordField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let adminModeButton = UIButton(type: .system)
    private let messageLabel = UILabel()
    private var isKeyboardVisible = false
    private var isAdminMode = false
    private var keyboardObserverTokens: [NSObjectProtocol] = []

    // MARK: - Init

    init(interactor: LoginBusinessLogic) {
        self.interactor = interactor
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        observeKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if !isKeyboardVisible, scrollView.contentOffset != .zero {
            scrollView.setContentOffset(.zero, animated: false)
        }
    }

    deinit {
        keyboardObserverTokens.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: - UI

    private func configureUI() {
        // Экран собран кодом: сначала создаются все визуальные элементы, затем
        // настраиваются constraints. Это упрощает поддержку без storyboard.
        view.backgroundColor = BrandColor.background

        configureScrollView()
        configureCard()
        configureBadge()
        configureLabels()
        configurePINField()
        configurePasswordField()
        configureButton()
        configureAdminModeButton()
        configureMessageLabel()
        configureTapToDismissKeyboard()
        setupConstraints()
    }

    private func configureScrollView() {
        scrollView.backgroundColor = BrandColor.background
        scrollView.alwaysBounceVertical = false
        scrollView.isScrollEnabled = false
        scrollView.keyboardDismissMode = .onDrag
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        contentView.backgroundColor = BrandColor.background

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
    }

    private func configureCard() {
        cardView.backgroundColor = BrandColor.surface
        cardView.layer.cornerRadius = 32
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = BrandColor.cgColor(BrandColor.shadow, compatibleWith: traitCollection)
        cardView.layer.shadowOpacity = 0.12
        cardView.layer.shadowRadius = 30
        cardView.layer.shadowOffset = CGSize(width: 0, height: 18)

        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = 18

        contentView.addSubview(cardView)
        cardView.addSubview(contentStackView)
    }

    private func configureBadge() {
        badgeView.backgroundColor = BrandColor.clear

        badgeImageView.contentMode = .scaleAspectFit
        badgeImageView.isAccessibilityElement = false

        badgeContainerView.addSubview(badgeView)
        badgeView.addSubview(badgeImageView)
        contentStackView.addArrangedSubview(badgeContainerView)
    }

    private func configureLabels() {
        titleLabel.text = "Вход в смену"
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.font = BrandFont.bold(34)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        subtitleLabel.text = "Введите PIN"
        subtitleLabel.textColor = BrandColor.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.font = BrandFont.regular(16)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.numberOfLines = 0

        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(subtitleLabel)
    }

    private func configurePINField() {
        pinField.keyboardType = .numberPad
        pinField.placeholder = "PIN"
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

        contentStackView.setCustomSpacing(28, after: subtitleLabel)
        contentStackView.addArrangedSubview(pinField)
        pinField.setHeight(58)
    }

    private func configurePasswordField() {
        passwordField.placeholder = "Пароль администратора"
        passwordField.textAlignment = .center
        passwordField.font = BrandFont.demiBold(20)
        passwordField.textColor = BrandColor.textPrimary
        passwordField.tintColor = BrandColor.accentOrange
        passwordField.backgroundColor = BrandColor.surfaceMuted
        passwordField.layer.cornerRadius = 18
        passwordField.layer.cornerCurve = .continuous
        passwordField.layer.borderWidth = 1
        passwordField.layer.borderColor = BrandColor.cgColor(BrandColor.fieldBorder, compatibleWith: traitCollection)
        passwordField.isSecureTextEntry = true
        passwordField.isHidden = true
        passwordField.delegate = self

        contentStackView.addArrangedSubview(passwordField)
        passwordField.setHeight(58)
    }

    private func configureButton() {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Войти"
        configuration.baseBackgroundColor = BrandColor.primaryBlue
        configuration.baseForegroundColor = BrandColor.onPrimary
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 16, leading: 18, bottom: 16, trailing: 18)

        loginButton.configuration = configuration
        loginButton.titleLabel?.font = BrandFont.demiBold(17)
        loginButton.addTarget(self, action: #selector(didTapLoginButton), for: .touchUpInside)

        contentStackView.addArrangedSubview(loginButton)
        loginButton.setHeight(56)
    }

    private func configureAdminModeButton() {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Войти как администратор"
        configuration.baseForegroundColor = BrandColor.primaryBlue
        configuration.contentInsets = .init(top: 8, leading: 12, bottom: 8, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = BrandFont.demiBold(15)
            return outgoing
        }

        adminModeButton.configuration = configuration
        adminModeButton.addTarget(self, action: #selector(didTapAdminModeButton), for: .touchUpInside)

        contentStackView.addArrangedSubview(adminModeButton)
    }

    private func configureMessageLabel() {
        messageLabel.textColor = BrandColor.error
        messageLabel.textAlignment = .center
        messageLabel.font = BrandFont.medium(14)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.numberOfLines = 0
        messageLabel.isHidden = true

        contentStackView.addArrangedSubview(messageLabel)
    }

    private func configureTapToDismissKeyboard() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapOutsideKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    private func setupConstraints() {
        let maxCardWidth: CGFloat = 430

        scrollView.pinTop(to: view.topAnchor)
        scrollView.pinLeft(to: view.leadingAnchor)
        scrollView.pinRight(to: view.trailingAnchor)
        scrollView.pinBottom(to: view.bottomAnchor)

        contentView.pinTop(to: scrollView.contentLayoutGuide.topAnchor)
        contentView.pinLeft(to: scrollView.contentLayoutGuide.leadingAnchor)
        contentView.pinRight(to: scrollView.contentLayoutGuide.trailingAnchor)
        contentView.pinBottom(to: scrollView.contentLayoutGuide.bottomAnchor)
        contentView.pinWidth(to: scrollView.frameLayoutGuide.widthAnchor)
        contentView.pinHeight(to: scrollView.frameLayoutGuide.heightAnchor, 1, .grOE)

        cardView.pinLeft(to: contentView.layoutMarginsGuide.leadingAnchor, 0, .grOE)
        cardView.pinRight(to: contentView.layoutMarginsGuide.trailingAnchor, 0, .lsOE)
        cardView.pinCenterX(to: contentView)
        cardView.pinCenterY(to: contentView)
        cardView.setWidth(mode: .lsOE, Double(maxCardWidth))
        cardView.pinWidth(to: contentView.widthAnchor, constant: -40, priority: .defaultHigh)
        cardView.pinTop(to: contentView.safeAreaLayoutGuide.topAnchor, 28, .grOE)
        cardView.pinBottom(to: contentView.safeAreaLayoutGuide.bottomAnchor, 28, .lsOE)

        contentStackView.pin(to: cardView, 26)

        badgeContainerView.setHeight(76)
        badgeView.setWidth(68)
        badgeView.setHeight(68)
        badgeView.pinCenter(to: badgeContainerView)
        badgeImageView.pin(to: badgeView)
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        keyboardObserverTokens = [
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleKeyboardWillChangeFrame(notification)
            },
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleKeyboardWillHide(notification)
            }
        ]
    }

    private func handleKeyboardWillChangeFrame(_ notification: Notification) {
        let transition = KeyboardTransition(notification: notification, in: view)
        updateForKeyboard(height: transition.overlapHeight, transition: transition)
    }

    private func handleKeyboardWillHide(_ notification: Notification) {
        updateForKeyboard(height: 0, transition: KeyboardTransition(notification: notification, in: view))
    }

    private func updateForKeyboard(height: CGFloat, transition: KeyboardTransition) {
        isKeyboardVisible = height > 0

        scrollView.isScrollEnabled = isKeyboardVisible
        scrollView.alwaysBounceVertical = false
        scrollView.contentInset.bottom = height
        scrollView.verticalScrollIndicatorInsets.bottom = height

        transition.animate { [weak self] in
            guard let self else { return }
            self.view.layoutIfNeeded()

            if self.isKeyboardVisible {
                let focusedField = self.passwordField.isFirstResponder ? self.passwordField : self.pinField
                let focusedRect = focusedField
                    .convert(focusedField.bounds, to: self.scrollView)
                    .insetBy(dx: 0, dy: -18)
                self.scrollView.scrollRectToVisible(focusedRect, animated: false)
            } else {
                self.scrollView.setContentOffset(.zero, animated: false)
            }
        }
    }

    // MARK: - Actions

    @objc
    private func didTapLoginButton() {
        if isAdminMode {
            interactor.submitAdmin(
                request: .init(
                    pinCode: pinField.text ?? "",
                    password: passwordField.text ?? ""
                )
            )
        } else {
            interactor.submit(request: .init(pinCode: pinField.text ?? ""))
        }
    }

    @objc
    private func didTapAdminModeButton() {
        isAdminMode.toggle()
        passwordField.text = nil
        messageLabel.isHidden = true
        messageLabel.text = nil
        applyLoginMode()
    }

    @objc
    private func didTapOutsideKeyboard() {
        view.endEditing(true)
    }
}

private extension LoginViewController {
    func applyLoginMode() {
        titleLabel.text = isAdminMode ? "Админ-панель" : "Вход в смену"
        subtitleLabel.text = isAdminMode ? "Введите PIN администратора и пароль" : "Введите PIN"
        passwordField.isHidden = !isAdminMode
        loginButton.configuration?.title = isAdminMode ? "Открыть админ-панель" : "Войти"
        adminModeButton.configuration?.title = isAdminMode ? "Вернуться ко входу в смену" : "Войти как администратор"
    }
}

// MARK: - LoginDisplayLogic

extension LoginViewController: LoginDisplayLogic {
    func display(viewModel: Login.Submit.ViewModel) {
        // ViewModel уже готова для UI: здесь нет бизнес-логики, только показать/скрыть
        // ошибку и очистить поле при неуспешной попытке.
        messageLabel.text = viewModel.errorMessage
        messageLabel.isHidden = viewModel.errorMessage == nil

        if viewModel.clearPINField {
            pinField.text = nil
        }
    }
}

// MARK: - UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        // Ограничение ввода на уровне UI дает мгновенную обратную связь, но финальная
        // проверка все равно остается в Interactor, куда может попасть любой текст.
        guard let currentText = textField.text else {
            return false
        }

        guard let swiftRange = Range(range, in: currentText) else {
            return false
        }

        let newText = currentText.replacingCharacters(in: swiftRange, with: string)

        if textField === passwordField {
            return newText.count <= 24
        }

        return newText.count <= 4 && newText.allSatisfy(\.isNumber)
    }
}
