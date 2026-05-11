import UIKit

final class AdminFormViewController: UIViewController {
    struct Field {
        let key: String
        let placeholder: String
        let text: String?
        let keyboardType: UIKeyboardType
        let autocapitalizationType: UITextAutocapitalizationType

        init(
            key: String,
            placeholder: String,
            text: String? = nil,
            keyboardType: UIKeyboardType = .default,
            autocapitalizationType: UITextAutocapitalizationType = .sentences
        ) {
            self.key = key
            self.placeholder = placeholder
            self.text = text
            self.keyboardType = keyboardType
            self.autocapitalizationType = autocapitalizationType
        }
    }

    private let formTitle: String
    private let formSubtitle: String?
    private let fields: [Field]
    private let submitTitle: String
    private let submitColor: UIColor
    private let onSubmit: ([String: String]) -> Void

    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    private let fieldsStackView = UIStackView()
    private let buttonsStackView = UIStackView()
    private var textFieldsByKey: [String: UITextField] = [:]
    private var keyboardObserverTokens: [NSObjectProtocol] = []

    init(
        title: String,
        subtitle: String? = nil,
        fields: [Field],
        submitTitle: String,
        submitColor: UIColor,
        onSubmit: @escaping ([String: String]) -> Void
    ) {
        self.formTitle = title
        self.formSubtitle = subtitle
        self.fields = fields
        self.submitTitle = submitTitle
        self.submitColor = submitColor
        self.onSubmit = onSubmit
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .formSheet
        preferredContentSize = CGSize(width: 520, height: min(660, 250 + fields.count * 72))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        setupConstraints()
        observeKeyboard()
    }

    deinit {
        keyboardObserverTokens.forEach(NotificationCenter.default.removeObserver)
    }

    private func configureUI() {
        let titleLabel = UILabel()
        let subtitleLabel = UILabel()
        let cancelButton = UIButton(type: .system)
        let submitButton = UIButton(type: .system)

        view.backgroundColor = BrandColor.surface
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true

        titleLabel.text = formTitle
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.bold(24)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center

        subtitleLabel.text = formSubtitle
        subtitleLabel.textColor = BrandColor.textSecondary
        subtitleLabel.font = BrandFont.regular(15)
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.isHidden = formSubtitle == nil

        contentStackView.axis = .vertical
        contentStackView.spacing = 16
        scrollView.keyboardDismissMode = .interactive
        scrollView.showsVerticalScrollIndicator = false

        fieldsStackView.axis = .vertical
        fieldsStackView.spacing = 12

        fields.forEach { field in
            let textField = makeTextField(for: field)
            textFieldsByKey[field.key] = textField
            fieldsStackView.addArrangedSubview(textField)
        }

        buttonsStackView.axis = .horizontal
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.spacing = 12

        configureButton(
            cancelButton,
            title: "Отмена",
            color: BrandColor.surfaceMuted,
            textColor: BrandColor.textPrimary
        )
        configureButton(
            submitButton,
            title: submitTitle,
            color: submitColor,
            textColor: BrandColor.onPrimary
        )

        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        submitButton.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(subtitleLabel)
        contentStackView.addArrangedSubview(fieldsStackView)
        contentStackView.addArrangedSubview(buttonsStackView)

        buttonsStackView.addArrangedSubview(cancelButton)
        buttonsStackView.addArrangedSubview(submitButton)
    }

    private func setupConstraints() {
        scrollView.pinTop(to: view.safeAreaLayoutGuide.topAnchor)
        scrollView.pinLeft(to: view.leadingAnchor)
        scrollView.pinRight(to: view.trailingAnchor)
        scrollView.pinBottom(to: view.bottomAnchor)

        contentStackView.pinTop(to: scrollView.contentLayoutGuide.topAnchor, 24)
        contentStackView.pinLeft(to: scrollView.contentLayoutGuide.leadingAnchor, 24)
        contentStackView.pinRight(to: scrollView.contentLayoutGuide.trailingAnchor, 24)
        contentStackView.pinBottom(to: scrollView.contentLayoutGuide.bottomAnchor, 24)
        contentStackView.pinWidth(to: scrollView.frameLayoutGuide.widthAnchor, constant: -48)
    }

    private func makeTextField(for field: Field) -> UITextField {
        let textField = UITextField()
        textField.placeholder = field.placeholder
        textField.text = field.text
        textField.keyboardType = field.keyboardType
        textField.autocapitalizationType = field.autocapitalizationType
        textField.textColor = BrandColor.textPrimary
        textField.tintColor = BrandColor.accentOrange
        textField.font = BrandFont.demiBold(17)
        textField.backgroundColor = BrandColor.surfaceMuted
        textField.layer.cornerRadius = 14
        textField.layer.cornerCurve = .continuous
        textField.layer.borderWidth = 1
        textField.layer.borderColor = BrandColor.cgColor(BrandColor.fieldBorder, compatibleWith: traitCollection)
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        textField.leftViewMode = .always
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .next
        textField.delegate = self
        textField.setHeight(52)
        return textField
    }

    private func configureButton(
        _ button: UIButton,
        title: String,
        color: UIColor,
        textColor: UIColor
    ) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = color
        configuration.baseForegroundColor = textColor
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = BrandFont.demiBold(16)
            return outgoing
        }

        button.configuration = configuration
        button.setHeight(52)
    }

    private func observeKeyboard() {
        keyboardObserverTokens = [
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleKeyboard(notification)
            },
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleKeyboard(notification)
            }
        ]
    }

    private func handleKeyboard(_ notification: Notification) {
        let transition = KeyboardTransition(notification: notification, in: view)
        scrollView.contentInset.bottom = transition.overlapHeight
        scrollView.verticalScrollIndicatorInsets.bottom = transition.overlapHeight

        transition.animate { [weak self] in
            guard let self else { return }
            self.view.layoutIfNeeded()
            guard let focusedField = self.textFieldsByKey.values.first(where: { $0.isFirstResponder }) else {
                return
            }
            let fieldRect = focusedField.convert(focusedField.bounds, to: self.scrollView)
            self.scrollView.scrollRectToVisible(fieldRect.insetBy(dx: 0, dy: -24), animated: false)
        }
    }

    @objc
    private func didTapCancel() {
        dismiss(animated: true)
    }

    @objc
    private func didTapSubmit() {
        let values = Dictionary(
            uniqueKeysWithValues: textFieldsByKey.map { key, textField in
                (key, textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            }
        )
        dismiss(animated: true) { [onSubmit] in
            onSubmit(values)
        }
    }
}

extension AdminFormViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let index = fieldsStackView.arrangedSubviews.firstIndex(of: textField) else {
            textField.resignFirstResponder()
            return true
        }

        let nextIndex = fieldsStackView.arrangedSubviews.index(after: index)
        if fieldsStackView.arrangedSubviews.indices.contains(nextIndex),
           let nextField = fieldsStackView.arrangedSubviews[nextIndex] as? UITextField {
            nextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}
