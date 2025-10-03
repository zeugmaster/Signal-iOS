//
// Copyright 2025 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import SignalServiceKit
public import SignalUI

@objc
public class CVComponentCashuToken: CVComponentBase, CVComponent {

    public var componentKey: CVComponentKey { .cashuToken }

    private let tokenString: String
    private let contactName: String

    init(
        itemModel: CVItemModel,
        tokenString: String,
        contactName: String
    ) {
        self.tokenString = tokenString
        self.contactName = contactName
        super.init(itemModel: itemModel)
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

        let topLabel = componentView.topLabel
        topLabelConfig.applyForRendering(label: topLabel)

        let tokenLabel = componentView.tokenLabel
        tokenLabelConfig.applyForRendering(label: tokenLabel)

        let hStackView = componentView.hStackView
        hStackView.addBlurBackgroundExactlyOnce(isIncoming: isIncoming)

        let cashuIcon = componentView.cashuIcon
        cashuIcon.contentMode = .center
        cashuIcon.setTemplateImageName("arrow-circle-right-32", tintColor: conversationStyle.bubbleTextColor(isIncoming: isIncoming))

        hStackView.configure(
            config: hStackConfig,
            cellMeasurement: cellMeasurement,
            measurementKey: .measurementKey_hStack,
            subviews: [cashuIcon, componentView.tokenLabel, componentView.rightSpace]
        )

        let vStackView = componentView.vStackView

        vStackView.configure(
            config: vStackConfig,
            cellMeasurement: cellMeasurement,
            measurementKey: .measurementKey_vStack,
            subviews: [topLabel, hStackView]
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
            layoutMargins: UIEdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 16)
        )
    }

    private var vStackConfig: CVStackViewConfig {
        CVStackViewConfig(
            axis: .vertical,
            alignment: .leading,
            spacing: 8,
            layoutMargins: UIEdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 0)
        )
    }

    private var tokenLabelConfig: CVLabelConfig {
        let font = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        return CVLabelConfig(
            text: .text(truncatedTokenString()),
            displayConfig: .forUnstyledText(
                font: font,
                textColor: conversationStyle.bubbleTextColor(isIncoming: isIncoming)
            ),
            font: font,
            textColor: conversationStyle.bubbleTextColor(isIncoming: isIncoming),
            numberOfLines: 1,
            lineBreakMode: .byTruncatingMiddle
        )
    }

    private var topLabelConfig: CVLabelConfig {
        let text: String
        let interactionType = itemModel.interaction.interactionType
        switch interactionType {
        case .incomingMessage:
            let format = OWSLocalizedString(
                "CASHU_PAYMENT_STATUS_IN_CHAT_SENT_YOU",
                comment: "Cashu payment status context with contact name, incoming. Embeds {{ Name of sending contact }}"
            )
            text = String(format: format, contactName)
        case .outgoingMessage:
            let format = OWSLocalizedString(
                "CASHU_PAYMENT_STATUS_IN_CHAT_YOU_SENT",
                comment: "Cashu payment status context with contact name, sent. Embeds {{ Name of receiving contact }}"
            )
            text = String(format: format, contactName)
        default:
            text = OWSLocalizedString(
                "CASHU_PAYMENT_STATUS_IN_CHAT_PAYMENT",
                comment: "Cashu payment status context"
            )
        }

        return CVLabelConfig(
            text: .text(text),
            displayConfig: .forUnstyledText(
                font: .dynamicTypeBody,
                textColor: conversationStyle.bubbleTextColor(isIncoming: isIncoming)
            ),
            font: UIFont.dynamicTypeBody,
            textColor: conversationStyle.bubbleTextColor(isIncoming: isIncoming),
            lineBreakMode: .byTruncatingMiddle
        )
    }

    public func measure(
        maxWidth: CGFloat,
        measurementBuilder: CVCellMeasurement.Builder
    ) -> CGSize {
        owsAssertDebug(maxWidth > 0)

        let iconSize = CGSize(square: 24)
        let maxTokenLabelWidth = max(0, maxWidth - hStackConfig.layoutMargins.totalWidth - iconSize.width - hStackConfig.spacing * 2 - 10)

        let tokenLabelSize = CVText.measureLabel(
            config: tokenLabelConfig,
            maxWidth: maxTokenLabelWidth
        )

        var hSubviewInfos = [ManualStackSubviewInfo]()
        hSubviewInfos.append(iconSize.asManualSubviewInfo())
        hSubviewInfos.append(tokenLabelSize.asManualSubviewInfo())
        hSubviewInfos.append(iconSize.asManualSubviewInfo()) // right spacer

        let hStackMeasurement = ManualStackView.measure(
            config: hStackConfig,
            measurementBuilder: measurementBuilder,
            measurementKey: .measurementKey_hStack,
            subviewInfos: hSubviewInfos,
            maxWidth: maxWidth
        )

        let maxTopLabelWidth = max(0, maxWidth - vStackConfig.layoutMargins.totalWidth)
        let topLabelSize = CVText.measureLabel(config: topLabelConfig, maxWidth: maxTopLabelWidth)

        var vSubviewInfos = [ManualStackSubviewInfo]()
        vSubviewInfos.append(topLabelSize.asManualSubviewInfo())
        vSubviewInfos.append(hStackMeasurement.measuredSize.asManualSubviewInfo)

        let vStackMeasurement = ManualStackView.measure(
            config: vStackConfig,
            measurementBuilder: measurementBuilder,
            measurementKey: .measurementKey_vStack,
            subviewInfos: vSubviewInfos
        )

        return vStackMeasurement.measuredSize
    }

    // MARK: - CVComponentView

    public class CVComponentViewCashuToken: NSObject, CVComponentView {

        fileprivate let hStackView = ManualStackView(name: "CashuToken.hStackView")
        fileprivate let vStackView = ManualStackView(name: "CashuToken.vStackView")

        fileprivate let cashuIcon = UIImageView()
        fileprivate var rightSpace = UIView()

        fileprivate let tokenLabel = CVLabel()
        fileprivate let topLabel = CVLabel()

        public var isDedicatedCellView = true

        public var rootView: UIView {
            vStackView
        }

        public func setIsCellVisible(_ isCellVisible: Bool) {}

        public func reset() {
            hStackView.reset()
            vStackView.reset()

            tokenLabel.text = nil
            topLabel.text = nil

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
    static let measurementKey_vStack = "CVComponentCashuToken.measurementKey_vStack"
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

