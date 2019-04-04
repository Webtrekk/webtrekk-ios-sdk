import Foundation

internal extension NSRange {

    init(forString string: String) {
		self.init(range: string.startIndex ..< string.endIndex, inString: string)
	}

    init(range: Range<String.Index>?, inString string: String) {
		if let range = range {
           let location = NSRange.locationForIndex(range.lowerBound, inString: string)
           let endLocation = NSRange.locationForIndex(range.upperBound, inString: string)

			self.init(location: location, length: location.distance(to: endLocation))
		} else {
			self.init(location: NSNotFound, length: 0)
		}
	}

    func endIndexInString(_ string: String) -> String.Index? {
		return NSRange.indexForLocation(NSMaxRange(self), inString: string)
	}

	fileprivate static func indexForLocation(_ location: Int, inString string: String) -> String.Index? {
		if location == NSNotFound {
			return nil
		}

        return string.utf16.index(string.utf16.startIndex, offsetBy: location, limitedBy: string.utf16.endIndex)?.samePosition(in: string)
	}

	private static func locationForIndex(_ index: String.Index, inString string: String) -> Int {
        guard let toPosition = index.samePosition(in: string.utf16) else {return -1}
		return string.utf16.distance(from: string.utf16.startIndex, to: toPosition)
	}

    func rangeInString(_ string: String) -> Range<String.Index>? {
		if let startIndex = startIndexInString(string),
           let endIndex = endIndexInString(string) {
			return startIndex ..< endIndex
		}

		return nil
	}

    func startIndexInString(_ string: String) -> String.Index? {
		return NSRange.indexForLocation(location, inString: string)
	}
}
