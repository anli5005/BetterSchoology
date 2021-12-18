//
//  MainView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

struct MainView: View {
    @State var selectedItem: CourseListView.Item? = CourseListView.Item.upcoming
    
    var body: some View {
        NavigationView {
            CourseListView(selectedItem: $selectedItem).frame(minWidth: 200, maxWidth: 400, maxHeight: .infinity)
            if #available(macOS 11.0, *) {
                EmptyView().toolbar {}
            }
        }
    }
}
