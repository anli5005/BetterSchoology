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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!

    var initialAuthCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let context = AuthContext()
        initialAuthCancellable = sharedClient.siteNavigationUiProps().sink(receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Error: \(error)")
                DispatchQueue.main.async {
                    context.status = .unauthenticated
                }
            }
        }, receiveValue: { props in
            DispatchQueue.main.async {
                context.status = .authenticated(user: props.props.user, store: SchoologyStore(client: sharedClient))
            }
        })
        
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()
            .environmentObject(context)
            .environmentObject(sharedClient)

        // Create the window and set the content view. 
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

