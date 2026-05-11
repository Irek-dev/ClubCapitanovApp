import Foundation

/// Presenter экрана открытия смены.
///
/// Он форматирует выбранную точку и сотрудника в готовые строки для карточки.
/// Само создание смены остается в Interactor.
protocol OpenShiftPresentationLogic {
    func present(response: OpenShift.Load.Response)
    func present(response: OpenShift.CatalogLoad.Response)
    func present(response: OpenShift.CatalogLoad.ErrorResponse)
}

final class OpenShiftPresenter: OpenShiftPresentationLogic {
    weak var viewController: OpenShiftDisplayLogic?

    func present(response: OpenShift.Load.Response) {
        viewController?.display(
            viewModel: .init(
                title: "Открыть смену?",
                pointText: "\(response.point.city), \(response.point.name)",
                employeeText: "Сотрудник: \(response.user.fullName)",
                buttonTitle: "Открыть смену"
            )
        )
    }

    func present(response: OpenShift.CatalogLoad.Response) {
        viewController?.displayLoading(isLoading: response.isLoading)
    }

    func present(response: OpenShift.CatalogLoad.ErrorResponse) {
        viewController?.displayError(message: "Не удалось загрузить каталоги. Проверьте интернет и попробуйте снова.")
    }
}
