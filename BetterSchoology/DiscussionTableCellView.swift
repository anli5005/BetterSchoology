//
//  DiscussionTableCellView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/21/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Cocoa
import SwiftSoup

class DiscussionTableCellView: NSTableCellView, NSTextViewDelegate {
    @IBOutlet weak var contentView: NSView?
    @IBOutlet weak var likeButton: NSButton?
    
    // weak var coordinator: DiscussionView.Coordinator?
    
    static let likedIndicator = "🥴"
    
    let textView = NSTextView(frame: .zero)
    
    static let unableToParse = attributedString(pageContent: "Unable to parse message.")!
    
    override func awakeFromNib() {
        textView.textContainerInset = NSSize(width: 5, height: 5)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.backgroundColor = .clear
        textView.delegate = self
        
        contentView?.addSubview(textView)
    }
    
    static func content(for message: Message, messages: [String: Message]? = nil) -> NSAttributedString {
        let content = NSMutableAttributedString()
        
        content.append(NSAttributedString(string: message.authorName + "\n", attributes: [
            .underlineStyle: message.isAdmin ? NSUnderlineStyle.single.rawValue : NSUnderlineStyle().rawValue,
            .font: NSFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: NSColor.textColor
        ]))
        
        if let date = message.date {
            content.append(NSAttributedString(string: userDateFormatter.string(from: date) + "\n", attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]))
        }
        
        if let parentId = message.parent {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]
             
            if let messages = messages, let parent = messages[parentId] {
                // attributes[.link] = URL(string: "betterschoology-internal://jump-to-parent")!
                content.append(NSAttributedString(string: "Replying to \(parent.authorName): ", attributes: attributes))
                let excerptLength = 48
                let text = (try? SwiftSoup.parse(parent.content).text()) ?? parent.content
                var excerpt = String(text.prefix(excerptLength))
                if text.count > excerptLength {
                    excerpt += "..."
                }
                
                content.append(NSAttributedString(string: excerpt, attributes: attributes.merging([
                    .font: NSFontManager.shared.convert(attributes[.font] as! NSFont, toHaveTrait: .italicFontMask)
                ], uniquingKeysWith: { _, b in b })))
                content.append(NSAttributedString(string: "\n", attributes: attributes))
            } else {
                content.append(NSAttributedString(string: "Replying\n", attributes: attributes))
            }
        }
        
        content.append(NSAttributedString(string: "\n"))
        
        var pageContent = message.content
        do {
            let document = try SwiftSoup.parse(message.content)
            
            if let body = document.body(), let last = body.children().last(), last.tagName().lowercased() == "p" {
                if !last.hasAttr("style") {
                    try last.attr("style", "margin-bottom: 0;")
                    pageContent = try body.html()
                }
            }
        } catch let e {
            print("Error parsing page content: \(e)")
        }
        content.append(attributedString(pageContent: pageContent) ?? DiscussionTableCellView.unableToParse)
        
        return content
    }
    
    var message: Message? {
        didSet {
            if let message = message, message.id != oldValue?.id {
                if let button = likeButton {
                    var buttonText = message.liked ? DiscussionTableCellView.likedIndicator : "Like"
                    if message.likes > 0 {
                        buttonText += " (\(message.likes))"
                    }
                    button.title = buttonText
                    button.isEnabled = false
                }
            }
        }
    }
    
    var text = NSAttributedString() {
        didSet {
            textView.textStorage?.setAttributedString(text)
        }
    }
    
    @IBAction func openInSchoology(sender: NSButton?) {
        /* if
            let coordinator = coordinator,
            let id = message?.id,
            let url = URL(string: "\(coordinator.parent.store.client.prefix)/\(coordinator.parent.discussion.material.urlSuffix)#comment-\(id)")
        {
            NSWorkspace.shared.open(url)
        } */
    }
    
    @IBAction func like(sender: NSButton?) {
        
    }
        
    func textDidEndEditing(_ notification: Notification) {
        textView.setSelectedRange(NSMakeRange(0, 0))
    }
    
    override func layout() {
        super.layout()
        if let view = contentView {
            textView.frame = view.bounds
        }
    }
}
