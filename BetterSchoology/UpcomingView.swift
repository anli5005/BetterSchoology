//
//  UpcomingView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 12/18/21.
//  Copyright © 2021 Anthony Li. All rights reserved.
//

import SwiftUI

struct UpcomingMaterialView: View {
    @EnvironmentObject var store: SchoologyStore
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var material: UpcomingMaterial
    var isOverdue: Bool
    @Binding var selectedMaterial: UpcomingMaterial?
    
    var course: Course? {
        if case .course(_) = material.realm, case .done(.success(let courses)) = store.courses {
            return courses.first(where: { material.realm.isIn(course: $0) })
        }
        
        return nil
    }
    
    var realmDescription: String {
        switch material.realm {
        case .course(let description):
            return description
        case .unknown(let description):
            return description
        case .school(let description):
            return description
        }
    }
    
    var body: some View {
        let isSelected = selectedMaterial?.id == material.id
        return Button {
            selectedMaterial = material
        } label: {
            VStack(alignment: .leading) {
                HStack(spacing: 2) {
                    if #available(macOS 11.0, *) {
                        switch material.realm {
                        case .course(_):
                            Image(systemName: "rectangle.on.rectangle").accessibilityLabel(Text("Course"))
                        case .unknown(_):
                            Image(systemName: "circle.fill").accessibilityLabel(Text("Other"))
                        case .school(_):
                            Image(systemName: "building.2").accessibilityLabel(Text("School"))
                        }
                    }
                    if let course = course {
                        Text(course.courseTitle)
                    } else {
                        Text(realmDescription)
                    }
                }.foregroundColor(.primary.opacity(0.8))
                
                Spacer().frame(height: 8)
                
                Text(material.material.kind.userVisibleName?.uppercased() ?? "OTHER").font(.caption).fontWeight(.medium).kerning(1.05).opacity(0.6)
                if #available(macOS 11.0, *) {
                    Text(material.material.name).fontWeight(.bold).font(.title3)
                } else {
                    Text(material.material.name).fontWeight(.bold).font(.caption)
                }
                
                if isOverdue || material.material.dueTime == true {
                    Spacer().frame(height: 8)
                }
                
                HStack {
                    if isOverdue {
                        HStack(spacing: 2) {
                            if #available(macOS 11.0, *) {
                                Image(systemName: "calendar")
                            }
                            Text("\(material.material.due!, formatter: userDateOnlyFormatter)")
                        }
                    }
                    if material.material.dueTime == true {
                        HStack(spacing: 2) {
                            if #available(macOS 11.0, *) {
                                Image(systemName: "clock")
                            }
                            Text("\(material.material.due!, formatter: userTimeOnlyFormatter)")
                        }
                    }
                }.foregroundColor(isOverdue ? .red : .primary.opacity(0.8))
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8).background(colorScheme == .dark ? Color.primary.opacity(0.1) : Color.white).border(Color.accentColor, width: isSelected ? 2 : 0).cornerRadius(4).shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 0)
        }.buttonStyle(PlainButtonStyle()).padding(.horizontal)
    }
}

struct UpcomingViewHeading: View {
    var text: Text
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            text.fontWeight(.bold).font(.headline)
            Divider()
        }.padding(.horizontal).padding(.top, 8)
    }
}

struct UpcomingView: View {
    @EnvironmentObject var store: SchoologyStore
    @State var selectedMaterial: UpcomingMaterial?
    
    enum ListItem: Identifiable {
        case heading(date: Date)
        case material(material: UpcomingMaterial)
        
        var id: AnyHashable {
            switch self {
            case .heading(let date):
                return AnyHashable(date)
            case .material(let material):
                return AnyHashable(material.id)
            }
        }
    }
    
    func getListItems(fromUpcomingMaterials upcomingMaterials: [UpcomingMaterial]) -> [ListItem] {
        let calendar = Calendar(identifier: .gregorian)
        let groups = [Date: [UpcomingMaterial]](grouping: upcomingMaterials, by: { material in
            return calendar.date(bySettingHour: 0, minute: 0, second: 0, of: material.material.due!) ?? material.material.due!
        })
        var items = [ListItem]()
        for (date, materials) in groups.sorted(by: { $0.key < $1.key }) {
            items.append(.heading(date: date))
            items.append(contentsOf: materials.map { ListItem.material(material: $0) })
        }
        return items
    }
    
    var isLoading: Bool {
        guard let overdueMaterials = store.overdueMaterials else {
            return true
        }
        
        if case .loading = overdueMaterials {
            return true
        }
        
        guard let upcomingMaterials = store.upcomingMaterials else {
            return true
        }
        
        if case .loading = upcomingMaterials {
            return true
        }
        
        return false
    }
    
    var listContent: some View {
        return Group {
            switch store.overdueMaterials {
            case .some(.done(.success(let materials))):
                UpcomingViewHeading(text: Text("Overdue")).foregroundColor(.red)
                ForEach(materials) { material in
                    UpcomingMaterialView(material: material, isOverdue: true, selectedMaterial: $selectedMaterial)
                }
            case .some(.done(.failure(_))):
                Text("Error")
            default:
                EmptyView()
            }
            switch store.upcomingMaterials {
            case .some(.done(.success(let materials))):
                ForEach(getListItems(fromUpcomingMaterials: materials)) { item in
                    switch item {
                    case .heading(let date):
                        UpcomingViewHeading(text: Text("\(date, formatter: userLongDateOnlyFormatter)"))
                    case .material(let material):
                        UpcomingMaterialView(material: material, isOverdue: false, selectedMaterial: $selectedMaterial)
                    }
                }
            case .some(.done(.failure(_))):
                Text("Error")
            default:
                EmptyView()
            }
            VStack {
                Text("That's all, folks!").italic().font(.title).opacity(0.6)
                Button {
                    NSWorkspace.shared.open(URL(string: "https://github.com/anli5005/BetterSchoology")!)
                } label: {
                    HStack {
                        Text("Made with ❤️ by anli")
                        if #available(macOS 11.0, *) {
                            Image(systemName: "arrow.up.right")
                        }
                    }
                }.buttonStyle(LinkButtonStyle())
            }.frame(maxWidth: .infinity, alignment: .center).padding(.top, 32).padding(.bottom, 36)
        }
    }
    
    var content: some View {
        let detail: MaterialDetail?
        let detailError: Error?
        
        if let material = selectedMaterial {
            store.requestMaterialDetails(material: material.material)
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
        
        return HStack(spacing: 0) {
            ZStack {
                ScrollView {
                    if #available(macOS 11.0, *) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            listContent
                        }.frame(maxWidth: .infinity, alignment: .topLeading)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            listContent
                        }.frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }.frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                if isLoading {
                    if #available(macOS 11.0, *) {
                        ProgressView().foregroundColor(Color.white).padding().background(Color.black).cornerRadius(8.0).opacity(0.5)
                    } else {
                        Text("Loading...").fontWeight(.bold).foregroundColor(Color.white).padding().background(Color.black).cornerRadius(8.0).opacity(0.5)
                    }
                }
            }
            Divider()
            Group {
                if selectedMaterial != nil {
                    if detail != nil {
                        MaterialDetailView(materialDetail: detail!)
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
    }
    
    var body: some View {
        store.requestOverdueMaterials()
        store.requestUpcomingMaterials()
        
        if #available(macOS 11.0, *) {
            return AnyView(content.toolbar {
                SidebarButton()
                ToolbarItem(placement: .primaryAction) {
                    RefreshButton(action: {
                        selectedMaterial = nil
                        self.store.materialDetails = [:]
                        self.store.overdueMaterials = nil
                        self.store.upcomingMaterials = nil
                        self.store.requestOverdueMaterials()
                        self.store.requestUpcomingMaterials()
                    })
                }
            }.navigationTitle("Upcoming"))
        } else {
            return AnyView(content)
        }
    }
}
