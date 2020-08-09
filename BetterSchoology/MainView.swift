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
                    ToolbarItem(placement: .primaryAction) {
                        RefreshButton()
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
