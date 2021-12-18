//
//  UpcomingView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 12/18/21.
//  Copyright © 2021 Anthony Li. All rights reserved.
//

import SwiftUI

struct UpcomingView: View {
    var content: some View {
        Text("Select a course to get started.").padding().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var body: some View {
        if #available(macOS 11.0, *) {
            return AnyView(content.toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                    }, label: {
                        Label("Sidebar", systemImage: "sidebar.leading")
                    })
                }
                ToolbarItem(placement: .primaryAction) {
                    Spacer()
                }
            })
        } else {
            return AnyView(content)
        }
    }
}
