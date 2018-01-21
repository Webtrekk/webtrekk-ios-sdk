import Foundation

internal extension String {

	internal func firstMatchForRegularExpression(_ regularExpression: NSRegularExpression) -> [String]? {
		guard let match = regularExpression.firstMatch(in: self, options: [], range: NSMakeRange(0, utf16.count)) else {
			return nil
		}

        return (0 ..< match.numberOfRanges).map { String(self[match.range(at: $0).rangeInString(self)!]) }
	}
	
	internal func firstMatchForRegularExpression(_ regularExpressionPattern: String) -> [String]? {
		do {
			let regularExpression = try NSRegularExpression(pattern: regularExpressionPattern, options: [])
			return firstMatchForRegularExpression(regularExpression)
		}
		catch let error {
			fatalError("Invalid regular expression pattern: \(error)")
		}
	}
    
    //check if string is matched to expression
    internal func isMatchForRegularExpression(_ expression: String) -> Bool?{
    
       do {
            let regularExpression = try NSRegularExpression(pattern: expression, options: [])
            return regularExpression.numberOfMatches(in: self, options: [], range: NSMakeRange(0, utf16.count)) == 1
       } catch let error {
            WebtrekkTracking.defaultLogger.logError("Error: \(error) for incorrect regular expression: \(expression)")
            return nil
       }
    }

	internal var nonEmpty: String? {
		if isEmpty {
			return nil
		}

		return self
	}

	internal var simpleDescription: String {
		return "\"\(self)\""
	}
    
    internal func isValidURL() -> Bool {
    
    if let url = URL(string: self), let _ = url.host{
            return true
        } else {
            return false
        }
    }
    
    internal func isTrackIdFormat() -> Bool{
        
        let trackIds = self.replacingOccurrences(of: " ", with: "").components(separatedBy: ",")
        
        guard trackIds.count > 0 else {
            return false
        }
        
        for trackId in trackIds {
            if !CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: trackId)) || trackId.utf8.count != 15 {
                return false
            }
        }
        
        return true
    }
    
    internal func sha256() -> String{
        return self.utf8.lazy.map({ $0 as UInt8 }).sha256().toHexString()
    }
    
    internal func md5() -> String{
        return self.utf8.lazy.map({ $0 as UInt8 }).md5().toHexString()
    }
    
    var coded: String{
        let codedChar = "$',/:?@=&+"
        var csValue = CharacterSet.urlQueryAllowed
        
        codedChar.forEach { (ch) in
            csValue.remove(ch.unicodeScalars.first!)
        }

        return self.addingPercentEncoding(withAllowedCharacters: csValue)!
    }
}

internal extension _Optional where Wrapped == String {

	internal var simpleDescription: String {
		return self.value?.simpleDescription ?? "<nil>"
	}
}
