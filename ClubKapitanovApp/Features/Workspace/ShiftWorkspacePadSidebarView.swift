import UIKit

/// Левая панель iPad-workspace.
///
/// Sidebar показывает контекст смены: название приложения, точку, время открытия
/// и навигацию по разделам. Он не знает бизнес-логики, а только сообщает
/// наружу выбранный `ShiftWorkspaceSection`.
final class ShiftWorkspacePadSidebarView: UIView {
    var onSelectSection: ((ShiftWorkspaceSection) -> Void)?

    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(viewModel: ShiftWorkspace.ViewModel) {
        // Sidebar пересобирается из ViewModel целиком. Для текущего размера данных
        // это проще и надежнее, чем точечно обновлять отдельные labels/buttons.
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let appTitleLabel = makeLabel(
            viewModel.appTitle,
            font: BrandFont.bold(24),
            color: BrandColor.textPrimary
        )
        let pointLabel = makeLabel(
            viewModel.pointName,
            font: BrandFont.demiBold(15),
            color: BrandColor.textPrimary
        )
        let openedAtLabel = makeLabel(
            viewModel.openedAtText,
            font: BrandFont.regular(12),
            color: BrandColor.textSecondary
        )

        stackView.addArrangedSubview(appTitleLabel)
        stackView.setCustomSpacing(18, after: appTitleLabel)
        stackView.addArrangedSubview(pointLabel)
        stackView.setCustomSpacing(8, after: pointLabel)
        stackView.addArrangedSubview(openedAtLabel)
        stackView.setCustomSpacing(28, after: openedAtLabel)

        stackView.addArrangedSubview(makeSpacer(height: 4))

        viewModel.sections.forEach { item in
            let button = makeSidebarButton(for: item)
            stackView.addArrangedSubview(button)
            stackView.setCustomSpacing(12, after: button)
        }

        stackView.addArrangedSubview(UIView())
    }

    private func configureUI() {
        backgroundColor = BrandColor.surface
        layer.shadowColor = BrandColor.cgColor(BrandColor.shadow, compatibleWith: traitCollection)
        layer.shadowOpacity = 0.10
        layer.shadowRadius = 24
        layer.shadowOffset = CGSize(width: 10, height: 0)

        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.alignment = .fill

        addSubview(stackView)
    }

    private func setupConstraints() {
        stackView.pinTop(to: safeAreaLayoutGuide.topAnchor, 46)
        stackView.pinLeft(to: leadingAnchor, 24)
        stackView.pinRight(to: trailingAnchor, 24)
        stackView.pinBottom(to: safeAreaLayoutGuide.bottomAnchor, 26)
    }

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func makeSpacer(height: CGFloat) -> UIView {
        let spacerView = UIView()
        spacerView.setHeight(height)
        return spacerView
    }

    private func makeSidebarButton(for item: ShiftWorkspace.SectionItemViewModel) -> UIButton {
        // В tag кладется rawValue раздела, чтобы target-action мог восстановить enum
        // без хранения отдельной таблицы UIButton -> section.
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.title = item.section.title
        configuration.image = UIImage(systemName: item.section.iconName)
        configuration.imagePadding = 10
        configuration.imagePlacement = .leading
        configuration.contentInsets = .init(top: 12, leading: 14, bottom: 12, trailing: 14)
        configuration.cornerStyle = .large
        configuration.baseBackgroundColor = item.isSelected ? item.section.tintColor.withAlphaComponent(0.16) : BrandColor.clear
        configuration.baseForegroundColor = item.isSelected ? item.section.tintColor : BrandColor.textPrimary

        button.configuration = configuration
        button.contentHorizontalAlignment = .left
        button.tag = item.section.rawValue
        button.titleLabel?.numberOfLines = 2
        button.layer.cornerRadius = 16
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = item.isSelected ? 1 : 0
        button.layer.borderColor = item.isSelected
            ? BrandColor.cgColor(item.section.tintColor.withAlphaComponent(0.22), compatibleWith: traitCollection)
            : BrandColor.cgColor(BrandColor.clear, compatibleWith: traitCollection)
        button.titleLabel?.font = BrandFont.demiBold(14)
        button.addTarget(self, action: #selector(didTapSidebarButton(_:)), for: .touchUpInside)
        button.setHeight(58)
        return button
    }

    @objc
    private func didTapSidebarButton(_ sender: UIButton) {
        guard let section = ShiftWorkspaceSection(rawValue: sender.tag) else { return }
        onSelectSection?(section)
    }

}
