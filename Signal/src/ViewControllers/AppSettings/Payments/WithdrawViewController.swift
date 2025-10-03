//
// Copyright 2025 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import UIKit
import SignalServiceKit
import SignalUI
import CashuDevKit

class WithdrawViewController: OWSViewController {
    
    private let invoiceTextField = UITextField()
    private let amountLabel = UILabel()
    private let feeLabel = UILabel()
    private let payButton = OWSButton()
    private let statusLabel = UILabel()
    
    private var currentQuote: MeltQuote?
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = OWSLocalizedString(
            "CASHU_WITHDRAW_TITLE",
            value: "Withdraw",
            comment: "Title for withdraw view"
        )
        
        view.backgroundColor = Theme.backgroundColor
        
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        invoiceTextField.becomeFirstResponder()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        let scrollView = UIScrollView()
        view.addSubview(scrollView)
        scrollView.autoPinEdgesToSuperviewEdges()
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stackView.isLayoutMarginsRelativeArrangement = true
        
        scrollView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        stackView.autoMatch(.width, to: .width, of: scrollView)
        
        // Instructions
        let instructionsLabel = UILabel()
        instructionsLabel.text = OWSLocalizedString(
            "CASHU_WITHDRAW_INSTRUCTIONS",
            value: "Paste a Lightning invoice to pay",
            comment: "Instructions for withdraw"
        )
        instructionsLabel.font = .dynamicTypeBody
        instructionsLabel.textColor = Theme.secondaryTextAndIconColor
        instructionsLabel.textAlignment = .center
        instructionsLabel.numberOfLines = 0
        stackView.addArrangedSubview(instructionsLabel)
        
        // Invoice text field
        let invoiceContainer = UIView()
        invoiceContainer.backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray80 : .ows_gray05
        invoiceContainer.layer.cornerRadius = 12
        
        invoiceTextField.placeholder = "lnbc..."
        invoiceTextField.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        invoiceTextField.textColor = Theme.primaryTextColor
        invoiceTextField.backgroundColor = .clear
        invoiceTextField.autocorrectionType = .no
        invoiceTextField.autocapitalizationType = .none
        invoiceTextField.delegate = self
        invoiceTextField.addTarget(self, action: #selector(invoiceTextChanged), for: .editingChanged)
        
        invoiceContainer.addSubview(invoiceTextField)
        invoiceTextField.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        
        stackView.addArrangedSubview(invoiceContainer)
        
        // Paste button
        let pasteButton = OWSButton()
        pasteButton.setTitle(OWSLocalizedString(
            "CASHU_PASTE_INVOICE",
            value: "Paste from clipboard",
            comment: "Button to paste invoice"
        ), for: .normal)
        pasteButton.setTitleColor(.ows_accentBlue, for: .normal)
        pasteButton.titleLabel?.font = .dynamicTypeBody
        pasteButton.addTarget(self, action: #selector(didTapPaste), for: .touchUpInside)
        stackView.addArrangedSubview(pasteButton)
        
        // Quote details (hidden initially)
        let quoteContainer = UIView()
        quoteContainer.backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray80 : .ows_gray05
        quoteContainer.layer.cornerRadius = 12
        quoteContainer.alpha = 0
        
        let quoteStack = UIStackView()
        quoteStack.axis = .vertical
        quoteStack.spacing = 12
        
        // Amount row
        let amountRow = UIStackView()
        amountRow.axis = .horizontal
        amountRow.distribution = .equalSpacing
        
        let amountTitleLabel = UILabel()
        amountTitleLabel.text = OWSLocalizedString(
            "CASHU_WITHDRAW_AMOUNT",
            value: "Amount",
            comment: "Label for invoice amount"
        )
        amountTitleLabel.font = .dynamicTypeBody
        amountTitleLabel.textColor = Theme.secondaryTextAndIconColor
        
        amountLabel.font = .dynamicTypeBody.semibold()
        amountLabel.textColor = Theme.primaryTextColor
        amountLabel.textAlignment = .right
        
        amountRow.addArrangedSubview(amountTitleLabel)
        amountRow.addArrangedSubview(amountLabel)
        
        // Fee row
        let feeRow = UIStackView()
        feeRow.axis = .horizontal
        feeRow.distribution = .equalSpacing
        
        let feeTitleLabel = UILabel()
        feeTitleLabel.text = OWSLocalizedString(
            "CASHU_WITHDRAW_FEE",
            value: "Fee",
            comment: "Label for invoice fee"
        )
        feeTitleLabel.font = .dynamicTypeBody
        feeTitleLabel.textColor = Theme.secondaryTextAndIconColor
        
        feeLabel.font = .dynamicTypeBody.semibold()
        feeLabel.textColor = Theme.primaryTextColor
        feeLabel.textAlignment = .right
        
        feeRow.addArrangedSubview(feeTitleLabel)
        feeRow.addArrangedSubview(feeLabel)
        
        quoteStack.addArrangedSubview(amountRow)
        quoteStack.addArrangedSubview(feeRow)
        
        quoteContainer.addSubview(quoteStack)
        quoteStack.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        
        stackView.addArrangedSubview(quoteContainer)
        
        // Status label
        statusLabel.font = .dynamicTypeCaption1
        statusLabel.textColor = Theme.secondaryTextAndIconColor
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        stackView.addArrangedSubview(statusLabel)
        
        // Pay button
        payButton.setTitle(OWSLocalizedString(
            "CASHU_PAY_INVOICE",
            value: "Pay invoice",
            comment: "Button to pay invoice"
        ), for: .normal)
        payButton.setBackgroundImage(UIImage.image(color: .ows_accentBlue), for: .normal)
        payButton.setTitleColor(.white, for: .normal)
        payButton.titleLabel?.font = .dynamicTypeBody.semibold()
        payButton.layer.cornerRadius = 12
        payButton.clipsToBounds = true
        payButton.autoSetDimension(.height, toSize: 52)
        payButton.addTarget(self, action: #selector(didTapPay), for: .touchUpInside)
        payButton.isEnabled = false
        payButton.alpha = 0.5
        
        stackView.addArrangedSubview(payButton)
        
        // Add spacer to push content up
        stackView.addArrangedSubview(UIView.vStretchingSpacer())
    }
    
    // MARK: - Actions
    
    @objc
    private func didTapPaste() {
        if let clipboardText = UIPasteboard.general.string {
            invoiceTextField.text = clipboardText
            invoiceTextChanged()
        }
    }
    
    @objc
    private func invoiceTextChanged() {
        guard let invoice = invoiceTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !invoice.isEmpty,
              invoice.lowercased().hasPrefix("lnbc") else {
            resetQuoteDisplay()
            return
        }
        
        // Fetch quote for this invoice
        fetchMeltQuote(invoice: invoice)
    }
    
    private func fetchMeltQuote(invoice: String) {
        statusLabel.text = OWSLocalizedString(
            "CASHU_FETCHING_QUOTE",
            value: "Checking invoice...",
            comment: "Status while fetching quote"
        )
        statusLabel.textColor = Theme.secondaryTextAndIconColor
        
        Task {
            do {
                let quote = try await CashuIntegration.shared.createMeltQuote(invoice: invoice)
                
                await MainActor.run {
                    self.currentQuote = quote
                    self.updateQuoteDisplay(quote: quote)
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.text = "Invalid invoice"
                    self.statusLabel.textColor = .ows_accentRed
                    self.resetQuoteDisplay()
                }
            }
        }
    }
    
    private func updateQuoteDisplay(quote: MeltQuote) {
        // Show amount and fee
        amountLabel.text = "\(formatAmount(quote.amount.value)) sats"
        feeLabel.text = "\(formatAmount(quote.feeReserve.value)) sats"
        
        // Show quote container
        if let quoteContainer = amountLabel.superview?.superview {
            UIView.animate(withDuration: 0.3) {
                quoteContainer.alpha = 1
            }
        }
        
        // Enable pay button
        payButton.isEnabled = true
        UIView.animate(withDuration: 0.3) {
            self.payButton.alpha = 1.0
        }
        
        statusLabel.text = OWSLocalizedString(
            "CASHU_READY_TO_PAY",
            value: "Ready to pay",
            comment: "Status when ready to pay"
        )
        statusLabel.textColor = .ows_accentGreen
    }
    
    private func resetQuoteDisplay() {
        currentQuote = nil
        amountLabel.text = ""
        feeLabel.text = ""
        
        if let quoteContainer = amountLabel.superview?.superview {
            UIView.animate(withDuration: 0.3) {
                quoteContainer.alpha = 0
            }
        }
        
        payButton.isEnabled = false
        UIView.animate(withDuration: 0.3) {
            self.payButton.alpha = 0.5
        }
        
        statusLabel.text = ""
    }
    
    @objc
    private func didTapPay() {
        guard let quote = currentQuote else { return }
        
        let confirmAlert = UIAlertController(
            title: OWSLocalizedString(
                "CASHU_CONFIRM_PAYMENT",
                value: "Confirm payment",
                comment: "Title for payment confirmation"
            ),
            message: String(
                format: OWSLocalizedString(
                    "CASHU_CONFIRM_PAYMENT_MESSAGE",
                    value: "Pay %@ sats (+ %@ sats fee)?",
                    comment: "Confirmation message for payment"
                ),
                formatAmount(quote.amount.value),
                formatAmount(quote.feeReserve.value)
            ),
            preferredStyle: .alert
        )
        
        confirmAlert.addAction(UIAlertAction(
            title: OWSLocalizedString(
                "CASHU_PAY",
                value: "Pay",
                comment: "Button to confirm payment"
            ),
            style: .default
        ) { [weak self] _ in
            self?.executeMelt(quoteId: quote.id)
        })
        
        confirmAlert.addAction(UIAlertAction(
            title: CommonStrings.cancelButton,
            style: .cancel
        ))
        
        present(confirmAlert, animated: true)
    }
    
    private func executeMelt(quoteId: String) {
        ModalActivityIndicatorViewController.present(
            fromViewController: self,
            canCancel: false
        ) { [weak self] modal in
            guard let self = self else { return }
            
            Task {
                do {
                    let result = try await CashuIntegration.shared.meltTokens(quoteId: quoteId)
                    
                    await MainActor.run {
                        modal.dismiss {
                            self.showPaymentSuccess(result: result)
                        }
                    }
                } catch {
                    await MainActor.run {
                        modal.dismiss {
                            OWSActionSheets.showErrorAlert(message: "Failed to pay invoice: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    private func showPaymentSuccess(result: CashuIntegration.MeltResult) {
        let message: String
        if let preimage = result.preimage {
            message = String(
                format: OWSLocalizedString(
                    "CASHU_PAYMENT_SUCCESS_WITH_PREIMAGE",
                    value: "Payment successful!\n\nPaid: %@ sats\nFee: %@ sats\nPreimage: %@",
                    comment: "Success message with preimage"
                ),
                formatAmount(result.amountPaid),
                formatAmount(result.feePaid),
                String(preimage.prefix(20)) + "..."
            )
        } else {
            message = String(
                format: OWSLocalizedString(
                    "CASHU_PAYMENT_SUCCESS",
                    value: "Payment successful!\n\nPaid: %@ sats\nFee: %@ sats",
                    comment: "Success message"
                ),
                formatAmount(result.amountPaid),
                formatAmount(result.feePaid)
            )
        }
        
        let alert = UIAlertController(
            title: OWSLocalizedString(
                "CASHU_PAYMENT_SENT",
                value: "Payment sent",
                comment: "Title for payment success"
            ),
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: CommonStrings.okButton,
            style: .default
        ) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Helpers
    
    private func formatAmount(_ sats: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: sats)) ?? "0"
    }
}

// MARK: - UITextFieldDelegate

extension WithdrawViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

