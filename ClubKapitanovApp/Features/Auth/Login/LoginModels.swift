import Foundation

/// Namespace моделей Login-модуля.
///
/// В VIP-подходе экран не передает друг другу сырые параметры напрямую: View создает
/// Request, Interactor возвращает Response, Presenter превращает его в ViewModel.
enum Login {
    enum Submit {
        struct Request {
            let pinCode: String
        }

        struct Response {
            let user: User?
        }

        struct ViewModel {
            let errorMessage: String?
            let clearPINField: Bool
        }
    }

    enum AdminSubmit {
        struct Request {
            let pinCode: String
            let password: String
        }
    }
}
