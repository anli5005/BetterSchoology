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
        
        if let result = store.courses {
            switch result {
            case .success(let courses):
                return AnyView(List(courses) { course in
                    NavigationLink(destination: Text(course.courseTitle).padding().frame(maxWidth: .infinity, maxHeight: .infinity)) {
                        CourseListItemView(course: course)
                    }
                })
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

