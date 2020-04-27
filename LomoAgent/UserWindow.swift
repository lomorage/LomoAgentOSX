//
//  UserWindow.swift
//  LomoAgent
//
//  Created by jeromy on 4/26/20.
//  Copyright © 2020 lomoware. All rights reserved.
//

import Foundation
import Cocoa
import CocoaLumberjack

class UserWindow: NSWindowController {

    @IBOutlet weak var tableview: NSTableView!

    override var windowNibName : String! {
        return "UserWindow"
    }

    override func windowWillLoad() {
        if let lomodService = getLomodService() {
            lomodService.getUserList()
        }
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        self.window?.level = .floating

        tableview.delegate = self
        tableview.dataSource = self
    }
}

extension UserWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if let lomodService = getLomodService() {
            return lomodService.members.count
        } else {
            return 0
        }
    }
}

extension UserWindow: NSTableViewDelegate {

    fileprivate enum CellIdentifiers {
        static let UserNameCell = "UserNameCellID"
        static let PasswordCell = "PasswordCellID"
        static let HomeDirCell = "HomeDirCellID"
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let lomodService = getLomodService() else {
            return nil
        }
        guard row < lomodService.members.count else {
            return nil
        }

        let item = lomodService.members[row]
        var cellIdentifier: String = ""
        var text = ""
        if tableColumn == tableview.tableColumns[0] {
            cellIdentifier = CellIdentifiers.UserNameCell
            text = item.userName
        } else if tableColumn == tableview.tableColumns[1] {
            cellIdentifier = CellIdentifiers.PasswordCell
        } else if tableColumn == tableview.tableColumns[2] {
            cellIdentifier = CellIdentifiers.HomeDirCell
            text = item.homeDir
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }

        return nil
    }
}
