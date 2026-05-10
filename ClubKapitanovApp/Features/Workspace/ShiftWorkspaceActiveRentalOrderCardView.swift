import UIKit

final class ActiveRentalOrderCardView: UIView, UIGestureRecognizerDelegate {
    var onComplete: ((ShiftWorkspace.ActiveRentalOrderViewModel) -> Void)?
    var onEdit: ((ShiftWorkspace.ActiveRentalOrderViewModel) -> Void)?

    private let viewModel: ShiftWorkspace.ActiveRentalOrderViewModel
    private let timerLabel = UILabel()
    private let overtimeLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private var timer: Timer?

    init(viewModel: ShiftWorkspace.ActiveRentalOrderViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        configureUI()
        updateTimerState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopTimer()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            stopTimer()
        } else {
            updateTimerState()
            startTimer()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: layer.cornerRadius
        ).cgPath
    }

    private func configureUI() {
        let stackView = UIStackView()
        let headerStackView = UIStackView()
        let titleLabel = UILabel()
        let startedAtLabel = UILabel()
        let itemsLabel = UILabel()
        let amountLabel = UILabel()
        let buttonsStackView = UIStackView()
        let editButton = UIButton(type: .system)
        let completeButton = UIButton(type: .system)

        backgroundColor = BrandColor.surface
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        applySoftShadow()
        configureCardTap()

        stackView.axis = .vertical
        stackView.spacing = 10

        headerStackView.axis = .horizontal
        headerStackView.spacing = 12
        headerStackView.alignment = .firstBaseline

        titleLabel.text = viewModel.title
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.bold(16)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        timerLabel.textColor = BrandColor.textPrimary
        timerLabel.font = BrandFont.timer(20)
        timerLabel.textAlignment = .right
        timerLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        startedAtLabel.text = viewModel.startedAtText
        startedAtLabel.textColor = BrandColor.textSecondary
        startedAtLabel.font = BrandFont.regular(13)

        itemsLabel.text = viewModel.itemsText
        itemsLabel.textColor = BrandColor.textPrimary
        itemsLabel.font = BrandFont.demiBold(15)
        itemsLabel.numberOfLines = 0

        amountLabel.text = viewModel.totalAmountText
        amountLabel.textColor = BrandColor.textPrimary
        amountLabel.font = BrandFont.bold(15)
        amountLabel.numberOfLines = 0

        overtimeLabel.textColor = BrandColor.error
        overtimeLabel.font = BrandFont.demiBold(13)
        overtimeLabel.numberOfLines = 0

        progressView.trackTintColor = BrandColor.fieldBorder
        progressView.layer.cornerRadius = 4
        progressView.clipsToBounds = true
        progressView.setHeight(8)

        buttonsStackView.axis = .horizontal
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.spacing = 10

        configureEditButton(editButton)
        configureCompleteButton(completeButton)

        addSubview(stackView)
        headerStackView.addArrangedSubview(titleLabel)
        headerStackView.addArrangedSubview(timerLabel)
        stackView.addArrangedSubview(headerStackView)
        stackView.addArrangedSubview(startedAtLabel)
        stackView.addArrangedSubview(itemsLabel)
        stackView.addArrangedSubview(amountLabel)
        stackView.addArrangedSubview(progressView)
        stackView.addArrangedSubview(overtimeLabel)
        stackView.addArrangedSubview(buttonsStackView)

        buttonsStackView.addArrangedSubview(editButton)
        buttonsStackView.addArrangedSubview(completeButton)

        stackView.pinTop(to: topAnchor, 16)
        stackView.pinLeft(to: leadingAnchor, 18)
        stackView.pinRight(to: trailingAnchor, 18)
        stackView.pinBottom(to: bottomAnchor, 16)
    }

    private func configureCardTap() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapEdit))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
    }

    private func configureEditButton(_ button: UIButton) {
        configureSecondaryButton(
            button,
            title: viewModel.editButtonTitle,
            systemName: "pencil"
        )
        button.addTarget(self, action: #selector(didTapEdit), for: .touchUpInside)
    }

    private func configureSecondaryButton(_ button: UIButton, title: String, systemName: String) {
        let titleFont = BrandFont.demiBold(14)
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: systemName)
        configuration.imagePadding = 8
        configuration.baseBackgroundColor = BrandColor.surfaceMuted
        configuration.baseForegroundColor = BrandColor.primaryBlue
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 10, leading: 14, bottom: 10, trailing: 14)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = titleFont
            return outgoing
        }

        button.configuration = configuration
        button.titleLabel?.minimumScaleFactor = 0.82
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.setHeight(42)
    }

    private func configureCompleteButton(_ button: UIButton) {
        let titleFont = BrandFont.demiBold(14)
        var configuration = UIButton.Configuration.filled()
        configuration.title = viewModel.completeButtonTitle
        configuration.image = UIImage(systemName: "checkmark.circle.fill")
        configuration.imagePadding = 8
        configuration.baseBackgroundColor = BrandColor.primaryBlue
        configuration.baseForegroundColor = BrandColor.onPrimary
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 10, leading: 14, bottom: 10, trailing: 14)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = titleFont
            return outgoing
        }

        button.configuration = configuration
        button.contentHorizontalAlignment = .trailing
        button.addTarget(self, action: #selector(didTapComplete), for: .touchUpInside)
        button.setHeight(42)
    }

    private func startTimer() {
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateTimerState()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateTimerState() {
        let now = Date()
        let duration = max(1, viewModel.expectedEndAt.timeIntervalSince(viewModel.startedAt))
        let elapsed = max(0, now.timeIntervalSince(viewModel.startedAt))
        let remaining = max(0, viewModel.expectedEndAt.timeIntervalSince(now))
        let isExpired = now >= viewModel.expectedEndAt

        progressView.progress = Float(min(1, elapsed / duration))

        if isExpired {
            timerLabel.text = "00:00"
            overtimeLabel.text = "Превышение: \(timeText(elapsed - duration))"
            overtimeLabel.isHidden = false
            progressView.progressTintColor = BrandColor.error
            progressView.progress = 1
            return
        }

        timerLabel.text = timeText(remaining)
        overtimeLabel.isHidden = true

        if remaining <= 60 {
            progressView.progressTintColor = BrandColor.error
        } else if elapsed >= 5 * 60 {
            progressView.progressTintColor = BrandColor.accentOrange
        } else {
            progressView.progressTintColor = BrandColor.success
        }
    }

    private func timeText(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.down)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func applySoftShadow() {
        layer.shadowColor = BrandColor.cgColor(BrandColor.shadow, compatibleWith: traitCollection)
        layer.shadowOpacity = 0.10
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: 10)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var touchedView: UIView? = touch.view

        while let view = touchedView, view !== self {
            if view is UIControl {
                return false
            }
            touchedView = view.superview
        }

        return true
    }

    @objc
    private func didTapEdit() {
        onEdit?(viewModel)
    }

    @objc
    private func didTapComplete() {
        onComplete?(viewModel)
    }
}
