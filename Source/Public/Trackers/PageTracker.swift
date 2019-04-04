#if !os(watchOS)
    import AVFoundation
#endif

public protocol PageTracker: class {

    var advertisementProperties: AdvertisementProperties { get set }
    var ecommerceProperties: EcommerceProperties { get set }
    var pageProperties: PageProperties { get set }
    var sessionDetails: [Int: TrackingValue] { get set }
    var userProperties: UserProperties { get set }
    var variables: [String: String] { get set }

    func trackAction(_ actionName: String)
    func trackAction(_ event: ActionEvent)
    func trackerForMedia(_ mediaName: String) -> MediaTracker
    func trackMediaAction(_ event: MediaEvent)
    func trackPageView()
    func trackPageView(_ pageViewEvent: PageViewEvent)

    #if !os(watchOS)
    func trackerForMedia(_ mediaName: String, automaticallyTrackingPlayer player: AVPlayer) -> MediaTracker
    #endif
}

public extension PageTracker {

    func trackAction(_ actionName: String) {
        trackAction(ActionEvent(actionProperties: ActionProperties(name: actionName), pageProperties: pageProperties))
    }

    subscript(key: String) -> String? {
        get {
            return variables[key]
        }

        set {
            variables[key] = newValue
        }
    }

}
