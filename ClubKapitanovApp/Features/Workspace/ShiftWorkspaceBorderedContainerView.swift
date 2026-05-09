import UIKit

final class ShiftWorkspaceBorderedContainerView: UIView {
    private let cornerRadius: CGFloat
    private let fillColor: UIColor

    init(cornerRadius: CGFloat, fillColor: UIColor = BrandColor.surfaceMuted) {
        self.cornerRadius = cornerRadius
        self.fillColor = fillColor
        super.init(frame: .zero)
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyStyle()
    }

    private func applyStyle() {
        ShiftWorkspaceLayerStyling.applyBorderedSurface(
            to: self,
            compatibleWith: traitCollection,
            cornerRadius: cornerRadius,
            fillColor: fillColor
        )
    }
}
