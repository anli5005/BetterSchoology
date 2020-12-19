//
//  MainView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        if #available(OSX 11.0, *) {
            AnyView(NavigationView {
                CourseListView().frame(minWidth: 200, maxWidth: 400, maxHeight: .infinity)
                Text("Select a course to get started.").padding().frame(maxWidth: .infinity, maxHeight: .infinity).toolbar {
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
                }
            })
        } else {
            AnyView(NavigationView {
                CourseListView().frame(minWidth: 200, maxWidth: 400, maxHeight: .infinity)
                Text("Select a course to get started.").padding().frame(maxWidth: .infinity, maxHeight: .infinity)
            })
        }
    }
}
