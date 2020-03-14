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
        let theMaterials = materialsStore.materials(in: nil)
        
        return VStack(alignment: .leading) {
            Text(course.courseTitle).font(.largeTitle).fontWeight(.bold)
            (try? theMaterials?.get()).map({ materials in
                List(materials) { material in
                    Text(material.name)
                }
            })
        }.padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
