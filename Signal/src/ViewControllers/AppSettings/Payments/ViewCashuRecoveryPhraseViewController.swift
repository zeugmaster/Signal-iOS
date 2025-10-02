//
// Copyright 2025 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import UIKit
import SignalServiceKit
import SignalUI

class ViewCashuRecoveryPhraseViewController: OWSTableViewController2 {
    
    private let mnemonic: String
    private let bottomStack = UIStackView()
    
    open override var bottomFooter: UIView? {
        get { bottomStack }
        set {}
    }
    
    init(mnemonic: String) {
        self.mnemonic = mnemonic
        super.init()
        self.shouldAvoidKeyboard = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = OWSLocalizedString(
            "SETTINGS_PAYMENTS_VIEW_PASSPHRASE_TITLE",
            comment: "Title for the recovery phrase view"
        )
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: Theme.iconImage(.buttonX),
            style: .plain,
            target: self,
            action: #selector(didTapDismiss)
        )
        
        buildBottomView()
        updateTableContents()
    }
    
    private func buildBottomView() {
        let copyButton = OWSFlatButton.insetButton(
            title: OWSLocalizedString(
                "SETTINGS_PAYMENTS_VIEW_PASSPHRASE_COPY_TO_CLIPBOARD",
                comment: "Button to copy recovery phrase"
            ),
            font: UIFont.dynamicTypeBody.semibold(),
            titleColor: .white,
            backgroundColor: .ows_accentBlue,
            target: self,
            selector: #selector(didTapCopy)
        )
        copyButton.autoSetHeightUsingFont()
        
        bottomStack.axis = .vertical
        bottomStack.alignment = .fill
        bottomStack.isLayoutMarginsRelativeArrangement = true
        bottomStack.layoutMargins = .init(top: 8, left: 20, bottom: 8, right: 20)
        bottomStack.addArrangedSubviews([copyButton])
    }
    
    private func updateTableContents() {
        let contents = OWSTableContents()
        
        let section = OWSTableSection()
        section.customHeaderView = buildHeader()
        section.customFooterView = buildFooter()
        section.hasBackground = false
        section.shouldDisableCellSelection = true
        
        section.add(OWSTableItem(
            customCellBlock: { [weak self] in
                let cell = OWSTableItem.newCell()
                guard let self = self else { return cell }
                let grid = self.buildMnemonicGrid()
                cell.contentView.addSubview(grid)
                grid.autoPinEdgesToSuperviewEdges()
                return cell
            },
            actionBlock: nil
        ))
        
        contents.add(section)
        self.contents = contents
    }
    
    private func buildHeader() -> UIView {
        let label = UILabel()
        label.text = OWSLocalizedString(
            "SETTINGS_PAYMENTS_VIEW_PASSPHRASE_WORDS_EXPLANATION",
            comment: "Instructions for recovery phrase"
        )
        label.font = .dynamicTypeSubheadlineClamped
        label.textColor = Theme.secondaryTextAndIconColor
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        
        let wrapper = UIView()
        wrapper.addSubview(label)
        label.autoPinEdgesToSuperviewMargins(with: UIEdgeInsets(hMargin: 20, vMargin: 16))
        
        return wrapper
    }
    
    private func buildFooter() -> UIView {
        let label = UILabel()
        label.text = OWSLocalizedString(
            "SETTINGS_PAYMENTS_VIEW_PASSPHRASE_WORDS_FOOTER_2",
            comment: "Warning not to share recovery phrase"
        )
        label.font = .dynamicTypeSubheadlineClamped
        label.textColor = Theme.secondaryTextAndIconColor
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        
        let wrapper = UIView()
        wrapper.addSubview(label)
        label.autoPinEdgesToSuperviewMargins(with: UIEdgeInsets(hMargin: 20, vMargin: 16))
        
        return wrapper
    }
    
    private func buildMnemonicGrid() -> UIView {
        let words = mnemonic.split(separator: " ").map(String.init)
        
        let gridContainer = UIView()
        gridContainer.backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray80 : .ows_gray02
        gridContainer.layer.cornerRadius = 12
        
        let gridStack = UIStackView()
        gridStack.axis = .vertical
        gridStack.spacing = 0
        gridStack.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        gridStack.isLayoutMarginsRelativeArrangement = true
        
        // Create rows of words (2 columns)
        var currentRow: UIStackView?
        
        for (index, word) in words.enumerated() {
            if index % 2 == 0 {
                currentRow = UIStackView()
                currentRow?.axis = .horizontal
                currentRow?.distribution = .fillEqually
                currentRow?.spacing = 16
                if let row = currentRow {
                    gridStack.addArrangedSubview(row)
                }
            }
            
            let wordView = buildWordView(index: index + 1, word: word)
            currentRow?.addArrangedSubview(wordView)
        }
        
        gridContainer.addSubview(gridStack)
        gridStack.autoPinEdgesToSuperviewEdges()
        
        return gridContainer
    }
    
    private func buildWordView(index: Int, word: String) -> UIView {
        let numberLabel = UILabel()
        numberLabel.text = "\(index)"
        numberLabel.font = .dynamicTypeCaption1Clamped
        numberLabel.textColor = Theme.secondaryTextAndIconColor
        numberLabel.setCompressionResistanceHorizontalHigh()
        
        let wordLabel = UILabel()
        wordLabel.text = word
        wordLabel.font = .dynamicTypeBodyClamped.monospaced()
        wordLabel.textColor = Theme.primaryTextColor
        
        let stack = UIStackView(arrangedSubviews: [numberLabel, wordLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.isLayoutMarginsRelativeArrangement = true
        
        return stack
    }
    
    // MARK: - Actions
    
    @objc
    private func didTapDismiss() {
        dismiss(animated: true)
    }
    
    @objc
    private func didTapCopy() {
        let alert = ActionSheetController(
            title: OWSLocalizedString(
                "SETTINGS_PAYMENTS_VIEW_PASSPHRASE_COPY_TO_CLIPBOARD_CONFIRM_TITLE",
                comment: "Confirmation for copying recovery phrase"
            ),
            message: OWSLocalizedString(
                "SETTINGS_PAYMENTS_VIEW_PASSPHRASE_COPY_TO_CLIPBOARD_CONFIRM_MESSAGE",
                comment: "Warning when copying recovery phrase"
            )
        )
        
        alert.addAction(ActionSheetAction(
            title: CommonStrings.copyButton,
            style: .default
        ) { [weak self] _ in
            guard let self = self else { return }
            UIPasteboard.general.string = self.mnemonic
            self.presentToast(text: "Copied to clipboard")
        })
        
        alert.addAction(OWSActionSheets.cancelAction)
        
        presentActionSheet(alert)
    }
}

