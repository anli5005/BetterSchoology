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
    @Binding var selectedMaterial: Material?
    @available(macOS 10.16, *) @EnvironmentObject var appDelegate: AppDelegate
    
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
        outlineView.focusRingType = .none
        outlineView.rowHeight = 18
        
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
        var selectSubject = PassthroughSubject<Material?, Never>()
        var selectCancellable: AnyCancellable?
        var doubleClickCancellables = [String: AnyCancellable]()
        
        init(_ parent: MaterialsOutlineView) {
            self.parent = parent
            self.selectCancellable = selectSubject.debounce(for: 0.15, scheduler: DispatchQueue.main).sink(receiveValue: { material in
                parent.selectedMaterial = material
            })
        }
        
        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            let id = item as? String
            
            parent.store.requestFolder(id: id)
            
            if let result = parent.store.materials[id] {
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
        
        /* func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            let view = (outlineView.makeView(withIdentifier: "MaterialRowView", owner: self) as? NSTextField) ?? { () -> NSTextField in
                let result = NSTextField(labelWithString: "")
                result.frame.size.width = outlineView.frame.width
                result.identifier = "MaterialRowView"
                
                return result
            }()
            let material = parent.store.materialsById[item as! String]!
            if let column = tableColumn {
                view.stringValue = (Column(rawValue: column.identifier)!.value(for: material) as? String) ?? ""
            } else {
                view.stringValue = material.name
            }
            return view
        } */
        
        /* func outlineViewItemDidExpand(_ notification: Notification) {
            if let id = notification.userInfo?["NSObject"] as? String {
                parent.store.requestFolder(id: id)
            }
        } */
        
        func outlineView(_ outlineView: NSOutlineView, shouldEdit tableColumn: NSTableColumn?, item: Any) -> Bool {
            return false
        }
        
        func outlineViewSelectionDidChange(_ notification: Notification) {
            if let sender = notification.object as? NSOutlineView {
                if let id = sender.item(atRow: sender.selectedRow) as? String {
                    selectSubject.send(parent.store.materialsById[id]!)
                } else {
                    selectSubject.send(nil)
                }
            }
        }
        
        func doubleClick(material: Material, with clickable: DoubleClickable? = nil) {
            if clickable?.acceptsDoubleClick == true {
                let delegate: AppDelegate
                if #available(macOS 10.16, *) {
                    delegate = parent.appDelegate
                } else {
                    delegate = NSApp.delegate as! AppDelegate
                }
                clickable!.handleDoubleClick(courseMaterialsStore: parent.store, delegate: delegate)
            } else if let url = URL(string: parent.globalStore.client.prefix + material.urlSuffix) {
                NSWorkspace.shared.open(url)
            } else {
                print("Unable to open \(material.urlSuffix)")
            }
        }
        
        @objc func doubleClick(sender: NSOutlineView) {
            if let id = sender.item(atRow: sender.clickedRow) as? String {
                let material = parent.store.materialsById[id]!
                if let type = parent.globalStore.client.detailFetcher(for: material)?.type(for: material), type is DoubleClickable.Type {
                    if doubleClickCancellables[id] == nil {
                        let loadable = parent.store.materialDetails[id]
                        if case .some(.done(.success(let detail))) = loadable {
                            doubleClick(material: material, with: (detail as! DoubleClickable))
                        } else {
                            parent.store.requestMaterialDetails(material: material)
                            doubleClickCancellables[id] = parent.store.materialDetailsPublishers[id]!.sink(receiveCompletion: { _ in }, receiveValue: { detail in
                                self.doubleClick(material: material, with: (detail as! DoubleClickable))
                                self.doubleClickCancellables[id] = nil
                            })
                        }
                    }
                } else {
                    doubleClick(material: material)
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
