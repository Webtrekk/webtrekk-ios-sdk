import UIKit

public class MediaEvent: TrackingEventWithMediaProperties {

    public var action: Action
    public var ipAddress: String?
    public var mediaProperties: MediaProperties
    public var pageName: String?
    public var variables: [String: String]
    public var viewControllerType: AnyObject.Type?

    public init(
        action: Action,
        mediaProperties: MediaProperties,
        pageName: String?,
        variables: [String: String] = [:]
    ) {
        self.action = action
        self.mediaProperties = mediaProperties
        self.pageName = pageName
        self.variables = variables
    }

    public init(
        action: Action,
        mediaProperties: MediaProperties,
        viewControllerType: AnyObject.Type?,
        variables: [String: String] = [:]
    ) {
        self.action = action
        self.mediaProperties = mediaProperties
        self.variables = variables
        self.viewControllerType = viewControllerType
    }

    public enum Action {
        case finish
        case initialize
        case pause
        case play
        case position
        case seek
        case stop
        case custom(name: String)
    }
}
