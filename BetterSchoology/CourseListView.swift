//
//  CourseListView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

struct CourseListView: View {
    @EnvironmentObject var store: SchoologyStore
    
    @State var selected: Course?
    
    var body: some View {
        store.requestCourses()
        
        if case .some(.done(let result)) = store.courses {
            switch result {
            case .success(let courses):
                return AnyView(List(courses) { course in
                    NavigationLink(destination: CourseDetailView(course: course, materialsStore: self.store.courseMaterialsStore(for: course.id)).environmentObject(self.store)) {
                        CourseListItemView(course: course).padding(.vertical, 8)
                    }.contextMenu {
                        Button(action: {
                            NSWorkspace.shared.open(URL(string: "\(self.store.client.prefix)/course/\(course.nid)")!)
                        }) {
                            Text("Open in Web Browser")
                            #if os(iOS)
                            Image(systemName: "safari")
                            #endif
                        }
                    }
                }
                .listStyle(SidebarListStyle()))
            case .failure(_):
                return AnyView(Text("Error loading courses."))
            }
        } else {
            return AnyView(Text("Loading courses..."))
        }
    }
}

struct CourseListView_Previews: PreviewProvider {
    static var previews: some View {
        CourseListView()
    }
}

