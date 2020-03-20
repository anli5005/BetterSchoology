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
    @State var selectedMaterial: Material?
    
    var body: some View {
        let badge: String?
        let detail: MaterialDetail?
        let detailError: Error?
        
        switch materialsStore.materials[nil] {
        case .none, .some(.loading):
            badge = "Loading..."
        case .some(.done(.failure(_))):
            badge = "Error"
        default:
            badge = nil
        }
                
        if let material = selectedMaterial {
            materialsStore.requestMaterialDetails(material: material)
            switch materialsStore.materialDetails[material.id] {
            case .none, .some(.loading):
                detail = nil
                detailError = nil
            case .some(.done(.failure(let error))):
                detail = nil
                detailError = error
            case .some(.done(.success(let result))):
                detail = result
                detailError = nil
            }
        } else {
            detail = nil
            detailError = nil
        }
        
        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(course.courseTitle).font(.largeTitle).fontWeight(.bold).padding().multilineTextAlignment(.center)
                Button(action: {
                    self.materialsStore.materials = [:]
                    self.materialsStore.materialDetails = [:]
                    self.materialsStore.reloadPublisher.send()
                    self.materialsStore.requestFolder(id: nil)
                }) {
                    Text("Reload Materials")
                }.padding(.bottom)
                ZStack(alignment: .center) {
                    MaterialsOutlineView(store: materialsStore, selectedMaterial: $selectedMaterial).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    if badge != nil {
                        Text(badge!).fontWeight(.bold).foregroundColor(Color.white).padding().background(Color.black).cornerRadius(8.0).opacity(0.5)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            Group {
                if selectedMaterial != nil {
                    if detail != nil {
                        MaterialDetailView(materialDetail: detail!)
                    } else if detailError != nil {
                        Text("Error loading details").padding()
                    } else {
                        Text("Loading details...").padding()
                    }
                } else {
                    Text("Select a material").padding()
                }
            }.frame(maxHeight: .infinity).frame(width: 480)
        }
    }
}
