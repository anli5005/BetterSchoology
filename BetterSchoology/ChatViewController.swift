//
//  ChatViewController.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/23/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Cocoa
import Combine

class ChatViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet weak var tableView: NSTableView?
    @IBOutlet weak var refreshButton: NSButton?
    @IBOutlet weak var autoRefreshIntervalPicker: NSPopUpButton?
    
    private var cancellables = Set<AnyCancellable>()
    private var timerPublisher: AnyCancellable?
   
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
            updateWindow()
        }
    }
    var sortedMessages = [(Message, NSAttributedString)]()
    var store: CourseMaterialsStore? {
        didSet {
            store?.$materialDetails.sink { [weak self] details in
                if let id = self?.discussion?.material.id {
                    if case .some(let loadable) = details[id] {
                        DispatchQueue.main.async {
                            if let self = self {
                                switch loadable {
                                case .done(let result):
                                    if case .success(let discussion as DiscussionMaterialDetail) = result {
                                        self.discussion = discussion
                                    }
                                    self.refreshButton?.isEnabled = true
                                default:
                                    self.refreshButton?.isEnabled = false
                                }
                            }
                        }
                    }
                }
            }.store(in: &cancellables)
        }
    }
    
    static let reuseIdentifier: NSUserInterfaceItemIdentifier = "DiscussionCell"
    
    let autoRefreshIntervals: [TimeInterval?] = [nil, 5, 10, 20, 60]
    
    func setAutoRefreshInterval(_ timeInterval: TimeInterval?) {
        if let interval = timeInterval {
            timerPublisher = Timer.publish(every: interval, on: .main, in: .common).autoconnect().sink { [weak self] _ in
                self?.refresh()
            }
        } else {
            timerPublisher = nil
        }
    }
    
    override func viewDidLoad() {
        tableView?.usesAutomaticRowHeights = false
        tableView?.rowHeight = 120
        tableView?.register(NSNib(nibNamed: "DiscussionTableCellView", bundle: Bundle.main)!, forIdentifier: ChatViewController.reuseIdentifier)
        tableView?.delegate = self
        tableView?.dataSource = self
        if let option = autoRefreshIntervalPicker?.indexOfSelectedItem {
            setAutoRefreshInterval(autoRefreshIntervals[option])
        } else {
            setAutoRefreshInterval(20)
        }
        updateWindow()
    }
    
    func updateWindow() {
        if isViewLoaded {
            var shouldScroll = false
            if let table = tableView, let y = table.enclosingScrollView?.contentView.bounds.maxY, y >= table.frame.height - 240 {
                shouldScroll = true
            }
            tableView?.reloadData()
            if let window = view.window {
                window.title = discussion?.fullName ?? "Discussion"
            }
            if shouldScroll {
                tableView?.scrollRowToVisible(sortedMessages.count - 1)
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
        view.controller = self
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
    
    @IBAction func changeAutoRefreshInterval(sender: NSPopUpButton?) {
        if let sender = sender {
            setAutoRefreshInterval(autoRefreshIntervals[sender.indexOfSelectedItem])
        }
    }
    
    func refresh() {
        if let material = discussion?.material, let store = store {
            store.requestMaterialDetails(material: material, force: true)
        }
    }
    
    @IBAction func refresh(sender: NSButton?) {
        refreshButton?.isEnabled = false
        refresh()
    }
    
    func openInSchoology(id: String) {
        if let prefix = store?.client.prefix, let suffix = discussion?.material.urlSuffix, let url = URL(string: "\(prefix)\(suffix)#comment-\(id)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func like(messageId: String) {
        if let store = store {
            let oldMessage = discussion?.messages[messageId]
            if var message = oldMessage {
                message.liked.toggle()
                message.likes += message.liked ? 1 : -1
                discussion!.messages[messageId] = message
            }
            
            store.client.like(messageId: messageId, csrf: discussion?.csrf).sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    print("Error parsing like response: \(error)")
                    DispatchQueue.main.async {
                        if let oldMessage = oldMessage, var message = self?.discussion?.messages[messageId] {
                            message.liked = oldMessage.liked
                            message.likes = oldMessage.likes
                            self!.discussion!.messages[messageId] = message
                        }
                    }
                }
            }, receiveValue: { [weak self] response in
                DispatchQueue.main.async {
                    if var message = self?.discussion?.messages[messageId] {
                        message.liked = response.liked
                        message.likes = response.c
                        self!.discussion!.messages[messageId] = message
                    }
                }
            }).store(in: &cancellables)
        }
    }
}
