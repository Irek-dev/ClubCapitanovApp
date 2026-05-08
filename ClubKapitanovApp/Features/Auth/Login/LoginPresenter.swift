import Foundation

/// Presentation layer Login-модуля.
///
/// Presenter не делает бизнес-решений. Его задача — превратить результат Interactor
/// в текст ошибки и флаги для UI: показывать сообщение или очистить PIN-поле.
protocol LoginPresentationLogic {
    func present(response: Login.Submit.Response, errorMessage: String?)
}

final class LoginPresenter: LoginPresentationLogic {
    // MARK: - Properties

    weak var viewController: LoginDisplayLogic?

    // MARK: - LoginPresentationLogic

    func present(response: Login.Submit.Response, errorMessage: String?) {
        // Если user nil, значит вход не успешен и PIN нужно очистить. ViewController
        // получает уже готовую ViewModel и не знает причин ошибки.
        let viewModel = Login.Submit.ViewModel(
            errorMessage: errorMessage,
            clearPINField: response.user == nil
        )
        viewController?.display(viewModel: viewModel)
    }
}
