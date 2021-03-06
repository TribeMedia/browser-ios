/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Shared

struct ThumbnailCellUX {
    /// Ratio of width:height of the thumbnail image.
    static let ImageAspectRatio: Float = 1.0
    static let BorderColor = UIColor.blackColor().colorWithAlphaComponent(0.1)
    static let BorderWidth: CGFloat = 1
    static let LabelColor = UIAccessibilityDarkerSystemColorsEnabled() ? UIColor.blackColor() : UIColor(rgb: 0x353535)
    static let LabelBackgroundColor = UIColor(white: 1.0, alpha: 0.5)
    static let LabelAlignment: NSTextAlignment = .Center
    static let SelectedOverlayColor = UIColor(white: 0.0, alpha: 0.25)
//    static let InsetSize: CGFloat = 20
//    static let InsetSizeCompact: CGFloat = 6
#if BRAVE
    static let InsetSize: CGFloat = 10
    static let InsetSizeCompact: CGFloat = 3
#endif
    static func insetsForCollectionViewSize(size: CGSize, traitCollection: UITraitCollection) -> UIEdgeInsets {
        let largeInsets = UIEdgeInsets(
                top: ThumbnailCellUX.InsetSize,
                left: ThumbnailCellUX.InsetSize,
                bottom: ThumbnailCellUX.InsetSize,
                right: ThumbnailCellUX.InsetSize
            )
        let smallInsets = UIEdgeInsets(
                top: ThumbnailCellUX.InsetSizeCompact,
                left: ThumbnailCellUX.InsetSizeCompact,
                bottom: ThumbnailCellUX.InsetSizeCompact,
                right: ThumbnailCellUX.InsetSizeCompact
            )

        if traitCollection.horizontalSizeClass == .Compact {
            return smallInsets
        } else {
            return largeInsets
        }
    }
#if BRAVE
    static let ImagePaddingWide: CGFloat = 4
    static let ImagePaddingCompact: CGFloat = 2
#endif
    static func imageInsetsForCollectionViewSize(size: CGSize, traitCollection: UITraitCollection) -> UIEdgeInsets {
        let largeInsets = UIEdgeInsets(
                top: ThumbnailCellUX.ImagePaddingWide,
                left: ThumbnailCellUX.ImagePaddingWide,
                bottom: ThumbnailCellUX.ImagePaddingWide,
                right: ThumbnailCellUX.ImagePaddingWide
            )

        let smallInsets = UIEdgeInsets(
                top: ThumbnailCellUX.ImagePaddingCompact,
                left: ThumbnailCellUX.ImagePaddingCompact,
                bottom: ThumbnailCellUX.ImagePaddingCompact,
                right: ThumbnailCellUX.ImagePaddingCompact
            )
        if traitCollection.horizontalSizeClass == .Compact {
            return smallInsets
        } else {
            return largeInsets // reminder: iphone landscape uses this
        }
    }

    static let LabelInsets = UIEdgeInsetsMake(7, 3, 7, 3)
    static let PlaceholderImage = UIImage(named: "defaultTopSiteIcon")
    static let CornerRadius: CGFloat = 3

    // Make the remove button look 20x20 in size but have the clickable area be 44x44
    static let RemoveButtonSize: CGFloat = 44
    static let RemoveButtonInsets = UIEdgeInsets(top: 11, left: 0, bottom: 11, right: 22)
    static let RemoveButtonAnimationDuration: NSTimeInterval = 0.4
    static let RemoveButtonAnimationDamping: CGFloat = 0.6

    static let NearestNeighbordScalingThreshold: CGFloat = 24
}

@objc protocol ThumbnailCellDelegate {
    func didRemoveThumbnail(thumbnailCell: ThumbnailCell)
    func didLongPressThumbnail(thumbnailCell: ThumbnailCell)
}

class ThumbnailCell: UICollectionViewCell {
    weak var delegate: ThumbnailCellDelegate?

    var imageInsets: UIEdgeInsets = UIEdgeInsetsZero
    var cellInsets: UIEdgeInsets = UIEdgeInsetsZero

    var imagePadding: CGFloat = 0 {
        didSet {
            // Find out if our image is going to have fractional pixel width.
            // If so, we inset by a tiny extra amount to get it down to an integer for better
            // image scaling.
            let parentWidth = self.imageWrapper.frame.width
            let width = (parentWidth - imagePadding)
            let fractionalW = width - floor(width)
            let additionalW = fractionalW / 2

            imageView.snp_remakeConstraints { make in
                let insets = UIEdgeInsets(top: imagePadding, left: imagePadding, bottom: imagePadding, right: imagePadding)
                make.top.equalTo(self.imageWrapper).inset(insets.top)
                make.bottom.equalTo(textWrapper.snp_top).offset(-imagePadding)
                make.left.equalTo(self.imageWrapper).inset(insets.left + additionalW)
                make.right.equalTo(self.imageWrapper).inset(insets.right + additionalW)
            }
            imageView.setNeedsUpdateConstraints()
        }
    }

    static func imageWithSize(image: UIImage, size:CGSize, maxScale: CGFloat) -> UIImage {
        var scaledImageRect = CGRect.zero;
        var aspectWidth:CGFloat = size.width / image.size.width;
        var aspectHeight:CGFloat = size.height / image.size.height;
        if aspectWidth > maxScale || aspectHeight > maxScale {
            let m = max(maxScale / aspectWidth, maxScale / aspectHeight)
            aspectWidth *= m
            aspectHeight *= m
        }
        let aspectRatio:CGFloat = min(aspectWidth, aspectHeight);
        scaledImageRect.size.width = image.size.width * aspectRatio;
        scaledImageRect.size.height = image.size.height * aspectRatio;
        scaledImageRect.origin.x = (size.width - scaledImageRect.size.width) / 2.0;
        scaledImageRect.origin.y = (size.height - scaledImageRect.size.height) / 2.0;
        UIGraphicsBeginImageContextWithOptions(size, false, 0);
        image.drawInRect(scaledImageRect);
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return scaledImage;
    }

    var image: UIImage? = nil {
        didSet {
            struct ContainerSize {
                static var size: CGSize = CGSizeZero
                static func scaledDown() -> CGSize {
                    return CGSizeMake(size.width * 0.75, size.height * 0.75)
                }
            }

            if imageView.frame.size.width > 0 {
                ContainerSize.size = imageView.frame.size
            }

            if var image = image {
                if image.size.width < 24 && ContainerSize.size != CGSizeZero {
                    var maxScale = CGFloat(4.0)
                    if ContainerSize.size.width > 170 {
                        // we are on iPad pro. Fragile, but no other way to detect this on simulator.
                        maxScale *= 2.0
                    }

                    image = ThumbnailCell.imageWithSize(image, size: ContainerSize.scaledDown(), maxScale: maxScale)
                    imageView.contentMode = .Center
                } else {
                    imageView.contentMode = UIViewContentMode.ScaleAspectFit
                }
                imageView.image = image

            } else {
                imageView.image = ThumbnailCellUX.PlaceholderImage
                imageView.contentMode = UIViewContentMode.Center
            }
        }
    }

    lazy var longPressGesture: UILongPressGestureRecognizer = {
        return UILongPressGestureRecognizer(target: self, action: #selector(ThumbnailCell.SELdidLongPress))
    }()

    lazy var textWrapper: UIView = {
        let wrapper = UIView()
        wrapper.backgroundColor = ThumbnailCellUX.LabelBackgroundColor
#if BRAVE
        wrapper.backgroundColor = UIColor.clearColor()
#endif
        return wrapper
    }()

    lazy var textLabel: UILabel = {
        let textLabel = UILabel()
        textLabel.setContentHuggingPriority(1000, forAxis: UILayoutConstraintAxis.Vertical)
        textLabel.font = DynamicFontHelper.defaultHelper.DefaultSmallFont
        textLabel.textColor = ThumbnailCellUX.LabelColor
        textLabel.textAlignment = ThumbnailCellUX.LabelAlignment
        return textLabel
    }()

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = UIViewContentMode.ScaleAspectFit

        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = ThumbnailCellUX.CornerRadius
        return imageView
    }()


    lazy var imageWrapper: UIView = {
        let imageWrapper = UIView()
    #if !BRAVE
        imageWrapper.layer.borderColor = ThumbnailCellUX.BorderColor.CGColor
        imageWrapper.layer.borderWidth = ThumbnailCellUX.BorderWidth
        imageWrapper.layer.cornerRadius = ThumbnailCellUX.CornerRadius
        imageWrapper.clipsToBounds = true
    #endif
        return imageWrapper
    }()

    lazy var removeButton: UIButton = {
        let removeButton = UIButton()
        removeButton.exclusiveTouch = true
        let removeButtonImage = UIImage(named: "TileCloseButton")
        removeButton.setImage(removeButtonImage, forState: UIControlState.Normal)
        removeButton.addTarget(self, action: #selector(ThumbnailCell.SELdidRemove), forControlEvents: UIControlEvents.TouchUpInside)
        removeButton.accessibilityLabel = NSLocalizedString("Remove page", comment: "Button shown in editing mode to remove this site from the top sites panel.")
        removeButton.hidden = true
        removeButton.sizeToFit()
        let buttonCenterX = floor(removeButton.bounds.width/2)
        let buttonCenterY = floor(removeButton.bounds.height/2)
        removeButton.center = CGPoint(x: buttonCenterX, y: buttonCenterY)
        return removeButton    }()

    lazy var backgroundImage: UIImageView = {
        let backgroundImage = UIImageView()
        backgroundImage.contentMode = UIViewContentMode.ScaleAspectFill
        return backgroundImage
    }()

    lazy var selectedOverlay: UIView = {
        let selectedOverlay = UIView()
        selectedOverlay.backgroundColor = ThumbnailCellUX.SelectedOverlayColor
        selectedOverlay.hidden = true
        return selectedOverlay
    }()

    override var selected: Bool {
        didSet {
            self.selectedOverlay.hidden = !selected
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.mainScreen().scale

        isAccessibilityElement = true
        addGestureRecognizer(longPressGesture)

        contentView.addSubview(imageWrapper)
//#if !BRAVE
        imageWrapper.addSubview(backgroundImage)
        backgroundImage.snp_remakeConstraints { make in
            make.top.bottom.left.right.equalTo(self.imageWrapper)
        }
//#endif
        imageWrapper.addSubview(imageView)
        imageWrapper.addSubview(textWrapper)
        imageWrapper.addSubview(selectedOverlay)
        textWrapper.addSubview(textLabel)
        contentView.addSubview(removeButton)

        textWrapper.snp_makeConstraints { make in
            make.bottom.equalTo(self.imageWrapper.snp_bottom) // .offset(ThumbnailCellUX.BorderWidth)
            make.left.right.equalTo(self.imageWrapper) // .offset(ThumbnailCellUX.BorderWidth)
        }

        selectedOverlay.snp_makeConstraints { make in
            make.edges.equalTo(self.imageWrapper)
        }

        textLabel.snp_remakeConstraints { make in
            make.edges.equalTo(self.textWrapper).inset(ThumbnailCellUX.LabelInsets) // TODO swift-2.0 I changes insets to inset - how can that be right?
        }

        // Prevents the textLabel from getting squished in relation to other view priorities.
        textLabel.setContentCompressionResistancePriority(1000, forAxis: UILayoutConstraintAxis.Vertical)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        backgroundImage.image = nil
        removeButton.hidden = true
        imageWrapper.backgroundColor = UIColor.clearColor()
        textLabel.font = DynamicFontHelper.defaultHelper.DefaultSmallFont
    }

    func SELdidRemove() {
        delegate?.didRemoveThumbnail(self)
    }


    func SELdidLongPress() {
        delegate?.didLongPressThumbnail(self)
    }

    func toggleRemoveButton(show: Bool) {
        // Only toggle if we change state
        if removeButton.hidden != show {
            return
        }

        if show {
            removeButton.hidden = false
        }

        let scaleTransform = CGAffineTransformMakeScale(0.01, 0.01)
        removeButton.transform = show ? scaleTransform : CGAffineTransformIdentity
        UIView.animateWithDuration(ThumbnailCellUX.RemoveButtonAnimationDuration,
            delay: 0,
            usingSpringWithDamping: ThumbnailCellUX.RemoveButtonAnimationDamping,
            initialSpringVelocity: 0,
            options: [UIViewAnimationOptions.AllowUserInteraction, UIViewAnimationOptions.CurveEaseInOut],
            animations: {
                self.removeButton.transform = show ? CGAffineTransformIdentity : scaleTransform
            }, completion: { _ in
                if !show {
                    self.removeButton.hidden = true
                }
            })
    }

    /**
     Updates the insets and padding of the cell based on the size of the container collection view

     - parameter size: Size of the container collection view
     */
    func updateLayoutForCollectionViewSize(size: CGSize, traitCollection: UITraitCollection, forSuggestedSite: Bool) {
        let cellInsets = ThumbnailCellUX.insetsForCollectionViewSize(size,
            traitCollection: traitCollection)
        let imageInsets = ThumbnailCellUX.imageInsetsForCollectionViewSize(size,
            traitCollection: traitCollection)

        if cellInsets != self.cellInsets {
            self.cellInsets = cellInsets
            imageWrapper.snp_remakeConstraints { make in
                make.edges.equalTo(self.contentView).inset(cellInsets)
            }
        }

        if forSuggestedSite {
            self.imagePadding = 0.0
            return
        }

        if imageInsets != self.imageInsets {
            imageView.snp_remakeConstraints { make in
                make.top.equalTo(self.imageWrapper).inset(imageInsets.top)
                make.left.right.equalTo(self.imageWrapper).inset(imageInsets.left)
                make.right.equalTo(self.imageWrapper).inset(imageInsets.right)
                make.bottom.equalTo(textWrapper.snp_top).offset(-imageInsets.top)
            }
        }
    }
}
