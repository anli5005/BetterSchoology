//
//  DiscussionView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/21/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

struct DiscussionView: NSViewRepresentable {
    @EnvironmentObject var store: SchoologyStore
    
    static let reuseIdentifier: NSUserInterfaceItemIdentifier = "DiscussionCell"
    
    let id = UUID()
    let discussion: DiscussionMaterialDetail
    let sortedMessages: [Message]
    
    init(discussion: DiscussionMaterialDetail) {
        self.discussion = discussion
        sortedMessages = discussion.messages.values.sorted { a, b in
            let aId = a.id
            let bId = b.id
            let countDiff = aId.count - bId.count
            if countDiff == 0 {
                return aId < bId
            } else {
                return countDiff < 0
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeNSView(context: NSViewRepresentableContext<DiscussionView>) -> NSScrollView {
        let tableView = NSTableView(frame: .zero)
        tableView.addTableColumn(NSTableColumn())
        tableView.headerView = nil
        tableView.usesAutomaticRowHeights = true
        tableView.register(NSNib(nibNamed: "DiscussionTableCellView", bundle: Bundle.main)!, forIdentifier: DiscussionView.reuseIdentifier)
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.rowHeight = 120
        
        let scrollView = NSScrollView(frame: .zero)
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        
        updateTableView(tableView, context: context)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: NSViewRepresentableContext<DiscussionView>) {
        if context.coordinator.parent.id != id {
            updateTableView(nsView.documentView as! NSTableView, context: context)
        }
    }
    
    func updateTableView(_ tableView: NSTableView, context: NSViewRepresentableContext<DiscussionView>) {
        let shouldScrollToBottom = !context.coordinator.wasScrolledToBottom || context.coordinator.parent.discussion.material.id != discussion.material.id
        
        context.coordinator.parent = self
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.reloadData()
        
        if shouldScrollToBottom {
            tableView.scrollRowToVisible(sortedMessages.count - 1)
            context.coordinator.wasScrolledToBottom = true
        }
    }
    
    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var parent: DiscussionView
        init(_ parent: DiscussionView) {
            self.parent = parent
        }
        
        var wasScrolledToBottom = false
                
        func numberOfRows(in tableView: NSTableView) -> Int {
            return parent.sortedMessages.count
        }
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let view = tableView.makeView(withIdentifier: DiscussionView.reuseIdentifier, owner: nil) as! DiscussionTableCellView
            view.coordinator = self
            view.message = parent.sortedMessages[row]
            return view
        }
        
        func tableView(_ tableView: NSTableView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
            return IndexSet()
        }
    }
}

struct DiscussionView_Previews: PreviewProvider {
    static var previews: some View {
        DiscussionView(discussion: DiscussionMaterialDetail(material: Material(id: "", name: "", kind: .discussion, available: nil, due: nil, meta: nil, urlSuffix: ""), fullName: "", content: "", files: [], messages: [:], rootMessages: []))
    }
}
