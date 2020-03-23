//
//  ChatViewController.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/23/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Cocoa

class ChatViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet weak var tableView: NSTableView?
    var discussion: DiscussionMaterialDetail? {
        didSet {
            if let discussion = discussion {
                sortedMessages = discussion.messages.values.sorted { a, b in
                    let aId = a.id
                    let bId = b.id
                    let countDiff = aId.count - bId.count
                    if countDiff == 0 {
                        return aId < bId
                    } else {
                        return countDiff < 0
                    }
                }.map { ($0, DiscussionTableCellView.content(for: $0, messages: discussion.messages)) }
            } else {
                sortedMessages = []
            }
            tableView?.reloadData()
            updateWindow()
        }
    }
    var sortedMessages = [(Message, NSAttributedString)]()
    
    static let reuseIdentifier: NSUserInterfaceItemIdentifier = "DiscussionCell"
    
    override func viewDidLoad() {
        tableView?.usesAutomaticRowHeights = false
        tableView?.rowHeight = 120
        tableView?.register(NSNib(nibNamed: "DiscussionTableCellView", bundle: Bundle.main)!, forIdentifier: ChatViewController.reuseIdentifier)
        tableView?.delegate = self
        tableView?.dataSource = self
        tableView?.reloadData()
        
        updateWindow()
    }
    
    func updateWindow() {
        if isViewLoaded {
            if let window = view.window {
                window.title = discussion?.fullName ?? "Discussion"
            }
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return sortedMessages.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = tableView.makeView(withIdentifier: ChatViewController.reuseIdentifier, owner: nil) as! DiscussionTableCellView
        view.message = sortedMessages[row].0
        view.text = sortedMessages[row].1
        return view
    }
    
    func tableView(_ tableView: NSTableView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
        return IndexSet()
    }
    
    let textView: NSTextView = {
        let view = NSTextView(frame: .zero)
        view.textContainerInset = NSSize(width: 5, height: 5)
        return view
    }()
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let width: CGFloat = view.frame.width - 10
        let str = sortedMessages[row].1
        textView.textStorage?.setAttributedString(str)
        if let container = textView.textContainer, let manager = textView.layoutManager {
            textView.frame.size.width = width
            container.size = CGSize(width: width, height: .greatestFiniteMagnitude)
            let size = manager.boundingRect(forGlyphRange: NSMakeRange(0, str.length), in: container)
            return size.height + 30
        } else {
            return 120
        }
    }
    
    func windowDidResize() {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        tableView?.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: sortedMessages.indices))
        NSAnimationContext.endGrouping()
    }
}
