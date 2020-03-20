//
//  DownloadManager.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/19/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Foundation
import Combine
import AppKit

class DownloadManager: ObservableObject {
    let database: FilesDatabase
    let client: SchoologyClient
    let fileManager: FileManager = .default
    
    @Published var fileStatuses = [String: FileStatus]()
    private var cancellables = Set<AnyCancellable>()
    
    struct FileStatus {
        var downloadStatus: DownloadStatus? = nil
        var diskStatus: DiskFileStatus? = nil
        var downloadPublisher: AnyPublisher<FileStatus, Error>? = nil
    }
    
    enum DownloadStatus {
        case downloading(Progress)
        case error(Error)
    }
    
    enum DiskFileStatus {
        case notOnDisk
        case onDisk(FileDownload)
        case fileError(FileDownload, Error)
        case fetchError(Error)
    }
    
    init(database: FilesDatabase, client: SchoologyClient) {
        self.database = database
        self.client = client
    }
    
    @discardableResult func download(file: SchoologyFile) -> AnyPublisher<FileStatus, Error> {
        if let publisher = fileStatuses[file.id!]?.downloadPublisher {
            return publisher
        }
        
        let subject = PassthroughSubject<FileStatus, Error>()
        let task = client.session.downloadTask(with: file.url!) { (url, response, error) in
            if (response as? HTTPURLResponse)?.statusCode == 200 {
                var result: URL?

                do {
                    let downloads = try self.fileManager.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                    var numAttempts = 0
                    while result == nil {
                        do {
                            var suffix: String?
                            if numAttempts > 10 {
                                suffix = "-\(Int.random(in: 10000..<100000))"
                            } else if numAttempts > 0 {
                                suffix = " (\(numAttempts))"
                            }
                            var destination = downloads.appendingPathComponent(file.id!, isDirectory: false)
                            if let suffix = suffix {
                                let ext = destination.pathExtension
                                let pathComponent: String
                                if ext.count > 0 {
                                    pathComponent = file.id!.prefix(file.id!.count - ext.count - 1) + suffix + "." + ext
                                } else {
                                    pathComponent = file.id! + suffix
                                }
                                destination = destination.deletingLastPathComponent().appendingPathComponent(pathComponent, isDirectory: false)
                            }
                            try self.fileManager.moveItem(at: url!, to: destination)
                            result = destination
                        } catch let e as NSError {
                            numAttempts += 1
                            if e.domain == NSCocoaErrorDomain && e.code == NSFileWriteFileExistsError {
                                if numAttempts >= 20 {
                                    throw e
                                }
                            } else {
                                throw e
                            }
                        }
                    }
                } catch let e {
                    DispatchQueue.main.async {
                        self.fileStatuses[file.id!]?.downloadStatus = .error(e)
                        self.fileStatuses[file.id!]?.downloadPublisher = nil
                    }
                    subject.send(completion: .failure(e))
                }
                
                do {
                    let bookmark = try result!.bookmarkData()
                    let download = FileDownload(id: file.id!, bookmark: bookmark, userVisible: true)
                    try self.database.upsertFile(download)
                    let status = FileStatus(downloadStatus: nil, diskStatus: .onDisk(download), downloadPublisher: nil)
                    DispatchQueue.main.async {
                        self.fileStatuses[file.id!] = status
                    }
                    subject.send(status)
                    subject.send(completion: .finished)
                } catch let e {
                    DispatchQueue.main.async {
                        self.fileStatuses[file.id!]?.downloadStatus = .error(e)
                        self.fileStatuses[file.id!]?.downloadPublisher = nil
                    }
                    subject.send(completion: .failure(e))
                }
            } else if error != nil {
                DispatchQueue.main.async {
                    self.fileStatuses[file.id!]?.downloadStatus = .error(SchoologyParseError.badStatusCode)
                    self.fileStatuses[file.id!]?.downloadPublisher = nil
                }
                subject.send(completion: .failure(SchoologyParseError.badStatusCode))
            } else {
                DispatchQueue.main.async {
                    self.fileStatuses[file.id!]?.downloadStatus = .error(error!)
                    self.fileStatuses[file.id!]?.downloadPublisher = nil
                }
                subject.send(completion: .failure(error!))
            }
        }
        
        task.resume()
        let publisher = subject.eraseToAnyPublisher()
        if fileStatuses[file.id!] == nil {
            fileStatuses[file.id!] = FileStatus(downloadStatus: .downloading(task.progress), diskStatus: nil, downloadPublisher: publisher)
        } else {
            fileStatuses[file.id!]!.downloadStatus = .downloading(task.progress)
            fileStatuses[file.id!]!.downloadPublisher = publisher
        }
        return publisher
    }
    
    func open(download: FileDownload, in workspace: NSWorkspace = .shared) throws {
        var isStale = false
        let url: URL
        do {
            url = try URL(resolvingBookmarkData: download.bookmark, options: .withoutUI, bookmarkDataIsStale: &isStale)
            workspace.open(url)
        } catch let e {
            self.fileStatuses[download.id]?.diskStatus = .fileError(download, e)
            throw e
        }
        
        if isStale {
            DispatchQueue.global(qos: .utility).async {
                do {
                    let data = try url.bookmarkData()
                    var newDownload = download
                    newDownload.bookmark = data
                    try self.database.upsertFile(newDownload)
                } catch let e {
                    print("Error regenerating stale bookmark data: \(e)")
                }
            }
        }
    }
    
    func downloadAndOpen(_ file: SchoologyFile) {
        sharedDownloadManager.download(file: file).sink(receiveCompletion: { _ in }, receiveValue: { status in
            if case .some(.onDisk(let download)) = status.diskStatus {
                try? sharedDownloadManager.open(download: download)
            }
        }).store(in: &cancellables)
    }
}
