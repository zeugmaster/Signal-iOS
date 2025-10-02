//
// Copyright 2025 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import UIKit
import SignalServiceKit
import SignalUI
import CashuDevKit

class AddFundsViewController: OWSViewController {
    
    private let amount: UInt64
    private let quote: CashuIntegration.MintQuoteInfo
    
    private let qrCodeView = QRCodeView(qrCodeTintColor: .blue)
    private let invoiceLabel = UILabel()
    private let statusLabel = UILabel()
    private let copyButton = OWSButton()
    
    private var pollingTimer: Timer?
    private var isPolling = false
    
    init(amount: UInt64, quote: CashuIntegration.MintQuoteInfo) {
        self.amount = amount
        self.quote = quote
        super.init()
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = OWSLocalizedString(
            "CASHU_ADD_FUNDS_TITLE",
            value: "Add funds",
            comment: "Title for add funds view"
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(didTapDone)
        )
        
        view.backgroundColor = Theme.backgroundColor
        
        setupUI()
        generateQRCode()
        startPolling()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPolling()
    }
    
    deinit {
        stopPolling()
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
        
        // Amount display
        let amountContainer = UIView()
        amountContainer.backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray80 : .ows_gray05
        amountContainer.layer.cornerRadius = 12
        
        let amountStack = UIStackView()
        amountStack.axis = .vertical
        amountStack.spacing = 8
        amountStack.alignment = .center
        
        let amountTitleLabel = UILabel()
        amountTitleLabel.text = OWSLocalizedString(
            "CASHU_ADD_FUNDS_AMOUNT",
            value: "Amount to add",
            comment: "Label for amount being added"
        )
        amountTitleLabel.font = .dynamicTypeBody
        amountTitleLabel.textColor = Theme.secondaryTextAndIconColor
        
        let amountValueLabel = UILabel()
        amountValueLabel.text = formatAmount(amount)
        amountValueLabel.font = .dynamicTypeTitle1.withSize(36)
        amountValueLabel.textColor = Theme.primaryTextColor
        
        let amountUnitLabel = UILabel()
        amountUnitLabel.text = "sats"
        amountUnitLabel.font = .dynamicTypeBody
        amountUnitLabel.textColor = Theme.secondaryTextAndIconColor
        
        amountStack.addArrangedSubview(amountTitleLabel)
        amountStack.addArrangedSubview(amountValueLabel)
        amountStack.addArrangedSubview(amountUnitLabel)
        
        amountContainer.addSubview(amountStack)
        amountStack.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        
        stackView.addArrangedSubview(amountContainer)
        
        // QR Code
        let qrCodeContainer = UIView()
        qrCodeContainer.addSubview(qrCodeView)
        qrCodeView.autoPinEdgesToSuperviewEdges()
        qrCodeView.autoSetDimensions(to: CGSize(square: 280))
        
        stackView.addArrangedSubview(qrCodeContainer)
        
        // Instructions
        let instructionsLabel = UILabel()
        instructionsLabel.text = OWSLocalizedString(
            "CASHU_SCAN_INVOICE_INSTRUCTIONS",
            value: "Scan this QR code with your Lightning wallet to add funds",
            comment: "Instructions for paying invoice"
        )
        instructionsLabel.font = .dynamicTypeBody
        instructionsLabel.textColor = Theme.primaryTextColor
        instructionsLabel.textAlignment = .center
        instructionsLabel.numberOfLines = 0
        stackView.addArrangedSubview(instructionsLabel)
        
        // Status label
        statusLabel.text = OWSLocalizedString(
            "CASHU_WAITING_FOR_PAYMENT",
            value: "Waiting for payment...",
            comment: "Status when waiting for invoice payment"
        )
        statusLabel.font = .dynamicTypeBody.italic()
        statusLabel.textColor = Theme.secondaryTextAndIconColor
        statusLabel.textAlignment = .center
        stackView.addArrangedSubview(statusLabel)
        
        // Invoice display (collapsed by default)
        let invoiceContainer = UIView()
        invoiceContainer.backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray90 : .ows_gray02
        invoiceContainer.layer.cornerRadius = 8
        
        invoiceLabel.text = quote.invoice
        invoiceLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        invoiceLabel.textColor = Theme.secondaryTextAndIconColor
        invoiceLabel.numberOfLines = 3
        invoiceLabel.lineBreakMode = .byTruncatingMiddle
        invoiceLabel.textAlignment = .center
        
        invoiceContainer.addSubview(invoiceLabel)
        invoiceLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(hMargin: 12, vMargin: 8))
        
        stackView.addArrangedSubview(invoiceContainer)
        
        // Copy button
        copyButton.setTitle(OWSLocalizedString(
            "CASHU_COPY_INVOICE",
            value: "Copy invoice",
            comment: "Button to copy invoice"
        ), for: .normal)
        copyButton.setTitleColor(.ows_accentBlue, for: .normal)
        copyButton.titleLabel?.font = .dynamicTypeBody.semibold()
        copyButton.backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray80 : .ows_gray05
        copyButton.layer.cornerRadius = 12
        copyButton.autoSetDimension(.height, toSize: 48)
        copyButton.addTarget(self, action: #selector(didTapCopy), for: .touchUpInside)
        
        stackView.addArrangedSubview(copyButton)
    }
    
    // MARK: - QR Code
    
    private func generateQRCode() {
        // Generate QR code from Lightning invoice
        if let url = URL(string: "lightning:\(quote.invoice)") {
            qrCodeView.setQRCode(url: url, stylingMode: .brandedWithoutLogo)
        } else {
            qrCodeView.setError()
        }
    }
    
    // MARK: - Actions
    
    @objc
    private func didTapDone() {
        stopPolling()
        navigationController?.popViewController(animated: true)
    }
    
    @objc
    private func didTapCopy() {
        UIPasteboard.general.string = quote.invoice
        
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.success)
        
        statusLabel.text = OWSLocalizedString(
            "CASHU_INVOICE_COPIED",
            value: "Invoice copied to clipboard",
            comment: "Status when invoice is copied"
        )
        statusLabel.textColor = .ows_accentGreen
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.resetStatusLabel()
        }
    }
    
    private func resetStatusLabel() {
        statusLabel.text = OWSLocalizedString(
            "CASHU_WAITING_FOR_PAYMENT",
            value: "Waiting for payment...",
            comment: "Status when waiting for invoice payment"
        )
        statusLabel.textColor = Theme.secondaryTextAndIconColor
    }
    
    // MARK: - Polling
    
    private func startPolling() {
        // Check immediately
        checkPaymentStatus()
        
        // Then poll every 3 seconds
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: 3.0,
            repeats: true
        ) { [weak self] _ in
            self?.checkPaymentStatus()
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isPolling = false
    }
    
    private func checkPaymentStatus() {
        guard !isPolling else { return }
        isPolling = true
        
        Task {
            do {
                // Try to mint - this will succeed if paid, throw if not
                try await CashuIntegration.shared.mintTokens(quoteId: quote.quoteId)
                
                // Success! Invoice was paid
                await MainActor.run {
                    self.stopPolling()
                    self.showPaymentSuccess()
                }
            } catch let error as FfiError {
                // Handle CashuDevKit specific errors
                await MainActor.run {
                    self.isPolling = false
                    
                    switch error {
                    case .PaymentPending:
                        // Expected - invoice not paid yet, continue polling
                        break
                        
                    case .Generic(let message):
                        // Check if it's the "Quote not paid" error
                        if message.lowercased().contains("quote not paid") {
                            // Expected - invoice not paid yet, continue polling
                            break
                        } else {
                            // Real generic error - stop polling
                            self.stopPolling()
                            self.showPaymentError(error)
                        }
                        
                    default:
                        // Real error - stop polling and show error
                        self.stopPolling()
                        self.showPaymentError(error)
                    }
                }
            } catch {
                // Handle other errors
                await MainActor.run {
                    self.isPolling = false
                    self.stopPolling()
                    self.showPaymentError(error)
                }
            }
        }
    }
    
    private func showPaymentSuccess() {
        statusLabel.text = OWSLocalizedString(
            "CASHU_PAYMENT_RECEIVED",
            value: "Payment received! Funds added.",
            comment: "Status when payment is confirmed"
        )
        statusLabel.textColor = .ows_accentGreen
        
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.success)
        
        // Dismiss after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }
    
    private func showPaymentError(_ error: Error) {
        statusLabel.text = OWSLocalizedString(
            "CASHU_PAYMENT_ERROR",
            value: "Error checking payment",
            comment: "Status when there's an error"
        )
        statusLabel.textColor = .ows_accentRed
        
        OWSActionSheets.showErrorAlert(message: error.localizedDescription)
    }
    
    // MARK: - Helpers
    
    private func formatAmount(_ sats: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: sats)) ?? "0"
    }
}

