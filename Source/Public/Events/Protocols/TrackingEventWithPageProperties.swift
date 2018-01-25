import UIKit

public protocol TrackingEventWithPageProperties: TrackingEvent {
	var pageProperties: PageProperties { get mutating set }
}

public extension TrackingEventWithPageProperties {

	public var pageName: String? {
		get { return pageProperties.name }
		mutating set { pageProperties.name = newValue }
	}

	public var viewControllerType: AnyObject.Type? {
		get { return pageProperties.viewControllerType }
		mutating set { pageProperties.viewControllerType = newValue }
	}
}
