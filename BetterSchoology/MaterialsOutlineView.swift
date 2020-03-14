//
//  MaterialsOutlineView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/14/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Cocoa
import SwiftUI
import Combine

struct MaterialsOutlineView: NSViewRepresentable {
    func updateNSView(_ nsView: NSOutlineView, context: NSViewRepresentableContext<MaterialsOutlineView>) {
        
    }
    
    var store: CourseMaterialsStore
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: NSViewRepresentableContext<MaterialsOutlineView>) -> NSOutlineView {
        let outlineView = NSOutlineView(frame: .zero)
        outlineView.delegate = context.coordinator
        outlineView.dataSource = context.coordinator
        
        let column = NSTableColumn()
        column.title = "Name"
        outlineView.addTableColumn(column)
                
        context.coordinator.listenCancellable = store.reloadPublisher.sink(receiveValue: { _ in
            outlineView.reloadData()
        })
        
        outlineView.reloadData()
        
        store.requestFolder(id: nil)
        
        return outlineView
    }
    
    class Coordinator: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource {
        let parent: MaterialsOutlineView
        
        var listenCancellable: AnyCancellable?
        
        init(_ parent: MaterialsOutlineView) {
            self.parent = parent
        }
        
        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            if let result = parent.store.materials[item as? String] {
                if case .done(.success(let materials)) = result {
                    return materials.count
                }
            }
            
            return 0
        }
        
        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            guard case .done(.success(let materials)) = parent.store.materials[item as? String] else {
                fatalError("Attempt to fetch unloaded Material")
            }
            return materials[index].id
        }
        
        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            return parent.store.materialsById[item as! String]!.kind == .folder
        }
        
        func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
            return parent.store.materialsById[item as! String]!.name
        }
        
        func outlineViewItemDidExpand(_ notification: Notification) {
            if let id = notification.userInfo?["NSObject"] as? String {
                parent.store.requestFolder(id: id)
            }
        }
    }
}
