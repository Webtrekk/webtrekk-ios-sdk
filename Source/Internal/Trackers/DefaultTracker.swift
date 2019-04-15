import UIKit

#if os(watchOS)
    import WatchKit
#elseif os(tvOS)
    import AVFoundation
    import Reachability
#else
    import AVFoundation
    import CoreTelephony
    import Reachability
#endif

final class DefaultTracker: Tracker {

    private static var instances = [ObjectIdentifier: WeakReference<DefaultTracker>]()
    private static let sharedDefaults = UserDefaults.standardDefaults.child(namespace: "webtrekk")

    #if !os(watchOS)
    fileprivate let application = UIApplication.shared
    private let deepLink = DeepLink()
    #else
    internal var isApplicationActive = false
    #endif

    fileprivate var flowObserver: UIFlowObserver!
    private var defaults: UserDefaults?
    private var isFirstEventOfSession = true
    private var isSampling = false
    private let sharedDefaults = UserDefaults.standardDefaults.child(namespace: "webtrekk")
    var requestManager: RequestManager?
    private var requestQueueBackupFile: URL?
    private var requestQueueLoaded = false
    private var requestUrlBuilder: RequestUrlBuilder?
    private var campaign: Campaign?
    private let appinstallGoal = AppinstallGoal()
    private var manualStart: Bool = false
    var isInitialited: Bool = false
    /**this value override pu parameter if it is setup from code in any other way or configuraion xml*/
    var pageURL: String?

    internal var global = GlobalProperties()

    let exceptionTracker: ExceptionTracker  = ExceptionTrackerImpl()

    let productListTracker: ProductListTracker = ProductListTrackerImpl()

    var exceptionTrackingImpl: ExceptionTrackerImpl? {
        return self.exceptionTracker as? ExceptionTrackerImpl
    }

    enum RequestType {
        case normal, exceptionTracking
    }

    var trackIds: [String] {
        get {
            guard self.checkIfInitialized() else {
                return []
            }
            return configuration.webtrekkId.replacingOccurrences(of: " ", with: "").components(separatedBy: ",")
        }
    }

    func initializeTracking(configuration: TrackerConfiguration) -> Bool {

        checkIsOnMainThread()

        guard !self.isInitialited else {
            logError("Webtrekk SDK has been already initialized.")
            return false
        }

        self.flowObserver = UIFlowObserver(tracker: self)

        let defaults = DefaultTracker.sharedDefaults

        var migratedRequestQueue: [URL]?
        if let webtrekkId = configuration.webtrekkId.nonEmpty, !(defaults.boolForKey(DefaultsKeys.migrationCompleted) ?? false) {
            defaults.set(key: DefaultsKeys.migrationCompleted, to: true)

            if WebtrekkTracking.migratesFromLibraryV3, let migration = Migration.migrateFromLibraryV3(webtrekkId: webtrekkId) {

                defaults.set(key: DefaultsKeys.everId, to: migration.everId)

                if let appVersion = migration.appVersion {
                    defaults.set(key: DefaultsKeys.appVersion, to: appVersion)
                }
                if !DefaultTracker.isOptedOutWasSetManually, let isOptedOut = migration.isOptedOut {
                    defaults.set(key: DefaultsKeys.isOptedOut, to: isOptedOut ? true : nil)
                }
                if let samplingRate = migration.samplingRate, let isSampling = migration.isSampling {
                    defaults.set(key: DefaultsKeys.isSampling, to: isSampling)
                    defaults.set(key: DefaultsKeys.samplingRate, to: samplingRate)
                }

                migratedRequestQueue = migration.requestQueue as [URL]?

                logInfo("Migrated from Webtrekk Library v3: \(migration)")
            }
        }

        self.convertDefaults()

        var configuration = configuration
        if let configurationData = defaults.dataForKey(DefaultsKeys.configuration) {
            do {
                let savedConfiguration = try XmlTrackerConfigurationParser().parse(xml: configurationData)
                if savedConfiguration.version > configuration.version {
                    logDebug("Using saved configuration (version \(savedConfiguration.version)).")
                    configuration = savedConfiguration
                }
            } catch let error {
                logError("Cannot load saved configuration. Will fall back to initial configuration. Error: \(error)")
            }
        }

        guard let validatedConfiguration = DefaultTracker.validatedConfiguration(configuration) else {
            logError("Invalid configuration initialization error")
            return false
        }

        configuration = validatedConfiguration

        self.configuration = configuration
        self.defaults = defaults

        checkForAppUpdate()

        self.exceptionTrackingImpl?.initializeExceptionTracking(config: configuration)
        self.isFirstEventAfterAppUpdate = defaults.boolForKey(DefaultsKeys.isFirstEventAfterAppUpdate) ?? false
        self.isFirstEventOfApp = defaults.boolForKey(DefaultsKeys.isFirstEventOfApp) ?? true
        self.manualStart = configuration.maximumSendDelay == 0
        self.requestManager = RequestManager(manualStart: self.manualStart)
        self.requestQueueBackupFile = DefaultTracker.requestQueueBackupFileForWebtrekkId(configuration.webtrekkId)
        self.campaign = Campaign(trackID: configuration.webtrekkId)

        guard let campaign = self.campaign else {
            return false
        }

        // default is true, so when it's not defined, everything works as before
        if configuration.enableCampaignTracking {
            campaign.processCampaign()
            self.appinstallGoal.setupAppinstallGoal()
        } else {
            // when using the enableCampaignTracking flag (false),
            // the campaign should be finished manually to not block the queue
            self.sharedDefaults.set(key: Campaign.campaignHasProcessed, to: true)
        }

        self.requestUrlBuilder = RequestUrlBuilder(serverUrl: configuration.serverUrl, webtrekkId: configuration.webtrekkId, campaign: campaign)

        DefaultTracker.instances[ObjectIdentifier(self)] = WeakReference(self)

        requestManager?.delegate = self

        if let migratedRequestQueue = migratedRequestQueue, !DefaultTracker.isOptedOut {
            requestManager?.prependRequests(migratedRequestQueue)
        }

        guard setUp() else {
            return false
        }

        checkForDuplicateTrackers()

        // exception tracking init

        logInfo("Initialization is completed")
        self.isInitialited = true

        self.exceptionTrackingImpl?.sendSavedException()
        return true
    }

    func checkIfInitialized() -> Bool {
        if !self.isInitialited {
            logError("Webtrekk SDK isn't initialited")
        }

        return self.isInitialited
    }

    deinit {
        let id = ObjectIdentifier(self)

        onMainQueue(synchronousIfPossible: true) {
            DefaultTracker.instances[id] = nil

            if let requestManager = self.requestManager, requestManager.started {
                requestManager.stop()
            }
        }
    }

    func initHibertationDate() {
        let date = Date()
        WebtrekkTracking.defaultLogger.logDebug("""
                save current date for session detection \(date) with defaults \(self.defaults == nil)
        """)
        self.defaults?.set(key: DefaultsKeys.appHibernationDate, to: date)
    }

    func updateFirstSession() {

        let hibernationDateSettings = self.defaults?.dateForKey(DefaultsKeys.appHibernationDate)

        WebtrekkTracking.defaultLogger.logDebug("""
                read saved date for session detection \(hibernationDateSettings.simpleDescription),
                defaults \(self.defaults == nil) value: \(hibernationDateSettings.simpleDescription)
                timeIntervalSinceNow is: \(String(describing: hibernationDateSettings?.timeIntervalSinceNow))
        """)

        if let hibernationDate = hibernationDateSettings, -hibernationDate.timeIntervalSinceNow < configuration.resendOnStartEventTime {
            self.isFirstEventOfSession = false
        } else {
            self.isFirstEventOfSession = true
        }
    }

    internal func initTimers() {
        checkIsOnMainThread()

        startRequestManager()

        _ = Timer.scheduledTimerWithTimeInterval(15) {
            self.updateConfiguration()
        }
    }

    typealias AutoEventHandler = ActionEventHandler & MediaEventHandler & PageViewEventHandler
    static let autotrackingEventHandler: AutoEventHandler = AutotrackingEventHandler()

    private func checkForAppUpdate() {
        checkIsOnMainThread()

        let lastCheckedAppVersion = defaults?.stringForKey(DefaultsKeys.appVersion)
        if lastCheckedAppVersion != Environment.appVersion {
            defaults?.set(key: DefaultsKeys.appVersion, to: Environment.appVersion)

            self.isFirstEventAfterAppUpdate = true
        }
    }

    private func checkForDuplicateTrackers() {
        let hasDuplicate = DefaultTracker.instances.values.contains { $0.target?.configuration.webtrekkId == configuration.webtrekkId && $0.target !== self }
        if hasDuplicate {
            logError("""
                    Multiple tracker instances for the same Webtrekk ID '\(configuration.webtrekkId)' were created.
                    This is not supported and will corrupt tracking.
                """)
        }
    }

    private func convertDefaults() {

        let settings = DefaultTracker.sharedDefaults
        let isConverted = settings.boolForKey(DefaultsKeys.isSettingsToAppSpecificConverted)

        // don't do anythig if converstions has been done
        guard isConverted == nil || !isConverted! else {
            return
        }

        settings.convertDefaultsToAppSpecific()

        settings.set(key: DefaultsKeys.isSettingsToAppSpecificConverted, to: true)
    }

    internal fileprivate(set) var configuration: TrackerConfiguration! {
        didSet {
            checkIsOnMainThread()

            requestUrlBuilder?.serverUrl = configuration.serverUrl
            requestUrlBuilder?.webtrekkId = configuration.webtrekkId

            updateSampling()

            updateAutomaticTracking()
        }
    }

    private func generateRequestProperties() -> TrackerRequest.Properties {

        var requestProperties = TrackerRequest.Properties(
            everId: everId,
            samplingRate: configuration.samplingRate,
            timeZone: TimeZone.current,
            timestamp: Date(),
            userAgent: DefaultTracker.userAgent
        )
        requestProperties.locale = Locale.current

        #if os(watchOS)
            let device = WKInterfaceDevice.current()
            requestProperties.screenSize = (width: Int(device.screenBounds.width * device.screenScale),
                                            height: Int(device.screenBounds.height * device.screenScale))
        #else
            let screen = UIScreen.main
            requestProperties.screenSize = (width: Int(screen.bounds.width * screen.scale),
                                            height: Int(screen.bounds.height * screen.scale))
        #endif

        if isFirstEventAfterAppUpdate && configuration.automaticallyTracksAppUpdates {
            requestProperties.isFirstEventAfterAppUpdate = true
        }
        if isFirstEventOfApp {
            requestProperties.isFirstEventOfApp = true
        }

        requestProperties.isFirstEventOfSession = self.isFirstEventOfSession

        if configuration.automaticallyTracksAdvertisingId {
            requestProperties.advertisingId = Environment.advertisingIdentifierManager?.advertisingIdentifier
        }
        if configuration.automaticallyTracksAdvertisingOptOut {
            requestProperties.advertisingTrackingEnabled = Environment.advertisingIdentifierManager?.advertisingTrackingEnabled
        }
        if configuration.automaticallyTracksAppVersion {
            requestProperties.appVersion = Environment.appVersion
        }
        if configuration.automaticallyTracksRequestQueueSize {
            requestProperties.requestQueueSize = requestManager?.queue.size.value
        }
        if configuration.automaticallyTracksAdClearId {
            requestProperties.adClearId = adClearId
        }

        #if !os(watchOS) && !os(tvOS)
            if configuration.automaticallyTracksConnectionType, let connectionType = retrieveConnectionType() {
                requestProperties.connectionType = connectionType
            }

            if configuration.automaticallyTracksInterfaceOrientation {
                requestProperties.interfaceOrientation = application.statusBarOrientation
            }
        #endif

        return requestProperties
    }

    internal func enqueueRequestForEvent(_ event: TrackingEvent, type: RequestType = .normal) {
        checkIsOnMainThread()

        guard self.checkIfInitialized() else {
            return
        }

        let requestProperties = generateRequestProperties()

        //merge lowest priority global properties over request properties.
        let requestBuilder = RequestTrackerBuilder(self.campaign!,
                                                   pageURL: self.pageURL,
                                                   configuration: self.configuration!,
                                                   global: self.global,
                                                   appInstall: self.appinstallGoal)

        #if !os(watchOS)
            requestBuilder.setDeepLink(deepLink: self.deepLink)
        #endif

        guard let request = requestBuilder.createRequest(event, requestProperties: requestProperties) else {
            return
        }

        if shouldEnqueueNewEvents {
            let requestUrls = self.requestUrlBuilder?.urlForRequests(request, type: type)
            requestUrls?.forEach {
                self.requestManager?.enqueueRequest($0, maximumDelay: configuration.maximumSendDelay)
            }

        }

        self.isFirstEventAfterAppUpdate = false
        self.isFirstEventOfApp = false
        self.isFirstEventOfSession = false
    }

    /*
     * AdClear ID
     */
    private var adClearIdInternal: UInt64?

    var adClearId: UInt64 {
        get {
            checkIsOnMainThread()

            if adClearIdInternal == nil {
                adClearIdInternal = AdClearId.getAdClearId()
            }

            return adClearIdInternal!
        }
    }

    /** get and set everID. If you set Ever ID it started to use new value for all requests*/
    var everId: String {
        get {
            checkIsOnMainThread()

            // cash ever id in internal parameter to avoid multiple request to setting.
            if everIdInternal == nil {
                everIdInternal = try? DefaultTracker.generateEverId()
                return everIdInternal!
            } else {
                return everIdInternal!
            }
        }

        set(newEverID) {
            checkIsOnMainThread()

            //check if ever id has correct format
            if let isMatched = newEverID.isMatchForRegularExpression("\\d{19}"), isMatched {
                // set ever id value in setting and in cash
                DefaultTracker.sharedDefaults.set(key: DefaultsKeys.everId, to: newEverID)
                self.everIdInternal = newEverID
            } else {
                WebtrekkTracking.defaultLogger.logError("Incorrect ever id format: \(newEverID)")
            }
        }
    }

    static func generateEverId() throws -> String {

        var everId = DefaultTracker.sharedDefaults.stringForKey(DefaultsKeys.everId)

        if everId != nil {
            return everId!
        } else {
            everId = String(format: "6%010.0f%08lu", arguments: [Date().timeIntervalSince1970, arc4random_uniform(99999999) + 1])
            DefaultTracker.sharedDefaults.set(key: DefaultsKeys.everId, to: everId)

            guard everId != nil else {
                let msg = "Can't generate ever id"
                _ = TrackerError(message: msg)
                return ""
            }

            return everId!
        }

    }

    //cash for ever id
    private var everIdInternal: String?

    private var isFirstEventAfterAppUpdate: Bool = false {
        didSet {
            checkIsOnMainThread()

            guard isFirstEventAfterAppUpdate != oldValue else {
                return
            }

            defaults?.set(key: DefaultsKeys.isFirstEventAfterAppUpdate, to: isFirstEventAfterAppUpdate)
        }
    }

    private var isFirstEventOfApp: Bool = true {
        didSet {
            checkIsOnMainThread()

            guard isFirstEventOfApp != oldValue else {
                return
            }

            defaults?.set(key: DefaultsKeys.isFirstEventOfApp, to: isFirstEventOfApp)
        }
    }

    internal static var isOptedOut = DefaultTracker.loadIsOptedOut() {
        didSet {
            checkIsOnMainThread()

            isOptedOutWasSetManually = true

            guard isOptedOut != oldValue else {
                return
            }

            sharedDefaults.set(key: DefaultsKeys.isOptedOut, to: isOptedOut ? true : nil)

            if isOptedOut {
                for trackerReference in instances.values {
                    trackerReference.target?.requestManager?.clearPendingRequests()
                }
            }
        }
    }
    private static var isOptedOutWasSetManually = false

    private static func loadIsOptedOut() -> Bool {
        checkIsOnMainThread()

        return sharedDefaults.boolForKey(DefaultsKeys.isOptedOut) ?? false
    }

    private func loadRequestQueue() {
        checkIsOnMainThread()

        guard self.checkIfInitialized() else {
            return
        }

        guard !self.requestQueueLoaded else {
            return
        }

        self.requestManager?.queue.load()
        requestQueueLoaded = true

        // do transition from old request file
        guard let file = self.requestQueueBackupFile else {
            return
        }

        let fileManager = FileManager.default
        guard fileManager.itemExistsAtURL(file) else {
            return
        }

        guard !DefaultTracker.isOptedOut else {

            self.requestManager?.queue.deleteAll()

            return
        }

        let queue: [URL]
        do {
            let data = try Data(contentsOf: file, options: [])

            let object = NSKeyedUnarchiver.unarchive(data: data)

            guard let _queue = object as? [URL] else {
                logError("Cannot load request queue from '\(file)': Data has wrong format: \(object.simpleDescription)")
                return
            }

            queue = _queue
        } catch let error {
            logError("Cannot load request queue from '\(file)': \(error)")
            return
        }

        logDebug("Loaded \(queue.count) queued request(s) from '\(file)'.")
        requestManager?.prependRequests(queue)

        // delete old archive file forever
        do {
            try FileManager.default.removeItem(at: file)
            logDebug("Deleted request queue at '\(file).")
        } catch let error {
            logError("Cannot remove request queue at '\(file)': \(error)")
        }
    }

    #if !os(watchOS) && !os(tvOS)
    private func retrieveConnectionType() -> TrackerRequest.Properties.ConnectionType? {
        guard let reachability = Reachability.init() else {
            return nil
        }

        switch reachability.connection {
        case .none:
            return .offline
        case .wifi:
            return .wifi
        case .cellular:
            guard let carrierType = CTTelephonyNetworkInfo().currentRadioAccessTechnology else {
                return .other
            }

            switch carrierType {
            case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x:
                return .cellular_2G
            case CTRadioAccessTechnologyWCDMA,
                 CTRadioAccessTechnologyHSDPA,
                 CTRadioAccessTechnologyHSUPA,
                 CTRadioAccessTechnologyCDMAEVDORev0,
                 CTRadioAccessTechnologyCDMAEVDORevA,
                 CTRadioAccessTechnologyCDMAEVDORevB,
                 CTRadioAccessTechnologyeHRPD:
                return .cellular_3G
            case CTRadioAccessTechnologyLTE:
                return .cellular_4G
            default:
                return .other
            }
        }
    }
    #endif

    //request for old backup file path. It is required for transiation only
    private static func requestQueueBackupFileForWebtrekkId(_ webtrekkId: String) -> URL? {
        checkIsOnMainThread()

        let searchPathDirectory: FileManager.SearchPathDirectory
        #if os(iOS) || os(OSX) || os(watchOS)
            searchPathDirectory = .applicationSupportDirectory
        #elseif os(tvOS)
            searchPathDirectory = .cachesDirectory
        #endif

        let fileManager = FileManager.default

        var directory: URL
        do {
            directory = try fileManager.url(for: searchPathDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch let error {
            logError("Cannot find directory for storing request queue backup file: \(error)")
            return nil
        }

        directory = directory.appendingPathComponent("Webtrekk")
        directory = directory.appendingPathComponent(webtrekkId)

        if !fileManager.itemExistsAtURL(directory) {
            return nil
        }

        return directory.appendingPathComponent("requestQueue.archive")
    }

    /**Functions sends all request from cache to server. Function can be used only for manual send mode, when <sendDelay>0</sendDelay>
     otherwise it produce error log and don't do anything*/
    internal func sendPendingEvents() {
        checkIsOnMainThread()

        guard checkIfInitialized() else {
            return
        }

        guard self.manualStart else {
            WebtrekkTracking.defaultLogger.logError("No manual send mode (sendDelay == 0). Command is ignored. ")
            return
        }

        self.requestManager?.sendAllRequests()
    }

    private func setUp() -> Bool {
        checkIsOnMainThread()

        guard self.flowObserver.setup() else {
            return false
        }

        #if !os(watchOS)
            setupAutoDeepLinkTrack()
        #endif

        updateSampling()

        return true
    }

    private var shouldEnqueueNewEvents: Bool {
        checkIsOnMainThread()

        return isSampling && !DefaultTracker.isOptedOut
    }

    func startRequestManager() {
        checkIsOnMainThread()

        guard checkIfInitialized() else {
            return
        }

        guard let started = requestManager?.started, !started else {
            return
        }

        loadRequestQueue()
        requestManager?.start()
    }

    func stopRequestManager() {

        guard checkIfInitialized() else {
            return
        }

        guard (requestManager?.started)! else {
            return
        }

        requestManager?.stop()
    }

    internal func trackAction(_ event: ActionEvent) {
        checkIsOnMainThread()

        handleEvent(event)
    }

    internal func trackMediaAction(_ event: MediaEvent) {
        checkIsOnMainThread()

        handleEvent(event)
    }

    internal func trackPageView(_ event: PageViewEvent) {
        checkIsOnMainThread()

        handleEvent(event)
    }

    internal func trackerForMedia(_ mediaName: String,
                                  pageName: String,
                                  mediaProperties: MediaProperties? = nil,
                                  variables: [String: String]? = nil) -> MediaTracker {
        checkIsOnMainThread()

        return DefaultMediaTracker(handler: self, mediaName: mediaName, pageName: pageName,
                                   mediaProperties: mediaProperties,
                                   variables: variables)
    }

    #if !os(watchOS)
    internal func trackerForMedia(_ mediaName: String,
                                  pageName: String,
                                  automaticallyTrackingPlayer player: AVPlayer,
                                  mediaProperties: MediaProperties? = nil,
                                  variables: [String: String]? = nil) -> MediaTracker {
        checkIsOnMainThread()

        let tracker = trackerForMedia(mediaName, pageName: pageName, mediaProperties: mediaProperties, variables: variables)
        AVPlayerTracker.track(player: player, with: tracker)

        return tracker
    }
    #endif

    internal func trackerForPage(_ pageName: String) -> PageTracker {
        checkIsOnMainThread()

        return DefaultPageTracker(handler: self, pageName: pageName)
    }

    /** return recommendation class instance for getting recommendations. Each call returns new instance. Returns nil if SDK isn't initialized*/
    func getRecommendations() -> Recommendation? {
        guard checkIfInitialized() else {
            return nil
        }

        return RecomendationImpl(configuration: self.configuration)
    }

    #if !os(watchOS)
    fileprivate func setupAutoDeepLinkTrack() {
        //init deep link to get automatic object
        self.deepLink.deepLinkInit()
    }
    #endif

    fileprivate func updateAutomaticTracking() {
        checkIsOnMainThread()

        guard let handler = DefaultTracker.autotrackingEventHandler as? AutotrackingEventHandler else {
            return
        }

        if self.configuration.automaticallyTrackedPages.isEmpty {
            if let index = handler.trackers.firstIndex(where: { [weak self] in $0.target === self}) {
                handler.trackers.remove(at: index)
            }
        } else {
            if !handler.trackers.contains(where: {[weak self] in $0.target === self }) {
                handler.trackers.append(WeakReference(self))
            }

            #if !os(watchOS)
            UIViewController.setUpAutomaticTracking()
            #else
            WKInterfaceController.setUpAutomaticTracking()
            #endif
        }
    }

    func updateConfiguration() {
        checkIsOnMainThread()

        guard let updateUrl = self.configuration.configurationUpdateUrl else {
            return
        }

        _ = requestManager?.fetch(url: updateUrl) { data, error in
            if let error = error {
                logError("Cannot load configuration from \(updateUrl): \(error)")
                return
            }
            guard let data = data, !data.isEmpty else {
                logError("Cannot load configuration from \(updateUrl): Server returned no data.")
                return
            }
            let maxSize = 1024*1024

            guard data.count < maxSize else {
                logError("Error load configuration xml. Exceeded size \(maxSize)")
                return
            }

            var configuration: TrackerConfiguration
            do {
                configuration = try XmlTrackerConfigurationParser().parse(xml: data)
            } catch let error {
                logError("Cannot parse configuration located at \(updateUrl): \(error)")
                return
            }

            guard configuration.version > self.configuration.version else {
                logInfo("Local configuration is up-to-date with version \(self.configuration.version).")
                return
            }

            guard let validatedConfiguration = DefaultTracker.validatedConfiguration(configuration) else {
                logError("Invalid updated configuration initialization error")
                return
            }

            configuration = validatedConfiguration

            logInfo("Updating from configuration version \(self.configuration.version) to version \(configuration.version) located at \(updateUrl).")
            self.defaults?.set(key: DefaultsKeys.configuration, to: data)

            self.configuration = configuration
        }
    }

    private func updateSampling() {
        checkIsOnMainThread()

        if let isSampling = defaults?.boolForKey(DefaultsKeys.isSampling),
           let samplingRate = defaults?.intForKey(DefaultsKeys.samplingRate), samplingRate == configuration.samplingRate {
           self.isSampling = isSampling
        } else {
            if configuration.samplingRate > 1 {
                self.isSampling = Int64(arc4random()) % Int64(configuration.samplingRate) == 0
            } else {
                self.isSampling = true
            }

            defaults?.set(key: DefaultsKeys.isSampling, to: isSampling)
            defaults?.set(key: DefaultsKeys.samplingRate, to: configuration.samplingRate)
        }
    }

    static let userAgent: String = {
        checkIsOnMainThread()

        let properties = [
            Environment.operatingSystemName + " " + Environment.operatingSystemVersionString,
            Environment.deviceModelString,
            Locale.current.identifier
            ].joined(separator: "; ")

        return "Tracking Library \(WebtrekkTracking.version) (\(properties))"
    }()

    private static func validatedConfiguration(_ configuration: TrackerConfiguration) -> TrackerConfiguration? {
        checkIsOnMainThread()

        var configuration = configuration
        var problems = [String]()
        var isError = false

        guard !configuration.webtrekkId.isEmpty else {
            configuration.webtrekkId = "ERROR"
            problems.append("webtrekkId must not be empty!! -> changed to 'ERROR'")

            return nil
        }

        guard !configuration.serverUrl.absoluteString.isEmpty else {

            problems.append("trackDomain must not be empty!! -> changed to 'ERROR'")

            return nil
        }

        var pageIndex = 0
        configuration.automaticallyTrackedPages = configuration.automaticallyTrackedPages.filter { page in
            defer { pageIndex += 1 }

            guard page.pageProperties.name?.nonEmpty != nil else {
                problems.append("automaticallyTrackedPages[\(pageIndex)] must not be empty")
                isError = true
                return false
            }

            RequestTrackerBuilder.produceWarningForProperties(properties: page)

            return true
        }

        RequestTrackerBuilder.produceWarningForProperties(properties: configuration.globalProperties)

        func checkProperty<Value>(_ name: String, value: Value, allowedValues: ClosedRange<Value>) -> Value {
            guard !allowedValues.contains(value) else {
                return value
            }

            let newValue = allowedValues.clamp(value)
            problems.append("\(name) (\(value)) must be \(TrackerConfiguration.allowedMaximumSendDelays.conditionText) -> was corrected to \(newValue)")
            isError = true
            return newValue
        }

        configuration.maximumSendDelay = checkProperty("maximumSendDelay",
                                                       value: configuration.maximumSendDelay,
                                                       allowedValues: TrackerConfiguration.allowedMaximumSendDelays)
        configuration.samplingRate = checkProperty("samplingRate",
                                                   value: configuration.samplingRate,
                                                   allowedValues: TrackerConfiguration.allowedSamplingRates)
        configuration.resendOnStartEventTime = checkProperty("resendOnStartEventTime",
                                                             value: configuration.resendOnStartEventTime,
                                                             allowedValues: TrackerConfiguration.allowedResendOnStartEventTimes)
        configuration.version = checkProperty("version",
                                              value: configuration.version,
                                              allowedValues: TrackerConfiguration.allowedVersions)

        if !problems.isEmpty {
            (isError ? logError : logWarning)("Illegal values in tracker configuration: \(problems.joined(separator: ", "))")
        }

        return configuration
    }

    #if !os(watchOS)

    /** set media code. Media code will be sent with next page request only. Only setter is working. Getter always returns ""d*/
    var mediaCode: String {
        get {
            return ""
        }

        set (newMediaCode) {
            checkIsOnMainThread()
            self.deepLink.setMediaCode(newMediaCode)
        }
    }
    #endif
}

extension DefaultTracker: ActionEventHandler {

    internal func handleEvent(_ event: ActionEvent) {
        checkIsOnMainThread()

        enqueueRequestForEvent(event)
    }
}

extension DefaultTracker: MediaEventHandler {

    internal func handleEvent(_ event: MediaEvent) {
        checkIsOnMainThread()

        enqueueRequestForEvent(event)
    }
}

extension DefaultTracker: PageViewEventHandler {

    internal func handleEvent(_ event: PageViewEvent) {
        checkIsOnMainThread()

        enqueueRequestForEvent(event)
    }
}

extension DefaultTracker: RequestManager.Delegate {

    internal func requestManager(_ requestManager: RequestManager, didFailToSendRequest request: URL, error: RequestManager.ConnectionError) {
        checkIsOnMainThread()

        requestManagerDidFinishRequest()
    }

    internal func requestManager(_ requestManager: RequestManager, didSendRequest request: URL) {
        checkIsOnMainThread()
    }

    private func requestManagerDidFinishRequest() {
        checkIsOnMainThread()

        guard self.checkIfInitialized() else {
            return
        }

        #if !os(watchOS)
            if self.requestManager!.queue.isEmpty {

                self.flowObserver.finishBackroundTask(requestManager: self.requestManager)

                if application.applicationState != .active {
                    stopRequestManager()
                }
            }
        #endif
    }
}

fileprivate final class AutotrackingEventHandler: ActionEventHandler, MediaEventHandler, PageViewEventHandler {

    fileprivate var trackers = [WeakReference<DefaultTracker>]()

    private func broadcastEvent<Event: TrackingEvent>(_ event: Event, handler: (DefaultTracker) -> (Event) -> Void) {
        var event = event

        for trackerOpt in trackers {
            guard let viewControllerType = event.viewControllerType,
                  let tracker = trackerOpt.target, tracker.configuration.automaticallyTrackedPageForViewControllerType(viewControllerType) != nil
            else {
                continue
            }

            handler(tracker)(event)
        }
    }

    fileprivate func handleEvent(_ event: ActionEvent) {
        checkIsOnMainThread()

        broadcastEvent(event, handler: DefaultTracker.handleEvent(_:))
    }

    fileprivate func handleEvent(_ event: MediaEvent) {
        checkIsOnMainThread()

        broadcastEvent(event, handler: DefaultTracker.handleEvent(_:))
    }

    fileprivate func handleEvent(_ event: PageViewEvent) {
        checkIsOnMainThread()

        broadcastEvent(event, handler: DefaultTracker.handleEvent(_:))
    }
}

struct DefaultsKeys {

    fileprivate static let appHibernationDate = "appHibernationDate"
    fileprivate static let appVersion = "appVersion"
    fileprivate static let configuration = "configuration"
    static let everId = "everId"
    fileprivate static let isFirstEventAfterAppUpdate = "isFirstEventAfterAppUpdate"
    fileprivate static let isFirstEventOfApp = "isFirstEventOfApp"
    fileprivate static let isSampling = "isSampling"
    fileprivate static let isOptedOut = "optedOut"
    fileprivate static let migrationCompleted = "migrationCompleted"
    fileprivate static let samplingRate = "samplingRate"
    static let adClearId = "adClearId"
    static let crossDeviceProperties = "CrossDeviceProperties"
    fileprivate static let isSettingsToAppSpecificConverted = "isSettingsToAppSpecificConverted"
    static let productListOrder = "productListOrder"
}

private extension TrackingValue {

    mutating func resolve(variables: [String: String]) -> Bool {
        switch self {
        case let .customVariable(key):
            if let value = variables[key] {
                self = .constant(value)
                return true
            }
        default:
            return false
        }
        return false
    }
}
