import UIKit

#if os(watchOS)
    import WatchKit
#else
    import AVFoundation
#endif

class UIFlowObserver: NSObject {

    unowned private let tracker: DefaultTracker

    #if !os(watchOS)
    fileprivate let application = UIApplication.shared
    fileprivate var applicationDidBecomeActiveObserver: NSObjectProtocol?
    fileprivate var applicationWillEnterForegroundObserver: NSObjectProtocol?
    fileprivate var applicationWillResignActiveObserver: NSObjectProtocol?
    private let deepLink = DeepLink()
    private var backgroundTaskIdentifier = UIBackgroundTaskInvalid
    #endif

    init(tracker: DefaultTracker) {
        self.tracker = tracker
    }

    deinit {
        #if !os(watchOS)
            let notificationCenter = NotificationCenter.default
            if let applicationDidBecomeActiveObserver = applicationDidBecomeActiveObserver {
                notificationCenter.removeObserver(applicationDidBecomeActiveObserver)
            }
            if let applicationWillEnterForegroundObserver = applicationWillEnterForegroundObserver {
                notificationCenter.removeObserver(applicationWillEnterForegroundObserver)
            }
            if let applicationWillResignActiveObserver = applicationWillResignActiveObserver {
                notificationCenter.removeObserver(applicationWillResignActiveObserver)
            }
        #endif
    }

    func setup() -> Bool {

        #if !os(watchOS)
            let notificationCenter = NotificationCenter.default
            applicationDidBecomeActiveObserver = notificationCenter.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: nil) { [weak self] _ in
            self?.WTapplicationDidBecomeActive()
            }
            applicationWillEnterForegroundObserver = notificationCenter.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: nil) { [weak self] _ in
            self?.WTapplicationWillEnterForeground()
            }
            applicationWillResignActiveObserver = notificationCenter.addObserver(forName: NSNotification.Name.UIApplicationWillResignActive, object: nil, queue: nil) { [weak self] _ in
            self?.WTapplicationWillResignActive()
            }
            return true
        #else
            guard let delegate = WKExtension.shared().delegate ,
                  let delegateClass = object_getClass(delegate) else {
                logError("Can't find extension delgate.")
                return false
            }

            // add methods to delegateClass
            let replacedMethods = [#selector(WTapplicationWillResignActive), #selector(WTapplicationWillEnterForeground), #selector(WTapplicationDidEnterBackground), #selector(WTapplicationDidBecomeActive)]
            let extentionOriginalMethodNames = ["applicationWillResignActive", "applicationDidBecomeActive", "applicationDidEnterBackground", "applicationDidBecomeActive"]

            for i in 0..<replacedMethods.count {

                guard replaceImplementationFromAnotherClass(toClass: delegateClass, methodChanged: Selector(extentionOriginalMethodNames[i]), fromClass: UIFlowObserver.self, methodAdded: replacedMethods[i]) else {
                    logError("Can't initialize WatchApp setup. See log above for details.")
                    return false
                }
             }
            return true
        #endif
    }

    internal func applicationDidFinishLaunching() {
        checkIsOnMainThread()

        _ = Timer.scheduledTimerWithTimeInterval(15) {
            self.tracker.updateConfiguration()
        }
    }

    @objc dynamic func WTapplicationDidBecomeActive() {

    #if os(watchOS)
        defer {
            if class_respondsToSelector(object_getClass(self), #selector(WTapplicationDidBecomeActive)) {
                self.WTapplicationDidBecomeActive()
            }
        }
        let tracker = WebtrekkTracking.instance() as! DefaultTracker
        tracker.isApplicationActive = true
    #else
        let tracker = self.tracker
    #endif

    checkIsOnMainThread()

    tracker.startRequestManager()

    #if !os(watchOS)
        finishBackroundTask(requestManager: tracker.requestManager)
    #endif
    }

    #if !os(watchOS)

    func finishBackroundTask(requestManager: RequestManager?) {

    guard let requestManager = requestManager else {
            WebtrekkTracking.logger.logError("can't finish background task requestManager isn't initialized")
            return
        }

        if requestManager.backgroundTaskIdentifier != UIBackgroundTaskInvalid {
            application.endBackgroundTask(requestManager.backgroundTaskIdentifier)
            requestManager.backgroundTaskIdentifier = UIBackgroundTaskInvalid
        }
    }
    #else

    // for watchOS only
    @objc dynamic func WTapplicationDidEnterBackground() {
        defer {
            if class_respondsToSelector(object_getClass(self), #selector(WTapplicationDidEnterBackground)) {
                self.WTapplicationDidEnterBackground()
            }
        }
        let tracker = WebtrekkTracking.instance() as! DefaultTracker

        if let started = tracker.requestManager?.started, started {
            tracker.stopRequestManager()
        }

        tracker.isApplicationActive = false
    }

    #endif

    @objc dynamic func WTapplicationWillResignActive() {

        WebtrekkTracking.defaultLogger.logDebug("applicationWillResignActive is called")

        #if os(watchOS)
            defer {
                if class_respondsToSelector(object_getClass(self), #selector(WTapplicationWillResignActive)) {
                    self.WTapplicationWillResignActive()
                }
            }
        let tracker = WebtrekkTracking.instance() as! DefaultTracker
        #else
        let tracker = self.tracker
        #endif

        checkIsOnMainThread()

        guard tracker.checkIfInitialized() else {
            return
        }

        tracker.initHibertationDate()

        #if !os(watchOS)
            if let requestManager = self.tracker.requestManager, requestManager.backgroundTaskIdentifier == UIBackgroundTaskInvalid,
               self.backgroundTaskIdentifier == UIBackgroundTaskInvalid, requestManager.isPending {
                self.backgroundTaskIdentifier = application.beginBackgroundTask(withName: "Webtrekk Tracker #\(self.tracker.configuration.webtrekkId)") { [weak self] in
                    guard let `self` = self else {
                        return
                    }

                    if !requestManager.started || !requestManager.finishing {
                        self.application.endBackgroundTask(self.backgroundTaskIdentifier)
                    }
                    self.backgroundTaskIdentifier = UIBackgroundTaskInvalid
                }
                requestManager.backgroundTaskIdentifier = self.backgroundTaskIdentifier
            }

            self.tracker.stopRequestManager()
        #endif
    }

    @objc dynamic func WTapplicationWillEnterForeground() {

        #if os(watchOS)
            defer {
                if class_respondsToSelector(object_getClass(self), #selector(WTapplicationWillEnterForeground)) {
                    self.WTapplicationWillEnterForeground()
                }
            }
            let tracker = WebtrekkTracking.instance() as! DefaultTracker
        #else
            let tracker = self.tracker
        #endif

        checkIsOnMainThread()

        guard tracker.checkIfInitialized() else {
            return
        }
        tracker.updateFirstSession()
    }
}
