import AVFoundation
import CoreTelephony
import ReachabilitySwift
import UIKit


public final class Webtrekk {

	public static let version = "4.0"


	private static let sharedDefaults = UserDefaults.standardDefaults.child(namespace: "webtrekk")

	internal typealias ScreenDimension = (width: Int, height: Int)

	internal static let pixelVersion = "400"
	public static let defaultLogger = DefaultLogger()

	private lazy var backupManager: BackupManager = BackupManager(fileManager: self.fileManager, logger: self.logger)
	private lazy var fileManager: FileManager = FileManager(logger: self.logger, identifier: self.configuration.webtrekkId)
	private lazy var requestManager: RequestManager = RequestManager(logger: self.logger, backupDelegate: self.backupManager, maximumNumberOfEvents: self.configuration.eventQueueLimit)

	private let defaults: UserDefaults
	private var applicationWillEnterForegroundObserver: NSObjectProtocol?
	private var applicationWillResignActiveObserver: NSObjectProtocol?
	private var isFirstEventOfSession = true
	private var isSampling = false

	public let configuration: TrackingConfiguration
	public var crossDeviceBridge: CrossDeviceBridgeParameter?
	public var plugins = [TrackingPlugin]()


	public init(configuration: TrackingConfiguration) {
		self.configuration = configuration
		self.defaults = Webtrekk.sharedDefaults.child(namespace: configuration.webtrekkId)
		self.isFirstEventOfApp = defaults.boolForKey(DefaultsKeys.isFirstEventOfApp) ?? true

		setUp()
	}


	deinit {
		let notificationCenter = NSNotificationCenter.defaultCenter()
		if let applicationWillEnterForegroundObserver = applicationWillEnterForegroundObserver {
			notificationCenter.removeObserver(applicationWillEnterForegroundObserver)
		}
		if let applicationWillResignActiveObserver = applicationWillResignActiveObserver {
			notificationCenter.removeObserver(applicationWillResignActiveObserver)
		}
	}


	private var advertisingIdentifier: NSUUID? {
		guard
			let identifierManagerClass = unsafeBitCast(NSClassFromString("ASIdentifierManager"), Optional<ASIdentifierManager.Type>.self),
			let manager = identifierManagerClass.sharedManager() where manager.advertisingTrackingEnabled,
			let advertisingIdentifier = manager.advertisingIdentifier
		else {
			return nil
		}

		return advertisingIdentifier
	}


	private func appUpdate() -> Bool {
		var appVersion: String
		if !configuration.appVersion.isEmpty {
			appVersion = configuration.appVersion
		} else if let version = NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as? String {
			appVersion = version
		}else {
			appVersion = ""
		}

		let userDefaults = NSUserDefaults.standardUserDefaults()
		if let version = userDefaults.stringForKey(UserStoreKey.VersionNumber) {
			if version != appVersion {
				userDefaults.setValue(appVersion, forKey:UserStoreKey.VersionNumber.rawValue)
				return true
			}
		} else {
			userDefaults.setValue(appVersion, forKey:UserStoreKey.VersionNumber.rawValue)
		}

		return false
	}


	private static let appVersion: String? = {
		return NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as? String
	}()


	private func applicationWillResignActive() {
		defaults.set(key: DefaultsKeys.applicationHibernationDate, to: NSDate())

		requestManager.sendAllEvents()
		// TODO backup
	}


	public func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) {
		updateAutomaticTracking()
	}


	private func applicationWillEnterForeground() {
		if let hibernationDate = defaults.dateForKey(DefaultsKeys.applicationHibernationDate) where -hibernationDate.timeIntervalSinceNow < configuration.sessionTimeoutInterval {
			isFirstEventOfSession = false
		}
		else {
			isFirstEventOfSession = true
		}
	}


	private static let _autotrackingEventHandler = AutotrackingEventHandler()
	internal static var autotrackingEventHandler: protocol<ActionEventHandler, MediaEventHandler, PageViewEventHandler> {
		return _autotrackingEventHandler
	}


	private func autotrackingPagePropertiesNameForViewControllerTypeName(viewControllerTypeName: String) -> PageProperties? {
		return configuration.automaticallyTrackedPages
			.firstMatching({ $0.matches(viewControllerTypeName: viewControllerTypeName) })?
			.pageProperties
	}


	private static func loadEverId() -> String {
		return sharedDefaults.stringForKey(DefaultsKeys.everId) ?? {
			let everId = String(format: "6%010.0f%08lu", arguments: [NSDate().timeIntervalSince1970, arc4random_uniform(99999999) + 1])
			sharedDefaults.set(key: DefaultsKeys.everId, to: everId)
			return everId
		}()
	}


	private static func loadIsOptedOut() -> Bool {
		 return sharedDefaults.boolForKey(DefaultsKeys.isOptedOut) ?? false
	}


	private func defaultUserAgent() -> String {
		return "Tracking Library \(Webtrekk.version) (\(Webtrekk.operatingSystemName()); \(Webtrekk.operatingSystemVersionString()); \(Webtrekk.deviceModelString()); \(NSLocale.currentLocale().localeIdentifier))"
	}


	private static func deviceModelString() -> String {
		let device = UIDevice.currentDevice()
		if device.isSimulator {
			return "\(operatingSystemName()) Simulator"
		}
		else {
			return device.modelIdentifier
		}
	}


	public static let everId = Webtrekk.loadEverId()


	private var isFirstEventOfApp: Bool {
		didSet {
			guard isFirstEventOfApp != oldValue else {
				return
			}

			defaults.set(key: DefaultsKeys.isFirstEventOfApp, to: isFirstEventOfApp)
		}
	}


	public static var isOptedOut = Webtrekk.loadIsOptedOut() {
		didSet {
			guard isOptedOut != oldValue else {
				return
			}

			sharedDefaults.set(key: DefaultsKeys.isOptedOut, to: isOptedOut ? true : nil)
		}
	}


	public var logger: Logger = Webtrekk.defaultLogger {
		didSet {
			guard logger !== oldValue else {
				return
			}

			fileManager.logger = logger
			requestManager.logger = logger
		}
	}


	private static func operatingSystemName() -> String {
		#if os(iOS)
			return "iOS"
		#elseif os(watchOS)
			return "watchOS"
		#elseif os(tvOS)
			return "tvOS"
		#elseif os(OSX)
			return "macOS"
		#endif
	}


	private static func operatingSystemVersionString() -> String {
		let version = NSProcessInfo().operatingSystemVersion
		if version.patchVersion == 0 {
			return "\(version.majorVersion).\(version.minorVersion)"
		}
		else {
			return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
		}
	}


	internal static func screenDimensions() -> ScreenDimension {
		let screenSize: CGRect = UIScreen.mainScreen().bounds
		return (width: Int(screenSize.width), height: Int(screenSize.height))
	}


	public func sendPendingEvents() {
		requestManager.sendAllEvents()
	}

	
	private func setUp() {
		setUpConfig()
		setUpRequestManager()
		setUpObservers()

		updateAutomaticTracking()
		updateSampling()
	}


	private func setUpConfig() {
		// check if there is a local dump of the config saved
		if let localConfig = fileManager.restoreConfiguration(configuration.trackingId) where localConfig.version > configuration.version {
			self.config = localConfig
		}
		else {
			fileManager.saveConfiguration(configuration)
		}

		guard configuration.enableRemoteConfiguration && !configuration.remoteConfigurationUrl.isEmpty, let url = NSURL(string: configuration.remoteConfigurationUrl) else {
			return
		}

		requestManager.fetch(url: url) { data, error in
			guard let xmlData = data else {
				self.logger.logInfo("No data could be retrieved from \(self.config.remoteConfigurationUrl).")
				return
			}
			guard let xmlString = String(data: xmlData, encoding: NSUTF8StringEncoding) else {
				self.logger.logInfo("Cannot parse data retreived from \(self.config.remoteConfigurationUrl)")
				return
			}

			let config: TrackerConfiguration!
			do {
				let parser = try XmlConfigParser(xmlString: xmlString)
				config = parser.trackerConfiguration
			} catch {
				self.logger.logInfo("\(WebtrekkError.RemoteParserError)")
				return
			}


			guard config.version > self.config.version else {
				self.logger.logInfo("Remote configuration is not newer then the currently used.")
				return
			}
			self.logger.logInfo("Updating tracker config from version \(self.config.version) to new version \(config.version)")
			self.config = config
			self.fileManager.saveConfiguration(config)
		}
	}


	private func setUpObservers() {
		let notificationCenter = NSNotificationCenter.defaultCenter()
		applicationWillEnterForegroundObserver = notificationCenter.addObserverForName(UIApplicationWillEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
			self?.applicationWillEnterForeground()
		}
		applicationWillResignActiveObserver = notificationCenter.addObserverForName(UIApplicationWillResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
			self?.applicationWillResignActive()
		}
	}


	private func setUpRequestManager() {
		NSTimer.scheduledTimerWithTimeInterval(5) {
			self.requestManager.sendAllEvents()
		}
	}


	private var shouldEnqueueNewEvents: Bool {
		return isSampling && !Webtrekk.isOptedOut
	}


	internal func track(eventKind: TrackingEvent.Kind) {
		var eventProperties = TrackingEvent.Properties(
			everId:       Webtrekk.everId,
			samplingRate: configuration.samplingRate,
			timeZone:     NSTimeZone.defaultTimeZone(),
			timestamp:    NSDate(),
			userAgent:    defaultUserAgent()
		)

		if isFirstEventOfApp {
			eventProperties.isFirstEventOfApp = true
		}
		if isFirstEventOfSession {
			eventProperties.isFirstEventOfSession = true
		}

		if configuration.automaticallyTracksAdvertisingId {
			eventProperties.advertisingId = advertisingIdentifier
		}
		if configuration.automaticallyTracksAppName {
			eventProperties.appVersion = Webtrekk.appVersion
		}
		if configuration.automaticallyTracksConnectionType, let reachability = try? Reachability.reachabilityForInternetConnection() {
			if reachability.isReachableViaWiFi() {
				eventProperties.connectionType = .wifi
			}
			else if reachability.isReachableViaWWAN() {
				if let carrierType = CTTelephonyNetworkInfo().currentRadioAccessTechnology {
					switch  carrierType {
					case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x:
						eventProperties.connectionType = .cellular_2G
					case CTRadioAccessTechnologyWCDMA,CTRadioAccessTechnologyHSDPA,CTRadioAccessTechnologyHSUPA,CTRadioAccessTechnologyCDMAEVDORev0,CTRadioAccessTechnologyCDMAEVDORevA,CTRadioAccessTechnologyCDMAEVDORevB,CTRadioAccessTechnologyeHRPD:
						eventProperties.connectionType = .cellular_3G
					case CTRadioAccessTechnologyLTE:
						eventProperties.connectionType = .cellular_4G
					default:
						eventProperties.connectionType = .other
					}
				}
				else {
					eventProperties.connectionType = .other
				}
			}
			else if reachability.isReachable() {
				eventProperties.connectionType = .other
			}
			else {
				eventProperties.connectionType = .offline
			}
		}
		if configuration.automaticallyTracksEventQueueSize {
			eventProperties.eventQueueSize = requestManager.eventCount
		}
		if configuration.automaticallyTracksInterfaceOrientation {
			eventProperties.interfaceOrientation = UIApplication.sharedApplication().statusBarOrientation
		}
		if configuration.automaticallyTracksAppUpdates {
			eventProperties.isAppUpdate = appUpdate()
		}

		// FIXME cross-device

		var event = TrackingEvent(kind: eventKind, properties: eventProperties)
		logger.logInfo("Event: \(event)")

		guard let url = UrlCreator.createUrlFromEvent(event, serverUrl: configuration.serverUrl, trackingId: configuration.webtrekkId) else {
			logger.logError("Cannot create URL for event: \(event)")
			return
		}

		for plugin in plugins {
			event = plugin.tracker(self, eventForTrackingEvent: event)
		}

		if shouldEnqueueNewEvents {
			requestManager.enqueueEvent(url, maximumDelay: configuration.maximumSendDelay)
		}

		for plugin in plugins {
			plugin.tracker(self, didTrackEvent: event)
		}

		isFirstEventOfApp = false
		isFirstEventOfSession = false
	}


	public func trackAction(action: String, inPage page: String) {
		// TODO
	}


	public func trackMedia(mediaName: String, mediaGroups: Set<IndexedProperty> = [], player: AVPlayer) {
		AVPlayerTracker.track(
			player: player,
			with:   DefaultMediaTracker(handler: self, mediaName: mediaName, mediaGroups: mediaGroups)
		)
	}


	public func trackViewOfPage(pageName: String) {
		// TODO
	}


	internal static func trackViewOfPage(pageName: String) {
		guard !autoTracker.isEmpty else {
			return
		}

		for tracker in autoTracker {
			tracker.trackViewOfPage(pageName)
		}
	}


	public func trackerForMedia(mediaName: String, mediaGroups: Set<IndexedProperty> = []) -> MediaTracker {
		return DefaultMediaTracker(handler: self, mediaName: mediaName, mediaGroups: mediaGroups)
	}

	
	public func trackerForPage(pageName: String) -> PageTracker {
		return DefaultPageTracker(handler: self, pageName: pageName)
	}


	private func updateAutomaticTracking() {
		let handler = Webtrekk._autotrackingEventHandler

		if configuration.automaticallyTrackedPages.isEmpty {
			if let index = handler.trackers.indexOf({ $0 === self}) {
				handler.trackers.removeAtIndex(index)
			}
		}
		else {
			if !handler.trackers.contains({ $0 === self }) {
				handler.trackers.append(self)
			}

			UIViewController.setUpAutomaticTracking()
		}
	}


	private func updateSampling() {
		if let isSampling = defaults.boolForKey(DefaultsKeys.isSampling), samplingRate = defaults.intForKey(DefaultsKeys.samplingRate) where samplingRate == configuration.samplingRate {
			self.isSampling = isSampling
		}
		else {
			self.isSampling = Int64(arc4random()) % Int64(configuration.samplingRate) == 0

			defaults.set(key: DefaultsKeys.isSampling, to: isSampling)
			defaults.set(key: DefaultsKeys.samplingRate, to: configuration.samplingRate)
		}
	}



	public final class DefaultLogger: Logger {

		public var enabled = true
		public var minimumLevel = LogLevel.Warning


		public func log(@autoclosure message message: () -> String, level: LogLevel) {
			guard enabled && level.rawValue >= minimumLevel.rawValue else {
				return
			}

			NSLog("%@", "[Webtrekk] \(message())")
		}
	}
}


extension Webtrekk: ActionEventHandler {

	internal func handleEvent(event: ActionEvent) {
		track(.action(event))
	}

}


extension Webtrekk: MediaEventHandler {

	internal func handleEvent(event: MediaEvent) {
		track(.media(event))
	}

}


extension Webtrekk: PageViewEventHandler {

	internal func handleEvent(event: PageViewEvent) {
		track(.pageView(event))
	}
}



private final class AutotrackingEventHandler: ActionEventHandler, MediaEventHandler, PageViewEventHandler {

	private var trackers = [Webtrekk]()


	private func handleEvent(event: ActionEvent) {
		var event = event

		for tracker in trackers {
			guard let viewControllerTypeName = event.pageProperties.viewControllerTypeName, pageProperties = tracker.autotrackingPagePropertiesNameForViewControllerTypeName(viewControllerTypeName) else {
				continue
			}

			event.pageProperties = event.pageProperties.merged(with: pageProperties)

			tracker.handleEvent(event)
		}
	}


	private func handleEvent(event: MediaEvent) {
		var event = event

		for tracker in trackers {
			guard let viewControllerTypeName = event.pageProperties.viewControllerTypeName, pageProperties = tracker.autotrackingPagePropertiesNameForViewControllerTypeName(viewControllerTypeName) else {
				continue
			}

			event.pageProperties = event.pageProperties.merged(with: pageProperties)

			tracker.handleEvent(event)
		}
	}


	private func handleEvent(event: PageViewEvent) {
		var event = event

		for tracker in trackers {
			guard let viewControllerTypeName = event.pageProperties.viewControllerTypeName, pageProperties = tracker.autotrackingPagePropertiesNameForViewControllerTypeName(viewControllerTypeName) else {
				continue
			}

			event.pageProperties = event.pageProperties.merged(with: pageProperties)

			tracker.handleEvent(event)
		}
	}
}



private struct DefaultsKeys {

	private static let applicationHibernationDate = "applicationHibernationDate"
	private static let everId = "everId"
	private static let isFirstEventOfApp = "isFirstEventOfApp"
	private static let isSampling = "isSampling"
	private static let isOptedOut = "optedOut"
	private static let samplingRate = "samplingRate"
}



public enum WebtrekkError: ErrorType {
	case InitError
	case InitParserError
	case NoTrackerConfiguration
	case RemoteParserError
}
