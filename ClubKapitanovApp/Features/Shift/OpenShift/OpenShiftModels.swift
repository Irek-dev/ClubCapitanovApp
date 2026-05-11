import Foundation

/// Namespace моделей экрана открытия смены.
///
/// Экран получает выбранную точку и пользователя, а Presenter готовит короткую
/// ViewModel с текстами подтверждения открытия смены.
enum OpenShift {
    enum Load {
        struct Response {
            let point: Point
            let user: User
        }

        struct ViewModel {
            let title: String
            let pointText: String
            let employeeText: String
            let buttonTitle: String
        }
    }

    enum CatalogLoad {
        struct Response {
            let isLoading: Bool
        }

        struct ErrorResponse {
            let error: Error
        }
    }
}
