//
//  PageContentView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/17/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

func attributedString(pageContent: String) -> NSAttributedString? {
    if let str = NSMutableAttributedString(html: Data(("<span style='font-family: system-ui;'>" + pageContent + "</span>").utf8), options: [.characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) {
        str.addAttribute(.foregroundColor, value: NSColor.textColor, range: NSMakeRange(0, str.length))
        str.addAttribute(.backgroundColor, value: NSColor.clear, range: NSMakeRange(0, str.length))
        return str
    } else {
        return nil
    }
}

struct PageContentView: View {
    var content: String
    
    init(_ content: String) {
        self.content = content
    }
    
    var body: some View {
        return AnyView(TextView(string: content).frame(maxWidth: .infinity, maxHeight: .infinity))
    }
    
    struct TextView: NSViewRepresentable {
        let string: String
        
        func makeNSView(context: NSViewRepresentableContext<TextView>) -> NSScrollView {
            let textView = NSTextView(frame: .zero)
            textView.autoresizingMask = [.width]
            textView.isVerticallyResizable = true
            textView.isEditable = false
            textView.textColor = .textColor
            
            let scrollView = NSScrollView(frame: .zero)
            scrollView.documentView = textView
            scrollView.hasVerticalScroller = true
            
            context.coordinator.string = string
            configureEventually(textView: textView)
            
            return scrollView
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(string: string)
        }
        
        func updateNSView(_ nsView: NSScrollView, context: NSViewRepresentableContext<TextView>) {
            let textView = nsView.documentView as! NSTextView
            if context.coordinator.string != string {
                context.coordinator.string = string
                textView.textStorage!.setAttributedString(NSAttributedString())
                configureEventually(textView: textView)
            }
        }
        
        func configureEventually(textView: NSTextView) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak textView] in
                if let content = attributedString(pageContent: self.string) {
                    textView?.textStorage?.setAttributedString(content)
                } else {
                    textView?.textStorage?.setAttributedString(NSAttributedString(string: "Unable to parse"))
                }
            }
        }
        
        class Coordinator {
            var string: String
            init(string: String) {
                self.string = string
            }
        }
    }
}
