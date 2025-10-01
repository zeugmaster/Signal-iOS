//
// Copyright 2025 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import UIKit
import SignalServiceKit
import SignalUI

protocol SendCashuViewDelegate: AnyObject {
    func didSendCashu(success: Bool, recipientAddress: SignalServiceAddress)
}

class SendCashuViewController: OWSViewController {
    
    weak var delegate: SendCashuViewDelegate?
    
    private let recipientAddress: SignalServiceAddress
    private let rootStack = UIStackView()
    private let amountTextField = UITextField()
    private let balanceLabel = UILabel()
    private let sendButton = OWSButton()
    
    private var currentBalance: UInt64 = 0
    
    init(recipientAddress: SignalServiceAddress) {
        self.recipientAddress = recipientAddress
        super.init()
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = OWSLocalizedString(
            "CASHU_SEND_TITLE",
            value: "Send payment",
            comment: "Title for send payment view"
        )
        
        navigationItem.leftBarButtonItem = .cancelButton { [weak self] in
            self?.didTapCancel()
        }
        
        view.backgroundColor = Theme.backgroundColor
        
        setupUI()
        loadBalance()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        amountTextField.becomeFirstResponder()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        rootStack.axis = .vertical
        rootStack.alignment = .fill
        rootStack.spacing = 24
        rootStack.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        rootStack.isLayoutMarginsRelativeArrangement = true
        
        view.addSubview(rootStack)
        rootStack.autoPinEdgesToSuperviewEdges()
        
        // Recipient info
        let recipientLabel = UILabel()
        recipientLabel.text = OWSLocalizedString(
            "CASHU_SEND_TO",
            value: "Send to",
            comment: "Label for recipient"
        )
        recipientLabel.font = .dynamicTypeBody
        recipientLabel.textColor = Theme.secondaryTextAndIconColor
        recipientLabel.textAlignment = .center
        rootStack.addArrangedSubview(recipientLabel)
        
        let recipientNameLabel = UILabel()
        recipientNameLabel.text = recipientAddress.serviceIdUppercaseString ?? recipientAddress.phoneNumber ?? "Unknown"
        recipientNameLabel.font = .dynamicTypeTitle2.semibold()
        recipientNameLabel.textColor = Theme.primaryTextColor
        recipientNameLabel.textAlignment = .center
        rootStack.addArrangedSubview(recipientNameLabel)
        
        rootStack.addArrangedSubview(.spacer(withHeight: 16))
        
        // Amount input
        let amountContainer = UIView()
        amountContainer.backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray80 : .ows_gray05
        amountContainer.layer.cornerRadius = 12
        
        let amountStack = UIStackView()
        amountStack.axis = .horizontal
        amountStack.spacing = 8
        amountStack.alignment = .center
        
        amountTextField.font = .dynamicTypeTitle1.withSize(48)
        amountTextField.textColor = Theme.primaryTextColor
        amountTextField.textAlignment = .center
        amountTextField.keyboardType = .numberPad
        amountTextField.placeholder = "0"
        amountTextField.delegate = self
        amountTextField.addTarget(self, action: #selector(amountDidChange), for: .editingChanged)
        
        let satsLabel = UILabel()
        satsLabel.text = "sats"
        satsLabel.font = .dynamicTypeTitle2
        satsLabel.textColor = Theme.secondaryTextAndIconColor
        
        amountStack.addArrangedSubview(amountTextField)
        amountStack.addArrangedSubview(satsLabel)
        
        amountContainer.addSubview(amountStack)
        amountStack.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24))
        
        rootStack.addArrangedSubview(amountContainer)
        
        // Balance label
        balanceLabel.font = .dynamicTypeBody
        balanceLabel.textColor = Theme.secondaryTextAndIconColor
        balanceLabel.textAlignment = .center
        rootStack.addArrangedSubview(balanceLabel)
        
        rootStack.addArrangedSubview(.vStretchingSpacer())
        
        // Send button
        sendButton.setTitle(OWSLocalizedString(
            "CASHU_SEND_BUTTON",
            value: "Send",
            comment: "Button to send payment"
        ), for: .normal)
        sendButton.setTitleColor(.ows_white, for: .normal)
        sendButton.backgroundColor = .ows_accentBlue
        sendButton.titleLabel?.font = .dynamicTypeBody.semibold()
        sendButton.layer.cornerRadius = 12
        sendButton.autoSetDimension(.height, toSize: 56)
        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        sendButton.isEnabled = false
        
        rootStack.addArrangedSubview(sendButton)
        
        updateSendButtonState()
    }
    
    // MARK: - Actions
    
    private func didTapCancel() {
        dismiss(animated: true)
    }
    
    @objc
    private func amountDidChange() {
        updateSendButtonState()
    }
    
    private func updateSendButtonState() {
        guard let amountText = amountTextField.text,
              let amount = UInt64(amountText),
              amount > 0,
              amount <= currentBalance else {
            sendButton.isEnabled = false
            sendButton.backgroundColor = .ows_gray25
            return
        }
        
        sendButton.isEnabled = true
        sendButton.backgroundColor = .ows_accentBlue
    }
    
    @objc
    private func didTapSend() {
        guard let amountText = amountTextField.text,
              let amount = UInt64(amountText),
              amount > 0,
              amount <= currentBalance else {
            OWSActionSheets.showErrorAlert(message: "Please enter a valid amount")
            return
        }
        
        performSend(amount: amount)
    }
    
    // MARK: - Balance
    
    private func loadBalance() {
        Task {
            do {
                let balance = try await CashuIntegration.shared.getBalance()
                await MainActor.run {
                    self.currentBalance = balance
                    self.updateBalanceLabel()
                    self.updateSendButtonState()
                }
            } catch {
                await MainActor.run {
                    self.currentBalance = 0
                    self.updateBalanceLabel()
                }
            }
        }
    }
    
    private func updateBalanceLabel() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let balanceString = formatter.string(from: NSNumber(value: currentBalance)) ?? "0"
        
        balanceLabel.text = String(format: OWSLocalizedString(
            "CASHU_BALANCE_FORMAT",
            value: "Balance: %@ sats",
            comment: "Format for showing balance"
        ), balanceString)
    }
    
    // MARK: - Send
    
    private func performSend(amount: UInt64) {
        ModalActivityIndicatorViewController.present(
            fromViewController: self,
            canCancel: false
        ) { [weak self] modal in
            guard let self = self else { return }
            
            Task {
                do {
                    // Create Cashu token
                    let tokenString = try await CashuIntegration.shared.sendTokens(amount: amount)
                    
                    // Send as message
                    try await self.sendTokenAsMessage(tokenString: tokenString)
                    
                    await MainActor.run {
                        modal.dismiss {
                            self.delegate?.didSendCashu(success: true, recipientAddress: self.recipientAddress)
                            self.dismiss(animated: true)
                        }
                    }
                } catch {
                    await MainActor.run {
                        modal.dismiss {
                            OWSActionSheets.showErrorAlert(message: "Failed to send payment: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    private func sendTokenAsMessage(tokenString: String) async throws {
        let thread = await SSKEnvironment.shared.databaseStorageRef.awaitableWrite { transaction in
            TSContactThread.getOrCreateThread(
                withContactAddress: self.recipientAddress,
                transaction: transaction
            )
        }
        
        ThreadUtil.enqueueMessage(
            body: MessageBody(text: tokenString, ranges: .empty),
            thread: thread
        )
    }
    
    // MARK: - Static Presentation
    
    static func present(
        from viewController: UIViewController,
        delegate: SendCashuViewDelegate?,
        recipientAddress: SignalServiceAddress
    ) {
        let sendVC = SendCashuViewController(recipientAddress: recipientAddress)
        sendVC.delegate = delegate
        
        let navController = OWSNavigationController(rootViewController: sendVC)
        viewController.present(navController, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension SendCashuViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Only allow numbers
        let allowedCharacters = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet)
    }
}

