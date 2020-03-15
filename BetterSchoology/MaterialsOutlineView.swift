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

extension NSUserInterfaceItemIdentifier: ExpressibleByStringLiteral {
    public init(stringLiteral: String) {
        self.init(rawValue: stringLiteral)
    }
}

struct MaterialsOutlineView: NSViewRepresentable {
    enum Column: NSUserInterfaceItemIdentifier, CaseIterable {
        case name = "name"
        case kind = "kind"
    }
    
    func updateNSView(_ nsView: NSScrollView, context: NSViewRepresentableContext<MaterialsOutlineView>) {
        
    }
    
    @EnvironmentObject var globalStore: SchoologyStore
    var store: CourseMaterialsStore
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: NSViewRepresentableContext<MaterialsOutlineView>) -> NSScrollView {
        let outlineView = NSOutlineView(frame: .zero)
        outlineView.delegate = context.coordinator
        outlineView.dataSource = context.coordinator
        outlineView.target = context.coordinator
        outlineView.doubleAction = #selector(Coordinator.doubleClick(sender:))
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle
        outlineView.allowsColumnReordering = true
        
        Column.allCases.forEach { column in
            let tableColumn = NSTableColumn()
            tableColumn.title = column.title
            tableColumn.identifier = column.rawValue
            outlineView.addTableColumn(tableColumn)
        }
                
        context.coordinator.listenCancellable = store.reloadPublisher.sink(receiveValue: { _ in
            outlineView.reloadData()
        })
        
        outlineView.reloadData()
        
        store.requestFolder(id: nil)
                
        let scrollView = NSScrollView(frame: .zero)
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        
        return scrollView
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
            let material = parent.store.materialsById[item as! String]!
            if let column = tableColumn {
                return Column(rawValue: column.identifier)!.value(for: material)
            } else {
                return material.name
            }
        }
        
        func outlineViewItemDidExpand(_ notification: Notification) {
            if let id = notification.userInfo?["NSObject"] as? String {
                parent.store.requestFolder(id: id)
            }
        }
        
        func outlineView(_ outlineView: NSOutlineView, shouldEdit tableColumn: NSTableColumn?, item: Any) -> Bool {
            return false
        }
        
        @objc func doubleClick(sender: NSOutlineView) {
            if let id = sender.item(atRow: sender.clickedRow) as? String {
                let material = parent.store.materialsById[id]!
                if let url = URL(string: parent.globalStore.client.prefix + material.urlSuffix) {
                    NSWorkspace.shared.open(url)
                } else {
                    print("Unable to open \(material.urlSuffix)")
                }
            }
        }
    }
}

extension MaterialsOutlineView.Column {
    var title: String {
        switch self {
        case .name:
            return "Name"
        case .kind:
            return "Kind"
        }
    }
    
    func value(for material: Material) -> Any? {
        switch self {
        case .name:
            return material.name
        case .kind:
            switch material.kind {
            case .file:
                return "File"
            case .link:
                return "Link"
            case .assignment:
                return "Assignment"
            case .page:
                return "Page"
            case .discussion:
                return "Discussion"
            case .quiz:
                return "Assessment"
            default:
                return nil
            }
        }
    }
}
