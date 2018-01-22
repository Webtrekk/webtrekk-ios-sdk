import Foundation

class StorePendingRequest {
    private let saveDirectory: FileManager.SearchPathDirectory
    private let fileName = "webtrekk_url_pending_queue.json"
    private var fileURL: URL?
    private var fileHandler: FileHandle?
    private let delimeter: Character = "\n"

    init() {
        #if os(tvOS)
            self.saveDirectory = .cachesDirectory
        #else
            self.saveDirectory = .applicationSupportDirectory
        #endif

        let fileManager = FileManager.default

        guard let url = fileManager.urls(for: saveDirectory, in: .userDomainMask).first else {
            logError("can't get application suport directory. No pending tracking functionality available")
            return
        }

        var basePath = url.appendingPathComponent("Webtrekk")

        if !fileManager.itemExistsAtURL(basePath) {
            do {
                try fileManager.createDirectory(at: basePath, withIntermediateDirectories: true)
                var resourceValue = URLResourceValues()
                resourceValue.isExcludedFromBackup = true
                try? basePath.setResourceValues(resourceValue)
            } catch let error {
                logError("Cannot create directory at '\(basePath)' for storing request queue backup file: \(error)")
                return
            }
        }

        self.fileURL = basePath.appendingPathComponent(self.fileName)

        //self.reader = TextFileReader(delimeter: self.delimeter)
    }

    private func createNewFile() {
        guard let url = self.fileURL else {
            return
        }

        guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil) else {
            WebtrekkTracking.defaultLogger.logError("can't create file for buffered tracking. No buffered tracking will be done. file path: \(url.path)")
            return
        }

        self.updateFileHandler()

        logDebug("file created at: \(url.path)")
    }

    private func updateFileHandler() {
        guard let fileURL = self.fileURL else {
            return
        }

        if let _ = self.fileHandler {
            return
        }

        do {
            self.fileHandler = try FileHandle(forUpdating: fileURL)
        } catch let error {
            WebtrekkTracking.defaultLogger.logError("can't create file for pending queue. Error: \(error)")
            return
        }

        WebtrekkTracking.defaultLogger.logDebug("file handler for pending queue initializated")
    }

    func save(parameters: [URLQueryItem]) {
        var jsonObject = [[String: String]]()

        if !self.exist {
            self.createNewFile()
        } else {
            self.updateFileHandler()
        }

        parameters.forEach { (item) in
            if let value = item.value {
                var keyValueMap = [String: String]()
                keyValueMap[item.name] = value
                jsonObject.append(keyValueMap)
            }
        }

        if JSONSerialization.isValidJSONObject(jsonObject), let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
            do {
                var data = jsonData

                data.append(String(self.delimeter).data(using: .utf8)!)
                self.fileHandler?.seekToEndOfFile()
                try CatchObC.catchException {
                    self.fileHandler?.write(data)
                }
            } catch let error {
                WebtrekkTracking.defaultLogger.logError("Exception during saving to pending queue file:\(error)")
                return
            }
        }
    }

    func load() -> [[URLQueryItem]]? {
        guard self.exist else {
            return nil
        }

        guard let fileContent = try? String(contentsOf: self.fileURL!, encoding: .utf8 ) else {
            WebtrekkTracking.defaultLogger.logError("can't read pending request")
            return nil
        }

        var items = [[URLQueryItem]]()
        let jsonsString = fileContent.split(separator: self.delimeter)

        jsonsString.forEach { (substring) in
            var parameters = [URLQueryItem]()
            if let data = String(substring).data(using: .utf8), let jsonObj = (try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: String]]) {
                jsonObj?.forEach {(keyValueItem) in
                    let queryItem = URLQueryItem(name: (keyValueItem.first?.key)!, value: keyValueItem.first?.value)
                    parameters.append(queryItem)
                }
            }

            if !parameters.isEmpty {
                items.append(parameters)
            }
        }

        return items.isEmpty ? nil : items
    }

    var exist : Bool {
        guard let url = self.fileURL else {
            return false
        }
        return FileManager.default.itemExistsAtURL(url)
    }

    func clearQueue() {
        guard let url = self.fileURL else {
            return
        }

        guard self.exist else {
            return
        }

        self.fileHandler?.closeFile()

        do {
            try FileManager.default.removeItem(at: url)
        } catch let error {
            WebtrekkTracking.defaultLogger.logError("Serious problem with urls saved file deletion: \(error). It might produce unexpected behaviour.")
        }

    }
}
