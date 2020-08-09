//
//  App.swift
//  BetterSchoology
//
//  Created by Anthony Li on 8/8/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

@available(macOS 11.0, iOS 14.0, *) struct BetterSchoologyApp: App {
    @NSApplicationDelegateAdaptor var delegate: AppDelegate
    var context: AuthContext {
        delegate.context
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(context).environmentObject(sharedClient)
        }
    }
}
