//
//  CourseListView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

struct CourseListView: View {
    enum Item: Hashable {
        case upcoming
        case course(nid: Int)
    }
    
    @EnvironmentObject var store: SchoologyStore
    
    @Binding var selectedItem: Item?
    
    var body: some View {
        store.requestCourses()
        
        return List {
            NavigationLink(destination: UpcomingView().environmentObject(self.store), tag: Item.upcoming, selection: $selectedItem) {
                if #available(macOS 11.0, *) {
                    Label("Upcoming", systemImage: "calendar.badge.clock")
                } else {
                    Text("Upcoming").fontWeight(.bold).padding(.vertical, 8)
                }
            }
            Section {
                if case .some(.done(let result)) = store.courses {
                    switch result {
                    case .success(let courses):
                        ForEach(courses) { course in
                            NavigationLink(destination: CourseDetailView(course: course, materialsStore: self.store.courseMaterialsStore(for: course.id)).environmentObject(self.store), tag: Item.course(nid: course.nid), selection: $selectedItem) {
                                if #available(macOS 11.0, *) {
                                    Label(course.courseTitle, systemImage: "rectangle.on.rectangle")
                                } else {
                                    CourseListItemView(course: course).padding(.vertical, 8)
                                }
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
                    case .failure(_):
                        Text("Error loading courses.")
                    }
                } else {
                    Text("Loading courses...")
                }
            } header: {
                Text("Courses")
            }
        }.listStyle(SidebarListStyle())
    }
}

