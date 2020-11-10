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

enum DownloadError: Error {
    case fileNotFound
    case unauthorizedBySandbox
}

class DownloadManager: ObservableObject {
    let database: FilesDatabase
    let client: SchoologyClient
    let fileManager: FileManager = .default
    
    @Published var fileStatuses = [String: FileStatus]()
    private var cancellables = Set<AnyCancellable>()
    
    struct FileStatus {
        var downloadStatus: DownloadStatus? = nil
        var diskStatus: DiskFileStatus? = nil
        var locateError: Error? = nil
        var downloadPublisher: AnyPublisher<FileStatus, Error>? = nil
        var diskPublisher: AnyPublisher<DiskFileStatus, Never>? = nil
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
                
                var base = "..a" + (file.name ?? file.id!)
                if base.starts(with: ".") {
                    base.removeFirst(base.reduce(0, { $0 + ($1 == "." ? 1 : 0) }))
                }
                
                do {
                    let downloads = try self.fileManager.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                    
                    var useBetterSchoologyFolder = false
                    var isDirectory: ObjCBool = false
                    let betterSchoologyFolder = downloads.appendingPathComponent("BetterSchoology", isDirectory: true)
                    if self.fileManager.fileExists(atPath: betterSchoologyFolder.path, isDirectory: &isDirectory) {
                        useBetterSchoologyFolder = isDirectory.boolValue
                    } else {
                        do {
                            try self.fileManager.createDirectory(at: betterSchoologyFolder, withIntermediateDirectories: false, attributes: nil)
                            useBetterSchoologyFolder = true
                        } catch let e {
                            print("Error creating BetterSchoology folder: \(e)")
                        }
                    }
                    
                    var numAttempts = 0
                    while result == nil {
                        do {
                            var suffix: String?
                            if numAttempts > 10 {
                                suffix = "-\(Int.random(in: 10000..<100000))"
                            } else if numAttempts > 0 {
                                suffix = " (\(numAttempts))"
                            }
                            var destination: URL
                            if numAttempts > 15 || !useBetterSchoologyFolder {
                                destination = downloads.appendingPathComponent(base, isDirectory: false)
                            } else {
                                destination = betterSchoologyFolder.appendingPathComponent(base, isDirectory: false)
                            }
                            if let suffix = suffix {
                                let ext = destination.pathExtension
                                let pathComponent: String
                                if ext.count > 0 {
                                    pathComponent = base.prefix(base.count - ext.count - 1) + suffix + "." + ext
                                } else {
                                    pathComponent = base + suffix
                                }
                                destination = destination.deletingLastPathComponent().appendingPathComponent(pathComponent, isDirectory: false)
                            }
                            try self.fileManager.moveItem(at: url!, to: destination)
                            result = destination
                        } catch let e as NSError {
                            numAttempts += 1
                            if e.domain == NSCocoaErrorDomain {
                                if numAttempts >= 20 {
                                    throw e
                                }
                            } else {
                                throw e
                            }
                        }
                        
                        self.locate(file: file, at: result!, subject: subject)
                    }
                } catch let e {
                    DispatchQueue.main.async {
                        self.fileStatuses[file.id!]?.downloadStatus = .error(e)
                        self.fileStatuses[file.id!]?.downloadPublisher = nil
                    }
                    subject.send(completion: .failure(e))
                }
            } else if error == nil {
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
        DispatchQueue.main.async {
            if self.fileStatuses[file.id!] == nil {
                self.fileStatuses[file.id!] = FileStatus(downloadStatus: .downloading(task.progress), downloadPublisher: publisher)
            } else {
                self.fileStatuses[file.id!]!.downloadStatus = .downloading(task.progress)
                self.fileStatuses[file.id!]!.downloadPublisher = publisher
            }
        }
        return publisher
    }
    
    func locate(file: SchoologyFile, at url: URL, subject: PassthroughSubject<FileStatus, Error>? = nil, useLocateErrors: Bool = false) {
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope)
            let download = FileDownload(id: file.id!, bookmark: bookmark, userVisible: true)
            try self.database.upsertFile(download)
            let status = FileStatus(downloadStatus: nil, diskStatus: .onDisk(download), downloadPublisher: nil)
            DispatchQueue.main.async {
                self.fileStatuses[file.id!] = status
            }
            subject?.send(status)
            subject?.send(completion: .finished)
        } catch let e {
            DispatchQueue.main.async {
                if useLocateErrors {
                    self.fileStatuses[file.id!]?.locateError = e
                } else {
                    self.fileStatuses[file.id!]?.downloadStatus = .error(e)
                    self.fileStatuses[file.id!]?.downloadPublisher = nil
                }
            }
            subject?.send(completion: .failure(e))
        }
    }
    
    @discardableResult func diskStatus(id: String, queue: DispatchQueue = .global(qos: .userInitiated), force: Bool = false) -> AnyPublisher<DiskFileStatus, Never> {
        if let publisher = fileStatuses[id]?.diskPublisher {
            return publisher
        }
        
        if !force && fileStatuses[id]?.diskStatus != nil {
            return Just(fileStatuses[id]!.diskStatus!).eraseToAnyPublisher()
        }
        
        let subject = PassthroughSubject<DiskFileStatus, Never>()
        
        queue.async {
            let status: DiskFileStatus
            do {
                if var download = try self.database.file(id: id) {
                    do {
                        var isStale = false
                        let url = try URL(resolvingBookmarkData: download.bookmark, options: [.withoutUI, .withSecurityScope], bookmarkDataIsStale: &isStale)
                        _ = url.startAccessingSecurityScopedResource()
                        
                        if isStale {
                            do {
                                let data = try url.bookmarkData(options: .withSecurityScope)
                                download.bookmark = data
                                try self.database.upsertFile(download)
                            } catch let e {
                                print("Error regenerating stale bookmark data: \(e)")
                            }
                        }
                        
                        if !self.fileManager.fileExists(atPath: url.path) {
                            url.stopAccessingSecurityScopedResource()
                            throw DownloadError.fileNotFound
                        }
                        
                        url.stopAccessingSecurityScopedResource()
                        status = .onDisk(download)
                    } catch let e {
                        status = .fileError(download, e)
                    }
                } else {
                    status = .notOnDisk
                }
            } catch let e {
                status = .fetchError(e)
            }
            
            DispatchQueue.main.async {
                self.fileStatuses[id]?.diskStatus = status
                self.fileStatuses[id]?.diskPublisher = nil
            }
            subject.send(status)
            subject.send(completion: .finished)
        }
        
        let publisher = subject.eraseToAnyPublisher()
        DispatchQueue.main.async {
            if self.fileStatuses[id] == nil {
                self.fileStatuses[id] = FileStatus(diskPublisher: publisher)
            } else {
                self.fileStatuses[id]!.diskPublisher = publisher
            }
        }
        return publisher
    }
    
    func withURL(of download: FileDownload, _ run: (URL, @escaping () -> Void) throws -> Void) throws {
        var isStale = false
        let url: URL
        do {
            url = try URL(resolvingBookmarkData: download.bookmark, options: [.withoutUI, .withSecurityScope], bookmarkDataIsStale: &isStale)
            if !url.startAccessingSecurityScopedResource() {
                throw DownloadError.unauthorizedBySandbox
            }
        } catch let e {
            self.fileStatuses[download.id]?.diskStatus = .fileError(download, e)
            throw e
        }
        
        try run(url) {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

extension DownloadManager {
    func open(download: FileDownload, in workspace: NSWorkspace = .shared) throws {
        try withURL(of: download) { (url, done) in
            workspace.open(url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
                done()
            }
        }
    }
    
    func revealInFinder(download: FileDownload, in workspace: NSWorkspace = .shared) throws {
        try withURL(of: download, { (url, done) in
            workspace.activateFileViewerSelecting([url])
            done()
        })
    }
    
    @discardableResult func downloadAndOpen(_ file: SchoologyFile, in workspace: NSWorkspace = .shared) -> AnyPublisher<Void, Error> {
        let subject = PassthroughSubject<Void, Error>()
        diskStatus(id: file.id!, force: true).mapError { $0 as Error }.flatMap { status -> AnyPublisher<FileDownload, Error> in
            switch status {
            case .notOnDisk, .fileError(_, _), .fetchError(_):
                return self.download(file: file).map { status in
                    guard case .some(.onDisk(let download)) = status.diskStatus else {
                        return nil
                    }
                    
                    return download
                }.filter { $0 != nil }.map{ $0! }.eraseToAnyPublisher()
            case .onDisk(let download):
                return Just(download).mapError { $0 as Error }.eraseToAnyPublisher()
            }
        }.tryMap { download in
            try self.open(download: download, in: workspace)
        }.sink(receiveCompletion: { completion in
            if case .failure(let e) = completion {
                subject.send(completion: .failure(e))
            }
        }, receiveValue: { _ in
            subject.send()
            subject.send(completion: .finished)
        }).store(in: &self.cancellables)
        return subject.eraseToAnyPublisher()
    }
}
