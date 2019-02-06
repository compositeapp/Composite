//
//  ProjectWindowController.swift
//  SCE-Mac
//
//  Created by Ronald "Danger" Mannak on 8/11/18.
//  Copyright © 2018 A Puzzle A Day. All rights reserved.
//

import Cocoa


private struct SerializationKey {
    
    static let project = "project"
}

final class ProjectWindowController: NSWindowController {
    
    @IBOutlet weak var runButton: NSToolbarItem!
    
    override var document: AnyObject? {
        didSet {
            window?.contentViewController?.representedObject = document
        }
    }
    
//    var consoleTextView: NSTextView {
//        return (self.window?.contentViewController?.children[1] as! CompositeSplitViewController).consoleView
//    }
//
//    var fileBrowserViewController: FileNavigatorViewController {
//        return (self.window?.contentViewController! as! NSSplitViewController).children[0] as! FileNavigatorViewController
//    }
    
//    private var editView: SyntaxTextView {
//        return (self.window?.contentViewController?.childViewControllers[1] as! CompositeSplitViewController).editorView
//    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        shouldCascadeWindows = true
    }

    override func windowDidLoad() {
        super.windowDidLoad()
//        window?.appearance = NSAppearance(named: .vibrantDark)
//            window?.restorationClass = EditWindowRestoration.self
    }
    
//    override func awakeFromNib() {
//        loadBrowser()
//    }
    
//    func loadBrowser(select item: String? = nil) {
////        guard let project = project, let document = document as? ProjectDocument else { return }
//        window?.title = project?.name ?? "Demo Project"
//        do {
////            let url = URL(fileURLWithPath: "/Users/ronalddanger/Development/Temp/Untitled9875/")
//
//            let url = URL(fileURLWithPath: "/Users/ronalddanger/Development/Temp/Untitled9875")
//            try fileBrowserViewController.load(url: url, projectName: "Demo Project", openFile: "contracts/Untitled9875.sol")
////            try fileBrowserViewController.load(url: document.workDirectory, projectName: project.name, openFile: item)
//        } catch {
//            let alert = NSAlert(error: error)
//            alert.runModal()
//        }
//    }

    
    /// Sets console vc text. Called by PreparingViewController
    func setConsole(_ string: String) {
//        consoleTextView.string = consoleTextView.string + "\n" + string
//
//        let range = NSRange(location:consoleTextView.string.count,length:0)
//        consoleTextView.scrollRangeToVisible(range)
    }

    func setEditor(url: URL) {
//        do {
//            let text = try String(contentsOf: url)
//            saveEditorFile()
//            editView.text = text
//            editorURL = url
//        } catch {
//            let alert = NSAlert(error: error)
//            alert.runModal()
//        }
    }
    
    func saveEditorFile() {
//        guard let editorURL = editorURL else {
//            return
//        }
//        do {
////            Occasional bug: projects get duplicated as subdirectories of an open project.
////            wrong url
////            ▿ file:///Users/ronalddanger/Development/Temp/Untitled89652768/Untitled2346789/contracts/TutorialToken.sol
////
////            untitled 89 is the right one.
////            this file is saved in the 2768 directory. the full project is actually saved there
////            print("******===== \(editorURL.path)")
//            try editView.text.write(to: editorURL, atomically: true, encoding: .utf8)
//        } catch {
//            let alert = NSAlert(error: error)
//            alert.runModal()
//        }
    }

    @IBAction func runButtonClicked(_ sender: Any) {
        
//        guard let document = document as? Document, let interface = document.interface else { return }
//        script?.terminate()
//        saveEditorFile()
//
//        do {
//            script = try interface.executeRun(workDirectory: document.workDirectory, output: { output in
//                self.setConsole(output)
//            }) { exitStatus in
//                self.script = nil
//                guard exitStatus == 0 else {
//                    let error = CompositeError.bashScriptFailed("Bash error")
//                    let alert = NSAlert(error: error)
//                    alert.runModal()
//                    return
//                }
//            }
//        } catch {
//            let alert = NSAlert(error: error)
//            alert.runModal()
//        }

    }

    @IBAction func pauseButtonClicked(_ sender: Any) {
//        script?.terminate()
//        script = nil
//        setConsole("Cancelled.")
//        runButton.isEnabled = true
    }
    
    @IBAction func lintButtonClicked(_ sender: Any) {
        
//        guard let document = document as? Document, let interface = document.interface else { return }
//        script?.terminate()
//        saveEditorFile()
//
//        do {
//            script = try interface.executeLint(workDirectory: document.workDirectory, output: { output in
//                self.setConsole(output)
//            }, finished: { exitStatus in
//                guard exitStatus == 0 else {
//                    let error = CompositeError.bashScriptFailed("Bash error")
//                    let alert = NSAlert(error: error)
//                    alert.runModal()
//                    return
//                }
//            })
//        } catch {
//            let alert = NSAlert(error: error)
//            alert.runModal()
//        }
    }
    
    @IBAction func webButtonClicked(_ sender: Any) {
        
      
        
//        guard let project = project, let sender = sender as? NSButton else { return }
//
//        if let webserver = webserver { webserver.terminate() }
//
//        if sender.state == .on {
////            sender.highlight(true)
//            do {
//                webserver = try ScriptTask.webserver(project: project, output: { output in
//                    self.setConsole(output)
//                }) {
//                    // finish
//                }
//            } catch {
////                sender.highlight(false)
//                let alert = NSAlert(error: error)
//                alert.runModal()
//            }
//        }
    }
    
    //    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
    //        <#code#>
    //    }
    
    
//    override func encodeRestorableState(with coder: NSCoder) {
//
//        // There is an issue encoding TextDocuments. The Project property in TextDocument
//        // is not being encoded. It seems that NSDocument properties of NSDocuments can't be stored
//        // So instead, we save the project file, and set the lastOpenFile to the current TextDocument
//        if let textDocument = document as? TextDocument, let project = textDocument.project {
//            coder.encode(project, forKey: SerializationKey.project)
//        }
//
//        super.encodeRestorableState(with: coder)
//
//    }
//
//    override func restoreState(with coder: NSCoder) {
//        super.restoreState(with: coder)
//
//        if coder.containsValue(forKey: SerializationKey.project) {
//            let project = coder.decodeObject(forKey: SerializationKey.project) as? Project
//            NSLog("found project: %@", project ?? "NIL")
//        }
//    }
    
    
}
