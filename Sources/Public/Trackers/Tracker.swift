//The MIT License (MIT)
//
//Copyright (c) 2016 Webtrekk GmbH
//
//Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
//"Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish,
//distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject
//to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//  Created by Widgetlabs
//


import UIKit

#if !os(watchOS)
	import AVFoundation
#endif


public protocol Tracker: class {

	/** get and set everID. If you set Ever ID it started to use new value for all requests*/
    var everId: String { get set }
    var trackIds: [String] { get }
	var global: GlobalProperties { get set }

    /**Functions sends all request from cache to server. Function can be used only for manual send mode, when <sendDelay>0</sendDelay>
     otherwise it returns false. It returns true if asynchronus command for sending is done*/
	func sendPendingEvents()

	func trackAction(_ event: ActionEvent)

	func trackMediaAction(_ event: MediaEvent)

	func trackPageView(_ event: PageViewEvent)

	
	func trackerForMedia(_ mediaName: String, pageName: String) -> MediaTracker

	#if !os(watchOS)
	func trackerForMedia(_ mediaName: String, pageName: String, automaticallyTrackingPlayer player: AVPlayer) -> MediaTracker
	#endif

	
	func trackerForPage(_ pageName: String) -> PageTracker
    
    #if !os(watchOS)
    /** set media code. Media code will be sent with next page request only. Only setter is working. Getter always returns ""*/
    var mediaCode: String { get set }
    #endif
    
    /**this value override pu parameter if it is setup from code in any other way or configuraion xml */
    var pageURL: String? { get set }
    
    /** return recommendation class instance for getting recommendations. Each call returns new instance. Returns nil if SDK isn't initialized*/
    func getRecommendations() -> Recommendation?
    
    /** return exceptoin tracking object that can be used for exception and error tracking in application */
    var exceptionTracker: ExceptionTracker { get }
}


public extension Tracker {

	public func trackAction(
		_ actionName: String,
		pageName: String,
		advertisementProperties: AdvertisementProperties = AdvertisementProperties(id: nil),
		ecommerceProperties: EcommerceProperties = EcommerceProperties(),
		sessionDetails: [Int: TrackingValue] = [:],
		userProperties: UserProperties = UserProperties(birthday: nil),
		variables: [String : String] = [:]
	) {
		trackAction(
			ActionProperties(name: actionName),
			pageProperties:          PageProperties(name: pageName),
			advertisementProperties: advertisementProperties,
			ecommerceProperties:     ecommerceProperties,
			sessionDetails:          sessionDetails,
			userProperties:          userProperties,
			variables:               variables
		)
	}


	public func trackAction(
		_ actionName: String,
		viewControllerType: AnyObject.Type,
		advertisementProperties: AdvertisementProperties = AdvertisementProperties(id: nil),
		ecommerceProperties: EcommerceProperties = EcommerceProperties(),
		sessionDetails: [Int: TrackingValue] = [:],
		userProperties: UserProperties = UserProperties(birthday: nil),
		variables: [String : String] = [:]
	) {
		trackAction(
			ActionProperties(name: actionName),
			pageProperties:          PageProperties(viewControllerType: viewControllerType),
			advertisementProperties: advertisementProperties,
			ecommerceProperties:     ecommerceProperties,
			sessionDetails:          sessionDetails,
			userProperties:          userProperties,
			variables:               variables
		)
	}


	public func trackAction(
		_ actionProperties: ActionProperties,
		pageProperties: PageProperties,
		advertisementProperties: AdvertisementProperties = AdvertisementProperties(id: nil),
		ecommerceProperties: EcommerceProperties = EcommerceProperties(),
		sessionDetails: [Int: TrackingValue] = [:],
		userProperties: UserProperties = UserProperties(birthday: nil),
		variables: [String : String] = [:]
	) {
		trackAction(ActionEvent(
			actionProperties:        actionProperties,
			pageProperties:          pageProperties,
			advertisementProperties: advertisementProperties,
			ecommerceProperties:     ecommerceProperties,
			sessionDetails:          sessionDetails,
			userProperties:          userProperties,
			variables:               variables
		))
	}


	public func trackMediaAction(
		_ action: MediaEvent.Action,
		mediaProperties: MediaProperties,
		pageName: String?,
		variables: [String : String] = [:]
	) {
		trackMediaAction(MediaEvent(
			action: action,
			mediaProperties: mediaProperties,
			pageName: pageName,
			variables: variables
		))
	}


	public func trackPageView(
		_ pageName: String,
		advertisementProperties: AdvertisementProperties = AdvertisementProperties(id: nil),
		ecommerceProperties: EcommerceProperties = EcommerceProperties(),
		sessionDetails: [Int: TrackingValue] = [:],
		userProperties: UserProperties = UserProperties(birthday: nil),
		variables: [String : String] = [:]
	) {
		trackPageView(
			PageProperties(name: pageName),
			advertisementProperties: advertisementProperties,
			ecommerceProperties:     ecommerceProperties,
			sessionDetails:          sessionDetails,
			userProperties:          userProperties,
			variables:               variables
		)
	}


	public func trackPageView(
		_ pageProperties: PageProperties,
		advertisementProperties: AdvertisementProperties = AdvertisementProperties(id: nil),
		ecommerceProperties: EcommerceProperties = EcommerceProperties(),
		sessionDetails: [Int: TrackingValue] = [:],
		userProperties: UserProperties = UserProperties(birthday: nil),
		variables: [String : String] = [:]
	) {
		trackPageView(PageViewEvent(
			pageProperties:          pageProperties,
			advertisementProperties: advertisementProperties,
			ecommerceProperties:     ecommerceProperties,
			sessionDetails:          sessionDetails,
			userProperties:          userProperties,
			variables:               variables
		))
	}
    
    public func trackCDB(_ crossDeviceProperties: CrossDeviceProperties)
    {
        global.crossDeviceProperties = crossDeviceProperties
        trackPageView("CDBPage")
    }
    
    public subscript(key: String) -> String? {
        get {
            return global.variables[key]
        }
        set {
            global.variables[key] = newValue
        }
    }
}
