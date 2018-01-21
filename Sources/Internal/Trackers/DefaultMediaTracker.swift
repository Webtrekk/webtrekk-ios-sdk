import UIKit


internal final class DefaultMediaTracker: MediaTracker {

	private let handler: MediaEventHandler

	internal var mediaProperties: MediaProperties
	internal var pageName: String?
    internal var variables : [String : String]
	internal var viewControllerType: AnyObject.Type?


    internal init(handler: MediaEventHandler, mediaName: String, pageName: String?, mediaProperties: MediaProperties?, variables: [String : String]?) {
        checkIsOnMainThread()
        
        self.handler = handler
        self.mediaProperties = mediaProperties ?? MediaProperties(name: mediaName)
        self.pageName = pageName
        self.variables = variables ?? [String : String]()
    }

	internal func trackAction(_ action: MediaEvent.Action) {
		checkIsOnMainThread()

		let event = MediaEvent(
			action:          action,
			mediaProperties: mediaProperties,
			pageName:        pageName,
			variables:       variables
		)
		event.viewControllerType = viewControllerType

		handler.handleEvent(event)
	}
}
