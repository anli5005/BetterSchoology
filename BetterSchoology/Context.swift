//
//  AuthContext.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI
import Combine

class AuthContext: ObservableObject {
    @Published var status = Status.unknown
    
    let persistCredentials = PassthroughSubject<SchoologyCredentials, Never>()
    
    enum Status {
        case unknown
        case unauthenticated
        case authenticated(user: User, store: SchoologyStore)
    }
}

extension SchoologyClient: ObservableObject {}

let sharedClient = SchoologyClient(session: URLSession(configuration: .default), prefix: "https://bca.schoology.com", schoolId: "11897239", materialDetailFetchers: [
    SimpleLinkFetcher(),
    PageLinkFetcher(),
    PageFetcher(),
    FileFetcher(),
    AssignmentFetcher(),
    DiscussionFetcher()
])

var sharedDownloadManager = DownloadManager(database: try! FilesDatabase(), client: sharedClient)

let userDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()
