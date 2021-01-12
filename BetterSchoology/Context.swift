//
//  AuthContext.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI
import Combine
import Quartz

class AuthContext: ObservableObject {
    @Published var status = Status.unknown
    
    let persistCredentials = PassthroughSubject<SchoologyCredentials, Never>()
    
    enum Status {
        case unknown
        case unauthenticated
        case authenticated(user: User, store: SchoologyStore)
    }
}

class QuickLookContext: NSObject, QLPreviewPanelDelegate, QLPreviewPanelDataSource {
    let panel = QLPreviewPanel.shared()
    
    override init() {
        super.init()
        panel?.delegate = self
        panel?.dataSource = self
    }
    
    var current: (URL, (() -> Void)?)? {
        didSet {
            if let done = oldValue?.1, oldValue?.0 != current?.0 {
                done()
            }
            panel?.reloadData()
        }
    }
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return current == nil ? 0 : 1
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return current?.0 as QLPreviewItem?
    }
}

extension SchoologyClient: ObservableObject {}

let sharedClient = SchoologyClient(sessionConfiguration: .default, prefix: "https://bca.schoology.com", schoolId: "11897239", materialDetailFetchers: [
    SimpleLinkFetcher(),
    PageLinkFetcher(),
    PageFetcher(),
    FileFetcher(),
    AssignmentFetcher(),
    QuizFetcher(),
    DiscussionFetcher(),
    FolderFetcher()
])

var sharedDownloadManager = DownloadManager(database: try! FilesDatabase(), client: sharedClient)

let userDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    formatter.doesRelativeDateFormatting = true
    return formatter
}()

let sharedQuickLook = QuickLookContext()
