import Foundation

/// Namespace моделей экрана выбора точки.
///
/// Экран показывает только ViewModel, а domain-сущности `Point` остаются в Interactor.
/// Это сохраняет направление зависимостей VIP: UI не решает правила доступа к точкам.
enum PointSelection {
    struct PointViewModel {
        let title: String
        let subtitle: String
    }

    enum Load {
        enum State {
            case loading
            case loaded
            case failed
        }

        struct Response {
            let user: User
            let points: [Point]
            let state: State
        }

        struct ViewModel {
            let title: String
            let subtitle: String
            let emptyText: String
            let showsRetry: Bool
            let points: [PointViewModel]
        }
    }
}
