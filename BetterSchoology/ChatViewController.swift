//
//  ChatViewController.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/23/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Cocoa
import Combine
import Down
import SwiftSoup

class ChatReplyTextView: NSTextView {
    static let isFirstResponderDidChange = Notification.Name(rawValue: "ChatReplyTextViewIsFirstResponderDidChange")
    static let optionEnter = Notification.Name(rawValue: "ChatReplyTextViewOptionEnter")
    
    var isFirstResponder = false {
        didSet {
            NotificationCenter.default.post(name: ChatReplyTextView.isFirstResponderDidChange, object: self)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string == "" && self.window?.firstResponder != self {
            let placeholder: NSString = "Write a new comment..."
            placeholder.draw(in: bounds.insetBy(dx: textContainerInset.width + 2, dy: textContainerInset.height), withAttributes: [
                .font: font as Any,
                .foregroundColor: NSColor.tertiaryLabelColor
            ])
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        if super.becomeFirstResponder() {
            isFirstResponder = true
            return true
        } else {
            return false
        }
    }
    
    override func resignFirstResponder() -> Bool {
        if super.resignFirstResponder() {
            isFirstResponder = false
            return true
        } else {
            return false
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if [36, 76].contains(event.keyCode) {
            if event.modifierFlags.contains(.option) {
                NotificationCenter.default.post(name: ChatReplyTextView.optionEnter, object: self)
                return
            }
        }
        
        super.keyDown(with: event)
    }
}

class ChatViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextViewDelegate {
    @IBOutlet weak var tableView: NSTableView?
    @IBOutlet weak var refreshButton: NSButton?
    @IBOutlet weak var autoRefreshIntervalPicker: NSPopUpButton?
    @IBOutlet weak var stackView: NSStackView?
    @IBOutlet weak var replyTextView: ChatReplyTextView?
    @IBOutlet weak var postButton: NSButton?
    @IBOutlet weak var replyDescriptionTextField: NSTextField?
    
    private var cancellables = Set<AnyCancellable>()
    private var timerPublisher: AnyCancellable?
   
    private var _discussion: DiscussionMaterialDetail?
    var discussion: DiscussionMaterialDetail? {
        get {
            _discussion
        }
        set {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
                var messages = [(Message, NSAttributedString)]()
                if let discussion = newValue {
                    messages = discussion.messages.values.sorted { a, b in
                        let aId = a.id
                        let bId = b.id
                        let countDiff = aId.count - bId.count
                        if countDiff == 0 {
                            return aId < bId
                        } else {
                            return countDiff < 0
                        }
                    }.map { ($0, DiscussionTableCellView.content(for: $0, messages: discussion.messages)) }
                }
                
                DispatchQueue.main.async {
                    self._discussion = newValue
                    self.sortedMessages = messages
                    self.updateWindow()
                }
            }
        }
    }
    var sortedMessages = [(Message, NSAttributedString)]()
    var store: SchoologyStore? {
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
    var isPosting = false {
        didSet {
            replyTextView?.isEditable = !isPosting
            replyTextView?.alphaValue = isPosting ? 0.7 : 1.0
            replyTextView?.isAutomaticQuoteSubstitutionEnabled = false
            updatePostButton()
        }
    }
    
    static let reuseIdentifier: NSUserInterfaceItemIdentifier = "DiscussionCell"
    
    let autoRefreshIntervals: [TimeInterval?] = [nil, 5, 10, 20, 60]
    
    var replyId: String?
    
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
        tableView?.tableColumns.first?.maxWidth = .infinity
        if let option = autoRefreshIntervalPicker?.indexOfSelectedItem {
            setAutoRefreshInterval(autoRefreshIntervals[option])
        } else {
            setAutoRefreshInterval(20)
        }
        replyTextView?.delegate = self
        replyTextView?.textContainerInset = NSSize(width: 10, height: 10)
        replyTextView?.font = .systemFont(ofSize: 15)
        if let object = replyTextView {
            NotificationCenter.default.publisher(for: ChatReplyTextView.isFirstResponderDidChange, object: object).sink { [weak self] _ in
                self?.updateStackView()
            }.store(in: &cancellables)
            NotificationCenter.default.publisher(for: ChatReplyTextView.optionEnter, object: object).sink { [weak self] _ in
                self?.post()
            }.store(in: &cancellables)
        }
        replyDescriptionTextField?.cell?.truncatesLastVisibleLine = true
        updateWindow()
    }
    
    func updateWindow() {
        if isViewLoaded {
            var shouldScroll = false
            if let table = tableView, let y = table.enclosingScrollView?.contentView.bounds.maxY, y >= table.frame.height - 50 {
                shouldScroll = true
            }
            tableView?.reloadData()
            if let window = view.window {
                window.title = discussion?.fullName ?? "Discussion"
            }
            if shouldScroll {
                tableView?.scrollRowToVisible(sortedMessages.count - 1)
            }
            updateReplyDescriptionTextField()
            updateStackView()
        }
    }
    
    func updateStackView() {
        if let stack = stackView {
            stack.setVisibilityPriority(replyId == nil ? .notVisible : .mustHold, for: stack.views[0])
            if replyTextView?.isFirstResponder == true {
                stack.setVisibilityPriority(.mustHold, for: stack.views[2])
            } else if let textView = replyTextView, let storage = textView.textStorage, storage.length > 0 {
                stack.setVisibilityPriority(.detachOnlyIfNecessary, for: stack.views[2])
            } else {
                stack.setVisibilityPriority(.notVisible, for: stack.views[2])
            }
        }
    }
    
    func updatePostButton() {
        postButton?.isEnabled = !isPosting
        if replyId == nil {
            postButton?.title = isPosting ? "Posting..." : "Post"
        } else {
            postButton?.title = isPosting ? "Replying..." : "Reply"
        }
    }
    
    func updateReplyDescriptionTextField() {
        if let id = replyId {
            guard let message = discussion?.messages[id] else {
                replyId = nil
                return
            }
            
            if let field = replyDescriptionTextField {
                var attributes: [NSAttributedString.Key: Any] = [.font: field.font as Any]
                let str = NSMutableAttributedString(string: "Replying to \(message.authorName): ")
                let text: String
                do {
                    text = try SwiftSoup.parse(message.content).text()
                } catch let e {
                    print("Error parsing HTML: \(e)")
                    text = message.content
                }
                if let font = attributes[.font] as? NSFont {
                    attributes[.font] = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                }
                str.append(NSAttributedString(string: text, attributes: attributes))
                field.attributedStringValue = str
            }
        } else {
            replyDescriptionTextField?.stringValue = "Replying"
        }
        
        updatePostButton()
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
    
    @IBAction func openInBrowser(sender: NSButton?) {
        if let prefix = store?.client.prefix, let suffix = discussion?.material.urlSuffix, let url = URL(string: "\(prefix)\(suffix)") {
            NSWorkspace.shared.open(url)
        }
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
    
    func reply(messageId: String?) {
        replyId = messageId
        updateReplyDescriptionTextField()
        updateStackView()
    }
    
    @IBAction func clearReply(sender: NSButton?) {
        reply(messageId: nil)
    }
    
    func post() {
        if let client = store?.client, let discussion = discussion, !isPosting {
            var content: String
            do {
                content = try Down(markdownString: replyTextView!.string).toHTML([.hardBreaks, .smartUnsafe])
            } catch let e {
                print("Couldn't parse Markdown: \(e)")
                return
            }
            
            do {
                let document = try SwiftSoup.parse(content)
                try document.select("pre").forEach { pre in
                    if !pre.hasAttr("style") {
                        try pre.attr("style", "white-space: pre;")
                    }
                }
                try document.select("pre > code").forEach { code in
                    if !code.hasAttr("style") {
                        try code.attr("style", "white-space: pre; padding: 0;")
                    }
                }
                content = try document.body()?.html() ?? document.html()
            } catch let e {
                print("Couldn't parse HTML from Markdown: \(e)")
            }
            
            isPosting = true
            let parent = replyId
            client.reply(discussion: discussion, parent: parent, content: content).receive(on: DispatchQueue.main).sink(receiveCompletion: { [weak self] completion in
                if case .failure(let e) = completion {
                    print("Error posting: \(e)")
                    self?.isPosting = false
                }
            }, receiveValue: { [weak self] response in
                self?.isPosting = false
                self?.replyTextView?.string = ""
                self?.replyId = nil
                if var newDiscussion = self?.discussion {
                    let message: Message?
                    do {
                        message = try response.message(parent: parent)
                    } catch let e {
                        message = nil
                        print("Error parsing new message: \(e)")
                    }
                    if let message = message {
                        newDiscussion.messages[message.id] = message
                        if let parent = parent {
                            newDiscussion.messages[parent]?.children.append(message.id)
                        } else {
                            newDiscussion.rootMessages.append(message.id)
                        }
                        self!.discussion = newDiscussion
                    }
                }
            }).store(in: &cancellables)
        }
    }
    
    @IBAction func post(sender: NSButton?) {
        post()
    }
    
    @IBAction func markdownReference(sender: NSButton?) {
        if let url = URL(string: "https://commonmark.org/help/") {
            NSWorkspace.shared.open(url)
        }
    }
}
