//
// Copyright 2025 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import UIKit
import SignalServiceKit
import SignalUI

@objc
class CashuWalletViewController: OWSTableViewController2 {
    
    private let mode: PaymentsSettingsMode
    
    // MARK: - UI Components
    
    private let balanceCard = UIView()
    private let balanceLabel = UILabel()
    private let balanceAmountLabel = UILabel()
    
    private let sendButton = UIButton()
    private let receiveButton = UIButton()
    private let mintButton = UIButton()
    private let settingsButton = UIButton()
    
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
                action: #selector(didTapDismiss),
                accessibilityIdentifier: "dismiss"
            )
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: Theme.iconImage(.buttonMore),
            style: .plain,
            target: self,
            action: #selector(didTapSettings)
        )
        
        updateTableContents()
        loadWalletBalance()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTableContents()
        loadWalletBalance()
    }
    
    // MARK: - Table Contents
    
    private func updateTableContents() {
        let contents = OWSTableContents()
        
        // Balance Section
        let balanceSection = OWSTableSection()
        balanceSection.headerTitle = OWSLocalizedString(
            "CASHU_WALLET_BALANCE_SECTION",
            value: "Balance",
            comment: "Header for balance section"
        )
        
        balanceSection.add(OWSTableItem(customCellBlock: { [weak self] in
            guard let self = self else { return UITableViewCell() }
            
            let cell = OWSTableItem.newCell()
            cell.selectionStyle = .none
            
            let cardView = UIView()
            cardView.backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray80 : .ows_gray05
            cardView.layer.cornerRadius = 12
            
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 8
            stackView.alignment = .center
            
            let titleLabel = UILabel()
            titleLabel.text = OWSLocalizedString(
                "CASHU_WALLET_YOUR_BALANCE",
                value: "Your balance",
                comment: "Label showing user's balance"
            )
            titleLabel.font = .dynamicTypeBody
            titleLabel.textColor = Theme.secondaryTextAndIconColor
            
            let amountLabel = UILabel()
            amountLabel.text = self.formatBalance(self.balance)
            amountLabel.font = .dynamicTypeTitle1.withSize(36)
            amountLabel.textColor = Theme.primaryTextColor
            
            let satsLabel = UILabel()
            satsLabel.text = "sats"
            satsLabel.font = .dynamicTypeBody
            satsLabel.textColor = Theme.secondaryTextAndIconColor
            
            stackView.addArrangedSubview(titleLabel)
            stackView.addArrangedSubview(amountLabel)
            stackView.addArrangedSubview(satsLabel)
            
            cardView.addSubview(stackView)
            stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 24, left: 16, bottom: 24, right: 16))
            
            cell.contentView.addSubview(cardView)
            cardView.autoPinEdgesToSuperviewMargins()
            
            return cell
        }))
        
        contents.add(balanceSection)
        
        // Actions Section
        let actionsSection = OWSTableSection()
        actionsSection.headerTitle = OWSLocalizedString(
            "CASHU_WALLET_ACTIONS_SECTION",
            value: "Actions",
            comment: "Header for actions section"
        )
        
        // Mint tokens (add funds)
        actionsSection.add(OWSTableItem.disclosureItem(
            withText: OWSLocalizedString(
                "CASHU_WALLET_ADD_FUNDS",
                value: "Add Funds",
                comment: "Button to add funds via Lightning"
            ),
            actionBlock: { [weak self] in
                self?.didTapAddFunds()
            }
        ))
        
        contents.add(actionsSection)
        
        // Transaction History Section
        let historySection = OWSTableSection()
        historySection.headerTitle = OWSLocalizedString(
            "CASHU_WALLET_HISTORY_SECTION",
            value: "Recent Transactions",
            comment: "Header for transaction history section"
        )
        
        // Placeholder for now
        // Commenting out transaction history for now - will be added later
        // historySection.add(OWSTableItem(customCellBlock: {
        //     let cell = OWSTableItem.newCell()
        //     cell.selectionStyle = .none
        //     
        //     let label = UILabel()
        //     label.text = OWSLocalizedString(
        //         "CASHU_WALLET_NO_TRANSACTIONS",
        //         value: "No transactions yet",
        //         comment: "Placeholder when there are no transactions"
        //     )
        //     label.font = .dynamicTypeBody
        //     label.textColor = Theme.secondaryTextAndIconColor
        //     label.textAlignment = .center
        //     
        //     cell.contentView.addSubview(label)
        //     label.autoPinEdgesToSuperviewMargins()
        //     label.autoSetDimension(.height, toSize: 60, relation: .greaterThanOrEqual)
        //     
        //     return cell
        // }))
        // 
        // contents.add(historySection)
        
        // Info Section
        let infoSection = OWSTableSection()
        infoSection.footerTitle = OWSLocalizedString(
            "CASHU_WALLET_INFO_FOOTER",
            value: "Cashu is a Chaumian ecash system for Bitcoin. Tokens are bearer instruments - keep them safe!",
            comment: "Footer text explaining Cashu"
        )
        
        infoSection.add(OWSTableItem.disclosureItem(
            withText: OWSLocalizedString(
                "CASHU_WALLET_MINT_INFO",
                value: "Current mint: \(mintUrl)",
                comment: "Shows current mint URL"
            ),
            actionBlock: { [weak self] in
                self?.didTapMintInfo()
            }
        ))
        
        contents.add(infoSection)
        
        self.contents = contents
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
                "CASHU_WALLET_BACKUP",
                value: "Backup Wallet",
                comment: "Option to backup Cashu wallet"
            ),
            style: .default
        ) { [weak self] _ in
            self?.showBackupWallet()
        })
        
        actionSheet.addAction(ActionSheetAction(
            title: OWSLocalizedString(
                "CASHU_WALLET_RESTORE",
                value: "Restore Wallet",
                comment: "Option to restore Cashu wallet"
            ),
            style: .default
        ) { [weak self] _ in
            self?.showRestoreWallet()
        })
        
        actionSheet.addAction(ActionSheetAction(
            title: OWSLocalizedString(
                "CASHU_WALLET_CHANGE_MINT",
                value: "Change Mint",
                comment: "Option to change Cashu mint"
            ),
            style: .default
        ) { [weak self] _ in
            self?.showChangeMint()
        })
        
        actionSheet.addAction(ActionSheetAction(
            title: OWSLocalizedString(
                "CASHU_WALLET_CLEAR",
                value: "Clear Wallet",
                comment: "Option to clear Cashu wallet"
            ),
            style: .destructive
        ) { [weak self] _ in
            self?.showClearWalletConfirmation()
        })
        
        actionSheet.addAction(OWSActionSheets.cancelAction)
        
        presentActionSheet(actionSheet)
    }
    
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
            self?.startMintingProcess(amount: amount)
        })
        
        alert.addAction(UIAlertAction(
            title: CommonStrings.cancelButton,
            style: .cancel
        ))
        
        present(alert, animated: true)
    }
    
    private func didTapMintInfo() {
        let alert = ActionSheetController(
            title: OWSLocalizedString(
                "CASHU_MINT_INFO_TITLE",
                value: "Mint Information",
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
                Logger.error("Failed to load wallet balance: \(error)")
                await MainActor.run {
                    self.balance = 0
                    self.updateTableContents()
                }
            }
        }
    }
    
    // MARK: - Minting Process
    
    private func startMintingProcess(amount: UInt64) {
        Task {
            do {
                // Request a mint quote (Lightning invoice)
                let quote = try await CashuIntegration.shared.createMintQuote(amount: amount)
                
                await MainActor.run {
                    self.showLightningInvoice(quote: quote, amount: amount)
                }
            } catch {
                await MainActor.run {
                    OWSActionSheets.showErrorAlert(message: "Failed to create invoice: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showLightningInvoice(quote: CashuIntegration.MintQuoteInfo, amount: UInt64) {
        // Truncate invoice for display
        let invoicePreview = String(quote.invoice.prefix(60)) + "..."
        
        let alert = ActionSheetController(
            title: OWSLocalizedString(
                "CASHU_LIGHTNING_INVOICE_TITLE",
                value: "Lightning invoice",
                comment: "Title for Lightning invoice display"
            ),
            message: String(format: OWSLocalizedString(
                "CASHU_LIGHTNING_INVOICE_MESSAGE",
                value: "Pay this invoice with your Lightning wallet to add %d sats:\n\n%@",
                comment: "Message explaining how to pay the invoice"
            ), amount, invoicePreview)
        )
        
        // Add copy button
        alert.addAction(ActionSheetAction(
            title: OWSLocalizedString(
                "CASHU_COPY_INVOICE",
                value: "Copy invoice",
                comment: "Button to copy Lightning invoice"
            ),
            style: .default
        ) { [weak self] _ in
            UIPasteboard.general.string = quote.invoice
            self?.showToast("Invoice copied to clipboard")
            self?.showLightningInvoice(quote: quote, amount: amount)
        })
        
        // Add check payment button
        alert.addAction(ActionSheetAction(
            title: OWSLocalizedString(
                "CASHU_CHECK_PAYMENT",
                value: "Check payment",
                comment: "Button to check if invoice was paid"
            ),
            style: .default
        ) { [weak self] _ in
            self?.checkPaymentAndMint(quote: quote, amount: amount)
        })
        
        alert.addAction(OWSActionSheets.cancelAction)
        
        presentActionSheet(alert)
    }
    
    private func checkPaymentAndMint(quote: CashuIntegration.MintQuoteInfo, amount: UInt64) {
        // Show loading
        ModalActivityIndicatorViewController.present(
            fromViewController: self,
            canCancel: false
        ) { [weak self] modal in
            guard let self = self else { return }
            
            Task {
                do {
                    // Check quote status and mint if paid
                    try await CashuIntegration.shared.mintTokens(quoteId: quote.quoteId)
                    
                    await MainActor.run {
                        modal.dismiss {
                            self.showToast("Funds added successfully!")
                            self.loadWalletBalance()
                        }
                    }
                } catch {
                    await MainActor.run {
                        modal.dismiss {
                            let errorMessage = error.localizedDescription
                            if errorMessage.contains("unpaid") || errorMessage.contains("pending") {
                                OWSActionSheets.showErrorAlert(message: "Invoice not paid yet. Please pay the invoice and try again.")
                                // Show the invoice again
                                self.showLightningInvoice(quote: quote, amount: amount)
                            } else {
                                OWSActionSheets.showErrorAlert(message: "Failed to mint tokens: \(errorMessage)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Settings Actions
    
    private func showBackupWallet() {
        // TODO: Implement wallet backup
        showToast("Backup feature coming soon!")
    }
    
    private func showRestoreWallet() {
        // TODO: Implement wallet restore
        showToast("Restore feature coming soon!")
    }
    
    private func showChangeMint() {
        let alert = UIAlertController(
            title: OWSLocalizedString(
                "CASHU_CHANGE_MINT_TITLE",
                value: "Change Mint",
                comment: "Title for change mint dialog"
            ),
            message: OWSLocalizedString(
                "CASHU_CHANGE_MINT_MESSAGE",
                value: "Enter the URL of the new mint",
                comment: "Message for change mint dialog"
            ),
            preferredStyle: .alert
        )
        
        alert.addTextField { [weak self] textField in
            textField.placeholder = "https://mint.example.com"
            textField.text = self?.mintUrl
        }
        
        alert.addAction(UIAlertAction(
            title: CommonStrings.saveButton,
            style: .default
        ) { [weak self, weak alert] _ in
            guard let newMintUrl = alert?.textFields?.first?.text,
                  !newMintUrl.isEmpty else {
                return
            }
            Task {
                await CashuIntegration.shared.setMintUrl(newMintUrl)
                await MainActor.run {
                    self?.updateTableContents()
                    self?.showToast("Mint updated")
                    self?.loadWalletBalance()
                }
            }
        })
        
        alert.addAction(UIAlertAction(
            title: CommonStrings.cancelButton,
            style: .cancel
        ))
        
        present(alert, animated: true)
    }
    
    private func showClearWalletConfirmation() {
        let alert = ActionSheetController(
            title: OWSLocalizedString(
                "CASHU_CLEAR_WALLET_TITLE",
                value: "Clear Wallet?",
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
                value: "Clear Wallet",
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
                self.showToast("Wallet cleared")
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
    
    private func showToast(_ message: String) {
        presentToast(text: message)
    }
}
