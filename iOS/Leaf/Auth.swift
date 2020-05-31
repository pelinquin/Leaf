/* local auth */

import LocalAuthentication

class authController {
    struct Credentials {
        var username: String
        var password: String
    }
    let server = "adox.io"
    struct KeychainError: Error {
        var status: OSStatus
        var localizedDescription: String {
            return SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error."
        }
    }

    func tapAdd(_ sender: Any) {
        let credentials = Credentials(username: "appleseed", password: "1234")
        do {
            try addCredentials(credentials, server: server)
            print("Added credentials.")
        } catch {
            if let error = error as? KeychainError { print(error.localizedDescription)}
        }
    }
    
    func read(_ sender: Any,_ value: Int) -> Bool {
        do {
            let credentials = try readCredentials(server: server, value)
            print("Read credentials: \(credentials.username)/\(credentials.password)")
            return true
        } catch {
            if let error = error as? KeychainError { print(error.localizedDescription)}
            return false
        }
    }
    
    func tapRead(_ sender: Any) {
        do {
            let credentials = try readCredentials(server: server)
            print("Read credentials: \(credentials.username)/\(credentials.password)")
        } catch {
            if let error = error as? KeychainError {print(error.localizedDescription)}
        }
    }

    func tapDelete(_ sender: Any) {
        do {
            try deleteCredentials(server: server)
            print("Deleted credentials.")
        } catch {
            if let error = error as? KeychainError {print(error.localizedDescription)}
        }
    }

    func show(status: String) { print (status)}

    func addCredentials(_ credentials: Credentials, server: String) throws {
        let account = credentials.username
        let password = credentials.password.data(using: String.Encoding.utf8)!
        let access = SecAccessControlCreateWithFlags(nil, // Use the default allocator.
                                                     kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                     .userPresence,
                                                     nil) // Ignore any error.
        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = 10
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccount as String: account,
                                    kSecAttrServer as String: server,
                                    kSecAttrAccessControl as String: access as Any,
                                    kSecUseAuthenticationContext as String: context,
                                    kSecValueData as String: password]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func readCredentials(server: String, _ value: Int = 0) throws -> Credentials {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrServer as String: server,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecUseOperationPrompt as String: "Ready to pay \(value)",
                                    kSecReturnData as String: true]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let existingItem = item as? [String: Any],
            let passwordData = existingItem[kSecValueData as String] as? Data,
            let password = String(data: passwordData, encoding: String.Encoding.utf8),
            let account = existingItem[kSecAttrAccount as String] as? String
            else {
                throw KeychainError(status: errSecInternalError)
        }
        return Credentials(username: account, password: password)
    }

    func deleteCredentials(server: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrServer as String: server]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }
}
