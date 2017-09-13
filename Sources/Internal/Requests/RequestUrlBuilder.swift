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

import CryptoSwift
import Foundation
import UIKit


internal final class RequestUrlBuilder {

	internal var baseUrl: URL


	internal init(serverUrl: URL, webtrekkId: String) {
		self.baseUrl = RequestUrlBuilder.buildBaseUrl(serverUrl: serverUrl, webtrekkId: webtrekkId)
		self.serverUrl = serverUrl
		self.webtrekkId = webtrekkId
	}


	fileprivate static func buildBaseUrl(serverUrl: URL, webtrekkId: String) -> URL {
		return serverUrl.appendingPathComponent(webtrekkId).appendingPathComponent("wt")
	}


	internal var serverUrl: URL {
		didSet {
			guard serverUrl != oldValue else {
				return
			}

			baseUrl = RequestUrlBuilder.buildBaseUrl(serverUrl: serverUrl, webtrekkId: webtrekkId)
		}
	}

    
    internal func append(arr: inout [URLQueryItem], name: String, value: String){
        arr.append(URLQueryItem(name: name, value: value))
    }

    internal func urlForRequest(_ request: TrackerRequest, type: DefaultTracker.RequestType) -> URL? {
		let event = request.event
		let pageNameOpt = event.pageName?.nonEmpty
        
        if pageNameOpt == nil && type == .normal {
			logError("Tracking event must contain a page name: \(request)")
			return nil
		}

		let properties = request.properties
		let screenSize = "\(properties.screenSize?.width ?? 0)x\(properties.screenSize?.height ?? 0)"
        let libraryVersionOriginal = WebtrekkTracking.version
        let libraryVersionParced = libraryVersionOriginal.replacingOccurrences(of: ".", with: "")

		var parameters = [URLQueryItem]()
        
        switch type {
        case .normal:
            // it has to b not null based on previous check for normal
            guard let pageName = pageNameOpt else {
                return nil
            }
            
            append(arr: &parameters, name: "p", value: libraryVersionParced + ",\(pageName),0,\(screenSize),32,0,\(Int64(properties.timestamp.timeIntervalSince1970 * 1000)),0,0,0")
            append(arr: &parameters, name: "eid", value: properties.everId)
            append(arr: &parameters, name: "fns", value: properties.isFirstEventOfSession ? "1" : "0")
            append(arr: &parameters, name: "mts", value: String(Int64(properties.timestamp.timeIntervalSince1970 * 1000)))
            append(arr: &parameters, name: "one", value: properties.isFirstEventOfApp ? "1" : "0")
            append(arr: &parameters, name: "ps", value: String(properties.samplingRate))
            append(arr: &parameters, name: "tz", value: String(Double(properties.timeZone.secondsFromGMT()) / 60 / 60))
            append(arr: &parameters, name: "X-WT-UA", value: properties.userAgent)
            
            if let language = (properties.locale as NSLocale?)?.object(forKey: NSLocale.Key.languageCode) as? String {
                append(arr: &parameters, name: "la", value: language)
            }
        case .exceptionTracking:
            append(arr: &parameters, name: "p", value: libraryVersionParced + ",,0,,,0,\(Int64(properties.timestamp.timeIntervalSince1970 * 1000)),0,0,0")
        }

		if let ipAddress = event.ipAddress {
			append(arr: &parameters, name: "X-WT-IP", value: ipAddress)
		}

		if let event = event as? MediaEvent {
			let actionId: String
			switch event.action {
			case .finish:           actionId = "finish"
			case .initialize:       actionId = "init"
			case .pause:            actionId = "pause"
			case .play:             actionId = "play"
			case .position:         actionId = "pos"
			case .seek:             actionId = "seek"
			case .stop:             actionId = "stop"
			case let .custom(name): actionId = name
			}
			append(arr: &parameters, name: "mk", value: actionId)
		}
		else {
			parameters += request.crossDeviceProperties.asQueryItems()
		}

		if let actionProperties = (event as? TrackingEventWithActionProperties)?.actionProperties {
			guard let name = actionProperties.name?.nonEmpty else {
				logError("Tracking event must contain an action name: \(request)")
				return nil
			}

			append(arr: &parameters, name: "ct", value: name)

			if let details = actionProperties.details {
				parameters += details.mapNotNil { URLQueryItem(name: "ck", property: $0, for: request) }
			}
		}
		
        if let advertisementProperties = (event as? TrackingEventWithAdvertisementProperties)?.advertisementProperties {
			if let action = advertisementProperties.action {
				append(arr: &parameters, name: "mca", value: action)
			}
			if let id = advertisementProperties.id {
				append(arr: &parameters, name: "mc", value: id)
			}
			if let details = advertisementProperties.details {
				parameters += details.mapNotNil { URLQueryItem(name: "cc", property: $0, for: request) }
			}
		}
		
        if let ecommerceProperties = (event as? TrackingEventWithEcommerceProperties)?.ecommerceProperties {
			parameters += ecommerceProperties.asQueryItems(for: request)
		}
		
        if let mediaProperties = (event as? TrackingEventWithMediaProperties)?.mediaProperties {
			guard mediaProperties.name?.nonEmpty != nil else {
				logError("Tracking event must contain a media name: \(request)")
				return nil
			}

			parameters += mediaProperties.asQueryItems(for: request)
		}
		
        if let pageProperties = (event as? TrackingEventWithPageProperties)?.pageProperties {
			parameters += pageProperties.asQueryItems(for: request)
		}
		
        if let sessionDetails = (event as? TrackingEventWithSessionDetails)?.sessionDetails {
			parameters += sessionDetails.mapNotNil { URLQueryItem(name: "cs", property: $0, for: request) }
		}
		
        if let userProperties = (event as? TrackingEventWithUserProperties)?.userProperties {
			parameters += userProperties.asQueryItems(for: request)
		}

		append(arr: &parameters, name: "eor", value: "1")

		var urlComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: true)
        
        guard let _ = urlComponents else {
			logError("Could not parse baseUrl: \(baseUrl)")
			return nil
		}

		urlComponents?.queryItems = parameters

		guard let url = urlComponents?.url else {
			logError("Cannot build URL from components: \(urlComponents.simpleDescription)")
			return nil
		}

		return url
	}


	internal var webtrekkId: String {
		didSet {
			guard webtrekkId != oldValue else {
				return
			}

			baseUrl = RequestUrlBuilder.buildBaseUrl(serverUrl: serverUrl, webtrekkId: webtrekkId)
		}
	}
}


private extension CrossDeviceProperties {
	func asQueryItems() -> [URLQueryItem] {
		var items = [URLQueryItem]()
		if let address = address {
			switch address {
			case let .plain(value):
				if value.isEmpty() {
					break
				}
				var result = ""
				if let regex = try? NSRegularExpression(pattern: "str\\.?\\s*\\|", options: NSRegularExpression.Options.caseInsensitive) {
					result = regex.stringByReplacingMatches(in: value.toLine() , options: .withTransparentBounds, range: NSMakeRange(0, value.toLine() .characters.count), withTemplate: "strasse|")
				}
				if result.isEmpty {
					break
				}
				items.append(URLQueryItem(name: "cdb5", value: result.md5().lowercased()))
				items.append(URLQueryItem(name: "cdb6", value: result.sha256().lowercased()))

			case let .hashed(md5, sha256):
				if let md5 = md5 {
					items.append(URLQueryItem(name: "cdb5", value: md5.lowercased()))
				}
				if let sha256 = sha256 {
					items.append(URLQueryItem(name: "cdb6", value: sha256.lowercased()))
				}
			}
		}

		if let androidId = androidId {
			items.append(URLQueryItem(name: "cdb7", value: androidId))
		}

		if let email = emailAddress {
			switch email {
			case let .plain(value):
                let result = value.trimmingCharacters(in: NSCharacterSet.whitespaces).lowercased()
				items.append(URLQueryItem(name: "cdb1", value: result.md5().lowercased()))
				items.append(URLQueryItem(name: "cdb2", value: result.sha256().lowercased()))

			case let .hashed(md5, sha256):
				if let md5 = md5 {
					items.append(URLQueryItem(name: "cdb1", value: md5.lowercased()))
				}
				if let sha256 = sha256 {
					items.append(URLQueryItem(name: "cdb2", value: sha256.lowercased()))
				}
			}
		}
		if let facebookId = facebookId {
			items.append(URLQueryItem(name: "cdb10", value: facebookId.lowercased().sha256().lowercased()))
		}
		if let googlePlusId = googlePlusId {
			items.append(URLQueryItem(name: "cdb12", value: googlePlusId.lowercased().sha256().lowercased()))
		}
		if let iosId = iosId {
			items.append(URLQueryItem(name: "cdb8", value: iosId))
		}
		if let linkedInId = linkedInId {
			items.append(URLQueryItem(name: "cdb13", value: linkedInId.lowercased().sha256().lowercased()))
		}
		if let phoneNumber = phoneNumber {
			switch phoneNumber {
			case let .plain(value):
				let result = value.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted).joined(separator: "")
				items.append(URLQueryItem(name: "cdb3", value: result.md5().lowercased()))
				items.append(URLQueryItem(name: "cdb4", value: result.sha256().lowercased()))

			case let .hashed(md5, sha256):
				if let md5 = md5 {
					items.append(URLQueryItem(name: "cdb3", value: md5.lowercased()))
				}
				if let sha256 = sha256 {
                    items.append(URLQueryItem(name: "cdb4", value: sha256.lowercased()))
				}
			}
		}
		if let twitterId = twitterId {
			items.append(URLQueryItem(name: "cdb11", value: twitterId.lowercased().sha256().lowercased()))
		}
		if let windowsId = windowsId {
			items.append(URLQueryItem(name: "cdb9", value: windowsId))
		}
		
        let numberOfCdbCustomParams = 29
        let customCdbParamBase = 50
        if let custom = custom {
            for (key,value) in custom {
                if key > 0 && key <= numberOfCdbCustomParams {
                    items.append(URLQueryItem(name: "cdb\(key+customCdbParamBase)", value: value))
                } else {
                    logError("Custom CDB parameter key \(key) is out of range, valid keys are between 1 and \(numberOfCdbCustomParams).")
                }
            }
        }

		return items
	}
}


private extension CrossDeviceProperties.Address {

	func isEmpty() -> Bool {
		if firstName != nil || lastName != nil || street != nil || streetNumber != nil || zipCode != nil {
			return false
		}
		return true
	}


	func toLine() -> String {
		return [firstName, lastName, zipCode, street, streetNumber].filterNonNil().joined(separator: "|").lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "ä", with: "ae").replacingOccurrences(of: "ö", with: "oe").replacingOccurrences(of: "ü", with: "ue").replacingOccurrences(of: "ß", with: "ss").replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "")
	}
}


private extension EcommerceProperties {

	func asQueryItems(for request: TrackerRequest) ->  [URLQueryItem] {
		var items = [URLQueryItem]()
		if let currencyCode = currencyCode {
			items.append(URLQueryItem(name: "cr", value: currencyCode))
		}
		if let details = details {
			items += details.mapNotNil { URLQueryItem(name: "cb", property: $0, for: request) }
		}
		if let orderNumber = orderNumber {
			items.append(URLQueryItem(name: "oi", value: orderNumber))
		}
		items += mergeProductQueryItems(for: request)
		if let status = status {
				items.append(URLQueryItem(name: "st", value: status.rawValue))
		}
		if let totalValue = totalValue {
			items.append(URLQueryItem(name: "ov", value: "\(totalValue)"))
		}
		if let voucherValue = voucherValue {
			items.append(URLQueryItem(name: "cb563", value: "\(voucherValue)"))
		}
		return items
	}


	private func mergeProductQueryItems(for request: TrackerRequest) -> [URLQueryItem] {
		
        if self.products == nil {
                return []
		}

		var items = [URLQueryItem]()

        if let names = products?.map({ $0.name ?? "" }) , names.joined(separator: "").nonEmpty != nil {
            items.append(URLQueryItem(name: "ba", value: names.joined(separator: ";")))
        }
		
        if let prices = products?.map({ $0.price ?? "" }) , prices.joined(separator: "").nonEmpty != nil {
            items.append(URLQueryItem(name: "co", value: prices.joined(separator: ";")))
        }
        
        if let quantity = products?.map({ $0.quantity.map { String($0) } ?? "" }) , quantity.joined(separator: "").nonEmpty != nil {
            items.append(URLQueryItem(name: "qn", value: quantity.joined(separator: ";")))
        }

		let categoryIndexes = Set(products?.flatMap { $0.categories.map { Array($0.keys) } ?? [] } ?? [])
        
		for categoryIndex in categoryIndexes {
            let value = products?.map({ $0.categories?[categoryIndex]?.serialized(for: request) ?? "" }).joined(separator: ";")
            
            if let _ = value {
                items.append(URLQueryItem(name: "ca\(categoryIndex)", value: value))
            }
		}

		return items
	}
}


private extension MediaProperties {

	func asQueryItems(for request: TrackerRequest) -> [URLQueryItem] {
		var items = [URLQueryItem]()
		if let bandwidth = bandwidth {
			items.append(URLQueryItem(name: "bw", value: "\(Int64(bandwidth))"))
		}
		if let groups = groups {
			items += groups.mapNotNil { URLQueryItem(name: "mg", property: $0, for: request) }
		}
		if let duration = duration {
			items.append(URLQueryItem(name: "mt2", value: "\(Int64(duration))"))
		}
		else {
			items.append(URLQueryItem(name: "mt2", value: "\(0)"))
		}
		items.append(URLQueryItem(name: "mi", value: name))

		if let position = position {
			items.append(URLQueryItem(name: "mt1", value: "\(Int64(position))"))
		}
		else {
			items.append(URLQueryItem(name: "mt1", value: "\(0)"))
		}
		if let soundIsMuted = soundIsMuted {
			items.append(URLQueryItem(name: "mut", value: soundIsMuted ? "1" : "0"))
		}
		if let soundVolume = soundVolume {
			items.append(URLQueryItem(name: "vol", value: "\(Int64(soundVolume * 100))"))
		}
		items.append(URLQueryItem(name: "x", value: "\(Int64(request.properties.timestamp.timeIntervalSince1970 * 1000))"))
		return items
	}
}


private extension PageProperties {

	func asQueryItems(for request: TrackerRequest) -> [URLQueryItem] {
		var items = [URLQueryItem]()
		if let details = details {
			items += details.mapNotNil { URLQueryItem(name: "cp", property: $0, for: request) }
		}
		if let groups = groups {
			items += groups.mapNotNil { URLQueryItem(name: "cg", property: $0, for: request) }
		}
		if let internalSearch = internalSearch {
			items.append(URLQueryItem(name: "is", value: internalSearch))
		}
		if let url = url {
			items.append(URLQueryItem(name: "pu", value: url))
		}
		return items
	}
}


private extension UserProperties {

	func asQueryItems(for request: TrackerRequest) -> [URLQueryItem] {
		var items = [URLQueryItem]()
		if let details = details {
			items += details.mapNotNil { URLQueryItem(name: "uc", property: $0, for: request) }
		}
		if let birthday = birthday {
			items = items.filter({$0.name != "uc707"})
			items.append(URLQueryItem(name: "uc707", value: birthday.serialized))
		}
		if let city = city {
			items = items.filter({$0.name != "uc708"})
			items.append(URLQueryItem(name: "uc708", value: city))
		}
		if let country = country {
			items = items.filter({$0.name != "uc709"})
			items.append(URLQueryItem(name: "uc709", value: country))
		}
		if let emailAddress = emailAddress {
			items = items.filter({$0.name != "uc700"})
			items.append(URLQueryItem(name: "uc700", value: emailAddress))
		}
		if let emailReceiverId = emailReceiverId {
			items = items.filter({$0.name != "uc701"})
			items.append(URLQueryItem(name: "uc701", value: emailReceiverId))
		}
		if let firstName = firstName {
			items = items.filter({$0.name != "uc703"})
			items.append(URLQueryItem(name: "uc703", value: firstName))
		}
		if let gender = gender {
			items = items.filter({$0.name != "uc706"})
			items.append(URLQueryItem(name: "uc706", value: String(gender.rawValue)))
		}
		if let id = id {
			items.append(URLQueryItem(name: "cd", value: id))
		}
		if let lastName = lastName {
			items = items.filter({$0.name != "uc704"})
			items.append(URLQueryItem(name: "uc704", value: lastName))
		}
		if let newsletterSubscribed = newsletterSubscribed {
			items = items.filter({$0.name != "uc702"})
			items.append(URLQueryItem(name: "uc702", value: newsletterSubscribed ? "1" : "2"))
		}
		if let phoneNumber = phoneNumber {
			items = items.filter({$0.name != "uc705"})
			items.append(URLQueryItem(name: "uc705", value: phoneNumber))
		}
		if let street = street {
			items = items.filter({$0.name != "uc711"})
			items.append(URLQueryItem(name: "uc711", value: street))
		}
		if let streetNumber = streetNumber {
			items = items.filter({$0.name != "uc712"})
			items.append(URLQueryItem(name: "uc712", value: streetNumber))
		}
		if let zipCode = zipCode {
			items = items.filter({$0.name != "uc710"})
			items.append(URLQueryItem(name: "uc710", value: zipCode))
		}

		return items
	}
}

extension TrackerRequest.Properties.ConnectionType {

	var serialized: String {
		switch self {
		case .cellular_2G: return "2G"
		case .cellular_3G: return "3G"
		case .cellular_4G: return "LTE"
		case .offline:     return "offline"
		case .other:       return "unknown"
		case .wifi:        return "WIFI"
		}
	}
}


private extension TrackingValue {

	func serialized(for request: TrackerRequest) -> String? {
		switch self {
		case let .constant(value):
			return value

		case let .defaultVariable(variable):
			switch variable {
			case .advertisingId:              return request.properties.advertisingId?.uuidString
			case .advertisingTrackingEnabled: return request.properties.advertisingTrackingEnabled.map { $0 ? "1" : "0" }
			case .appVersion:                 return request.properties.appVersion
			case .connectionType:             return request.properties.connectionType?.serialized
            case .interfaceOrientation:
            #if !os(iOS)
                return "undefined"
            #else
                return request.properties.interfaceOrientation?.serialized
            #endif
			case .isFirstEventAfterAppUpdate: return request.properties.isFirstEventAfterAppUpdate ? "1" : "0"
			case .requestQueueSize:           return request.properties.requestQueueSize.map { String($0) }
            case .adClearId:                  return String(describing: request.properties.adClearId)
			}

		case let .customVariable(name):
			return request.event.variables[name]
		}
	}
}


private extension URLQueryItem {

	init?(name: String, property: (Int, TrackingValue), for request: TrackerRequest) {
		guard let value = property.1.serialized(for: request) else {
			return nil
		}

		self.init(name: "\(name)\(property.0)", value: value)
	}
}


#if !os(watchOS) && !os(tvOS)
extension UIInterfaceOrientation {

	var serialized: String {
        switch self {
        case .landscapeLeft, .landscapeRight: return "landscape"
        case .portrait, .portraitUpsideDown:  return "portrait"
        case .unknown:                        return "undefined"
        }
	}
}
#endif


private extension UserProperties.Birthday {

	var serialized: String {
		return String(format: "%04d%02d%02d", year, month, day)
	}
}
