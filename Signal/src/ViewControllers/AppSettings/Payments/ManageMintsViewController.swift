//
// Copyright 2025 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import UIKit
import SignalServiceKit
import SignalUI

class ManageMintsViewController: OWSTableViewController2 {
    
    private var mints: [String] = []
    private var activeMint: String = ""
    
    private static let keyValueStore = KeyValueStore(collection: "CashuMints")
    private static let mintsKey = "savedMints"
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = OWSLocalizedString(
            "CASHU_MANAGE_MINTS",
            value: "Manage mints",
            comment: "Title for manage mints view"
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(didTapAddMint)
        )
        
        loadMints()
        updateTableContents()
    }
    
    // MARK: - Data
    
    private func loadMints() {
        activeMint = CashuIntegration.shared.getMintUrl()
        
        mints = SSKEnvironment.shared.databaseStorageRef.read { transaction in
            if let saved: [String] = try? Self.keyValueStore.getCodableValue(
                forKey: Self.mintsKey,
                transaction: transaction
            ) {
                return saved
            }
            return []
        }
        
        // Always include the default and active mint
        let defaultMint = "https://testnut.cashu.space"
        if !mints.contains(defaultMint) {
            mints.append(defaultMint)
        }
        if !mints.contains(activeMint) {
            mints.insert(activeMint, at: 0)
        }
        
        saveMints()
    }
    
    private func saveMints() {
        SSKEnvironment.shared.databaseStorageRef.write { transaction in
            try? Self.keyValueStore.setCodable(
                self.mints,
                key: Self.mintsKey,
                transaction: transaction
            )
        }
    }
    
    // MARK: - Table Contents
    
    private func updateTableContents() {
        let contents = OWSTableContents()
        
        let mintsSection = OWSTableSection()
        mintsSection.headerTitle = OWSLocalizedString(
            "CASHU_AVAILABLE_MINTS",
            value: "Available mints",
            comment: "Header for mints list"
        )
        mintsSection.footerTitle = OWSLocalizedString(
            "CASHU_MINTS_FOOTER",
            value: "Mints are trusted third parties that issue ecash tokens. Choose one you trust.",
            comment: "Footer explaining mints"
        )
        
        for mint in mints {
            let isActive = mint == activeMint
            
            mintsSection.add(OWSTableItem(
                customCellBlock: { [weak self] in
                    let cell = OWSTableItem.newCell()
                    cell.selectionStyle = .default
                    
                    let mintNameLabel = UILabel()
                    mintNameLabel.text = self?.extractMintName(from: mint) ?? mint
                    mintNameLabel.font = .dynamicTypeBody
                    mintNameLabel.textColor = Theme.primaryTextColor
                    mintNameLabel.numberOfLines = 1
                    
                    let mintUrlLabel = UILabel()
                    mintUrlLabel.text = mint
                    mintUrlLabel.font = .dynamicTypeCaption1
                    mintUrlLabel.textColor = Theme.secondaryTextAndIconColor
                    mintUrlLabel.numberOfLines = 1
                    mintUrlLabel.lineBreakMode = .byTruncatingMiddle
                    
                    let labelStack = UIStackView(arrangedSubviews: [mintNameLabel, mintUrlLabel])
                    labelStack.axis = .vertical
                    labelStack.spacing = 2
                    labelStack.alignment = .leading
                    
                    cell.contentView.addSubview(labelStack)
                    labelStack.autoPinEdgesToSuperviewMargins()
                    
                    if isActive {
                        cell.accessoryType = .checkmark
                    } else {
                        cell.accessoryType = .none
                    }
                    
                    return cell
                },
                actionBlock: { [weak self] in
                    self?.selectMint(mint)
                }
            ))
        }
        
        contents.add(mintsSection)
        
        self.contents = contents
    }
    
    // MARK: - Actions
    
    @objc
    private func didTapAddMint() {
        let alert = UIAlertController(
            title: OWSLocalizedString(
                "CASHU_ADD_MINT_TITLE",
                value: "Add mint",
                comment: "Title for add mint dialog"
            ),
            message: OWSLocalizedString(
                "CASHU_ADD_MINT_MESSAGE",
                value: "Enter the mint URL",
                comment: "Message for add mint dialog"
            ),
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "https://mint.example.com"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
        }
        
        alert.addAction(UIAlertAction(
            title: CommonStrings.addButton,
            style: .default
        ) { [weak self, weak alert] _ in
            guard let mintUrl = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !mintUrl.isEmpty,
                  URL(string: mintUrl) != nil else {
                OWSActionSheets.showErrorAlert(message: "Please enter a valid URL")
                return
            }
            self?.addMint(mintUrl)
        })
        
        alert.addAction(UIAlertAction(
            title: CommonStrings.cancelButton,
            style: .cancel
        ))
        
        present(alert, animated: true)
    }
    
    private func addMint(_ mintUrl: String) {
        guard !mints.contains(mintUrl) else {
            presentToast(text: "Mint already exists")
            return
        }
        
        mints.insert(mintUrl, at: 0)
        saveMints()
        updateTableContents()
        presentToast(text: "Mint added")
    }
    
    private func selectMint(_ mint: String) {
        guard mint != activeMint else { return }
        
        let alert = ActionSheetController(
            title: OWSLocalizedString(
                "CASHU_SWITCH_MINT_TITLE",
                value: "Switch mint?",
                comment: "Title for switch mint confirmation"
            ),
            message: OWSLocalizedString(
                "CASHU_SWITCH_MINT_MESSAGE",
                value: "Switching mints will reinitialize your wallet. Make sure your current balance is zero or backed up.",
                comment: "Warning when switching mints"
            )
        )
        
        alert.addAction(ActionSheetAction(
            title: OWSLocalizedString(
                "CASHU_SWITCH_MINT_CONFIRM",
                value: "Switch mint",
                comment: "Confirm switch mint"
            ),
            style: .default
        ) { [weak self] _ in
            self?.performMintSwitch(to: mint)
        })
        
        alert.addAction(OWSActionSheets.cancelAction)
        
        presentActionSheet(alert)
    }
    
    private func performMintSwitch(to mint: String) {
        ModalActivityIndicatorViewController.present(
            fromViewController: self,
            canCancel: false
        ) { [weak self] modal in
            guard let self = self else { return }
            
            Task {
                await CashuIntegration.shared.setMintUrl(mint)
                await MainActor.run {
                    modal.dismiss {
                        self.activeMint = mint
                        self.updateTableContents()
                        self.presentToast(text: "Mint switched")
                        self.navigationController?.popViewController(animated: true)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func extractMintName(from url: String) -> String {
        if let host = URL(string: url)?.host {
            return host
        }
        return url
    }
}

