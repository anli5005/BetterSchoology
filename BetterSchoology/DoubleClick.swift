//
//  DoubleClick.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/16/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Cocoa

protocol DoubleClickable {
    var acceptsDoubleClick: Bool { get }
    func handleDoubleClick()
}

extension LinkMaterialDetail: DoubleClickable {
    var acceptsDoubleClick: Bool { url != nil }
    func handleDoubleClick() {
        NSWorkspace.shared.open(url!)
    }
}

extension FileMaterialDetail: DoubleClickable {
    var acceptsDoubleClick: Bool { file.id != nil }
    func handleDoubleClick() {
        sharedDownloadManager.downloadAndOpen(file)
    }
}

extension DiscussionMaterialDetail: DoubleClickable {
    var acceptsDoubleClick: Bool { true }
    func handleDoubleClick() {
        DispatchQueue.main.async {
            self.openChatWindow()
        }
    }
}
