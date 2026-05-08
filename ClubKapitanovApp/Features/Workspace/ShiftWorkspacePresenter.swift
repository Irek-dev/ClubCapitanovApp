import Foundation

/// Presentation layer workspace.
///
/// Presenter отвечает за верхнеуровневую сборку ViewModel и делегирует детализацию
/// центральных секций отдельной фабрике, чтобы сам слой presentation не превращался
/// в большой файл с расчетами, форматированием и fallback-правилами.
protocol ShiftWorkspacePresentationLogic {
    func present(response: ShiftWorkspace.Load.Response)
    func present(feedback: ShiftWorkspace.ActionFeedback.Response)
}

final class ShiftWorkspacePresenter: ShiftWorkspacePresentationLogic {
    weak var viewController: ShiftWorkspaceDisplayLogic?

    private let contentFactory: ShiftWorkspaceContentFactory

    init(contentFactory: ShiftWorkspaceContentFactory) {
        self.contentFactory = contentFactory
    }

    func present(response: ShiftWorkspace.Load.Response) {
        let state = response.state
        let viewModel = ShiftWorkspace.ViewModel(
            screenTitle: state.selectedSection.title,
            appTitle: "Клуб Капитанов",
            pointName: state.shift.point.name,
            openedAtText: "Смена открыта: \(AppDateFormatter.dateTime(state.shift.openedAt))",
            participants: state.shift.participants.filter { $0.leftAt == nil }.map {
                .init(
                    id: $0.id,
                    name: $0.displayNameSnapshot,
                    joinedAtText: "с \(AppDateFormatter.time($0.joinedAt))"
                )
            },
            addParticipantButtonTitle: "Добавить сотрудника",
            sections: ShiftWorkspaceSection.allCases.map {
                .init(section: $0, isSelected: $0 == state.selectedSection)
            },
            content: contentFactory.makeContentViewModel(from: state),
            closeShiftModal: contentFactory.makeCloseShiftModalViewModel(from: state)
        )
        viewController?.display(viewModel: viewModel)
    }

    func present(feedback: ShiftWorkspace.ActionFeedback.Response) {
        viewController?.display(
            feedback: .init(
                title: feedback.title,
                message: feedback.message
            )
        )
    }
}
