//
//  FilesDatabase.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/18/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import Foundation
import SQLite
import Combine

struct FileDownload {
    var id: String
    var bookmark: Data
    var userVisible: Bool
}

class FilesDatabase {
    let db: Connection
    
    let files = Table("files")
    
    let id = Expression<String>("id")
    let bookmark = Expression<SQLite.Blob>("bookmark")
    let userVisible = Expression<Bool>("userVisible")
    let path = Expression<String?>("path")
    let hash = Expression<Blob?>("hash")
    let hashAlg = Expression<String?>("hashAlg")
    let meta = Expression<Blob?>("meta")
    
    init(_ connection: Connection) {
        self.db = connection
    }
    
    convenience init(_ filename: String) throws {
        self.init(try Connection(filename))
    }
    
    convenience init() throws {
        self.init(try Connection())
    }
    
    func setup() throws {
        try db.run(files.create(ifNotExists: true) { table in
            table.column(id, primaryKey: true)
            table.column(bookmark)
            table.column(path)
            table.column(hash)
            table.column(hashAlg)
            table.column(meta)
            table.column(userVisible)
        })
    }
    
    func file(id: String) throws -> FileDownload? {
        guard let row = try db.prepare(files.filter(self.id == id)).first(where: { _ in true }) else {
            return nil
        }
        
        return FileDownload(id: row[self.id], bookmark: Data(row[bookmark].bytes), userVisible: row[userVisible])
    }
    
    func upsertFile(_ file: FileDownload) throws {
        let dbFile = files.filter(id == file.id)
        let setters = [bookmark <- Blob(bytes: [UInt8](file.bookmark)), userVisible <- file.userVisible]
        
        if try db.run(dbFile.update(setters)) < 1 {
            try db.run(files.insert([id <- file.id] + setters))
        }
    }
}

extension FilesDatabase {
    func filePublisher(id: String, queue: DispatchQueue = .global(qos: .userInitiated)) -> Future<FileDownload?, Error> {
        return Future { promise in
            queue.async {
                do {
                    let download = try self.file(id: id)
                    promise(.success(download))
                } catch let e {
                    promise(.failure(e))
                }
            }
        }
    }
}
