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
        let badge: String?
        switch materialsStore.materials[nil] {
        case .none, .some(.loading):
            badge = "Loading..."
        case .some(.done(.failure(_))):
            badge = "Error"
        default:
            badge = nil
        }
        
        return VStack {
            Text(course.courseTitle).font(.largeTitle).fontWeight(.bold).padding()
            ZStack(alignment: .center) {
                MaterialsOutlineView(store: materialsStore).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if badge != nil {
                    Text(badge!).fontWeight(.bold).foregroundColor(Color.white).padding().background(Color.black).cornerRadius(8.0).opacity(0.5)
                }
            }
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
