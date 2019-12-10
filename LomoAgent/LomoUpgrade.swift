//
//  LomoUpgrade.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 9/4/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Foundation
import os.log
import Zip

let LOMO_UPGRADE_URL = "https://lomorage.com/release.json"

// todo: share we have sha256 for updater as well? Share we remove pre-post in json if not used?
struct UpgradeConfig {
    let agentSha256: String
    let agentVer: String
    let agentUrl: String
    let updateVer: String
    let updateUrl: String
}

class LomoUpgrade {

    private var networkSession: NetworkSession!

    private let upgradeUrl: String

    var config: UpgradeConfig?

    init(url: String) {
        upgradeUrl = url
        let defaultConfiguration = URLSessionConfiguration.default
        defaultConfiguration.allowsCellularAccess = false
        defaultConfiguration.timeoutIntervalForRequest = 20
        networkSession = URLSession(configuration: defaultConfiguration)
    }

    func update() {
        fetchUpdateConf()

        if needUpdateLomoUpg() {
            let succ = updateLomoUpg()
            guard succ else {
                os_log("update LomoUpg failed!", log: .logic, type: .error)
                return
            }
        }

        if needUpdateAgent() {
            updateAgent()
        }
    }

    func updateLomoUpg() -> Bool {
        guard config != nil else {
            return false
        }

        let cacheFilePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        var destinationFileUrl: URL? = cacheFilePath.appendingPathComponent("LomoUpg.zip")
        guard destinationFileUrl != nil else {
            os_log("updateLomoUpg, destinationFileUrl is nil", log: .logic, type: .error)
            return false
        }

        if let updateUrl = URL(string: config!.updateUrl) {
            let urlRequest = URLRequest(url: updateUrl)
            let sessionConfig = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfig)

            let opGroup = DispatchGroup()
            opGroup.enter()
            let task = session.downloadTask(with: urlRequest) { (tempLocalUrl, response, error) in
                if let tempLocalUrl = tempLocalUrl, error == nil {
                    // Success
                    try? FileManager.default.removeItem(at: destinationFileUrl!)
                    do {
                        try FileManager.default.copyItem(at: tempLocalUrl, to: destinationFileUrl!)
                    } catch (let writeError) {
                        os_log("updateLomoUpg, Error copying file from %{public}s to %{public}s, err: %{public}s", log: .logic, type: .error, tempLocalUrl.absoluteString, destinationFileUrl!.absoluteString, writeError.localizedDescription)
                        try? FileManager.default.removeItem(at: destinationFileUrl!)
                        destinationFileUrl = nil
                    }
                } else {
                    os_log("updateLomoUpg, Error took place while downloading a file. Error description: %{public}s", log: .logic, type: .error, String(describing: error?.localizedDescription))
                    destinationFileUrl = nil
                }
                opGroup.leave()
            }
            task.resume()
            opGroup.wait()
        }

        if destinationFileUrl != nil {
            guard let executablePath = Bundle.main.executableURL?.deletingLastPathComponent(), let lomoupgPath = URL(string: executablePath.path) else {
                os_log("updateLomoUpg, can't get lomoupgPath", log: .logic, type: .error)
                return false
            }

            do {
                try Zip.unzipFile(destinationFileUrl!, destination: lomoupgPath, overwrite: true, password: nil)
                os_log("updateLomoUpg, unzip %{public}s to %{public}s succ",
                       log: .logic, type: .error,
                       destinationFileUrl!.absoluteString,
                       lomoupgPath.absoluteString)
                return true
            } catch let err as NSError  {
                os_log("updateLomoUpg, unzip %{public}s to %{public}s failed with error: %{public}s",
                       log: .logic, type: .error,
                       destinationFileUrl!.absoluteString,
                       lomoupgPath.absoluteString,
                       err.localizedDescription)
            }

            try? FileManager.default.removeItem(at: destinationFileUrl!)
        }

        return false
    }

    func updateAgent() {
        if let executablePath = Bundle.main.executableURL?.deletingLastPathComponent() {
            let lomoupgPath = executablePath.path + "/lomoupg"
            os_log("lomoupg Path: %{public}s", log: .logic, lomoupgPath)
            guard FileManager.default.fileExists(atPath: lomoupgPath) else {
                os_log("lomoupgPath not found: %{public}s", log: .logic, type: .error, lomoupgPath)
                return
            }
            let cacheFilePathURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let appPath = Bundle.main.bundleURL

            let task = Process()
            task.launchPath = lomoupgPath
            task.arguments = [
                "--app-dir", appPath.path,
                "--backup-dir", cacheFilePathURL.path,
                "--curr-version", getCurrentAgentVer()!,
                "--precmd", "/usr/bin/killall",
                "--precmdarg", "LomoAgent",
                "--postcmd", "open",
                "--postcmdarg", Bundle.main.bundlePath,
                "--log-dir", getLogDir()!
            ]

            // not able to get result now, will get reboot if succ
            task.launch()
        } else {
            os_log("updateAgent error, not able to get lomoupg path", log: .logic, type: .error)
        }
    }

    func needUpdateAgent() -> Bool {
        if let c = config {
            if let latestVer = Version(ver: c.agentVer),
                let currentVer = getCurrentAgentVer(),
                let currVer = Version(ver: currentVer) {
                return currVer < latestVer
            } else {
                return false
            }
        } else {
            return false // config not available yet
        }
    }

    func needUpdateLomoUpg() -> Bool {
        if let c = config {
            if let latestVer = Version(ver: c.updateVer),
                let currentVer = getCurrentLomoUpgVer(),
                let currVer = Version(ver: currentVer) {
                return currVer < latestVer
            } else {
                return false
            }
        }
        return false // config not available yet or LomoUpg not exist
    }

    func getCurrentAgentVer() -> String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    func getCurrentLomoUpgVer() -> String? {
        if let executablePath = Bundle.main.executableURL?.deletingLastPathComponent() {
            let lomoupgPath = executablePath.path + "/lomoupg"
            os_log("lomoupg Path: %{public}s", log: .logic, lomoupgPath)
            guard FileManager.default.fileExists(atPath: lomoupgPath) else {
                os_log("getCurrentLomoUpgVer, lomoupg not found: %{public}s", log: .logic, type: .error, lomoupgPath)
                return nil
            }
            let (output, error, status) = runCommand(cmd: lomoupgPath, args: "--version")
            if status == 0 {
                return output.first
            } else {
                os_log("getCurrentLomoUpgVer error: %{public}s", log: .logic, type: .error, error)
                return nil
            }
        } else {
            os_log("getCurrentLomoUpgVer error, not able to get lomoupg path", log: .logic, type: .error)
            return nil
        }
    }

    func fetchUpdateConf() {
        if let url = URL(string: upgradeUrl) {
            let opGroup = DispatchGroup()
            opGroup.enter()
            self.networkSession.loadData(with: url, completionHandler: { (data, response, error) in
                if let error = error {
                    os_log("needUpdateLomoupgAndLomoAgent request error: %{public}s", log: .logic, type: .error, error.localizedDescription)
                } else if let data = data, let httpresp = response as? HTTPURLResponse {
                    if httpresp.statusCode == 200, let jsonResult = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        os_log("needUpdateLomoupgAndLomoAgent, json response:  %{public}@", log: .logic, jsonResult!)

                        if let osxConf = jsonResult?["darwin"] as? [String: Any] {

                            guard let agentSha256 = osxConf["SHA256"] as? String,
                                let agentVer = osxConf["Version"] as? String,
                                let agentUrl = osxConf["URL"] as? String,
                                let updateVer = osxConf["LomoUpgVer"] as? String,
                                let updateUrl = osxConf["LomoUpdateURL"] as? String else {
                                    os_log("fetchContactList, malformed format!", log: .logic, type: .error)
                                    return
                            }

                            self.config = UpgradeConfig(agentSha256: agentSha256, agentVer: agentVer, agentUrl: agentUrl, updateVer: updateVer, updateUrl: updateUrl)
                        } else {
                            os_log("fetchContactList, osx version not available", log: .logic, type: .error)
                        }

                    } else {
                        os_log("fetchContactList, userList error: %{public}s\n%{public}@", log: .logic, type: .error, String(data: data, encoding: .utf8)!, httpresp)
                    }
                } else {
                    os_log("needUpdateLomoupgAndLomoAgent, error: %{public}s", log: .logic, type: .error, String(describing: response))
                }
            }, sync: opGroup)
            opGroup.wait()
        }
    }
}
