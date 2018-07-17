import UIKit

public struct PageProperties {

	public var details: [Int: TrackingValue]?
	public var groups: [Int: TrackingValue]?
	public var name: String?
	public var internalSearch: String?
	public var viewControllerType: AnyObject.Type?
    public var url: String? {
        didSet {
            if !isURLCanBeSet(self.url) {
                printInvalidURL(self.url!)
            }
        }
    }

    public init(
        name: String? = nil,
        details: [Int: TrackingValue]? = nil,
        groups: [Int: TrackingValue]? = nil,
        internalSearch: String? = nil,
        url: String? = nil
	) {
		self.details = details
		self.groups = groups
		self.name = name
		self.internalSearch = internalSearch

        setUpURL(url: url)
	}

	public init(
		viewControllerType: AnyObject.Type?,
		details: [Int: TrackingValue]? = nil,
		groups: [Int: TrackingValue]? = nil,
		internalSearch: String? = nil,
		url: String? = nil
	) {
		self.details = details
		self.groups = groups
		self.internalSearch = internalSearch
		setUpURL(url: url)
		self.viewControllerType = viewControllerType
	}

    internal func merged(over other: PageProperties) -> PageProperties {
		var new = self
		new.details = details.merged(over: other.details)
		new.groups = groups.merged(over: other.groups)
		new.name = name ?? other.name
        new.internalSearch = internalSearch ?? other.internalSearch
		new.viewControllerType = viewControllerType ?? other.viewControllerType
		new.url = url ?? other.url
		return new
	}

    mutating private func setUpURL(url: String?) {
        if isURLCanBeSet(url) {
            self.url = url
        } else {
            printInvalidURL(url!)
        }
    }

    fileprivate func isURLCanBeSet(_ url: String?) -> Bool {
       return url == nil || url!.isValidURL()
    }

    fileprivate func printInvalidURL(_ url: String) {
        WebtrekkTracking.defaultLogger.logError("Invalid URL \(url) for pu parameter")
    }
}
