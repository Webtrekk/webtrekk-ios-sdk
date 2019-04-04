import Foundation

internal extension String {

    func firstMatchForRegularExpression(_ regularExpression: NSRegularExpression) -> [String]? {
        guard let match = regularExpression.firstMatch(in: self, options: [], range: NSMakeRange(0, utf16.count)) else {
            return nil
        }

        return (0 ..< match.numberOfRanges).map { String(self[match.range(at: $0).rangeInString(self)!]) }
    }

    func firstMatchForRegularExpression(_ regularExpressionPattern: String) -> [String]? {
        do {
            let regularExpression = try NSRegularExpression(pattern: regularExpressionPattern, options: [])
            return firstMatchForRegularExpression(regularExpression)
        } catch let error {
            fatalError("Invalid regular expression pattern: \(error)")
        }
    }

    //check if string is matched to expression
    func isMatchForRegularExpression(_ expression: String) -> Bool? {

       do {
            let regularExpression = try NSRegularExpression(pattern: expression, options: [])
            return regularExpression.numberOfMatches(in: self, options: [], range: NSMakeRange(0, utf16.count)) == 1
       } catch let error {
            WebtrekkTracking.defaultLogger.logError("Error: \(error) for incorrect regular expression: \(expression)")
            return nil
       }
    }

    var nonEmpty: String? {
        if isEmpty {
            return nil
        }

        return self
    }

    var simpleDescription: String {
        return "\"\(self)\""
    }

    func isValidURL() -> Bool {

    if let url = URL(string: self), url.host != nil {
            return true
        } else {
            return false
        }
    }

    func isTrackIdFormat() -> Bool {

        let trackIds = self.replacingOccurrences(of: " ", with: "").components(separatedBy: ",")

        guard trackIds.isEmpty else {
            return false
        }

        for trackId in trackIds {
            if !CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: trackId)) || trackId.utf8.count != 15 {
                return false
            }
        }

        return true
    }

    func sha256() -> String {
        return self.utf8.lazy.map({ $0 as UInt8 }).sha256().toHexString()
    }

    func md5() -> String {
        return self.utf8.lazy.map({ $0 as UInt8 }).md5().toHexString()
    }

    var coded: String {
        let codedChar = "$',/:?@=&+"
        var csValue = CharacterSet.urlQueryAllowed

        codedChar.forEach { (ch) in
            csValue.remove(ch.unicodeScalars.first!)
        }

        return self.addingPercentEncoding(withAllowedCharacters: csValue)!
    }
}

internal extension _Optional where Wrapped == String {

    var simpleDescription: String {
        return self.value?.simpleDescription ?? "<nil>"
    }
}
