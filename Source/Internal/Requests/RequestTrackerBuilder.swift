import Foundation

final class RequestTrackerBuilder {

    private let lastCdbPropertiesSentTime = "lastCdbPropertiesSentTime"

    #if !os(watchOS)
    var deepLink: DeepLink!
    #endif

    let campaign: Campaign
    let appinstallGoal: AppinstallGoal
    let pageURL: String?
    let configuration: TrackerConfiguration
    let global: GlobalProperties

    init (_ campaign: Campaign, pageURL: String?, configuration: TrackerConfiguration,
          global: GlobalProperties, appInstall: AppinstallGoal) {
        self.campaign = campaign
        self.pageURL = pageURL
        self.configuration = configuration
        self.global = global
        self.appinstallGoal = appInstall
    }

    #if !os(watchOS)
    func setDeepLink(deepLink: DeepLink) {
        self.deepLink = deepLink
    }
    #endif

    // create mergedTrackerRequest
    func createRequest(_ event: TrackingEvent, requestProperties: TrackerRequest.Properties) -> TrackerRequest? {

        var event = event

        // it's a dedicated CDB request:
        if !global.crossDeviceProperties.isEmpty() {

            // if there are CDB properties already stored on the device,
            // merge the new ones with them and store the result on the device:
            if let oldCDBProperties = CrossDeviceProperties.loadFromDevice() {
                let newCDBProperties = global.crossDeviceProperties
                // the new ones have a higher priority (i.e. its properties can overwrite existig ones):
                // (nil values won't overwrite existing values though)
                newCDBProperties.merged(over: oldCDBProperties).saveToDevice()
            } else {
                // else just save the cdb properties from the current request to the device:
                global.crossDeviceProperties.saveToDevice()
            }
        }

        // it's not a dedicated CDB request:
        else {
            if cdbPropertiesNeedResend(), let oldCDBProperties = CrossDeviceProperties.loadFromDevice() {
                global.crossDeviceProperties = oldCDBProperties

                // save the lastCdbPropertiesSentTime:
                // (This should only be set here. Because if setting it is also triggered by a dedicated CDB request,
                // the automatic sending of the merged properties might never happen. This would only be the case though,
                // if the customer has a suboptimal implementation and sends the dedicated CDB requests too often.)
                let now = Int(Date().timeIntervalSince1970)
                UserDefaults.standardDefaults.child(namespace: "webtrekk").set(key: lastCdbPropertiesSentTime, to: now)
            }

            globalPropertiesByApplyingEvent(from: &event, requestProperties: requestProperties)

            eventByApplyingAutomaticPageTracking(to: &event)

            installGoalSetup(to: &event)

            #if !os(watchOS)
                deepLinkOverride(to: &event)
            #endif

            pageURLOverride(to: &event)
        }

        return createRequestForEvent(event, requestProperties: requestProperties)
    }

    private func cdbPropertiesNeedResend() -> Bool {
        if let lastSend = UserDefaults.standardDefaults.child(namespace: "webtrekk").intForKey(lastCdbPropertiesSentTime) {
            let now = Int(Date().timeIntervalSince1970)
            return (now - lastSend) > 86400 // one day
        } else {
            return true
        }
    }

    // override media code in request in case of deeplink
    #if !os(watchOS)
    private func deepLinkOverride(to event: inout TrackingEvent) {
        guard var _ = event as? TrackingEventWithAdvertisementProperties,
            let _ = event as? TrackingEventWithEcommerceProperties else {
                return
        }

        if let mc = self.deepLink.getAndDeletSavedDeepLinkMediaCode() {

            var eventWithAdvertisementProperties = event as! TrackingEventWithAdvertisementProperties
            eventWithAdvertisementProperties.advertisementProperties.id = mc
        }
    }
    #endif

    // override some parameter in request if campaign is completed
    private func installGoalSetup(to event: inout TrackingEvent) {

        guard var _ = event as? TrackingEventWithAdvertisementProperties,
            let _ = event as? TrackingEventWithEcommerceProperties else {
                return
        }

        if self.appinstallGoal.checkAppinstallGoal() {
            var eventWithEcommerceProperties = event as! TrackingEventWithEcommerceProperties
            var detailsToAdd = eventWithEcommerceProperties.ecommerceProperties.details ?? [Int: TrackingValue]()
            detailsToAdd[900] = "1"
            eventWithEcommerceProperties.ecommerceProperties.details = detailsToAdd
            self.appinstallGoal.fininshAppinstallGoal()
        }
    }

    //override PageURLParameter
    private func pageURLOverride(to event: inout TrackingEvent) {

        guard var _ = event as? TrackingEventWithPageProperties else {
            return
        }

        if let pageURL = self.pageURL {

            guard pageURL.isValidURL() else {
                WebtrekkTracking.defaultLogger.logError("Invalid URL \(pageURL) for override pu parameter")
                return
            }

            var eventWithPageProperties = event as! TrackingEventWithPageProperties
            eventWithPageProperties.pageProperties.url = pageURL
        }
    }

    private func eventByApplyingAutomaticPageTracking(to event: inout TrackingEvent) {
        checkIsOnMainThread()

        guard let
            viewControllerType = event.viewControllerType,
            let pageProperties = self.configuration.automaticallyTrackedPageForViewControllerType(viewControllerType)
            else {
                return
        }

        if let page = applyKeys(keys: event.variables, properties: pageProperties) as? TrackerConfiguration.Page {
            mergeProperties(event: &event, properties: page, rewriteEvent: true)
        } else {
            WebtrekkTracking.logger.logError("incorect type of return value from apply Keys for page parameters")
        }
    }

    private func globalPropertiesByApplyingEvent(from event: inout TrackingEvent,
                                                 requestProperties: TrackerRequest.Properties) {
        checkIsOnMainThread()

        event.variables = self.global.variables.merged(over: event.variables)

        if let globalSettings = applyKeys(keys: event.variables,
                                          properties: configuration.globalProperties) as? GlobalProperties {

            // merge autoParameters
            let autoProperties = getAutoParameters(event: event, requestProperties: requestProperties)
            mergeProperties(event: &event, properties: globalSettings, rewriteEvent: false)
            mergeProperties(event: &event, properties: autoProperties, rewriteEvent: false)
            mergeProperties(event: &event, properties: self.global, rewriteEvent: false)
            //let globalAndAuto = autoProperties.merged(over: self.global)

            // merge global from code and from configuration.
            //let global = globalSettings.merged(over: globalAndAuto)

            //return event//mergeProperties(event: event, properties: global, rewriteEvent: false)
        } else {
            WebtrekkTracking.logger.logError("incorect type of return value from apply Keys for global parameters")
        }
    }

    private func applyKeys(keys: [String: String], properties: BaseProperties) -> BaseProperties {

        guard let trackingParameter = properties.trackingParameters else {
            return properties
        }

        if let globalProperties = properties as? GlobalProperties {
            return GlobalProperties(actionProperties: trackingParameter.actionProperties(variables: keys),
                                    advertisementProperties: trackingParameter.advertisementProperties(variables: keys),
                                    crossDeviceProperties: globalProperties.crossDeviceProperties,
                                    ecommerceProperties: trackingParameter.ecommerceProperties(variables: keys),
                                    ipAddress: trackingParameter.resolveIPAddress(variables: keys),
                                    mediaProperties: trackingParameter.mediaProperties(variables: keys),
                                    pageProperties: trackingParameter.pageProperties(variables: keys),
                                    sessionDetails: trackingParameter.sessionDetails(variables: keys),
                                    userProperties: trackingParameter.userProperties(variables: keys),
                                    variables: globalProperties.variables)
        }
        if let pageProperties = properties as? TrackerConfiguration.Page {

            var page = trackingParameter.pageProperties(variables: keys)
            //override name from xml
            page.name = pageProperties.pageProperties.name

            return TrackerConfiguration.Page(viewControllerTypeNamePattern: pageProperties.viewControllerTypeNamePattern,
                                             pageProperties: page,
                                             actionProperties: trackingParameter.actionProperties(variables: keys),
                                             advertisementProperties: trackingParameter.advertisementProperties(variables: keys),
                                             ecommerceProperties: trackingParameter.ecommerceProperties(variables: keys),
                                             ipAddress: trackingParameter.resolveIPAddress(variables: keys),
                                             mediaProperties: trackingParameter.mediaProperties(variables: keys),
                                             sessionDetails: trackingParameter.sessionDetails(variables: keys),
                                             userProperties: trackingParameter.userProperties(variables: keys))
        }

        WebtrekkTracking.logger.logError("Unsupported type of properties")
        return properties
    }

    private func createRequestForEvent(_ event: TrackingEvent, requestProperties: TrackerRequest.Properties) -> TrackerRequest? {
        checkIsOnMainThread()

        guard validateEvent(event) else {
            return nil
        }

        let currentCrossDeviceProperties = global.crossDeviceProperties
        // reset the crossDeviceProperties so they don't get immediately sent again:
        global.crossDeviceProperties = CrossDeviceProperties()

        return TrackerRequest(
            crossDeviceProperties: currentCrossDeviceProperties,
            event: event,
            properties: requestProperties
        )
    }

    private func validateEvent(_ event: TrackingEvent) -> Bool {
        checkIsOnMainThread()

        if let event = event as? TrackingEventWithActionProperties {
            guard event.actionProperties.name?.nonEmpty != nil else {
                logError("Cannot track event without .actionProperties.name set: \(event)")
                return false
            }
        }

        if let event = event as? TrackingEventWithMediaProperties {
            guard event.mediaProperties.name?.nonEmpty != nil else {
                logError("Cannot track event without .mediaProperties.name set: \(event)")
                return false
            }
        }

        return true
    }

    private func mergeProperties(event: inout TrackingEvent, properties: BaseProperties, rewriteEvent: Bool) {

        let mergeTool = PropertyMerger()

        if rewriteEvent {
            event.ipAddress = properties.ipAddress ?? event.ipAddress
            event.pageName = properties.pageProperties.name ?? event.pageName
        } else {
            event.ipAddress = event.ipAddress ?? properties.ipAddress
            event.pageName = event.pageName ?? properties.pageProperties.name
        }

        guard !(event is ActionEvent) || properties is AutoParametersProperties else {
            return
        }

        if var eventWithActionProperties = event as? TrackingEventWithActionProperties {
            eventWithActionProperties.actionProperties = mergeTool.mergeProperties(first: properties.actionProperties,
                                                                                   second: eventWithActionProperties.actionProperties,
                                                                                   from1Over2: rewriteEvent)
        }
        if var eventWithAdvertisementProperties = event as? TrackingEventWithAdvertisementProperties {
            eventWithAdvertisementProperties.advertisementProperties = mergeTool.mergeProperties(first: properties.advertisementProperties,
                                                                                                 second: eventWithAdvertisementProperties.advertisementProperties,
                                                                                                 from1Over2: rewriteEvent)
        }
        if var eventWithEcommerceProperties = event as? TrackingEventWithEcommerceProperties {
            eventWithEcommerceProperties.ecommerceProperties = mergeTool.mergeProperties(first: properties.ecommerceProperties,
                                                                                         second: eventWithEcommerceProperties.ecommerceProperties,
                                                                                         from1Over2: rewriteEvent)
        }
        if var eventWithMediaProperties = event as? TrackingEventWithMediaProperties {
            eventWithMediaProperties.mediaProperties = mergeTool.mergeProperties(first: properties.mediaProperties,
                                                                                 second: eventWithMediaProperties.mediaProperties,
                                                                                 from1Over2: rewriteEvent)
        }
        if var eventWithPageProperties = event as? TrackingEventWithPageProperties {
            eventWithPageProperties.pageProperties = mergeTool.mergeProperties(first: properties.pageProperties,
                                                                               second: eventWithPageProperties.pageProperties,
                                                                               from1Over2: rewriteEvent)
        }
        if var eventWithUserProperties = event as? TrackingEventWithUserProperties {
            eventWithUserProperties.userProperties = mergeTool.mergeProperties(first: properties.userProperties,
                                                                               second: eventWithUserProperties.userProperties,
                                                                               from1Over2: rewriteEvent)
        }

        if var eventWithSessionDetails = event as? TrackingEventWithSessionDetails {
            eventWithSessionDetails.sessionDetails = mergeTool.mergeProperties(first: properties.sessionDetails,
                                                                               second: eventWithSessionDetails.sessionDetails,
                                                                               from1Over2: rewriteEvent)
        }
    }

    private class AutoParametersProperties: GlobalProperties {

    }

    private enum AutoParametersAttrNumbers: Int {
        case screenOrientation = 783, requestQueueSize
        case appVersion = 804
        case connectionType = 807
        case advertisingId = 809
        case advertisingTrackingEnabled = 813
        case isFirstEventAfterAppUpdate = 815
        case adClearId = 808
    }

    private static let autoParameters: [AutoParametersAttrNumbers: CustomParType] =
        [.screenOrientation: .pageParameter,
         .requestQueueSize: .pageParameter,
         .appVersion: .sessionParameter,
         .connectionType: .sessionParameter,
         .advertisingId: .sessionParameter,
         .advertisingTrackingEnabled: .sessionParameter,
         .isFirstEventAfterAppUpdate: .sessionParameter,
         .adClearId: .sessionParameter]

    private func getAutoParameters (event: TrackingEvent,
                                    requestProperties properties: TrackerRequest.Properties) -> AutoParametersProperties {

        var sessionDetails: [Int: TrackingValue] = [:]
        var pageDetails: [Int: TrackingValue] = [:]

        if !(event is ActionEvent) {

            #if !os(watchOS) && !os(tvOS)
                if let interfaceOrientation = properties.interfaceOrientation {
                    pageDetails[AutoParametersAttrNumbers.screenOrientation.rawValue] = .constant(interfaceOrientation.serialized)
                }

                if let connectionType = properties.connectionType {
                    sessionDetails[AutoParametersAttrNumbers.connectionType.rawValue] = .constant(connectionType.serialized)
                }
            #endif

            if let requestQueueSize = properties.requestQueueSize {
                pageDetails[AutoParametersAttrNumbers.requestQueueSize.rawValue] = .constant(String(requestQueueSize))
            }
            if let appVersion = properties.appVersion {
                sessionDetails[AutoParametersAttrNumbers.appVersion.rawValue] = .constant(appVersion)
            }
            if let advertisingId = properties.advertisingId {
                sessionDetails[AutoParametersAttrNumbers.advertisingId.rawValue] = .constant(advertisingId.uuidString)
            }
            if let advertisingTrackingEnabled = properties.advertisingTrackingEnabled {
                sessionDetails[AutoParametersAttrNumbers.advertisingTrackingEnabled.rawValue] = .constant(advertisingTrackingEnabled ? "1" : "0")
            }
            if properties.isFirstEventAfterAppUpdate {
                sessionDetails[AutoParametersAttrNumbers.isFirstEventAfterAppUpdate.rawValue] = .constant("1")
            }
        }

        if let adClearId = properties.adClearId {
            sessionDetails[AutoParametersAttrNumbers.adClearId.rawValue] = .constant(String(adClearId))
        }

        let pageProp = PageProperties(name: nil, details: pageDetails.isEmpty ? nil: pageDetails)

        return AutoParametersProperties(pageProperties: pageProp, sessionDetails: sessionDetails)
    }

    static func produceWarningForProperties(properties: BaseProperties) {

        for (num, type) in autoParameters {
            let value = properties.trackingParameters?.categories[type]?[num.rawValue]

            if value != nil {
                logWarning("""
                        auto parameter \"\(num)\" will be overwritten.
                        If you don't want it, remove \"\(type)\" custom parameter number \(num.rawValue) definition.
                    """)
            }
        }
    }
}

private class PropertyMerger {
    func mergeProperties(first property1: ActionProperties,
                         second property2: ActionProperties,
                         from1Over2: Bool) -> ActionProperties {
        if from1Over2 {
            return property1.merged(over: property2)
        } else {
            return property2.merged(over: property1)
        }
    }

    func mergeProperties(first property1: AdvertisementProperties,
                         second property2: AdvertisementProperties,
                         from1Over2: Bool) -> AdvertisementProperties {
        if from1Over2 {
            return property1.merged(over: property2)
        } else {
            return property2.merged(over: property1)
        }
    }

    func mergeProperties(first property1: EcommerceProperties,
                         second property2: EcommerceProperties,
                         from1Over2: Bool) -> EcommerceProperties {

        if from1Over2 {
            return property1.merged(over: property2)
        } else {
            return property2.merged(over: property1)
        }
    }

    func mergeProperties(first property1: MediaProperties,
                         second property2: MediaProperties,
                         from1Over2: Bool) -> MediaProperties {
        if from1Over2 {
            return property1.merged(over: property2)
        } else {
            return property2.merged(over: property1)
        }
    }

    func mergeProperties(first property1: PageProperties,
                         second property2: PageProperties,
                         from1Over2: Bool) -> PageProperties {
        if from1Over2 {
            return property1.merged(over: property2)
        } else {
            return property2.merged(over: property1)
        }
    }

    func mergeProperties(first property1: [Int: TrackingValue],
                         second property2: [Int: TrackingValue],
                         from1Over2: Bool) -> [Int: TrackingValue] {
        if from1Over2 {
            return property1.merged(over: property2)
        } else {
            return property2.merged(over: property1)
        }
    }

    func mergeProperties(first property1: UserProperties,
                         second property2: UserProperties,
                         from1Over2: Bool) -> UserProperties {
        if from1Over2 {
            return property1.merged(over: property2)
        } else {
            return property2.merged(over: property1)
        }
    }
}
