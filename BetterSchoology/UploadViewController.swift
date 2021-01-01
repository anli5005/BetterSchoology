//
//  UploadViewController.swift
//  BetterSchoology
//
//  Created by Anthony Li on 1/1/21.
//  Copyright © 2021 Anthony Li. All rights reserved.
//

import AppKit
import Foundation
import SwiftUI

struct UploadProgress: Identifiable {
    let id: UUID
}

struct UploadConfirmation: Identifiable {
    let id: UUID
    let alert: Alert
}

class UploadViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    var client: SchoologyClient
    var destination: SubmissionAccepting {
        didSet {
            assert(destination.acceptsSubmissions)
            if destination.submitURLSuffix != oldValue.submitURLSuffix {
                items = []
            }
        }
    }
    let filePromiseQueue = OperationQueue()
    fileprivate var coordinator: InternalUploadView.Coordinator?
    
    @IBOutlet weak var tableView: NSTableView?
    @IBOutlet weak var submitButton: NSButton?
    
    enum UploadItem {
        case loading(promise: NSFilePromiseReceiver)
        case url(URL)
        case error(Error)
    }
    
    var items = [UploadItem]() {
        didSet {
            tableView?.reloadData()
            submitButton?.isEnabled = !items.isEmpty && items.allSatisfy { item in
                if case .url(_) = item {
                    return true
                }
                return false
            }
        }
    }
    
    init(destination: SubmissionAccepting, with client: SchoologyClient = sharedClient) {
        self.destination = destination
        self.client = client
        super.init(nibName: "UploadViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        view.registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) } + [.fileURL])
        (view as? UploadContainerView)?.uploadController = self
        tableView?.delegate = self
        tableView?.dataSource = self
        tableView?.reloadData()
        submitButton?.isEnabled = !items.isEmpty && items.allSatisfy { item in
            if case .url(_) = item {
                return true
            }
            return false
        }
    }
    
    func handle(draggingInfo: NSDraggingInfo) -> Bool {
        let pasteboard = draggingInfo.draggingPasteboard
        if let promises = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil)?.compactMap({ $0 as? NSFilePromiseReceiver }), !promises.isEmpty {
            promises.forEach { promise in
                let destinationURL: URL
                do {
                    destinationURL = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: FileManager.default.homeDirectoryForCurrentUser, create: true)
                } catch let e {
                    items.append(.error(e))
                    return
                }
                items.append(.loading(promise: promise))
                promise.receivePromisedFiles(atDestination: destinationURL, options: [:], operationQueue: filePromiseQueue) { (fileURL, error) in
                    OperationQueue.main.addOperation { [weak self] in
                        guard let self = self else { return }
                        
                        if let index = self.items.firstIndex(where: { item in
                            if case .loading(let itemPromise) = item {
                                return itemPromise == promise
                            } else {
                                return false
                            }
                        }) {
                            if let error = error {
                                self.items.replaceSubrange(index...index, with: [.error(error)])
                            } else {
                                self.items.replaceSubrange(index...index, with: [.url(fileURL)])
                            }
                        }
                    }
                }
            }
            return true
        } else {
            let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: nil) ?? []).compactMap { $0 as? URL }
            if !urls.isEmpty && !urls.contains(where: { url in
                var isDirectory: ObjCBool = false
                if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                    return true
                }
                return isDirectory.boolValue
            }) {
                urls.forEach { self.items.append(.url($0)) }
                return true
            }
        }
        return false
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch items[row] {
        case .loading(_):
            let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("LoadingCell"), owner: nil)
            view?.subviews.lazy.compactMap { $0 as? NSProgressIndicator }.first?.startAnimation(self)
            return view
        case .error(_):
            return tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ErrorCell"), owner: nil)
        case .url(let url):
            if let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("URLCell"), owner: nil) as? NSTableCellView {
                view.textField?.stringValue = url.lastPathComponent
                return view
            }
            return nil
        }
    }
    
    @IBAction func submit(sender: Any?) {
        coordinator?.parent.uploadConfirmation = UploadConfirmation(id: UUID(), alert: Alert(title: Text("Submit \(items.count) file(s)?"), message: Text("This action can't be undone."), primaryButton: Alert.Button.default(Text("Submit")) { [weak self] in
            self?.coordinator?.parent.uploadConfirmation = nil
        }, secondaryButton: Alert.Button.cancel { [weak self] in
            self?.coordinator?.parent.uploadConfirmation = nil
        }))
    }
}

class UploadContainerView: NSView {
    weak var uploadController: UploadViewController?
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        if pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil)?.compactMap({ $0 as? NSFilePromiseReceiver }).isEmpty == false {
            return .copy
        } else {
            let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: nil) ?? []).compactMap { $0 as? URL }
            if !urls.isEmpty && !urls.contains(where: { url in
                var isDirectory: ObjCBool = false
                if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                    return true
                }
                return isDirectory.boolValue
            }) {
                return .copy
            } else {
                return []
            }
        }
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return uploadController?.handle(draggingInfo: sender) ?? false
    }
}

private struct InternalUploadView: NSViewControllerRepresentable {
    var destination: SubmissionAccepting
    @Binding var uploadProgress: UploadProgress?
    @Binding var uploadConfirmation: UploadConfirmation?
    
    func makeNSViewController(context: Context) -> UploadViewController {
        let controller = UploadViewController(destination: destination)
        controller.coordinator = context.coordinator
        return controller
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func updateNSViewController(_ nsViewController: UploadViewController, context: Context) {
        nsViewController.destination = destination
        nsViewController.coordinator = context.coordinator
    }
    
    struct Coordinator {
        var parent: InternalUploadView
    }
}

struct UploadView: View {
    var destination: SubmissionAccepting
    @State var uploadProgress: UploadProgress?
    @State var uploadConfirmation: UploadConfirmation?
    
    var body: some View {
        InternalUploadView(destination: destination, uploadProgress: $uploadProgress, uploadConfirmation: $uploadConfirmation).sheet(item: $uploadProgress, content: { uploadProgress in
            Text("Uploading...")
        }).alert(item: $uploadConfirmation, content: { $0.alert })
    }
}
