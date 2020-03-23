//
//  ChatWindowController.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/22/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Cocoa

class ChatWindowController: NSWindowController, NSWindowDelegate {

    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.delegate = self
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    func windowWillClose(_ notification: Notification) {
        if let delegate = NSApp.delegate as? AppDelegate {
            if let id = (contentViewController as? ChatViewController)?.discussion?.material.id {
                delegate.chatWindows[id] = nil
            }
            delegate.windowControllers.remove(self)
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        (contentViewController as? ChatViewController)?.windowDidResize()
    }

}
