import UIKit

struct KeyboardTransition {
    let overlapHeight: CGFloat
    let animationDuration: TimeInterval
    let animationOptions: UIView.AnimationOptions

    init(notification: Notification, in view: UIView) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
            overlapHeight = max(0, view.bounds.maxY - keyboardFrameInView.minY)
        } else {
            overlapHeight = 0
        }

        animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        let rawCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        animationOptions = UIView.AnimationOptions(rawValue: rawCurve << 16)
    }

    func animate(_ animations: @escaping () -> Void) {
        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            options: animationOptions,
            animations: animations
        )
    }
}
