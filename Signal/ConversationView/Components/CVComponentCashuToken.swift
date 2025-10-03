//
// Copyright 2025 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import SignalServiceKit
public import SignalUI
import CashuDevKit

@objc
public class CVComponentCashuToken: CVComponentBase, CVComponent {

    public var componentKey: CVComponentKey { .cashuToken }

    private let tokenString: String
    private let contactName: String
    private let tokenAmount: UInt64?

    init(
        itemModel: CVItemModel,
        tokenString: String,
        contactName: String
    ) {
        self.tokenString = tokenString
        self.contactName = contactName
        
        // Try to decode the token to get the amount
        self.tokenAmount = Self.decodeTokenAmount(tokenString)
        
        super.init(itemModel: itemModel)
    }
    
    private static func decodeTokenAmount(_ tokenString: String) -> UInt64? {
        do {
            let token = try Token.fromString(encodedToken: tokenString)
            let proofs = try token.proofsSimple()
            let totalAmount = proofs.map { $0.amount().value }.reduce(0, +)
            return totalAmount
        } catch {
            Logger.warn("Failed to decode cashu token amount: \(error)")
            return nil
        }
    }

    public override var debugDescription: String {
        return "CVComponentCashuToken(token: \(truncatedTokenString()))"
    }

    public func buildComponentView(componentDelegate: CVComponentDelegate) -> CVComponentView {
        CVComponentViewCashuToken()
    }

    public func configureForRendering(
        componentView componentViewParam: CVComponentView,
        cellMeasurement: CVCellMeasurement,
        componentDelegate: CVComponentDelegate
    ) {
        guard let componentView = componentViewParam as? CVComponentViewCashuToken else {
            owsFailDebug("Unexpected componentView.")
            componentViewParam.reset()
            return
        }

        let amountLabel = componentView.amountLabel
        amountLabelConfig.applyForRendering(label: amountLabel)

        let hStackView = componentView.hStackView
        hStackView.addBlurBackgroundExactlyOnce(isIncoming: isIncoming)

        let cashuIcon = componentView.cashuIcon
        cashuIcon.contentMode = .center
        cashuIcon.setTemplateImageName("payment-28", tintColor: conversationStyle.bubbleTextColor(isIncoming: isIncoming))

        hStackView.configure(
            config: hStackConfig,
            cellMeasurement: cellMeasurement,
            measurementKey: .measurementKey_hStack,
            subviews: [cashuIcon, componentView.amountLabel, componentView.rightSpace]
        )
    }

    private func truncatedTokenString() -> String {
        if tokenString.count > 20 {
            let prefix = tokenString.prefix(15)
            return "\(prefix)..."
        }
        return tokenString
    }

    private var hStackConfig: CVStackViewConfig {
        CVStackViewConfig(
            axis: .horizontal,
            alignment: .center,
            spacing: 12,
            layoutMargins: UIEdgeInsets(top: 25, leading: 12, bottom: 25, trailing: 16)
        )
    }

    private func formatAmount() -> NSAttributedString {
        guard let amount = tokenAmount else {
            let text = OWSLocalizedString(
                "CASHU_TOKEN_INVALID",
                comment: "Status indicator for invalid cashu tokens."
            )
            return NSAttributedString(string: text)
        }
        
        // Format like payment: large amount + " sats" in thinner font
        let firstAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.dynamicTypeLargeTitle1Clamped.withSize(32)]
        
        let startingFont = UIFont.dynamicTypeLargeTitle1Clamped.withSize(32)
        let traits = [UIFontDescriptor.TraitKey.weight: UIFont.Weight.thin]
        let thinFontDescriptor = startingFont.fontDescriptor.addingAttributes(
            [UIFontDescriptor.AttributeName.traits: traits]
        )
        
        let newThinFont = UIFont(descriptor: thinFontDescriptor, size: startingFont.pointSize)
        let secondAttributes: [NSAttributedString.Key: Any] = [.font: newThinFont]
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.groupingSeparator = ","
        let formattedAmount = numberFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        
        let firstString = NSMutableAttributedString(string: formattedAmount, attributes: firstAttributes)
        let secondString = NSMutableAttributedString(string: " sats", attributes: secondAttributes)
        
        firstString.append(secondString)
        return firstString
    }

    private var amountLabelConfig: CVLabelConfig {
        let font = UIFont.dynamicTypeLargeTitle1Clamped.withSize(28)
        return CVLabelConfig(
            text: .attributedText(formatAmount()),
            displayConfig: .forUnstyledText(
                font: font,
                textColor: conversationStyle.bubbleTextColor(isIncoming: isIncoming)
            ),
            font: font,
            textColor: conversationStyle.bubbleTextColor(isIncoming: isIncoming),
            numberOfLines: 1,
            lineBreakMode: .byWordWrapping,
            textAlignment: .center
        )
    }

    public func measure(
        maxWidth: CGFloat,
        measurementBuilder: CVCellMeasurement.Builder
    ) -> CGSize {
        owsAssertDebug(maxWidth > 0)

        let iconSize = CGSize(square: 28)
        let maxAmountLabelWidth = max(0, maxWidth - hStackConfig.layoutMargins.totalWidth - iconSize.width - hStackConfig.spacing * 2 - 10)

        let amountLabelSize = CVText.measureLabel(
            config: amountLabelConfig,
            maxWidth: maxAmountLabelWidth
        )

        var hSubviewInfos = [ManualStackSubviewInfo]()
        hSubviewInfos.append(iconSize.asManualSubviewInfo())
        hSubviewInfos.append(amountLabelSize.asManualSubviewInfo())
        hSubviewInfos.append(iconSize.asManualSubviewInfo()) // right spacer

        let hStackMeasurement = ManualStackView.measure(
            config: hStackConfig,
            measurementBuilder: measurementBuilder,
            measurementKey: .measurementKey_hStack,
            subviewInfos: hSubviewInfos,
            maxWidth: maxWidth
        )

        return hStackMeasurement.measuredSize
    }

    // MARK: - CVComponentView

    public class CVComponentViewCashuToken: NSObject, CVComponentView {

        fileprivate let hStackView = ManualStackView(name: "CashuToken.hStackView")

        fileprivate let cashuIcon = UIImageView()
        fileprivate var rightSpace = UIView()

        fileprivate let amountLabel = CVLabel()

        public var isDedicatedCellView = true

        public var rootView: UIView {
            hStackView
        }

        public func setIsCellVisible(_ isCellVisible: Bool) {}

        public func reset() {
            hStackView.reset()

            amountLabel.text = nil

            rightSpace.removeAllSubviews()
        }
    }

    public override func handleTap(
        sender: UIGestureRecognizer,
        componentDelegate: CVComponentDelegate,
        componentView: CVComponentView,
        renderItem: CVRenderItem
    ) -> Bool {
        componentDelegate.didTapCashuToken(tokenString: tokenString)
        return true
    }
}

// MARK: - Constants

fileprivate extension String {
    static let measurementKey_hStack = "CVComponentCashuToken.measurementKey_hStack"
}

extension CVComponentCashuToken: CVAccessibilityComponent {
    public var accessibilityDescription: String {
        return OWSLocalizedString(
            "CASHU_TOKEN_ACCESSIBILITY_LABEL",
            comment: "Accessibility label for cashu token in conversation"
        )
    }
}

fileprivate extension ManualStackView {
    func addBlurBackgroundExactlyOnce(isIncoming: Bool) {
        var subviewsToCheck = self.subviews
        while let subviewToCheck = subviewsToCheck.popLast() {
            if subviewToCheck is UIVisualEffectView {
                // already exists
                return
            }
            subviewsToCheck = subviewToCheck.subviews + subviewsToCheck
        }

        let effect: UIBlurEffect.Style = {
            (Theme.isDarkThemeEnabled && isIncoming) ? .regular : .extraLight
        }()

        let blurBackground = self.addBlur(style: effect)
        blurBackground.alpha = {
            switch (Theme.isDarkThemeEnabled, isIncoming) {
            case (_, false):
                return 0.4
            case (true, true):
                return 1
            case (false, true):
                return 1
            }
        }()
    }
}

fileprivate extension UIView {
    @discardableResult
    func addBlur(style: UIBlurEffect.Style = .extraLight) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: style)
        let blurBackground = UIVisualEffectView(effect: blurEffect)
        blurBackground.alpha = 0.3
        blurBackground.layer.cornerRadius = 18
        blurBackground.clipsToBounds = true
        blurBackground.frame = self.frame
        blurBackground.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurBackground)
        return blurBackground
    }
}

