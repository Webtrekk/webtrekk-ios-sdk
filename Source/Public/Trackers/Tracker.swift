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

    func trackerForMedia(_ mediaName: String,
                         pageName: String,
                         mediaProperties: MediaProperties?,
                         variables: [String: String]?) -> MediaTracker

    #if !os(watchOS)
    func trackerForMedia(_ mediaName: String,
                         pageName: String,
                         automaticallyTrackingPlayer player: AVPlayer,
                         mediaProperties: MediaProperties?,
                         variables: [String: String]?) -> MediaTracker
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

    /** return product list tracker instace for product list tracking */
    var productListTracker: ProductListTracker { get }
}

public extension Tracker {

    func trackAction(
        _ actionName: String,
        pageName: String,
        advertisementProperties: AdvertisementProperties = AdvertisementProperties(),
        ecommerceProperties: EcommerceProperties = EcommerceProperties(),
        sessionDetails: [Int: TrackingValue] = [:],
        userProperties: UserProperties = UserProperties(),
        variables: [String: String] = [:]
    ) {
        trackAction(
            ActionProperties(name: actionName),
            pageProperties: PageProperties(name: pageName),
            advertisementProperties: advertisementProperties,
            ecommerceProperties: ecommerceProperties,
            sessionDetails: sessionDetails,
            userProperties: userProperties,
            variables: variables
        )
    }

    func trackAction(
        _ actionName: String,
        viewControllerType: AnyObject.Type,
        advertisementProperties: AdvertisementProperties = AdvertisementProperties(),
        ecommerceProperties: EcommerceProperties = EcommerceProperties(),
        sessionDetails: [Int: TrackingValue] = [:],
        userProperties: UserProperties = UserProperties(),
        variables: [String: String] = [:]
    ) {
        trackAction(
            ActionProperties(name: actionName),
            pageProperties: PageProperties(viewControllerType: viewControllerType),
            advertisementProperties: advertisementProperties,
            ecommerceProperties: ecommerceProperties,
            sessionDetails: sessionDetails,
            userProperties: userProperties,
            variables: variables
        )
    }

    func trackAction(
        _ actionProperties: ActionProperties,
        pageProperties: PageProperties = PageProperties(),
        advertisementProperties: AdvertisementProperties = AdvertisementProperties(),
        ecommerceProperties: EcommerceProperties = EcommerceProperties(),
        sessionDetails: [Int: TrackingValue] = [:],
        userProperties: UserProperties = UserProperties(),
        variables: [String: String] = [:]
    ) {
        trackAction(ActionEvent(
            actionProperties: actionProperties,
            pageProperties: pageProperties,
            advertisementProperties: advertisementProperties,
            ecommerceProperties: ecommerceProperties,
            sessionDetails: sessionDetails,
            userProperties: userProperties,
            variables: variables
        ))
    }

    func trackMediaAction(
        _ action: MediaEvent.Action,
        mediaProperties: MediaProperties,
        pageName: String?,
        variables: [String: String] = [:]
    ) {
        trackMediaAction(MediaEvent(
            action: action,
            mediaProperties: mediaProperties,
            pageName: pageName,
            variables: variables
        ))
    }

    func trackPageView(
        _ pageName: String,
        advertisementProperties: AdvertisementProperties = AdvertisementProperties(),
        ecommerceProperties: EcommerceProperties = EcommerceProperties(),
        sessionDetails: [Int: TrackingValue] = [:],
        userProperties: UserProperties = UserProperties(),
        variables: [String: String] = [:]
    ) {
        trackPageView(
            PageProperties(name: pageName),
            advertisementProperties: advertisementProperties,
            ecommerceProperties: ecommerceProperties,
            sessionDetails: sessionDetails,
            userProperties: userProperties,
            variables: variables
        )
    }

    func trackPageView(
        _ pageProperties: PageProperties,
        advertisementProperties: AdvertisementProperties = AdvertisementProperties(),
        ecommerceProperties: EcommerceProperties = EcommerceProperties(),
        sessionDetails: [Int: TrackingValue] = [:],
        userProperties: UserProperties = UserProperties(),
        variables: [String: String] = [:]
    ) {
        trackPageView(PageViewEvent(
            pageProperties: pageProperties,
            advertisementProperties: advertisementProperties,
            ecommerceProperties: ecommerceProperties,
            sessionDetails: sessionDetails,
            userProperties: userProperties,
            variables: variables
        ))
    }

    func trackCDB(_ crossDeviceProperties: CrossDeviceProperties) {
        global.crossDeviceProperties = crossDeviceProperties
        trackPageView("CDBPage")
    }

    subscript(key: String) -> String? {
        get {
            return global.variables[key]
        }
        set {
            global.variables[key] = newValue
        }
    }

    func trackerForMedia(_ mediaName: String,
                         pageName: String,
                         mediaProperties: MediaProperties? = nil,
                         variables: [String: String]? = nil) -> MediaTracker {

        return trackerForMedia(mediaName,
                               pageName: pageName,
                               mediaProperties: mediaProperties,
                               variables: variables)
    }

    #if !os(watchOS)
    func trackerForMedia(_ mediaName: String,
                         pageName: String,
                         automaticallyTrackingPlayer player: AVPlayer,
                         mediaProperties: MediaProperties? = nil,
                         variables: [String: String]? = nil) -> MediaTracker {

        return trackerForMedia(mediaName, pageName: pageName,
                               automaticallyTrackingPlayer: player,
                               mediaProperties: mediaProperties,
                               variables: variables)
    }
    #endif
}
