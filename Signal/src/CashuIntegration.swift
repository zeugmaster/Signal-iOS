//
// Copyright 2025 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import SignalServiceKit
// Note: To use CashuDevKit, you need to add it as a dependency to the Signal target in Xcode:
// 1. Open Signal.xcworkspace in Xcode
// 2. Select the Signal project in the navigator
// 3. Select the Signal target
// 4. Go to the "General" tab
// 5. In "Frameworks, Libraries, and Embedded Content", click "+"
// 6. Select "CashuDevKit" from the cdk-swift package
// 7. Make sure it's set to "Do Not Embed"

// CashuDevKit is now linked to the Signal target
import CashuDevKit

/// Integration point for Cashu functionality in Signal
class CashuIntegration: NSObject {
    
    // MARK: - Singleton
    
    @objc
    static let shared = CashuIntegration()
    
    // MARK: - Properties
    
    private var wallet: Wallet?
    private var database: WalletSqliteDatabase?
    private let defaultMintUrl = "https://testnut.cashu.space"
    private let defaultMnemonic = generateMnemonic() // Generate a new mnemonic on first use
    
    // MARK: - KeyValueStore for persistence
    
    private static let keyValueStore = KeyValueStore(collection: "CashuWallet")
    private static let walletMnemonicKey = "walletMnemonic"
    private static let mintUrlKey = "mintUrl"
    private static let databasePathKey = "databasePath"
    
    private override init() {
        super.init()
        Task {
            await initializeWallet()
        }
    }
    
    private static func generateMnemonic() -> String {
        // Generate a 12-word mnemonic for the wallet
        // In production, this should use a secure random generator
        // For now, using a placeholder
        return "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    }
    
    // MARK: - Public Methods
    
    /// Initialize Cashu integration
    func initialize() {
        Logger.info("Initializing Cashu integration...")
        Task {
            await initializeWallet()
        }
    }
    
    private func initializeWallet() async {
        do {
            // Get or create database (with filePath)
            let dbPath = getDatabasePath()
            database = try WalletSqliteDatabase(filePath: dbPath)
            
            // Get or create mnemonic
            let mnemonic = await getMnemonic()
            
            // Create wallet config
            let config = WalletConfig(targetProofCount: 3)
            
            // Create wallet
            wallet = try Wallet(
                mintUrl: getMintUrl(),
                unit: .sat,
                mnemonic: mnemonic,
                db: database!,
                config: config
            )
            
            Logger.info("Wallet initialized successfully")
        } catch {
            Logger.error("Failed to initialize wallet: \(error)")
        }
    }
    
    /// Check if Cashu is available
    @objc
    var isAvailable: Bool {
        return wallet != nil
    }
    
    /// Get or create wallet
    func getOrCreateWallet() async throws -> Wallet {
        if let wallet = wallet {
            return wallet
        }
        
        await initializeWallet()
        
        guard let wallet = wallet else {
            throw CashuError.walletNotInitialized
        }
        
        return wallet
    }
    
    /// Get current mint URL
    func getMintUrl() -> String {
        return SSKEnvironment.shared.databaseStorageRef.read { transaction in
            Self.keyValueStore.getString(Self.mintUrlKey, transaction: transaction) ?? defaultMintUrl
        }
    }
    
    /// Set mint URL
    func setMintUrl(_ url: String) async {
        await SSKEnvironment.shared.databaseStorageRef.awaitableWrite { transaction in
            Self.keyValueStore.setString(url, key: Self.mintUrlKey, transaction: transaction)
        }
        // Reinitialize wallet with new mint
        await initializeWallet()
    }
    
    private func getMnemonic() async -> String {
        // First check if we already have a mnemonic
        let existing = SSKEnvironment.shared.databaseStorageRef.read { transaction in
            Self.keyValueStore.getString(Self.walletMnemonicKey, transaction: transaction)
        }
        
        if let existing = existing {
            return existing
        }
        
        // Generate and save new mnemonic
        let newMnemonic = Self.generateMnemonic()
        await SSKEnvironment.shared.databaseStorageRef.awaitableWrite { transaction in
            Self.keyValueStore.setString(newMnemonic, key: Self.walletMnemonicKey, transaction: transaction)
        }
        return newMnemonic
    }
    
    private func getDatabasePath() -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return "\(documentsPath)/cashu_wallet.db"
    }
    
    // MARK: - Cashu Operations
    
    /// Create a new Cashu wallet
    func createWallet() async throws {
        Logger.info("Creating Cashu wallet...")
        await initializeWallet()
    }
    
    /// Mint quote information
    struct MintQuoteInfo {
        let quoteId: String
        let invoice: String
    }
    
    /// Create a mint quote (Lightning invoice)
    func createMintQuote(amount: UInt64) async throws -> MintQuoteInfo {
        Logger.info("Creating mint quote for \(amount) sats")
        let wallet = try await getOrCreateWallet()
        
        let quote = try await wallet.mintQuote(
            amount: Amount(value: amount),
            description: "Add funds to Cashu wallet"
        )
        
        return MintQuoteInfo(
            quoteId: quote.id,
            invoice: quote.request
        )
    }
    
    /// Mint tokens after invoice is paid
    func mintTokens(quoteId: String) async throws {
        Logger.info("Minting tokens for quote: \(quoteId)")
        let wallet = try await getOrCreateWallet()
        
        // Mint the tokens - this will check if paid and throw if not
        let _ = try await wallet.mint(
            quoteId: quoteId,
            amountSplitTarget: .none,
            spendingConditions: nil
        )
        
        Logger.info("Tokens minted successfully")
    }
    
    /// Send Cashu tokens
    func sendTokens(amount: UInt64) async throws -> String {
        Logger.info("Sending \(amount) tokens")
        let wallet = try await getOrCreateWallet()
        
        // Create a token to send using prepareSend API
        let sendOptions = SendOptions(
            memo: nil,
            conditions: nil,
            amountSplitTarget: .none,
            sendKind: .onlineExact,
            includeFee: true,
            maxProofs: nil,
            metadata: [:]
        )
        let preparedSend = try await wallet.prepareSend(amount: Amount(value: amount), options: sendOptions)
        let token = try await preparedSend.confirm(memo: nil)
        
        return token.encode()
    }
    
    /// Receive Cashu tokens
    func receiveTokens(tokenString: String) async throws {
        Logger.info("Receiving tokens...")
        let wallet = try await getOrCreateWallet()
        
        // Parse and receive the token using Token.fromString
        let token = try Token.fromString(encodedToken: tokenString)
        let receiveOptions = ReceiveOptions(
            amountSplitTarget: .none,
            p2pkSigningKeys: [],
            preimages: [],
            metadata: [:]
        )
        let _ = try await wallet.receive(token: token, options: receiveOptions)
        
        Logger.info("Tokens received successfully")
    }
    
    /// Get wallet balance
    func getBalance() async throws -> UInt64 {
        Logger.info("Getting wallet balance...")
        let wallet = try await getOrCreateWallet()
        
        // Get total balance using totalBalance() API
        let balance = try await wallet.totalBalance()
        
        return balance.value
    }
    
    /// Clear wallet
    func clearWallet() async {
        wallet = nil
        database = nil
        
        // Clear stored data
        await SSKEnvironment.shared.databaseStorageRef.awaitableWrite { transaction in
            Self.keyValueStore.removeAll(transaction: transaction)
        }
        
        // Delete database file
        let dbPath = getDatabasePath()
        try? FileManager.default.removeItem(atPath: dbPath)
        
        Logger.info("Wallet cleared")
    }
}

// MARK: - Error Types

public enum CashuError: Error {
    case walletNotInitialized
    case invalidToken
    case insufficientBalance
    case mintConnectionError
    case databaseError
}

// MARK: - Logger Extension

private extension CashuIntegration {
    enum Logger {
        static func info(_ message: String) {
            print("[CashuIntegration] \(message)")
        }
        
        static func error(_ message: String) {
            print("[CashuIntegration] ERROR: \(message)")
        }
    }
}
