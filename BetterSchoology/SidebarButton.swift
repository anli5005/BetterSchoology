//
//  SidebarButton.swift
//  BetterSchoology
//
//  Created by Anthony Li on 12/18/21.
//  Copyright © 2021 Anthony Li. All rights reserved.
//

import SwiftUI

@available(macOS 11.0, *)
struct SidebarButton: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: {
                NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
            }, label: {
                Label("Sidebar", systemImage: "sidebar.leading")
            })
        }
    }
}
