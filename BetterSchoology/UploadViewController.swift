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
import Combine
import Dispatch

// MARK: Basic Structs

struct UploadProgress: Identifiable {
    let id: UUID
    var fileCount: Int
    var isCanceling: Bool
    var status: Status
    var error: Error?
    
    enum Status {
        case fetchingDetails
        case uploading(uploaded: Int, current: String)
        case submitting
        case complete
    }
}

extension UploadProgress {
    var progress: Double {
        switch status {
        case .fetchingDetails:
            return 0
        case .uploading(let uploaded, _):
            return Double(uploaded + 1) / Double(fileCount + 2)
        case .submitting:
            return Double(fileCount + 1) / Double(fileCount + 2)
        case .complete:
            return 1
        }
    }
    
    var canCancel: Bool {
        if isCanceling { return false }
        switch status {
        case .submitting, .complete:
            return false
        default:
            return true
        }
    }
}

struct UploadConfirmation: Identifiable {
    let id: UUID
    let alert: Alert
}

enum UploadError: LocalizedError {
    case emptyFile
    
    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "Empty files are not supported due to a limitation with Schoology."
        }
    }
}

// MARK: UploadViewController

class UploadViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate, NSServicesMenuRequestor {
    var client: SchoologyClient
    var destination: SubmissionAccepting {
        didSet {
            assert(destination.acceptsSubmissions)
            if destination.submitURLSuffix != oldValue.submitURLSuffix {
                clearItems()
            }
        }
    }
    let filePromiseQueue = OperationQueue()
    fileprivate var coordinator: InternalUploadView.Coordinator?
    var cancellables = Set<AnyCancellable>()
    
    @IBOutlet weak var tableView: NSTableView?
    @IBOutlet weak var submitButton: NSButton?
    @IBOutlet weak var addButton: NSButton?
    
    enum UploadItem {
        case loading(promise: NSFilePromiseReceiver, url: URL)
        case url(url: URL, isTemporary: Bool)
    }
    
    // MARK: Setup & View Reloading
    
    var items = [UploadItem]() {
        didSet {
            tableView?.reloadData()
            submitButton?.isEnabled = items.allSatisfy { item in
                if case .url(_, _) = item {
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
        submitButton?.isEnabled = items.allSatisfy { item in
            if case .url(_, _) = item {
                return true
            }
            return false
        }
        addButton?.menu?.delegate = self
    }
    
    // MARK: File Handling
    
    func handleFileAddError(_ error: Error) {
        print(error)
        coordinator?.parent.uploadConfirmation = UploadConfirmation(id: UUID(), alert: Alert(title: Text("An error occurred while adding the file."), message: Text(error.localizedDescription), dismissButton: Alert.Button.default(Text("OK")) { [weak self] in
            self?.coordinator?.parent.uploadConfirmation = nil
        }))
    }
    
    func verifyFile(at url: URL) throws {
        if let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber {
            if size.intValue == 0 {
                throw UploadError.emptyFile
            }
        }
    }
    
    func handle(draggingInfo: NSDraggingInfo) -> Bool {
        let pasteboard = draggingInfo.draggingPasteboard
        if let promises = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil)?.compactMap({ $0 as? NSFilePromiseReceiver }), !promises.isEmpty {
            promises.forEach { promise in
                let destinationURL: URL
                do {
                    let tempURL = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: FileManager.default.homeDirectoryForCurrentUser, create: true)
                    destinationURL = tempURL.appendingPathComponent(UUID().uuidString)
                    try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: false, attributes: nil)
                } catch let e {
                    handleFileAddError(e)
                    return
                }
                items.append(.loading(promise: promise, url: destinationURL))
                promise.receivePromisedFiles(atDestination: destinationURL, options: [:], operationQueue: filePromiseQueue) { (fileURL, error) in
                    OperationQueue.main.addOperation { [weak self] in
                        guard let self = self else { return }
                        
                        if let index = self.items.firstIndex(where: { item in
                            if case .loading(let itemPromise, _) = item {
                                return itemPromise == promise
                            } else {
                                return false
                            }
                        }) {
                            do {
                                if let error = error {
                                    throw error
                                }
                                try self.verifyFile(at: fileURL)
                                self.items.replaceSubrange(index...index, with: [.url(url: fileURL, isTemporary: true)])
                            } catch let e {
                                self.items.remove(at: index)
                                self.handleFileAddError(e)
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
                urls.forEach { url in
                    do {
                        try self.verifyFile(at: url)
                        self.items.append(.url(url: url, isTemporary: false))
                    } catch let e {
                        self.handleFileAddError(e)
                    }
                }
                return true
            }
        }
        return false
    }
    
    // MARK: Table View
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch items[row] {
        case .loading(_, _):
            let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("LoadingCell"), owner: nil)
            view?.subviews.lazy.compactMap { $0 as? NSProgressIndicator }.first?.startAnimation(self)
            return view
        case .url(let url, _):
            if let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("URLCell"), owner: nil) as? NSTableCellView {
                view.textField?.stringValue = url.lastPathComponent
                return view
            }
            return nil
        }
    }
    
    // MARK: Submission
    
    @IBAction func submit(sender: Any?) {
        let confirmationText: String
        if items.isEmpty {
            confirmationText = "A blank text file will be created for you. This action can't be undone."
        } else {
            confirmationText = "This action can't be undone."
        }
        coordinator?.parent.uploadConfirmation = UploadConfirmation(id: UUID(), alert: Alert(title: Text("Submit \(items.count) file(s)?"), message: Text(confirmationText), primaryButton: Alert.Button.default(Text("Submit")) { [weak self] in
            self?.coordinator?.parent.uploadConfirmation = nil
            self?.uploadAndSubmit()
        }, secondaryButton: Alert.Button.cancel { [weak self] in
            self?.coordinator?.parent.uploadConfirmation = nil
        }))
    }
    
    func handleUploadError(_ error: Error) {
        DispatchQueue.main.async {
            self.coordinator?.parent.uploadProgress?.error = error
        }
        print(error)
    }
    
    private func finalizeSubmission(files: [String: String], to destination: SubmissionAccepting, with uploadDetails: SchoologyClient.UploadDetailsResponse) {
        DispatchQueue.main.async {
            self.coordinator?.parent.uploadProgress?.status = .submitting
        }
        client.submit(fileMetadataIdsAndTitles: files, to: destination, uploadDetails: uploadDetails).sink(receiveCompletion: { completion in
            switch completion {
            case .failure(let e):
                self.handleUploadError(e)
            case .finished:
                // We're finished
                DispatchQueue.main.async {
                    self.coordinator?.parent.uploadProgress = nil
                    self.clearItems()
                }
            }
        }, receiveValue: {}).store(in: &cancellables)
    }
    
    private func upload<T: RandomAccessCollection>(remainingURLs: T, details: SchoologyClient.UploadDetailsResponse, to destination: SubmissionAccepting, filesUploaded: [String: String] = [:]) where T.Element == URL {
        if coordinator?.parent.uploadProgress?.isCanceling == true {
            coordinator?.parent.uploadProgress = nil
            return
        }
        if let url = remainingURLs.last {
            DispatchQueue.main.async {
                self.coordinator?.parent.uploadProgress?.status = .uploading(uploaded: filesUploaded.count, current: url.lastPathComponent)
            }
            var mimeType = "text/plain"
            if let type = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, url.pathExtension as CFString, nil) {
                if let mime = UTTypeCopyPreferredTagWithClass(type.takeRetainedValue(), kUTTagClassMIMEType) {
                    mimeType = mime.takeRetainedValue() as String
                }
            }
            client.upload(name: url.lastPathComponent, type: mimeType, token: SubmissionToken(details).token, makeStream: { $0(InputStream(url: url)) }).sink(receiveCompletion: { completion in
                if case .failure(let e) = completion {
                    self.handleUploadError(e)
                }
            }, receiveValue: { response in
                var files = filesUploaded
                files[response] = url.lastPathComponent
                self.upload(remainingURLs: remainingURLs.prefix(upTo: remainingURLs.index(before: remainingURLs.endIndex)), details: details, to: destination, filesUploaded: files)
            }).store(in: &cancellables)
        } else {
            finalizeSubmission(files: filesUploaded, to: destination, with: details)
        }
    }
    
    func uploadAndSubmit() {
        var urls = items.map { item -> URL in
            if case .url(let url, _) = item {
                return url
            } else {
                fatalError("Attempt to submit non-URL item")
            }
        }
        if urls.isEmpty {
            urls = [Bundle.main.url(forResource: "Submission", withExtension: "txt")!]
        }
        let dest = destination
        coordinator?.parent.uploadProgress = UploadProgress(id: UUID(), fileCount: urls.count, isCanceling: false, status: .fetchingDetails)
        client.uploadDetails(for: dest).sink(receiveCompletion: { completion in
            if case .failure(let e) = completion {
                self.handleUploadError(e)
            }
        }, receiveValue: { details in
            self.upload(remainingURLs: urls, details: details, to: dest)
        }).store(in: &cancellables)
    }
    
    // MARK: Continuity Camera
    
    func url(for name: String, with ext: String) throws -> URL {
        let destinationURL = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: FileManager.default.homeDirectoryForCurrentUser, create: true)
        var filename = name + "." + ext
        var i = 1
        while items.contains(where: { item in
            if case .url(let url, _) = item {
                return url.lastPathComponent == filename
            }
            return false
        }) {
            i += 1
            filename = "\(name) \(i).\(ext)"
        }
        return destinationURL.appendingPathComponent(filename)
    }
    
    func readSelection(from pasteboard: NSPasteboard) -> Bool {
        do {
            switch pasteboard.availableType(from: [.pdf, .png]) {
            case .some(.pdf):
                guard let data = pasteboard.data(forType: .pdf) else { return false }
                let url = try self.url(for: "Scanned Document", with: "pdf")
                try data.write(to: url)
                items.append(.url(url: url, isTemporary: true))
                return true
            case .some(.png):
                guard let data = pasteboard.data(forType: .png) else { return false }
                let url = try self.url(for: "Image", with: "png")
                try data.write(to: url)
                items.append(.url(url: url, isTemporary: true))
                return true
            default:
                guard pasteboard.canReadItem(withDataConformingToTypes: NSImage.imageTypes) else { return false }
                guard let image = NSImage(pasteboard: pasteboard) else { return false }
                guard let data = NSBitmapImageRep.representationOfImageReps(in: image.representations, using: .jpeg, properties: [:]) else { return false }
                let url = try self.url(for: "Photo", with: "jpg")
                try data.write(to: url)
                items.append(.url(url: url, isTemporary: true))
                return true
            }
        } catch let e {
            print(e)
            return false
        }
    }
    
    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?) -> Any? {
        if let pasteboardType = returnType, NSImage.imageTypes.contains(pasteboardType.rawValue) {
            return self
        } else {
            return super.validRequestor(forSendType: sendType, returnType: returnType)
        }
    }
    
    // MARK: The Add Button
    
    @IBAction func addButtonAction(sender: NSButton) {
        guard let event = NSApp.currentEvent else { return }
        view.window?.makeFirstResponder(self)
        let menu = NSMenu()
        
        let selectFile = NSMenuItem(title: "Select Files...", action: #selector(selectFile(sender:)), keyEquivalent: "")
        selectFile.target = self
        menu.addItem(selectFile)
        
        NSMenu.popUpContextMenu(menu, with: event, for: sender)
    }
    
    @objc func selectFile(sender: Any?) {
        let dialog = NSOpenPanel()
        dialog.showsHiddenFiles = false
        dialog.allowsMultipleSelection = true
        dialog.canChooseDirectories = false
        dialog.showsResizeIndicator = true
        dialog.prompt = "Select"
        
        if dialog.runModal() == .OK {
            items.append(contentsOf: dialog.urls.compactMap { url in
                do {
                    try self.verifyFile(at: url)
                    return UploadItem.url(url: url, isTemporary: false)
                } catch let e {
                    self.handleFileAddError(e)
                    return nil
                }
            })
        }
    }
    
    // MARK: Cleanup
    
    func cleanup() {
        filePromiseQueue.cancelAllOperations()
        items.compactMap { item -> URL? in
            if case .url(let url, let temp) = item, temp {
                return url
            } else if case .loading(_, let url) = item {
                return url
            } else {
                return nil
            }
        }.forEach { url in
            do {
                print("Removing temporary file at \(url.absoluteString)")
                try FileManager.default.removeItem(at: url)
            } catch let e {
                print("Error removing temporary file: \(e)")
            }
        }
    }
    
    func clearItems() {
        cleanup()
        items = []
    }
    
    deinit {
        cleanup()
    }
}

// MARK: UploadContainerView

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

// MARK: SwiftUI

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
            VStack(alignment: .leading) {
                Text("Submitting \(uploadProgress.fileCount) file(s)...").font(.headline)
                if uploadProgress.isCanceling {
                    Text("Canceling...")
                } else {
                    switch uploadProgress.status {
                    case .fetchingDetails:
                        Text("Preparing to submit...")
                    case .uploading(let uploaded, let current):
                        Text("Uploading \(uploaded + 1) of \(uploadProgress.fileCount) (\(current))...")
                    case .submitting:
                        Text("Finalizing submission...")
                    case .complete:
                        Text("Done!")
                    }
                }
                if let error = uploadProgress.error {
                    Text(error.localizedDescription).foregroundColor(.red).lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                }
                if #available(macOS 11.0, *) {
                    ProgressView(value: uploadProgress.progress).progressViewStyle(LinearProgressViewStyle())
                }
                if uploadProgress.error != nil {
                    Button("OK") {
                        self.uploadProgress = nil
                    }.frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Button("Cancel") {
                        self.uploadProgress?.isCanceling = true
                    }.frame(maxWidth: .infinity, alignment: .trailing).disabled(!uploadProgress.canCancel)
                }
            }.padding().frame(width: 300)
        }).alert(item: $uploadConfirmation, content: { $0.alert })
    }
}
