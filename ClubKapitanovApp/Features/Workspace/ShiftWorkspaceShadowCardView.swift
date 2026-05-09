import UIKit

final class ShiftWorkspaceShadowCardView: UIView {
    private let cornerRadius: CGFloat
    private let shadowOpacity: Float
    private let shadowRadius: CGFloat
    private let shadowOffset: CGSize

    init(
        cornerRadius: CGFloat = 22,
        shadowOpacity: Float = 0.10,
        shadowRadius: CGFloat = 18,
        shadowOffset: CGSize = CGSize(width: 0, height: 10)
    ) {
        self.cornerRadius = cornerRadius
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
        super.init(frame: .zero)
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ShiftWorkspaceLayerStyling.updateShadowPath(for: self)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyStyle()
    }

    private func applyStyle() {
        backgroundColor = BrandColor.surface
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        ShiftWorkspaceLayerStyling.applySoftShadow(
            to: self,
            compatibleWith: traitCollection,
            opacity: shadowOpacity,
            radius: shadowRadius,
            offset: shadowOffset
        )
    }
}
