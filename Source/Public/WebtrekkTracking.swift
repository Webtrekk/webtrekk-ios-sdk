import Foundation
import UIKit

#if os(watchOS)
import WatchKit
#endif

#if os(iOS)
import WebKit
#endif

public class WebtrekkTracking {

    /** Current version of the sdk */
    public static let version: String = Bundle.init(for: WebtrekkTracking.self).object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String? ?? "9.9.9"

    /** the default implementation of `TrackingLogger` used for the sdk */
    public static let defaultLogger = DefaultTrackingLogger()

    /** Enable, disable or filter log outputs from the sdk by configuring the logger accordingly. A user implementation of `TrackingLogger` can be used too. */
    public static var logger: TrackingLogger = WebtrekkTracking.defaultLogger

    /** Indicates wether the sdk tries to migrated stored data from the previous major version. */
    public static var migratesFromLibraryV3 = true

    /** Main track object */
    internal static var tracker: Tracker?

     /** Get main shared Webtrekk instance. */
    public static func instance() -> Tracker {
        if tracker == nil {
            tracker = DefaultTracker()
        }

        return tracker!
    }

    /** return true if Webtrekk is already initialized. */
    public static func isInitialized() -> Bool {

        guard self.tracker != nil else {
            return false
        }

        let tracker = self.tracker as! DefaultTracker

        return tracker.isInitialited
    }

    /** initialize tracking. It should be called before invoking instance() function
     Optional parameter "configurationFile" is used to define location of webtrekk configuration file.
     In case this parameter is nil the default location is in main bundle with name webtrekk_config 
     and xml extension*/
    public static func initTrack(_ configurationFile: URL? = nil) throws {
        guard let confFile = configurationFile ?? Bundle.main.url(forResource: "webtrekk_config",
                                                                  withExtension: "xml") else {
            throw TrackerError(message: """
                    Cannot locate webtrekk_config.xml in '\(Bundle.main.bundlePath)'.
                    Either place the file there or use WebtrekkTracking.createTracker(configurationFile:)
                    to specify the file's location.
                """)
        }

        checkIsOnMainThread()

        _ = try createTracker(configurationFile: confFile)
    }

    /**
    Creates a `Tracker` with the given configurationFile URL.

    - Parameter configurationFile: The location of the configuration xml.

    - Throws: `TrackError` when the configurationFile could not be located or when the configuration is not valid.
    */
    private static func createTracker(configurationFile: URL) throws -> Tracker {

        guard let configurationData = try? Data(contentsOf: configurationFile) else {
            throw TrackerError(message: "Cannot load Webtrekk configuration file '\(configurationFile)'")
        }

        do {
            let tracker = instance() as! DefaultTracker
            guard tracker.initializeTracking(configuration: try XmlTrackerConfigurationParser().parse(xml: configurationData)) else {
                throw TrackerError(message: "Cannot initialize Webtrekk tracking see log above for details")
            }

            tracker.initTimers()

            return tracker
        } catch let error {
            throw TrackerError(message: "Cannot load Webtrekk configuration file '\(configurationFile)': \(error)")
        }
    }

    /** Set wether the tracking is disabled or not. */
    public static var isOptedOut: Bool {
        get { return DefaultTracker.isOptedOut }
        set { DefaultTracker.isOptedOut = newValue }
    }

    /** Returns a `PageTracker` for a corresponding `UIViewController` or WKInterfaceController for watchOS which were configured by the xml. */
    #if !os(watchOS)
    public static func trackerForAutotrackedViewController(_ viewController: UIViewController) -> PageTracker {
        checkIsOnMainThread()

        return viewController.automaticTracker
    }

    #else

    public static func trackerForAutotrackedViewController(_ viewController: WKInterfaceController) -> PageTracker {
        checkIsOnMainThread()

        return viewController.automaticTracker
    }
    #endif

    #if os(iOS)

    /** Update or create an instance of the WKWebViewConfiguration class that is used for WKWebView.
     After that all the pages that open in WKWebView and have PIXEL (starting with version 4.4.0)
     integration will do tracking with the same everId (the one that has the application).
     if the configuration is provided in the parameter, it uses the instance and returns it back.
     If the parameter is not provided a new instance is created. In any case the instance of WKWebViewConfiguration is returned.
     
     In case Webtrekk isn't initialized function returns nil and write error message in log.
    */
    @discardableResult
    public static func updateWKWebViewConfiguration(_ configuration: WKWebViewConfiguration? = nil) -> WKWebViewConfiguration? {

        guard let tracker = tracker else {
            logger.logError("Error updating WKWebView configuration. Webtrekk isn't initialized.")
            return nil
        }

        let everId = tracker.everId

        let userScript = WKUserScript(
            source: "var webtrekkApplicationEverId = \"\(everId)\";",
            injectionTime: WKUserScriptInjectionTime.atDocumentStart,
            forMainFrameOnly: false
        )

        let configurationLocal = configuration ?? WKWebViewConfiguration()
        configurationLocal.userContentController.addUserScript(userScript)

        return configurationLocal
    }
    #endif
}
