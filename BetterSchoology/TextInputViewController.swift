//
//  TextInputViewController.swift
//  BetterSchoology
//
//  Created by Anthony Li on 1/10/21.
//  Copyright © 2021 Anthony Li. All rights reserved.
//

import Foundation
import AppKit
import SwiftUI

// TODO: Replace this entire class.
class TextInputViewController: NSViewController {
    @IBOutlet weak var titleLabel: NSTextField?
    @IBOutlet weak var textView: NSTextView?
    @IBOutlet weak var cancelButton: NSButton?
    @IBOutlet weak var saveButton: NSButton?
    
    var initialText: String?
    var currentID: UUID?
    var cancel: (() -> Void)?
    var save: ((String) -> Void)?
    var isClosing = false {
        didSet {
            cancelButton?.isEnabled = !isClosing
            saveButton?.isEnabled = !isClosing
        }
    }
    
    init() {
        super.init(nibName: "TextInputViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBAction func cancel(sender: Any) {
        isClosing = true
        cancel?()
    }
    
    @IBAction func save(sender: Any) {
        isClosing = true
        let text = textView?.string ?? ""
        save?(text)
    }
    
    func setTitle(_ title: String) {
        titleLabel?.stringValue = title
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let text = initialText {
            textView?.string = text
            initialText = nil
        }
    }
    
    func updateText(_ text: String, id: UUID) {
        if currentID != id {
            if isViewLoaded {
                textView?.string = text
            } else {
                // Save text for update later
                initialText = text
            }
            currentID = id
            isClosing = false
        }
    }
}

// TODO: Combine with ChatReplyTextView
class TextInputTextView: NSTextView {
    @IBOutlet weak var controller: TextInputViewController?
    
    override func keyDown(with event: NSEvent) {
        if [36, 76].contains(event.keyCode) {
            if event.modifierFlags.contains(.option) {
                controller?.save(sender: self)
                return
            }
        }
        
        super.keyDown(with: event)
    }
}

struct TextInputDialog: NSViewControllerRepresentable {
    var id: UUID
    var title: String
    var initialText: String
    var cancel: () -> Void
    var save: (String) -> Void
    
    func makeNSViewController(context: Context) -> TextInputViewController {
        let controller = TextInputViewController()
        updateNSViewController(controller, context: context)
        return controller
    }
    
    func updateNSViewController(_ nsViewController: TextInputViewController, context: Context) {
        nsViewController.setTitle(title)
        nsViewController.updateText(initialText, id: id)
        nsViewController.cancel = cancel
        nsViewController.save = save
    }
}
