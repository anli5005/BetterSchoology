//
//  AppDelegate.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Cocoa
import SwiftUI
import Combine

fileprivate let keychainQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "dev.anli.BetterSchoology.bca"
]

private extension Dictionary {
    func mergingToCFDictionary(_ other: Dictionary<Key, Value>) -> CFDictionary {
        merging(other, uniquingKeysWith: { _, b in b }) as CFDictionary
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!
    var windowControllers = Set<NSWindowController>()
    var chatWindows = [AnyHashable: NSWindow]()
    
    var hostingController: NSHostingController<AnyView>?

    private var initialAuthCancellable: AnyCancellable?
    private var persistAuthCancellable: AnyCancellable?
    
    private var didFindKeychainItem = false
    
    func getCredentialsFromKeychain() -> SchoologyCredentials? {
        var passwordData: CFTypeRef?
        let status = SecItemCopyMatching(keychainQuery.mergingToCFDictionary([
            kSecReturnData as String: true as CFBoolean
        ]), &passwordData)
        
        if status == errSecSuccess, let data = passwordData as? Data, let password = String(data: data, encoding: .utf8) {
            var dictData: CFTypeRef?
            let attributesStatus = SecItemCopyMatching(keychainQuery.mergingToCFDictionary([
                kSecReturnAttributes as String: true as CFBoolean
            ]), &dictData)
            if attributesStatus == errSecSuccess, let dict = dictData as? [String: Any], let username = dict[kSecAttrAccount as String] as? String {
                didFindKeychainItem = true
                return SchoologyCredentials(username: username, password: password)
            }
        }
        
        return nil
    }
    
    let context = AuthContext()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints")
        
        if let creds = getCredentialsFromKeychain() {
            print("Found credentials")
            initialAuthCancellable = sharedClient.authenticate(credentials: creds).flatMap {
                sharedClient.siteNavigationUiProps()
            }.sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Authentication error: \(error)")
                    DispatchQueue.main.async {
                        self.context.status = .unauthenticated
                    }
                }
            }, receiveValue: { props in
                DispatchQueue.main.async {
                    self.context.status = .authenticated(user: props.props.user, store: SchoologyStore(client: sharedClient))
                }
            })
        } else {
            print("Could not find credentials")
            context.status = .unauthenticated
        }
                
        persistAuthCancellable = context.persistCredentials.sink(receiveValue: { credentials in
            DispatchQueue.global(qos: .utility).async {
                let attributes: [String: Any] = [
                    kSecAttrAccount as String: credentials.username,
                    kSecValueData as String: Data(credentials.password.utf8),
                    kSecAttrLabel as String: "BetterSchoology BCA Password"
                ]
                let status: OSStatus
                if self.didFindKeychainItem {
                    status = SecItemUpdate(keychainQuery as CFDictionary, attributes as CFDictionary)
                    print("Updated keychain, status \(status)")
                } else {
                    status = SecItemAdd(keychainQuery.mergingToCFDictionary(attributes), nil)
                    print("Added to keychain, status \(status)")
                }
                self.didFindKeychainItem = true
            }
        })
        
        do {
            let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("dev.anli.BetterSchoology", isDirectory: true)
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false, attributes: nil)
            }
            let path = dir.appendingPathComponent("downloads.db", isDirectory: false).path
            let db = try FilesDatabase(path)
            sharedDownloadManager = DownloadManager(database: db, client: sharedClient)
        } catch let e {
            print("Error with downloads database: \(e)")
        }
        
        do {
            try sharedDownloadManager.database.setup()
        } catch let e {
            print("Error setting up downloads database: \(e)")
        }
        
        if #available(macOS 11.0, *) {
            return
        }
        
        // Create the SwiftUI view that provides the window contents.
        let contentView = AnyView(ContentView()
            .environmentObject(context)
            .environmentObject(sharedClient))

        // Create the window and set the content view.
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Main Window")
        hostingController = NSHostingController(rootView: contentView)
        window.contentView = hostingController!.view
        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

