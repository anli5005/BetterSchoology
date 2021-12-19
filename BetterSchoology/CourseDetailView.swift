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
    @EnvironmentObject var store: SchoologyStore
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
            store.requestMaterialDetails(material: material)
            switch store.materialDetails[material.id] {
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
        
        let stack = HStack(spacing: 0) {
            VStack(spacing: 0) {
                if #available(macOS 11.0, iOS 14.0, *) {
                    EmptyView()
                } else {
                    Text(course.courseTitle).font(.largeTitle).fontWeight(.bold).padding().multilineTextAlignment(.center)
                    Button(action: {
                        self.materialsStore.materials = [:]
                        self.store.materialDetails = [:]
                        self.materialsStore.reloadPublisher.send()
                        self.materialsStore.requestFolder(id: nil)
                    }) {
                        Text("Reload Materials")
                    }.padding(.bottom)
                }
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
                        MaterialDetailView(materialDetail: detail!).environmentObject(self.materialsStore)
                    } else if detailError != nil {
                        Text("Error loading details").padding()
                    } else {
                        if #available(macOS 11.0, iOS 14.0, *) {
                            ProgressView("Loading details...").progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Loading details...").padding()
                        }
                    }
                } else {
                    Text("Select a material").padding()
                }
            }.frame(maxHeight: .infinity).frame(width: 400)
        }
        
        if #available(macOS 11.0, iOS 14.0, *) {
            let view = stack.toolbar {
                SidebarButton()
                ToolbarItem(placement: .primaryAction) {
                    RefreshButton(action: {
                        self.materialsStore.materials = [:]
                        self.store.materialDetails = [:]
                        self.materialsStore.reloadPublisher.send()
                        self.materialsStore.requestFolder(id: nil)
                    })
                }
                ToolbarItem(content: {
                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "\(self.store.client.prefix)/course/\(course.nid)")!)
                    }, label: {
                        Label("Open in Web Browser", systemImage: "safari")
                    })
                })
            }.navigationTitle(course.courseTitle)
            if !course.sectionTitle.isEmpty {
                return AnyView(view.navigationSubtitle(Text(course.sectionTitle)))
            } else {
                return AnyView(view)
            }
        } else {
            return AnyView(stack)
        }
    }
}
