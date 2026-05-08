import Foundation

/// Presenter экрана выбора точки.
///
/// Превращает список domain-точек в строки для таблицы: название точки и человекочитаемый
/// адрес. ViewController не знает, как форматировать `Point`.
protocol PointSelectionPresentationLogic {
    func present(response: PointSelection.Load.Response)
}

final class PointSelectionPresenter: PointSelectionPresentationLogic {
    weak var viewController: PointSelectionDisplayLogic?

    func present(response: PointSelection.Load.Response) {
        // Форматирование адреса остается здесь, чтобы таблица получала уже готовый
        // текст и занималась только отображением ячеек.
        let points = response.points.map { point in
            PointSelection.PointViewModel(
                title: point.name,
                subtitle: [point.city, point.address]
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
            )
        }

        viewController?.display(
            viewModel: .init(
                title: "Выберите рабочую точку",
                subtitle: "Сотрудник: \(response.user.fullName)",
                emptyText: "Для этого пользователя нет доступных активных точек.",
                points: points
            )
        )
    }
}
