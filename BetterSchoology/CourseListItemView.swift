//
//  CourseListView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

struct CourseListItemView: View {
    var course: Course
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(course.courseTitle).fontWeight(.bold)
            Text(course.sectionTitle).opacity(0.5)
        }
    }
}

struct CourseListItemView_Previews: PreviewProvider {
    static var previews: some View {
        let course = try! JSONDecoder().decode(Course.self, from: Data("""
        {"nid":2208074382,"courseTitle":"Functional Programming","sectionTitle":"4-6(A-B,D-E)","buildingTitle":"Bergen County Academies","logoImgSrc":"https:\\/\\/bca.schoology.com\\/sites\\/all\\/themes\\/schoology_theme\\/images\\/course-default.svg","courseNid":2198069905,"weight":23,"isCsl":false,"adminType":"none"}
        """.utf8))
        return Group {
            CourseListItemView(course: course).padding().environment(\.colorScheme, .light).background(Color.white)
            CourseListItemView(course: course).padding().environment(\.colorScheme, .dark).background(Color.black)
        }
    }
}

