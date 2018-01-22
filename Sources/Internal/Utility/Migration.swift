import Foundation

internal struct Migration {

	internal let appVersion: String?
	internal let everId: String
	internal let isOptedOut: Bool?
	internal let isSampling: Bool?
	internal let requestQueue: [URL]?
	internal let samplingRate: Int?

	internal static func migrateFromLibraryV3(webtrekkId: String) -> Migration? {
		#if os(iOS)
			let fileManager = FileManager.default
			let userDefaults = Foundation.UserDefaults.standard

			let cachesDirectory = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
			let documentDirectory = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
			let libraryDirectory = try? fileManager.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false)

			let everIdFileV2 = documentDirectory?.appendingPathComponent("webtrekk-id")
			let everIdFileV3 = libraryDirectory?.appendingPathComponent("webtrekk-id")

			let requestQueueFileV2 = cachesDirectory?.appendingPathComponent("webtrekk-\(webtrekkId)")
			let requestQueueFileV3 = cachesDirectory?.appendingPathComponent("webtrekk-queue")

			let samplingFileV2 = documentDirectory?.appendingPathComponent("webtrekk-sampling")
			let samplingFileV3 = libraryDirectory?.appendingPathComponent("webtrekk-sampling")

			let appVersionFileV2 = documentDirectory?.appendingPathComponent("webtrekk-app-version")
			let appVersionFileV3 = libraryDirectory?.appendingPathComponent("webtrekk-app-version")

			defer {
				let files = [everIdFileV2, everIdFileV3, requestQueueFileV2, requestQueueFileV3, samplingFileV2, samplingFileV3, appVersionFileV2, appVersionFileV3].filterNonNil()
				for file in files where fileManager.itemExistsAtURL(file) {
					do {
						try fileManager.removeItem(at: file)
					} catch let error {
						logWarning("Cannot remove \(file) of previous Webtrekk Library version: \(error)")
					}
				}

				userDefaults.removeObject(forKey: "Webtrekk.optedOut")
			}

			let everId: String
            var encoding = String.Encoding.utf8

			if let file = everIdFileV3, let _everId = (try? String(contentsOf: file, usedEncoding: &encoding))?.nonEmpty {
				everId = _everId
			} else if let file = everIdFileV2, let _everId = (try? String(contentsOf: file, usedEncoding: &encoding))?.nonEmpty {
				everId = _everId
			} else {
				return nil
			}

			let requestQueue: [URL]?
			if let file = requestQueueFileV3, let _requestQueue = NSKeyedUnarchiver.unarchive(file: file) as? [String] {
				requestQueue = _requestQueue.map({ URL(string: $0) }).filterNonNil()
			} else if let file = requestQueueFileV2, let _requestQueue = NSKeyedUnarchiver.unarchive(file: file) as? [String] {
				requestQueue = _requestQueue.map({ URL(string: $0) }).filterNonNil()
			} else {
				requestQueue = nil
			}

			let isSampling: Bool?
			let samplingRate: Int?
			if let file = samplingFileV3,
               let string = try? String(contentsOf: file, usedEncoding: &encoding),
               let (_isSampling, _samplingRate) = parseSampling(string) {
				isSampling = _isSampling
				samplingRate = _samplingRate
			} else if let file = samplingFileV2,
                let string = try? String(contentsOf: file, usedEncoding: &encoding),
                let (_isSampling, _samplingRate) = parseSampling(string) {
                    isSampling = _isSampling
                    samplingRate = _samplingRate
			} else {
				isSampling = nil
				samplingRate = nil
			}

			let appVersion: String?
			if let file = appVersionFileV3,
               let _appVersion = (try? String(contentsOf: file, usedEncoding:  &encoding))?.nonEmpty {
				appVersion = _appVersion
			} else if let file = appVersionFileV2,
                let _appVersion = (try? String(contentsOf: file, usedEncoding: &encoding))?.nonEmpty {
                    appVersion = _appVersion
			} else {
				appVersion = nil
			}

			let isOptedOut = userDefaults.object(forKey: "Webtrekk.optedOut") as? Bool

			return Migration(
				appVersion:   appVersion,
				everId:       everId,
				isOptedOut:   isOptedOut,
				isSampling:   isSampling,
				requestQueue: requestQueue,
				samplingRate: samplingRate
			)
		#else
			return nil
		#endif
	}

	fileprivate static func parseSampling(_ string: String) -> (isSampling: Bool, samplingRate: Int)? {
		let components = string.components(separatedBy: "|")

		guard components.count == 2 else {
			return nil
		}

		guard let isSampling = Int(components[0]),
              let samplingRate = Int(components[1]), isSampling == 1 || isSampling == 0 else {
			return nil
		}

		return (isSampling: isSampling == 1, samplingRate: samplingRate)
	}
}

extension Migration: CustomStringConvertible {

	internal var description: String {
		return "Migration(\n"
			+ "\teverId: \(everId.simpleDescription)\n"
			+ "\tappVersion: \(appVersion.simpleDescription)\n"
			+ "\tisOptedOut: \(isOptedOut.simpleDescription)\n"
			+ "\tisSampling: \(isSampling.simpleDescription)\n"
			+ "\trequestQueueSize: \((requestQueue?.count).simpleDescription)\n"
			+ "\tsamplingRate: \(samplingRate.simpleDescription)\n"
			+ ")"
	}
}

extension NSKeyedUnarchiver {

	static func unarchive(file: URL) -> AnyObject? {
		guard let data = try? Data(contentsOf: file) else {
			return nil
		}

        return unarchive(data: data)
	}

    static func unarchive(data: Data) -> AnyObject? {
            return unarchiveObject(with: data) as AnyObject?
    }
}
