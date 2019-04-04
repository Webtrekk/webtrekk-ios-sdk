import Foundation

internal extension FileManager {

	@nonobjc
    func itemExistsAtURL(_ url: URL) -> Bool {
		guard url.isFileURL, !url.path.isEmpty else {
			return false
		}

		return fileExists(atPath: url.path)
	}
}
