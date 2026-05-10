import UIKit

/// Контейнерный ViewController основного workspace.
///
/// Экран делегирует весь визуальный layout в `ShiftWorkspacePadView`, а сам связывает
/// UIKit-события с Interactor и принимает ViewModel от Presenter.
protocol ShiftWorkspaceDisplayLogic: AnyObject {
    func display(viewModel: ShiftWorkspace.ViewModel)
    func display(feedback: ShiftWorkspace.ActionFeedback.ViewModel)
}

final class ShiftWorkspaceViewController: UIViewController {
    private let interactor: ShiftWorkspaceBusinessLogic
    private let workspaceView = ShiftWorkspacePadView()

    init(interactor: ShiftWorkspaceBusinessLogic) {
        self.interactor = interactor
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = workspaceView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        workspaceView.delegate = self
        navigationItem.hidesBackButton = true
        interactor.load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}

extension ShiftWorkspaceViewController: ShiftWorkspaceDisplayLogic {
    func display(viewModel: ShiftWorkspace.ViewModel) {
        // Presenter присылает цельную ViewModel, а корневой view решает, какие
        // подкомпоненты sidebar/content/modal должны обновиться.
        title = viewModel.screenTitle
        workspaceView.render(viewModel: viewModel)
    }

    func display(feedback: ShiftWorkspace.ActionFeedback.ViewModel) {
        workspaceView.showToast(title: feedback.title, message: feedback.message)
    }
}

extension ShiftWorkspaceViewController: ShiftWorkspacePadViewDelegate {
    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didSelect section: ShiftWorkspaceSection) {
        interactor.select(section: section)
    }

    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didSubmitParticipantPIN pinCode: String) {
        interactor.addParticipant(pinCode: pinCode)
    }

    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didRemoveParticipant id: UUID) {
        interactor.removeParticipant(id: id)
    }

    func shiftWorkspacePadView(
        _ view: ShiftWorkspacePadView,
        didSubmitRentalOrderItems selections: [ShiftWorkspace.RentalOrderItemInput],
        paymentMethod: PaymentMethod
    ) {
        interactor.createRentalOrder(selections, paymentMethod: paymentMethod)
    }

    func shiftWorkspacePadView(
        _ view: ShiftWorkspacePadView,
        didEditRentalOrder id: UUID,
        selections: [ShiftWorkspace.RentalOrderItemInput],
        paymentMethod: PaymentMethod
    ) {
        interactor.editRentalOrder(id: id, selections: selections, paymentMethod: paymentMethod)
    }

    func shiftWorkspacePadView(
        _ view: ShiftWorkspacePadView,
        didCompleteRentalOrder id: UUID
    ) {
        interactor.completeRentalOrder(id: id)
    }

    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didExtendRentalOrder id: UUID) {
        interactor.extendRentalOrder(id: id)
    }

    func shiftWorkspacePadView(
        _ view: ShiftWorkspacePadView,
        didConfirmSouvenirAt index: Int,
        quantity: Int,
        paymentMethod: PaymentMethod
    ) {
        interactor.addSouvenir(at: index, quantity: quantity, paymentMethod: paymentMethod)
    }

    func shiftWorkspacePadView(
        _ view: ShiftWorkspacePadView,
        didConfirmFineAt index: Int,
        quantity: Int,
        paymentMethod: PaymentMethod
    ) {
        interactor.addFine(at: index, quantity: quantity, paymentMethod: paymentMethod)
    }

    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didIncreaseSouvenirQuantityAt index: Int) {
        interactor.increaseSouvenirQuantity(at: index)
    }

    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didDecreaseSouvenirQuantityAt index: Int) {
        interactor.decreaseSouvenirQuantity(at: index)
    }

    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didIncreaseFineQuantityAt index: Int) {
        interactor.increaseFineQuantity(at: index)
    }

    func shiftWorkspacePadView(_ view: ShiftWorkspacePadView, didDecreaseFineQuantityAt index: Int) {
        interactor.decreaseFineQuantity(at: index)
    }

    func shiftWorkspacePadView(
        _ view: ShiftWorkspacePadView,
        didConfirmCloseShiftWith manualInput: ShiftCloseReportManualInput
    ) {
        interactor.closeShift(manualInput: manualInput)
    }
}
