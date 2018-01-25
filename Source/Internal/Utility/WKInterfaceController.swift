import WatchKit

internal extension WKInterfaceController {

    private static var isSwizzled = false
    private static var autoTrackerKey = UInt8()

    internal var automaticTracker: PageTracker {
        return objc_getAssociatedObject(self, &WKInterfaceController.autoTrackerKey) as? PageTracker ?? {
            let tracker = DefaultPageTracker(handler: DefaultTracker.autotrackingEventHandler, viewControllerType: type(of: self))
            objc_setAssociatedObject(self, &WKInterfaceController.autoTrackerKey, tracker, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return tracker
            }()
    }

    internal static func setUpAutomaticTracking() {
        guard !isSwizzled else {
            return
        }

        isSwizzled = true

        _ = swizzleMethod(ofType: WKInterfaceController.self, fromSelector: #selector(willActivate), toSelector: #selector(wtWillActivate))
    }

    @objc dynamic func wtWillActivate() {
        self.wtWillActivate()

        guard WebtrekkTracking.isInitialized() else {
            return
        }

        let tracker = WebtrekkTracking.instance() as! DefaultTracker
        if tracker.isApplicationActive {
            automaticTracker.trackPageView()
        }
    }
}
