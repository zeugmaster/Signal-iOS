//
// Copyright 2025 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import UIKit
import Lottie
import SignalServiceKit
import SignalUI

class CashuWalletViewController: OWSTableViewController2 {
    
    private let mode: PaymentsSettingsMode
    
    private var balance: UInt64 = 0
    private var mintUrl: String {
        CashuIntegration.shared.getMintUrl()
    }
    
    // MARK: - Initialization
    
    init(mode: PaymentsSettingsMode) {
        self.mode = mode
        super.init()
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = OWSLocalizedString(
            "SETTINGS_PAYMENTS_TITLE",
            comment: "Title for the payments view"
        )
        
        if mode == .standalone {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(didTapDismiss)
            )
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: Theme.iconImage(.buttonMore),
            style: .plain,
            target: self,
            action: #selector(didTapSettings)
        )
        
        loadWalletBalance()
        updateTableContents()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadWalletBalance()
        updateTableContents()
    }
    
    // MARK: - Table Contents
    
    private func updateTableContents() {
        let contents = OWSTableContents()
        
        // Header with balance and action buttons
        let headerSection = OWSTableSection()
        headerSection.hasBackground = false
        headerSection.shouldDisableCellSelection = true
        headerSection.add(OWSTableItem(
            customCellBlock: { [weak self] in
                let cell = OWSTableItem.newCell()
                self?.configureHeaderCell(cell: cell)
                return cell
            },
            actionBlock: nil
        ))
        contents.add(headerSection)
        
        // Recovery phrase help card
        contents.add(buildRecoveryPhraseCard())
        
        self.contents = contents
    }
    
    private func buildRecoveryPhraseCard() -> OWSTableSection {
        let section = OWSTableSection()
        
        section.add(OWSTableItem(
            customCellBlock: {
                let titleLabel = UILabel()
                titleLabel.text = OWSLocalizedString(
                    "CASHU_RECOVERY_PHRASE_CARD_TITLE",
                    value: "Back up your recovery phrase",
                    comment: "Title for recovery phrase card"
                )
                titleLabel.textColor = Theme.primaryTextColor
                titleLabel.font = UIFont.dynamicTypeBodyClamped.semibold()
                
                let bodyLabel = UILabel()
                bodyLabel.text = OWSLocalizedString(
                    "CASHU_RECOVERY_PHRASE_CARD_BODY",
                    value: "Write down your 12-word recovery phrase to restore your wallet if you lose access to this device.",
                    comment: "Description for recovery phrase card"
                )
                bodyLabel.textColor = Theme.secondaryTextAndIconColor
                bodyLabel.font = UIFont.dynamicTypeSubheadlineClamped
                bodyLabel.numberOfLines = 0
                bodyLabel.lineBreakMode = .byWordWrapping
                
                let buttonLabel = UILabel()
                buttonLabel.text = OWSLocalizedString(
                    "CASHU_RECOVERY_PHRASE_CARD_BUTTON",
                    value: "View recovery phrase",
                    comment: "Button in recovery phrase card"
                )
                buttonLabel.textColor = Theme.accentBlueColor
                buttonLabel.font = UIFont.dynamicTypeSubheadlineClamped
                
                let iconName = Theme.isDarkThemeEnabled ? "restore-dark" : "restore"
                let animationView = LottieAnimationView(name: iconName)
                animationView.contentMode = .scaleAspectFit
                animationView.autoSetDimensions(to: .square(80))
                
                let vStack = UIStackView(arrangedSubviews: [
                    titleLabel,
                    bodyLabel,
                    buttonLabel
                ])
                vStack.axis = .vertical
                vStack.alignment = .leading
                vStack.spacing = 8
                
                let hStack = UIStackView(arrangedSubviews: [
                    vStack,
                    animationView
                ])
                hStack.axis = .horizontal
                hStack.alignment = .center
                hStack.spacing = 16
                
                let cell = OWSTableItem.newCell()
                cell.contentView.addSubview(hStack)
                hStack.autoPinEdgesToSuperviewMargins()
                
                return cell
            },
            actionBlock: { [weak self] in
                self?.showRecoveryPhrase()
            }
        ))
        
        return section
    }
    
    private func configureHeaderCell(cell: UITableViewCell) {
        // Balance label
        let balanceLabel = UILabel()
        balanceLabel.font = UIFont.regularFont(ofSize: 54)
        balanceLabel.textAlignment = .center
        balanceLabel.adjustsFontSizeToFitWidth = true
        balanceLabel.text = formatBalance(balance) + " sats"
        balanceLabel.textColor = Theme.primaryTextColor
        
        let balanceStack = UIStackView(arrangedSubviews: [balanceLabel])
        balanceStack.axis = .vertical
        balanceStack.alignment = .fill
        
        // Mint info label
        let mintLabel = UILabel()
        mintLabel.font = .dynamicTypeSubheadlineClamped
        mintLabel.textColor = Theme.secondaryTextAndIconColor
        mintLabel.textAlignment = .center
        mintLabel.numberOfLines = 0
        
        let mintNameLabel = UILabel()
        mintNameLabel.text = extractMintName(from: mintUrl)
        mintNameLabel.font = .dynamicTypeSubheadlineClamped
        mintNameLabel.textColor = Theme.secondaryTextAndIconColor
        mintNameLabel.textAlignment = .center
        
        let mintStack = UIStackView(arrangedSubviews: [mintNameLabel])
        mintStack.axis = .vertical
        mintStack.alignment = .center
        mintStack.isUserInteractionEnabled = true
        mintStack.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapMintInfo)))
        
        // Add funds button
        let addFundsButton = buildHeaderButton(
            title: OWSLocalizedString(
                "CASHU_ADD_FUNDS",
                value: "Add funds",
                comment: "Button to add funds"
            ),
            iconName: "plus",
            selector: #selector(didTapAddFunds)
        )
        
        let buttonStack = UIStackView(arrangedSubviews: [addFundsButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .fill
        buttonStack.distribution = .fillEqually
        
        let headerStack = OWSStackView(
            name: "headerStack",
            arrangedSubviews: [
                balanceStack,
                UIView.spacer(withHeight: 8),
                mintStack,
                UIView.spacer(withHeight: 44),
                buttonStack
            ]
        )
        headerStack.axis = .vertical
        headerStack.alignment = .fill
        headerStack.layoutMargins = .init(top: 30, left: 0, bottom: 8, right: 0)
        headerStack.isLayoutMarginsRelativeArrangement = true
        cell.contentView.addSubview(headerStack)
        headerStack.autoPinEdgesToSuperviewEdges()
        
        headerStack.addTapGesture { [weak self] in
            self?.loadWalletBalance()
        }
    }
    
    private func buildHeaderButton(title: String, iconName: String, selector: Selector) -> UIView {
        let iconView = UIImageView.withTemplateImageName(
            iconName,
            tintColor: Theme.primaryIconColor
        )
        iconView.autoSetDimensions(to: .square(24))
        
        let label = UILabel()
        label.text = title
        label.textColor = Theme.primaryTextColor
        label.font = .dynamicTypeCaption2Clamped
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        
        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 5
        stack.layoutMargins = UIEdgeInsets(top: 12, leading: 20, bottom: 6, trailing: 20)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.isUserInteractionEnabled = true
        stack.addGestureRecognizer(UITapGestureRecognizer(target: self, action: selector))
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = OWSTableViewController2.cellBackgroundColor(isUsingPresentedStyle: true)
        backgroundView.layer.cornerRadius = 10
        stack.addSubview(backgroundView)
        stack.sendSubviewToBack(backgroundView)
        backgroundView.autoPinEdgesToSuperviewEdges()
        
        return stack
    }
    
    // MARK: - Actions
    
    @objc
    private func didTapDismiss() {
        dismiss(animated: true)
    }
    
    @objc
    private func didTapSettings() {
        let actionSheet = ActionSheetController(title: nil, message: nil)
        
        actionSheet.addAction(ActionSheetAction(
            title: OWSLocalizedString(
                "CASHU_VIEW_RECOVERY_PHRASE",
                value: "View recovery phrase",
                comment: "Option to view recovery phrase"
            ),
            style: .default
        ) { [weak self] _ in
            self?.showRecoveryPhrase()
        })
        
        actionSheet.addAction(ActionSheetAction(
            title: OWSLocalizedString(
                "CASHU_MANAGE_MINTS",
                value: "Manage mints",
                comment: "Option to manage mints"
            ),
            style: .default
        ) { [weak self] _ in
            self?.showManageMints()
        })
        
        actionSheet.addAction(ActionSheetAction(
            title: OWSLocalizedString(
                "CASHU_CLEAR_WALLET",
                value: "Clear wallet",
                comment: "Option to clear wallet"
            ),
            style: .destructive
        ) { [weak self] _ in
            self?.showClearWalletConfirmation()
        })
        
        actionSheet.addAction(OWSActionSheets.cancelAction)
        
        presentActionSheet(actionSheet)
    }
    
    private func showRecoveryPhrase() {
        Task {
            guard let mnemonic = await CashuIntegration.shared.getWalletMnemonic() else {
                await MainActor.run {
                    OWSActionSheets.showErrorAlert(message: "No recovery phrase found")
                }
                return
            }
            
            await MainActor.run {
                let recoveryVC = ViewCashuRecoveryPhraseViewController(mnemonic: mnemonic)
                let navController = OWSNavigationController(rootViewController: recoveryVC)
                self.present(navController, animated: true)
            }
        }
    }
    
    @objc
    private func didTapMintInfo() {
        let alert = ActionSheetController(
            title: OWSLocalizedString(
                "CASHU_MINT_INFO_TITLE",
                value: "Mint information",
                comment: "Title for mint info dialog"
            ),
            message: String(format: OWSLocalizedString(
                "CASHU_MINT_INFO_MESSAGE",
                value: "Current mint: %@\n\nMints are trusted third parties that issue ecash tokens.",
                comment: "Message showing mint info"
            ), mintUrl)
        )
        
        alert.addAction(OWSActionSheets.okayAction)
        
        presentActionSheet(alert)
    }
    
    @objc
    private func didTapAddFunds() {
        let alert = UIAlertController(
            title: OWSLocalizedString(
                "CASHU_ADD_FUNDS_TITLE",
                value: "Add funds",
                comment: "Title for add funds dialog"
            ),
            message: OWSLocalizedString(
                "CASHU_ADD_FUNDS_MESSAGE",
                value: "Enter amount in sats",
                comment: "Message for add funds dialog"
            ),
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Amount"
            textField.keyboardType = .numberPad
        }
        
        alert.addAction(UIAlertAction(
            title: CommonStrings.continueButton,
            style: .default
        ) { [weak self, weak alert] _ in
            guard let amountText = alert?.textFields?.first?.text,
                  let amount = UInt64(amountText),
                  amount > 0 else {
                OWSActionSheets.showErrorAlert(message: "Please enter a valid amount")
                return
            }
            self?.createInvoiceAndShowQR(amount: amount)
        })
        
        alert.addAction(UIAlertAction(
            title: CommonStrings.cancelButton,
            style: .cancel
        ))
        
        present(alert, animated: true)
    }
    
    private func showManageMints() {
        let manageMintsVC = ManageMintsViewController()
        navigationController?.pushViewController(manageMintsVC, animated: true)
    }
    
    private func showClearWalletConfirmation() {
        let alert = ActionSheetController(
            title: OWSLocalizedString(
                "CASHU_CLEAR_WALLET_TITLE",
                value: "Clear wallet?",
                comment: "Title for clear wallet confirmation"
            ),
            message: OWSLocalizedString(
                "CASHU_CLEAR_WALLET_MESSAGE",
                value: "This will delete all tokens. Make sure you have backed them up!",
                comment: "Warning message for clear wallet"
            )
        )
        
        alert.addAction(ActionSheetAction(
            title: OWSLocalizedString(
                "CASHU_CLEAR_WALLET_CONFIRM",
                value: "Clear wallet",
                comment: "Confirm clear wallet button"
            ),
            style: .destructive
        ) { [weak self] _ in
            self?.clearWallet()
        })
        
        alert.addAction(OWSActionSheets.cancelAction)
        
        presentActionSheet(alert)
    }
    
    private func clearWallet() {
        Task {
            await CashuIntegration.shared.clearWallet()
            await MainActor.run {
                self.balance = 0
                self.updateTableContents()
                self.presentToast(text: "Wallet cleared")
            }
        }
    }
    
    // MARK: - Wallet Operations
    
    private func loadWalletBalance() {
        Task {
            do {
                let balance = try await CashuIntegration.shared.getBalance()
                await MainActor.run {
                    self.balance = balance
                    self.updateTableContents()
                }
            } catch {
                await MainActor.run {
                    self.balance = 0
                    self.updateTableContents()
                }
            }
        }
    }
    
    // MARK: - Minting Process
    
    private func createInvoiceAndShowQR(amount: UInt64) {
        ModalActivityIndicatorViewController.present(
            fromViewController: self,
            canCancel: false
        ) { [weak self] modal in
            guard let self = self else { return }
            
            Task {
                do {
                    // Request a mint quote (Lightning invoice)
                    let quote = try await CashuIntegration.shared.createMintQuote(amount: amount)
                    
                    await MainActor.run {
                        modal.dismiss {
                            let addFundsVC = AddFundsViewController(amount: amount, quote: quote)
                            self.navigationController?.pushViewController(addFundsVC, animated: true)
                        }
                    }
                } catch {
                    await MainActor.run {
                        modal.dismiss {
                            OWSActionSheets.showErrorAlert(message: "Failed to create invoice: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatBalance(_ sats: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: sats)) ?? "0"
    }
    
    private func extractMintName(from url: String) -> String {
        if let host = URL(string: url)?.host {
            return host
        }
        return url
    }
}
