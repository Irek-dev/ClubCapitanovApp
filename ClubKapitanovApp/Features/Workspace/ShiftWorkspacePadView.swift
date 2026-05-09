import UIKit

/// Корневой UIView для iPad-workspace.
///
/// Этот view собирает два крупных блока: sidebar и content. Также здесь живут overlay:
/// toast, модалка подтверждения операции и модалка закрытия смены. Бизнес-действия
/// уходят наружу через delegate.
protocol ShiftWorkspacePadViewDelegate: AnyObject {
    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didSelect section: ShiftWorkspaceSection)
    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didSubmitParticipantPIN pinCode: String)
    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didRemoveParticipant id: UUID)
    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didSubmitRentalOrderItems selections: [ShiftWorkspace.RentalOrderItemInput])
    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didCompleteRentalOrder id: UUID, paymentMethod: PaymentMethod)
    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didConfirmSouvenirAt index: Int, quantity: Int, paymentMethod: PaymentMethod)
    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didConfirmFineAt index: Int, quantity: Int, paymentMethod: PaymentMethod)
    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didIncreaseSouvenirQuantityAt index: Int)
    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didDecreaseSouvenirQuantityAt index: Int)
    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didIncreaseFineQuantityAt index: Int)
    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didDecreaseFineQuantityAt index: Int)
    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didConfirmCloseShiftWith manualInput: ShiftCloseReportManualInput)
}

final class ShiftWorkspacePadView: UIView {
    weak var delegate: ShiftWorkspacePadViewDelegate?

    private let sidebarView = ShiftWorkspacePadSidebarView()
    private let contentView = ShiftWorkspacePadContentView()
    private var closeOverlayView: ShiftWorkspaceCloseShiftModalView?
    private var operationOverlayView: ShiftWorkspaceOperationConfirmModalView?
    private var addParticipantOverlayView: ShiftWorkspaceAddParticipantModalView?
    private var rentalOrderOverlayView: ShiftWorkspaceRentalOrderModalView?
    private var rentalPaymentOverlayView: ShiftWorkspaceRentalPaymentModalView?
    private var toastView: UIView?
    private var closeShiftModalViewModel: ShiftWorkspace.CloseShiftModalViewModel?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        setupConstraints()
        bindActions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(viewModel: ShiftWorkspace.ViewModel) {
        // Храним ViewModel модалки закрытия отдельно, потому что сама модалка создается
        // только по нажатию на кнопку в разделе закрытия смены.
        closeShiftModalViewModel = viewModel.closeShiftModal
        sidebarView.render(viewModel: viewModel)
        contentView.render(title: viewModel.screenTitle, content: viewModel.content)
    }

    func showToast(title: String, message: String) {
        // Toast — короткая обратная связь после добавления операции. Он не блокирует
        // экран и автоматически исчезает после небольшой задержки.
        toastView?.removeFromSuperview()

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialLight))
        let stackView = UIStackView()
        let titleLabel = UILabel()
        let messageLabel = UILabel()

        blurView.layer.cornerRadius = 24
        blurView.layer.cornerCurve = .continuous
        blurView.layer.masksToBounds = true
        blurView.alpha = 0
        blurView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)

        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .center

        titleLabel.text = title
        titleLabel.textColor = BrandColor.textPrimary
        titleLabel.font = BrandFont.bold(20)

        messageLabel.text = message
        messageLabel.textColor = BrandColor.textSecondary
        messageLabel.font = BrandFont.regular(14)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        addSubview(blurView)
        blurView.contentView.addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)

        blurView.pinCenterX(to: contentView)
        blurView.pinCenterY(to: contentView)
        blurView.setWidth(mode: .grOE, 240)
        blurView.setWidth(mode: .lsOE, 360)

        stackView.pinTop(to: blurView.contentView.topAnchor, 18)
        stackView.pinLeft(to: blurView.contentView.leadingAnchor, 24)
        stackView.pinRight(to: blurView.contentView.trailingAnchor, 24)
        stackView.pinBottom(to: blurView.contentView.bottomAnchor, 18)

        toastView = blurView

        UIView.animate(withDuration: 0.18) {
            blurView.alpha = 1
            blurView.transform = .identity
        } completion: { [weak self, weak blurView] _ in
            UIView.animate(withDuration: 0.18, delay: 1.0, options: [.curveEaseInOut]) {
                blurView?.alpha = 0
                blurView?.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            } completion: { _ in
                blurView?.removeFromSuperview()
                if self?.toastView === blurView {
                    self?.toastView = nil
                }
            }
        }
    }

    private func configureUI() {
        backgroundColor = BrandColor.background

        addSubview(sidebarView)
        addSubview(contentView)
    }

    private func setupConstraints() {
        sidebarView.pinTop(to: topAnchor)
        sidebarView.pinLeft(to: leadingAnchor)
        sidebarView.pinBottom(to: bottomAnchor)
        sidebarView.setWidth(320)

        contentView.pinTop(to: topAnchor)
        contentView.pinLeft(to: sidebarView.trailingAnchor)
        contentView.pinRight(to: trailingAnchor)
        contentView.pinBottom(to: bottomAnchor)
    }

    private func bindActions() {
        // Content/sidebar ничего не знают об Interactor. Они отдают UI-события сюда,
        // а этот корневой view переводит их в delegate-вызовы ViewController.
        sidebarView.onSelectSection = { [weak self] section in
            guard let self else { return }
            delegate?.shiftWorkspacePadView(self, didSelect: section)
        }

        sidebarView.onAddParticipant = { [weak self] in
            self?.showAddParticipantModal()
        }

        sidebarView.onRemoveParticipant = { [weak self] id in
            guard let self else { return }
            delegate?.shiftWorkspacePadView(self, didRemoveParticipant: id)
        }

        contentView.onTapCreateRentalOrder = { [weak self] rentalTypes in
            self?.showRentalOrderModal(rentalTypes: rentalTypes)
        }

        contentView.onCompleteRentalOrder = { [weak self] order in
            self?.showRentalPaymentModal(order: order)
        }

        contentView.onTapSouvenir = { [weak self] viewModel in
            guard let self else { return }
            showOperationConfirmModal(
                viewModel: viewModel,
                kind: .souvenir,
                tintColor: ShiftWorkspaceSection.souvenirs.tintColor
            )
        }

        contentView.onTapFine = { [weak self] viewModel in
            guard let self else { return }
            showOperationConfirmModal(
                viewModel: viewModel,
                kind: .fine,
                tintColor: ShiftWorkspaceSection.fines.tintColor
            )
        }

        contentView.onIncreaseQuantity = { [weak self] adjustment in
            guard let self else { return }
            switch adjustment.kind {
            case .souvenir:
                delegate?.shiftWorkspacePadView(self, didIncreaseSouvenirQuantityAt: adjustment.index)
            case .fine:
                delegate?.shiftWorkspacePadView(self, didIncreaseFineQuantityAt: adjustment.index)
            }
        }

        contentView.onDecreaseQuantity = { [weak self] adjustment in
            guard let self else { return }
            switch adjustment.kind {
            case .souvenir:
                delegate?.shiftWorkspacePadView(self, didDecreaseSouvenirQuantityAt: adjustment.index)
            case .fine:
                delegate?.shiftWorkspacePadView(self, didDecreaseFineQuantityAt: adjustment.index)
            }
        }

        contentView.onTapCloseShift = { [weak self] in
            self?.showCloseShiftModal()
        }
    }

    private func showAddParticipantModal() {
        addParticipantOverlayView?.removeFromSuperview()

        let overlayView = ShiftWorkspaceAddParticipantModalView()
        overlayView.onDismiss = { [weak self] in
            self?.dismissAddParticipantModal()
        }
        overlayView.onConfirm = { [weak self] pinCode in
            guard let self else { return }
            dismissAddParticipantModal()
            delegate?.shiftWorkspacePadView(self, didSubmitParticipantPIN: pinCode)
        }

        addSubview(overlayView)
        overlayView.pin(to: self)

        addParticipantOverlayView = overlayView
    }

    private func dismissAddParticipantModal() {
        addParticipantOverlayView?.removeFromSuperview()
        addParticipantOverlayView = nil
    }

    private func showRentalOrderModal(rentalTypes: [ShiftWorkspace.RentalOrderItemTypeViewModel]) {
        rentalOrderOverlayView?.removeFromSuperview()

        let overlayView = ShiftWorkspaceRentalOrderModalView(rentalTypes: rentalTypes)
        overlayView.onDismiss = { [weak self] in
            self?.dismissRentalOrderModal()
        }
        overlayView.onConfirm = { [weak self] selections in
            guard let self else { return }
            dismissRentalOrderModal()
            delegate?.shiftWorkspacePadView(self, didSubmitRentalOrderItems: selections)
        }

        addSubview(overlayView)
        overlayView.pin(to: self)

        rentalOrderOverlayView = overlayView
    }

    private func dismissRentalOrderModal() {
        rentalOrderOverlayView?.removeFromSuperview()
        rentalOrderOverlayView = nil
    }

    private func showOperationConfirmModal(
        viewModel: ShiftWorkspace.ActionButtonViewModel,
        kind: ShiftWorkspace.OperationKind,
        tintColor: UIColor
    ) {
        // Тап по кнопке сувенирки/штрафа сначала открывает подтверждение. Наружу
        // уходят только уже подтвержденные количество и способ оплаты.
        operationOverlayView?.removeFromSuperview()

        let overlayView = ShiftWorkspaceOperationConfirmModalView(
            viewModel: viewModel,
            tintColor: tintColor
        )
        overlayView.onDismiss = { [weak self] in
            self?.dismissOperationConfirmModal()
        }
        overlayView.onConfirm = { [weak self] quantity, paymentMethod in
            guard let self else { return }
            dismissOperationConfirmModal()

            switch kind {
            case .souvenir:
                delegate?.shiftWorkspacePadView(
                    self,
                    didConfirmSouvenirAt: viewModel.index,
                    quantity: quantity,
                    paymentMethod: paymentMethod
                )
            case .fine:
                delegate?.shiftWorkspacePadView(
                    self,
                    didConfirmFineAt: viewModel.index,
                    quantity: quantity,
                    paymentMethod: paymentMethod
                )
            }
        }

        addSubview(overlayView)
        overlayView.pin(to: self)

        operationOverlayView = overlayView
    }

    private func dismissOperationConfirmModal() {
        operationOverlayView?.removeFromSuperview()
        operationOverlayView = nil
    }

    private func showRentalPaymentModal(order: ShiftWorkspace.ActiveRentalOrderViewModel) {
        rentalPaymentOverlayView?.removeFromSuperview()

        let overlayView = ShiftWorkspaceRentalPaymentModalView(order: order)
        overlayView.onDismiss = { [weak self] in
            self?.dismissRentalPaymentModal()
        }
        overlayView.onConfirm = { [weak self] paymentMethod in
            guard let self else { return }
            dismissRentalPaymentModal()
            delegate?.shiftWorkspacePadView(
                self,
                didCompleteRentalOrder: order.id,
                paymentMethod: paymentMethod
            )
        }

        addSubview(overlayView)
        overlayView.pin(to: self)

        rentalPaymentOverlayView = overlayView
    }

    private func dismissRentalPaymentModal() {
        rentalPaymentOverlayView?.removeFromSuperview()
        rentalPaymentOverlayView = nil
    }

    private func showCloseShiftModal() {
        // Модалка закрытия использует последнюю ViewModel, чтобы показать актуальные
        // итоги смены перед необратимым действием закрытия.
        guard let viewModel = closeShiftModalViewModel else { return }

        closeOverlayView?.removeFromSuperview()

        let overlayView = ShiftWorkspaceCloseShiftModalView(viewModel: viewModel)
        overlayView.onDismiss = { [weak self] in
            self?.dismissCloseShiftModal()
        }
        overlayView.onConfirm = { [weak self] manualInput in
            guard let self else { return }
            dismissCloseShiftModal()
            self.delegate?.shiftWorkspacePadView(self, didConfirmCloseShiftWith: manualInput)
        }

        addSubview(overlayView)
        overlayView.pin(to: self)

        closeOverlayView = overlayView
    }

    private func dismissCloseShiftModal() {
        closeOverlayView?.removeFromSuperview()
        closeOverlayView = nil
    }
}
