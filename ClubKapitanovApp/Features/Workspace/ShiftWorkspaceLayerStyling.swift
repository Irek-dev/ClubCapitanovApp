import UIKit

enum ShiftWorkspaceLayerStyling {
    static func applyBorderedSurface(
        to view: UIView,
        compatibleWith traitCollection: UITraitCollection,
        cornerRadius: CGFloat,
        fillColor: UIColor
    ) {
        view.backgroundColor = fillColor
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = BrandColor.cgColor(BrandColor.fieldBorder, compatibleWith: traitCollection)
    }

    static func applySoftShadow(
        to view: UIView,
        compatibleWith traitCollection: UITraitCollection,
        opacity: Float,
        radius: CGFloat,
        offset: CGSize
    ) {
        view.layer.shadowColor = BrandColor.cgColor(BrandColor.shadow, compatibleWith: traitCollection)
        view.layer.shadowOpacity = opacity
        view.layer.shadowRadius = radius
        view.layer.shadowOffset = offset
    }

    static func updateShadowPath(for view: UIView) {
        guard view.bounds != .zero else { return }
        view.layer.shadowPath = UIBezierPath(
            roundedRect: view.bounds,
            cornerRadius: view.layer.cornerRadius
        ).cgPath
    }
}
