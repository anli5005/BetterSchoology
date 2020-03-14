//
//  CourseDetailView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

struct CourseDetailView: View {
    var course: Course
    @ObservedObject var materialsStore: CourseMaterialsStore
    
    var body: some View {
        return ScrollView {
            Text(course.courseTitle).font(.largeTitle).fontWeight(.bold).padding()
            MaterialsOutlineView(store: materialsStore).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
