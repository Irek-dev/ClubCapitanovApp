import UIKit

/// Центральная область workspace справа от sidebar.
///
/// View получает enum `ContentViewModel` и строит соответствующий раздел: прокат,
/// сувенирка, штрафы, временный отчет или закрытие смены. Все действия отдаются
/// наружу closure-ами, чтобы view не зависел от Interactor.
final class ShiftWorkspacePadContentView: UIView {
    private enum ReportPreviewLineStyle {
        case separator
        case title
        case bullet
        case section
        case keyValue
    }

    var onTapSouvenir: ((ShiftWorkspace.ActionButtonViewModel) -> Void)?
    var onTapFine: ((ShiftWorkspace.ActionButtonViewModel) -> Void)?
    var onTapCreateRentalOrder: (([ShiftWorkspace.RentalOrderItemTypeViewModel]) -> Void)?
    var onTapAddParticipant: (() -> Void)?
    var onRemoveParticipant: ((UUID) -> Void)?
    var onCompleteRentalOrder: ((ShiftWorkspace.ActiveRentalOrderViewModel) -> Void)?
    var onEditRentalOrder: ((ShiftWorkspace.ActiveRentalOrderViewModel, [ShiftWorkspace.RentalOrderItemTypeViewModel]) -> Void)?
    var onIncreaseQuantity: ((ShiftWorkspace.QuantityAdjustmentViewModel) -> Void)?
    var onDecreaseQuantity: ((ShiftWorkspace.QuantityAdjustmentViewModel) -> Void)?
    var onTapCloseShift: (() -> Void)?

    private let titleLabel = UILabel()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var souvenirButtonsByIndex: [Int: ShiftWorkspace.ActionButtonViewModel] = [:]
    private var fineButtonsByIndex: [Int: ShiftWorkspace.ActionButtonViewModel] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(title: String, content: ShiftWorkspace.ContentViewModel) {
        // При смене раздела проще пересобрать stackView полностью: структура контента
        // у разделов разная, а объем элементов небольшой.
        titleLabel.text = title
        souvenirButtonsByIndex.removeAll()
        fineButtonsByIndex.removeAll()

        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        switch content {
        case let .ducks(intro, createOrderButtonTitle, rentalTypes, activeOrders, _, report):
            stackView.addArrangedSubview(makeSectionIntro(intro))
            let button = makeCompactActionButton(
                title: createOrderButtonTitle,
                color: ShiftWorkspaceSection.ducks.tintColor
            )
            button.addAction(
                UIAction { [weak self] _ in
                    self?.onTapCreateRentalOrder?(rentalTypes)
                },
                for: .touchUpInside
            )
            stackView.addArrangedSubview(makeTrailingView(button))
            if !activeOrders.isEmpty {
                stackView.addArrangedSubview(makeSubsectionTitle("Активные заказы"))
                activeOrders.forEach { order in
                    let cardView = ActiveRentalOrderCardView(viewModel: order)
                    cardView.onComplete = { [weak self] order in
                        self?.onCompleteRentalOrder?(order)
                    }
                    cardView.onEdit = { [weak self] order in
                        self?.onEditRentalOrder?(order, rentalTypes)
                    }
                    stackView.addArrangedSubview(cardView)
                }
            }
            stackView.addArrangedSubview(makeGroupedOperationsCard(report))
        case let .participants(intro, participants, addButtonTitle):
            stackView.addArrangedSubview(makeSectionIntro(intro))
            let button = makeCompactActionButton(
                title: addButtonTitle,
                color: ShiftWorkspaceSection.participants.tintColor,
                systemName: "person.badge.plus"
            )
            button.addAction(
                UIAction { [weak self] _ in
                    self?.onTapAddParticipant?()
                },
                for: .touchUpInside
            )
            stackView.addArrangedSubview(makeTrailingView(button))
            stackView.addArrangedSubview(makeParticipantsCard(participants))
        case let .souvenirs(intro, buttons, summaryLines, report):
            stackView.addArrangedSubview(makeSectionIntro(intro))
            buttons.forEach { buttonViewModel in
                souvenirButtonsByIndex[buttonViewModel.index] = buttonViewModel
                let button = makeActionButton(
                    title: buttonViewModel.title,
                    color: ShiftWorkspaceSection.souvenirs.tintColor
                )
                button.tag = buttonViewModel.index
                button.addTarget(self, action: #selector(didTapSouvenirButton(_:)), for: .touchUpInside)
                stackView.addArrangedSubview(button)
            }
            if !summaryLines.isEmpty {
                stackView.addArrangedSubview(makeMutedCard(lines: summaryLines))
            }
            stackView.addArrangedSubview(makeGroupedOperationsCard(report))
        case let .fines(intro, buttons, summaryLines, report):
            stackView.addArrangedSubview(makeSectionIntro(intro))
            buttons.forEach { buttonViewModel in
                fineButtonsByIndex[buttonViewModel.index] = buttonViewModel
                let button = makeActionButton(
                    title: buttonViewModel.title,
                    color: ShiftWorkspaceSection.fines.tintColor
                )
                button.tag = buttonViewModel.index
                button.addTarget(self, action: #selector(didTapFineButton(_:)), for: .touchUpInside)
                stackView.addArrangedSubview(button)
            }
            if !summaryLines.isEmpty {
                stackView.addArrangedSubview(makeMutedCard(lines: summaryLines))
            }
            stackView.addArrangedSubview(makeGroupedOperationsCard(report))
        case let .temporaryReport(intro, infoLines, rentalReport, summaryLines, employeeLines, souvenirReport, fineReport):
            stackView.addArrangedSubview(makeSectionIntro(intro))
            if !infoLines.isEmpty {
                stackView.addArrangedSubview(makeReportPreviewCard(lines: infoLines))
            }
            stackView.addArrangedSubview(makeGroupedOperationsCard(rentalReport))
            if !summaryLines.isEmpty {
                stackView.addArrangedSubview(makeMutedCard(lines: summaryLines))
            }
            if !employeeLines.isEmpty {
                stackView.addArrangedSubview(makeMutedCard(lines: employeeLines))
            }
            if !souvenirReport.title.isEmpty {
                stackView.addArrangedSubview(makeGroupedOperationsCard(souvenirReport))
            }
            if !fineReport.title.isEmpty {
                stackView.addArrangedSubview(makeGroupedOperationsCard(fineReport))
            }
        case let .closeShift(intro, shiftLines, buttonTitle):
            stackView.addArrangedSubview(makeSectionIntro(intro))
            stackView.addArrangedSubview(makeReportPreviewCard(lines: shiftLines))
            let button = makeActionButton(title: buttonTitle, color: ShiftWorkspaceSection.closeShift.tintColor)
            button.addTarget(self, action: #selector(didTapCloseShiftButton), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
    }

    private func configureUI() {
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.bold(24)
        titleLabel.textAlignment = .center

        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill

        addSubview(titleLabel)
        addSubview(scrollView)
        scrollView.addSubview(stackView)
    }

    private func setupConstraints() {
        titleLabel.pinTop(to: safeAreaLayoutGuide.topAnchor, 30)
        titleLabel.pinCenterX(to: centerXAnchor)

        scrollView.pinTop(to: titleLabel.bottomAnchor, 32)
        scrollView.pinLeft(to: leadingAnchor)
        scrollView.pinRight(to: trailingAnchor)
        scrollView.pinBottom(to: bottomAnchor)

        stackView.pinTop(to: scrollView.contentLayoutGuide.topAnchor)
        stackView.pinLeft(to: scrollView.contentLayoutGuide.leadingAnchor, 34)
        stackView.pinRight(to: scrollView.contentLayoutGuide.trailingAnchor, 34)
        stackView.pinBottom(to: scrollView.contentLayoutGuide.bottomAnchor, 34, .lsOE)
        stackView.pinWidth(to: scrollView.frameLayoutGuide.widthAnchor, constant: -68)
    }

    private func makeSectionIntro(_ text: String) -> UILabel {
        makeMultilineLabel(text: text, color: BrandColor.textSecondary, font: BrandFont.regular(17))
    }

    private func makeSubsectionTitle(_ text: String) -> UILabel {
        makeMultilineLabel(text: text, color: BrandColor.textPrimary, font: BrandFont.bold(18))
    }

    private func makeActionButton(title: String, color: UIColor) -> UIButton {
        let titleFont = BrandFont.heavy(18)
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = color
        configuration.baseForegroundColor = BrandColor.onPrimary
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 16, leading: 18, bottom: 16, trailing: 18)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = titleFont
            return outgoing
        }

        let button = UIButton(type: .system)
        button.configuration = configuration
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.minimumScaleFactor = 0.86
        button.titleLabel?.numberOfLines = 1
        button.setHeight(56)
        return button
    }

    private func makeCompactActionButton(
        title: String,
        color: UIColor,
        systemName: String? = nil
    ) -> UIButton {
        let titleFont = BrandFont.demiBold(15)
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        if let systemName {
            configuration.image = UIImage(systemName: systemName)
            configuration.imagePadding = 8
        }
        configuration.baseBackgroundColor = color
        configuration.baseForegroundColor = BrandColor.onPrimary
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 12, leading: 18, bottom: 12, trailing: 18)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = titleFont
            return outgoing
        }

        let button = UIButton(type: .system)
        button.configuration = configuration
        button.setHeight(44)
        return button
    }

    private func makeTrailingView(_ contentView: UIView) -> UIView {
        let containerView = UIView()
        containerView.addSubview(contentView)

        contentView.pinTop(to: containerView.topAnchor)
        contentView.pinRight(to: containerView.trailingAnchor)
        contentView.pinBottom(to: containerView.bottomAnchor)

        return containerView
    }

    private func makeParticipantsCard(_ participants: [ShiftWorkspace.ParticipantViewModel]) -> UIView {
        let stackView = UIStackView()
        let titleLabel = makeMultilineLabel(
            text: "Сотрудники на смене",
            color: BrandColor.textPrimary,
            font: BrandFont.bold(18)
        )

        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.addArrangedSubview(titleLabel)

        if participants.isEmpty {
            stackView.addArrangedSubview(
                makeMultilineLabel(
                    text: "Сотрудники пока не добавлены",
                    color: BrandColor.textSecondary,
                    font: BrandFont.regular(15)
                )
            )
        } else {
            participants.forEach { participant in
                stackView.addArrangedSubview(makeParticipantRow(participant))
            }
        }

        return makeShadowCard(containing: stackView)
    }

    private func makeParticipantRow(_ participant: ShiftWorkspace.ParticipantViewModel) -> UIView {
        let rowView = UIView()
        let labelsStackView = UIStackView()
        let nameLabel = makeMultilineLabel(
            text: participant.name,
            color: BrandColor.textPrimary,
            font: BrandFont.demiBold(16)
        )
        let joinedLabel = makeMultilineLabel(
            text: participant.joinedAtText,
            color: BrandColor.textSecondary,
            font: BrandFont.regular(14)
        )
        let removeButton = makeRemoveParticipantButton(participantID: participant.id)

        labelsStackView.axis = .vertical
        labelsStackView.spacing = 3
        labelsStackView.addArrangedSubview(nameLabel)
        labelsStackView.addArrangedSubview(joinedLabel)

        rowView.addSubview(labelsStackView)
        rowView.addSubview(removeButton)

        labelsStackView.pinTop(to: rowView.topAnchor, 2)
        labelsStackView.pinLeft(to: rowView.leadingAnchor)
        labelsStackView.pinRight(to: removeButton.leadingAnchor, 16)
        labelsStackView.pinBottom(to: rowView.bottomAnchor, 2)

        removeButton.pinRight(to: rowView.trailingAnchor)
        removeButton.pinCenterY(to: rowView)

        rowView.setHeight(mode: .grOE, 48)
        return rowView
    }

    private func makeRemoveParticipantButton(participantID: UUID) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "trash")
        configuration.baseBackgroundColor = BrandColor.surfaceMuted
        configuration.baseForegroundColor = BrandColor.textSecondary
        configuration.cornerStyle = .capsule
        configuration.contentInsets = .init(top: 9, leading: 9, bottom: 9, trailing: 9)

        let button = UIButton(type: .system)
        button.configuration = configuration
        button.accessibilityLabel = "Удалить сотрудника из смены"
        button.addAction(
            UIAction { [weak self] _ in
                self?.onRemoveParticipant?(participantID)
            },
            for: .touchUpInside
        )
        button.setWidth(40)
        button.setHeight(40)
        return button
    }

    private func makeMutedCard(lines: [String]) -> UIView {
        makeShadowCard(
            containing: makeMultilineLabel(
                text: lines.joined(separator: "\n"),
                color: BrandColor.textPrimary,
                font: BrandFont.regular(15)
            )
        )
    }

    private func makeReportPreviewCard(lines: [String]) -> UIView {
        let stackView = UIStackView()

        stackView.axis = .vertical
        stackView.spacing = 10

        lines.forEach { line in
            switch reportPreviewLineStyle(for: line) {
            case .separator:
                stackView.addArrangedSubview(makeReportSeparator())
            case .title:
                stackView.addArrangedSubview(makeReportPreviewLabel(String(line.dropFirst()), font: BrandFont.bold(22)))
            case .bullet:
                stackView.addArrangedSubview(makeReportPreviewLabel(line, font: BrandFont.regular(15)))
            case .section:
                stackView.addArrangedSubview(makeReportPreviewLabel(line, font: BrandFont.bold(17)))
            case .keyValue:
                stackView.addArrangedSubview(makeReportKeyValueRow(line))
            }
        }

        return makeShadowCard(containing: stackView)
    }

    private func reportPreviewLineStyle(for line: String) -> ReportPreviewLineStyle {
        if line.isEmpty {
            return .separator
        }

        if line.hasPrefix("#") {
            return .title
        }

        if line.hasPrefix("- ") {
            return .bullet
        }

        return line.contains(":") ? .keyValue : .section
    }

    private func makeReportPreviewLabel(_ text: String, font: UIFont) -> UILabel {
        makeMultilineLabel(text: text, color: BrandColor.textPrimary, font: font)
    }

    private func makeMultilineLabel(
        text: String?,
        color: UIColor,
        font: UIFont,
        textAlignment: NSTextAlignment = .natural
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = font
        label.numberOfLines = 0
        label.textAlignment = textAlignment
        return label
    }

    private func makeShadowCard(containing contentView: UIView) -> UIView {
        let cardView = ShiftWorkspaceShadowCardView()
        cardView.addSubview(contentView)
        contentView.pin(to: cardView, 18)
        return cardView
    }

    private func makeReportKeyValueRow(_ line: String) -> UIView {
        let rowView = UIView()
        let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
        let keyLabel = makeMultilineLabel(
            text: parts.first.map { "\($0):" },
            color: BrandColor.textSecondary,
            font: BrandFont.regular(15)
        )
        let valueLabel = makeMultilineLabel(
            text: parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : "",
            color: BrandColor.textPrimary,
            font: BrandFont.demiBold(15),
            textAlignment: .right
        )

        rowView.addSubview(keyLabel)
        rowView.addSubview(valueLabel)

        keyLabel.pinTop(to: rowView.topAnchor)
        keyLabel.pinLeft(to: rowView.leadingAnchor)
        keyLabel.pinRight(to: valueLabel.leadingAnchor, 14)
        keyLabel.pinBottom(to: rowView.bottomAnchor)

        valueLabel.pinTop(to: rowView.topAnchor)
        valueLabel.pinRight(to: rowView.trailingAnchor)
        valueLabel.pinBottom(to: rowView.bottomAnchor)
        valueLabel.setWidth(mode: .grOE, 170)

        return rowView
    }

    private func makeReportSeparator() -> UIView {
        let separatorView = UIView()
        separatorView.backgroundColor = BrandColor.fieldBorder
        separatorView.setHeight(1)
        return separatorView
    }

    private func makeGroupedOperationsCard(_ group: ShiftWorkspace.ReportGroupViewModel) -> UIView {
        // Карточка отчета используется и для сувенирки, и для штрафов. Строки могут
        // быть только информационными или управляемыми через +/-.
        let stackView = UIStackView()
        let titleLabel = UILabel()

        stackView.axis = .vertical
        stackView.spacing = 12

        titleLabel.text = group.title
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.bold(18)
        stackView.addArrangedSubview(titleLabel)

        if group.rows.isEmpty {
            stackView.addArrangedSubview(
                makeMultilineLabel(
                    text: group.emptyText,
                    color: BrandColor.textSecondary,
                    font: BrandFont.regular(15)
                )
            )
        } else {
            group.rows.forEach { row in
                stackView.addArrangedSubview(makeReportRow(row))
            }
        }

        if let footerText = group.footerText {
            if !group.rows.isEmpty {
                stackView.addArrangedSubview(makeReportSeparator())
            }

            stackView.addArrangedSubview(
                makeMultilineLabel(
                    text: footerText,
                    color: BrandColor.textPrimary,
                    font: BrandFont.bold(16),
                    textAlignment: .right
                )
            )
        }

        return makeShadowCard(containing: stackView)
    }

    private func makeReportRow(_ row: ShiftWorkspace.ReportRowViewModel) -> UIView {
        // Если у строки есть quantityAdjustment, справа добавляются кнопки изменения
        // количества. Без adjustment строка остается обычной исторической записью.
        let rowView = UIView()
        let titleLabel = UILabel()
        let detailLabel = UILabel()
        let amountLabel = UILabel()
        let controlsStackView = UIStackView()

        titleLabel.text = row.title
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.demiBold(15)
        titleLabel.numberOfLines = 0

        detailLabel.text = row.detail
        detailLabel.textColor = BrandColor.textSecondary
        detailLabel.font = BrandFont.regular(14)
        detailLabel.numberOfLines = 0

        amountLabel.text = row.amount
        amountLabel.textColor = BrandColor.textPrimary
        amountLabel.font = BrandFont.bold(15)
        amountLabel.textAlignment = .right
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        rowView.addSubview(titleLabel)
        rowView.addSubview(detailLabel)
        rowView.addSubview(amountLabel)

        if let quantityAdjustment = row.quantityAdjustment {
            controlsStackView.axis = .horizontal
            controlsStackView.spacing = 8
            controlsStackView.alignment = .center

            let decrementButton = makeQuantityButton(systemName: "minus")
            let incrementButton = makeQuantityButton(systemName: "plus")

            decrementButton.addAction(
                UIAction { [weak self] _ in
                    self?.onDecreaseQuantity?(quantityAdjustment)
                },
                for: .touchUpInside
            )
            incrementButton.addAction(
                UIAction { [weak self] _ in
                    self?.onIncreaseQuantity?(quantityAdjustment)
                },
                for: .touchUpInside
            )

            controlsStackView.addArrangedSubview(decrementButton)
            controlsStackView.addArrangedSubview(incrementButton)
            rowView.addSubview(controlsStackView)
        }

        titleLabel.pinTop(to: rowView.topAnchor)
        titleLabel.pinLeft(to: rowView.leadingAnchor)

        detailLabel.pinTop(to: titleLabel.bottomAnchor, 2)
        detailLabel.pinLeft(to: titleLabel.leadingAnchor)
        detailLabel.pinRight(to: titleLabel.trailingAnchor)
        detailLabel.pinBottom(to: rowView.bottomAnchor)

        if row.quantityAdjustment == nil {
            titleLabel.pinRight(to: amountLabel.leadingAnchor, 12)
            amountLabel.pinRight(to: rowView.trailingAnchor)
        } else {
            controlsStackView.pinRight(to: rowView.trailingAnchor)
            controlsStackView.pinCenterY(to: rowView)
            titleLabel.pinRight(to: amountLabel.leadingAnchor, 12)
            amountLabel.pinRight(to: controlsStackView.leadingAnchor, 14)
            rowView.setHeight(mode: .grOE, 44)
        }

        amountLabel.pinCenterY(to: rowView)

        return rowView
    }

    private func makeQuantityButton(systemName: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: systemName)
        configuration.baseBackgroundColor = BrandColor.surfaceMuted
        configuration.baseForegroundColor = BrandColor.textPrimary
        configuration.cornerStyle = .capsule
        configuration.contentInsets = .init(top: 8, leading: 8, bottom: 8, trailing: 8)

        let button = UIButton(type: .system)
        button.configuration = configuration
        button.tintColor = BrandColor.textPrimary
        button.accessibilityLabel = systemName == "minus" ? "Уменьшить количество" : "Увеличить количество"
        button.setWidth(36)
        button.setHeight(36)
        return button
    }

    @objc
    private func didTapSouvenirButton(_ sender: UIButton) {
        guard let viewModel = souvenirButtonsByIndex[sender.tag] else { return }
        onTapSouvenir?(viewModel)
    }

    @objc
    private func didTapFineButton(_ sender: UIButton) {
        guard let viewModel = fineButtonsByIndex[sender.tag] else { return }
        onTapFine?(viewModel)
    }

    @objc
    private func didTapCloseShiftButton() {
        onTapCloseShift?()
    }
}
