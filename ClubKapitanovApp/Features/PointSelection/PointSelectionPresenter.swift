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

        let emptyText: String
        let showsRetry: Bool
        switch response.state {
        case .loading:
            emptyText = "Загрузка точек..."
            showsRetry = false
        case .loaded:
            emptyText = "Для этого пользователя нет доступных активных точек."
            showsRetry = false
        case .failed:
            emptyText = "Не удалось загрузить точки. Проверьте интернет и попробуйте снова."
            showsRetry = true
        }

        viewController?.display(
            viewModel: .init(
                title: "Выберите рабочую точку",
                subtitle: "Сотрудник: \(response.user.fullName)",
                emptyText: emptyText,
                showsRetry: showsRetry,
                points: points
            )
        )
    }
}
