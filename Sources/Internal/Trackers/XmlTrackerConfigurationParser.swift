import Foundation


internal class XmlTrackerConfigurationParser {

	private var autoTracked: Bool?
	private var automaticallyTracksAdvertisingId: Bool?
	private var automaticallyTracksAdvertisingOptOut: Bool?
	private var automaticallyTracksAppUpdates: Bool?
	private var automaticallyTracksAppVersion: Bool?
	private var automaticallyTracksRequestQueueSize: Bool?
	private var configurationUpdateUrl: URL?
	private var enableRemoteConfiguration: Bool?
	private var maximumSendDelay: TimeInterval?
	private var resendOnStartEventTime: TimeInterval?
	private var samplingRate: Int?
	private var serverUrl: URL?
	private var version: Int?
	private var webtrekkId: String?
	private var automaticallyTrackedPages = Array<TrackerConfiguration.Page>()
    private var automaticallyTracksAdClearId: Bool?
    private var errorLogLevel: Int?
    
    #if !os(watchOS)
	private var automaticallyTracksConnectionType: Bool?
	private var automaticallyTracksInterfaceOrientation: Bool?
	#endif

	private var globalScreenTrackingParameter: TrackingParameter?

	internal func parse(xml data: Data) throws -> TrackerConfiguration {
		return try readFromRootElement(XmlParser().parse(xml: data))
	}


	private func parseScreenTrackingParameter(xmlElement: XmlElement) -> TrackingParameter {
		var categories = [CustomParType: [Int: PropertyValue]]()

		var parameters = [PropertyName: PropertyValue]()
		for child in xmlElement.children {
			switch child.name {
			case "parameter":
				guard let element = readFromParameterElement(child) else {
					break
				}
				parameters[element.0] = element.1

			case CustomParType.actionParameter.rawValue:   categories[.actionParameter] = readFromCategoryElement(xmlElement: child)
            case CustomParType.adParameter.rawValue:   categories[.adParameter] = readFromCategoryElement(xmlElement: child)
            case CustomParType.ecomParameter.rawValue:   categories[.ecomParameter] = readFromCategoryElement(xmlElement: child)
            case CustomParType.mediaCategories.rawValue:   categories[.mediaCategories] = readFromCategoryElement(xmlElement: child)
            case CustomParType.pageCategories.rawValue:   categories[.pageCategories] = readFromCategoryElement(xmlElement: child)
            case CustomParType.pageParameter.rawValue:   categories[.pageParameter] = readFromCategoryElement(xmlElement: child)
            case CustomParType.productCategories.rawValue:   categories[.productCategories] = readFromCategoryElement(xmlElement: child)
            case CustomParType.sessionParameter.rawValue:   categories[.sessionParameter] = readFromCategoryElement(xmlElement: child)
            case CustomParType.userCategories.rawValue:   categories[.userCategories] = readFromCategoryElement(xmlElement: child)

			default: break
			}
		}
		return TrackingParameter(categories: categories, parameters: parameters)
	}


	private func readFromGlobalElement(_ xmlElement: XmlElement) throws {
		guard xmlElement.name == "globalTrackingParameter" else {
			throw TrackerError(message: "\(xmlElement.path.joined(separator: ".")) needs to be globalTrackingParameter")
		}
		guard !xmlElement.children.isEmpty else {
			return
		}
		globalScreenTrackingParameter = parseScreenTrackingParameter(xmlElement: xmlElement)
	}


	fileprivate func readFromRootElement(_ xmlElement: XmlElement) throws -> TrackerConfiguration {
		guard xmlElement.name == "webtrekkConfiguration" else {
			throw TrackerError(message: "\(xmlElement.path.joined(separator: ".")) root node needs to be webtrekkConfiguration")
		}
		guard !xmlElement.children.isEmpty else {
			throw TrackerError(message: "\(xmlElement.path.joined(separator: ".")) webtrekkConfiguration can not be empty")
		}
        
        var recommendationsL: [String: URL]?
        
		for child in xmlElement.children {
			do {
				switch child.name {
				case "enableRemoteConfiguration": self.enableRemoteConfiguration = try parseBool(child.text)
				case "resendOnStartEventTime":    self.resendOnStartEventTime = try parseDouble(child.text, allowedRange: TrackerConfiguration.allowedResendOnStartEventTimes)
				case "sampling":                  self.samplingRate = try parseInt(child.text, allowedRange: TrackerConfiguration.allowedSamplingRates)
				case "sendDelay":                 self.maximumSendDelay = try parseDouble(child.text, allowedRange: TrackerConfiguration.allowedMaximumSendDelays)
				case "trackingConfigurationUrl":  self.configurationUpdateUrl = try parseUrl(child.text, emptyAllowed: true)
				case "trackDomain":               self.serverUrl = try parseUrl(child.text, emptyAllowed: false)
				case "trackId":                   self.webtrekkId = try parseString(child.text, emptyAllowed: false)
				case "version":                   self.version = try parseInt(child.text, allowedRange: TrackerConfiguration.allowedVersions)

				case "autoTracked":                  self.autoTracked = try parseBool(child.text)
				case "autoTrackAdvertiserId":        self.automaticallyTracksAdvertisingId = try parseBool(child.text)
				case "autoTrackAdvertisementOptOut": self.automaticallyTracksAdvertisingOptOut = try parseBool(child.text)
				case "autoTrackAppUpdate":           self.automaticallyTracksAppUpdates = try parseBool(child.text)
				case "autoTrackAppVersionName":      self.automaticallyTracksAppVersion = try parseBool(child.text)
				case "autoTrackRequestUrlStoreSize": self.automaticallyTracksRequestQueueSize = try parseBool(child.text)
                case "autoTrackAdClearId":           self.automaticallyTracksAdClearId = try parseBool(child.text)
                    
                case "globalTrackingParameter" : try readFromGlobalElement(child)
                case "recommendations" : try recommendationsL = readRecommendations(xmlElement: child)
                case "screen": try readFromScreenElement(child)
                case "autoTrackConnectionType":
                    #if !os(watchOS) && !os(tvOS)
                    self.automaticallyTracksConnectionType = try parseBool(child.text)
                    #else
                    logError("autoTrackConnectionType isn't supported for watchOS and tvOS")
                    #endif
                case "autoTrackScreenOrientation":
                    #if !os(watchOS) && !os(tvOS)
                    self.automaticallyTracksInterfaceOrientation = try parseBool(child.text)
                    #else
                    logError("autoTrackScreenOrientation isn't supported for watchOS and tvOS")
                    #endif
                case "errorLogLevel":
                    if self.errorLogLevel == nil || (self.errorLogLevel != nil && self.errorLogLevel != 0) {
                    self.errorLogLevel = try parseInt(child.text, allowedRange: 1...3)
                    }
                case "errorLogEnable":
                    if let enable = try parseBool(child.text) {
                    self.errorLogLevel = enable ? self.errorLogLevel : 0
                    }
				default:
                    guard child.name != "autoTrackAppVersionCode" && child.name != "maxRequests" else {
                        break
                    }
                        logWarning("Element \(child.name) not found")
                        break
				}
			}
			catch let error as TrackerError {
				throw TrackerError(message: "\(xmlElement.path.joined(separator: ".")): \(error.message)")
			}
		}

		guard let webtrekkId = webtrekkId, let serverUrl = serverUrl else {
			throw TrackerError(message: "trackId and trackDomain must be set.")
		}
        
        logDebug("track domain is:\(serverUrl)")
        logDebug("trackID is:\(webtrekkId)")

		var trackerConfiguration = TrackerConfiguration(webtrekkId: webtrekkId, serverUrl: serverUrl)

		if let configurationUpdateUrl = configurationUpdateUrl {
			trackerConfiguration.configurationUpdateUrl = configurationUpdateUrl
		}

		if let enableRemoteConfiguration = enableRemoteConfiguration , !enableRemoteConfiguration {
			trackerConfiguration.configurationUpdateUrl = nil
		}

		if let resendOnStartEventTime = resendOnStartEventTime {
			trackerConfiguration.resendOnStartEventTime = resendOnStartEventTime
		}

		if let samplingRate = samplingRate {
			trackerConfiguration.samplingRate = samplingRate
		}

		if let maximumSendDelay = maximumSendDelay {
			trackerConfiguration.maximumSendDelay = maximumSendDelay
            logDebug("sendDelay is:\(maximumSendDelay)")
            if maximumSendDelay == 0 {
                logInfo("sendDelay is equal to 0, please use sendPendingEvents for manual message send")
            }
		}

		if let version = version {
			trackerConfiguration.version = version
		}

		if let automaticallyTracksAdvertisingId = self.automaticallyTracksAdvertisingId {
			trackerConfiguration.automaticallyTracksAdvertisingId = automaticallyTracksAdvertisingId
		}

		if let automaticallyTracksAdvertisingOptOut = self.automaticallyTracksAdvertisingOptOut {
			trackerConfiguration.automaticallyTracksAdvertisingOptOut = automaticallyTracksAdvertisingOptOut
		}

		if let automaticallyTracksAppUpdates = self.automaticallyTracksAppUpdates {
			trackerConfiguration.automaticallyTracksAppUpdates = automaticallyTracksAppUpdates
		}

		if let automaticallyTracksAppVersion = self.automaticallyTracksAppVersion {
			trackerConfiguration.automaticallyTracksAppVersion = automaticallyTracksAppVersion
		}

		if let automaticallyTracksRequestQueueSize = self.automaticallyTracksRequestQueueSize {
			trackerConfiguration.automaticallyTracksRequestQueueSize = automaticallyTracksRequestQueueSize
		}
        
        if let automaticallyTracksAdClearId = self.automaticallyTracksAdClearId {
            trackerConfiguration.automaticallyTracksAdClearId = automaticallyTracksAdClearId
        }
        
        if let recommendations = recommendationsL {
            trackerConfiguration.recommendations = recommendations
        }
        
        if let errorLogLevel = self.errorLogLevel {
            trackerConfiguration.errorLogLevel = errorLogLevel
        }
		
        #if !os(watchOS)
			if let automaticallyTracksConnectionType = automaticallyTracksConnectionType {
				trackerConfiguration.automaticallyTracksConnectionType = automaticallyTracksConnectionType
			}

			if let automaticallyTracksInterfaceOrientation = automaticallyTracksInterfaceOrientation {
				trackerConfiguration.automaticallyTracksInterfaceOrientation = automaticallyTracksInterfaceOrientation
			}
		#endif

        trackerConfiguration.automaticallyTrackedPages = automaticallyTrackedPages
		
        if let globalParameter = globalScreenTrackingParameter {
            trackerConfiguration.globalProperties = GlobalProperties()
            trackerConfiguration.globalProperties.trackingParameters = globalParameter
		}
		return trackerConfiguration
	}


	fileprivate func readFromScreenElement(_ xmlElement: XmlElement) throws {
		guard xmlElement.name == "screen" else {
			throw TrackerError(message: "\(xmlElement.path.joined(separator: ".")) nodes needs to be screen")
		}
		guard !xmlElement.children.isEmpty else {
			throw TrackerError(message: "\(xmlElement.path.joined(separator: ".")) node can not be empty")
		}
		// TODO: create screen here and append afterwards to array of screens
		var viewControllerType: String?
		var pageName: String?
		var autoTracked: Bool?
		var screenTrackingParameter: TrackingParameter?
		for child in xmlElement.children {
			switch child.name {
			case "classname": viewControllerType = try parseString(child.text, emptyAllowed: false)
			case "mappingname": pageName = try parseString(child.text, emptyAllowed: false)
			case "autoTracked": autoTracked = try parseBool(child.text)
			case "screenTrackingParameter": screenTrackingParameter = try readFromScreenTrackingParameterElement(xmlElement: child)
			default: break
			}
		}

		// if autotracked is not set it is assumed enabled
		if let globalAutoTracked = self.autoTracked , !globalAutoTracked {
			if let screenAutoTracked = autoTracked , screenAutoTracked {
				autoTracked = true
			}
			else {
				autoTracked = false
			}
		}
		autoTracked = autoTracked ?? true

		guard let isTrackingEnabled = autoTracked , isTrackingEnabled else {
			return
		}

		guard let viewControllerTypeName = viewControllerType else {
			throw TrackerError(message: "$\(xmlElement.path).classname needs to be set")
		}

		let patternString: String
		if viewControllerTypeName.hasPrefix("/") {
			guard let _patternString = viewControllerTypeName.firstMatchForRegularExpression("^/(.*)/$")?[1] else {
				throw TrackerError(message: "invalid regular expression: missing trailing slash")
			}
			patternString = _patternString
		}
		else {
			patternString = "\\b\(NSRegularExpression.escapedPattern(for: viewControllerTypeName))\\b"
		}

		var page: TrackerConfiguration.Page
		do {
			let pattern = try NSRegularExpression(pattern: patternString, options: [])
            page = TrackerConfiguration.Page(viewControllerTypeNamePattern: pattern, pageProperties: PageProperties(name: pageName))
		}
		catch let error {
			throw TrackerError(message: "invalid regular expression: \(error)")
		}

		if let screenParameter = screenTrackingParameter {
            page.trackingParameters = screenParameter
		}
        
		automaticallyTrackedPages.append(page)
	}
    
	private func readFromScreenTrackingParameterElement(xmlElement: XmlElement) throws -> TrackingParameter? {
		guard xmlElement.name == "screenTrackingParameter" else {
			throw TrackerError(message: "screenTrackingParameter nodes needs to be screenTrackingParameter")
		}
		guard !xmlElement.children.isEmpty else {
			return nil
		}

		return parseScreenTrackingParameter(xmlElement: xmlElement)
	}


    private func readRecommendations(xmlElement recomendParent: XmlElement) throws -> [String: URL]?{
        guard !recomendParent.children.isEmpty else {
            return nil
        }
        
        var recommendations: [String: URL] = [:]
        
        for child in recomendParent.children where child.name == "recommendation" {
            if let name = child.attributes["name"], let url = try parseUrl(child.text, emptyAllowed: false) {
                recommendations[name] = url
            }
        }
        
        guard !recommendations.isEmpty else {
            return nil
        }
        
        return recommendations
    }

    private func readFromCategoryElement(xmlElement: XmlElement) -> [Int: PropertyValue]? {
		guard !xmlElement.children.isEmpty else {
			return nil
		}
		var xmlCategoryElements = [Int: PropertyValue]()
		for child in xmlElement.children where child.name == "parameter" {
			guard let indexString = child.attributes["id"], let index = Int(indexString) else {
				continue
			}
            if let key = child.attributes["key"] {
                xmlCategoryElements[index] = .key(key)
            }else{
                xmlCategoryElements[index] = .value(child.text)
            }
		}
		return xmlCategoryElements
	}

	private func readFromParameterElement(_ xmlElement: XmlElement) -> (PropertyName, PropertyValue)? {
		guard xmlElement.name == "parameter" else {
			return nil
		}
		guard let parameterName = xmlElement.attributes["id"] else {
			return nil
		}
		if let propertyName = PropertyName(rawValue: parameterName) {
            if let key = xmlElement.attributes["key"] {
                return (propertyName, value: .key(key))
            }else{
                return (propertyName, value: .value(xmlElement.text))
            }
		}
		else {
			// TODO: PropertyName is not defined yet, log or throw?
			return nil
		}
	}


	private func parseBool(_ string: String) throws -> Bool?{
		switch (string) {
		case "true":  return true
		case "false": return false

		default:
			throw TrackerError(message: "'\(string)' is not a valid boolean (expected 'true' or 'false')")
		}
	}


	private func parseDouble(_ string: String, allowedRange: ClosedRange<Double>) throws -> Double? {
		guard let value = Double(string) else {
			throw TrackerError(message: "'\(string)' is not a valid number")
		}

		if !allowedRange.contains(value) {
			throw TrackerError(message: "value (\(value)) must be \(allowedRange.conditionText)")
		}

		return value
	}


	private func parseInt(_ string: String, allowedRange: ClosedRange<Int>) throws -> Int? {
		guard let value = Int(string) else {
			throw TrackerError(message: "'\(string)' is not a valid integer")
		}

		if !allowedRange.contains(value) {
			if allowedRange.upperBound == .max {
				throw TrackerError(message: "value (\(value)) must be larger than or equal to \(allowedRange.lowerBound)")
			}
			if allowedRange.lowerBound == .min {
				throw TrackerError(message: "value (\(value)) must be smaller than or equal to \(allowedRange.upperBound)")
			}

			throw TrackerError(message: "value (\(value)) must be between \(allowedRange.lowerBound) (inclusive) and \(allowedRange.upperBound) (inclusive)")
		}

		return value
	}


	private func parseString(_ string: String, emptyAllowed: Bool) throws -> String? {
		if string.isEmpty {
			if !emptyAllowed {
				throw TrackerError(message: "must not be empty")
			}

			return nil
		}

		return string
	}


	private func parseUrl(_ string: String, emptyAllowed: Bool) throws -> URL? {
		if string.isEmpty {
			if !emptyAllowed {
				throw TrackerError(message: "must not be empty")
			}

			return nil
		}

		guard let value = URL(string: string) else {
			throw TrackerError(message: "'\(string)' is not a valid URL")
		}

		return value
	}
}
