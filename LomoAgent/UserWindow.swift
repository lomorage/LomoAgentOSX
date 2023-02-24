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

let PASSWROD_PALCEHOLD = "********"

class PasswordTextField: NSTextField
{
    var member: Member?

    override func textDidBeginEditing(_ notification: Notification) {
        //stringValue = ""
    }

    override func textShouldEndEditing(_ textObject: NSText) -> Bool {
        if stringValue.count >= 6 {
            return true
        } else if stringValue.count > 0 {
            DDLogWarn("password should be no less than 6 characters")
            dialogAlert(message: passwordTooShortLocalized, info: "")
            return false
        } else {
            return true //leave black if no change required
        }
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidChange(notification)

        guard stringValue.count > 0 && stringValue != PASSWROD_PALCEHOLD else {
            stringValue = PASSWROD_PALCEHOLD
            return
        }

        if let m = member, let username = m.userName, let encryptedPwd = getEncryptPassword(m.userName, stringValue), let lomodService = getLomodService() {
            var result = passwordChangeFailLocalized
            if lomodService.changePassword(for: username, with: encryptedPwd) {
                result = passwordChangeSuccLocalized
            }
            dialogAlert(message: result, info: "")
        }

        stringValue = PASSWROD_PALCEHOLD
    }
}

class UserWindow: NSWindowController {

    var createUserWindow: CreateUserWindow!

    @IBOutlet weak var tableview: NSTableView!

    @IBAction func onClickAddUser(_ sender: Any) {
        createUserWindow.showWindow(nil)
        createUserWindow.passwordTextField.stringValue = ""
        createUserWindow.userNameTextField.stringValue = ""

        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func onClickDelUser(_ sender: Any) {
        var userList = [String]()
        if let lomodService = getLomodService() {
            for row in tableview.selectedRowIndexes {
                let user = lomodService.members[row]
                userList.append(user.userName!)
            }

            if dialogOKCancel(message: String(format: alertDelUser, userList.joined(separator: ",")), info: "") {
                var failUserLst = [String]()
                for user in userList {
                    if lomodService.deleteUser(username: user) {
                        DDLogInfo("delete user \(user) succ")
                    } else {
                        DDLogWarn("delete user \(user) failed")
                        failUserLst.append(user)
                    }
                }

                if failUserLst.isEmpty {
                    NotificationCenter.default.post(name: .NotifyUserChanged, object: self)
                    dialogAlert(
                        message: String(format: alertDelUserSucc, userList.joined(separator: ",")),
                        info: String(format: deleteUserFolder, userList.joined(separator: ","))
                    )
                    if let homeDir = UserDefaults.standard.string(forKey: PREF_HOME_DIR) {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: homeDir)])
                    }
                } else {
                    dialogAlert(
                        message: String(format: alertDelUserFailure, failUserLst.joined(separator: ",")),
                        info: ""
                    )
                }

            }
        }
    }

    override var windowNibName : String! {
        return "UserWindow"
    }

    override func windowWillLoad() {
        if let lomodService = getLomodService() {
            lomodService.getUserList()
        }
    }

    @objc private func onItemClicked() {
        if tableview.clickedColumn == 1 {
            if let cell = tableview.view(atColumn: tableview.clickedColumn, row: tableview.clickedRow, makeIfNecessary: false) as? NSTableCellView {
                self.window?.makeFirstResponder(cell.textField)

                if let passwordTextField = cell.textField as? PasswordTextField {
                    guard let lomodService = getLomodService() else {
                        return
                    }
                    let row = tableview.clickedRow
                    guard row < lomodService.members.count else {
                        return
                    }
                    passwordTextField.stringValue = ""
                    passwordTextField.member = lomodService.members[row]
                }
            }
        }
    }

    @objc func onLomodServiceChanged(_ notification: Notification) {
        DispatchQueue.main.async {
            if let lomodService = getLomodService() {
                lomodService.getUserList()
            }
            self.tableview.reloadData()
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
        tableview.action = #selector(onItemClicked)

        createUserWindow = CreateUserWindow()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onLomodServiceChanged(_:)),
                                               name: .NotifyRefresh,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onLomodServiceChanged(_:)),
                                               name: .NotifyUserChanged,
                                               object: nil)
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
            text = PASSWROD_PALCEHOLD;
        } else if tableColumn == tableview.tableColumns[2] {
            cellIdentifier = CellIdentifiers.HomeDirCell
            text = item.homeDir
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            if cellIdentifier == CellIdentifiers.PasswordCell {
                cell.toolTip = clickChangePasswordLocalized
            }
            return cell
        }

        return nil
    }
}
