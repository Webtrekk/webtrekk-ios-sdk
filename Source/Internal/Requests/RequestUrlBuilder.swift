import Foundation
import UIKit

internal final class RequestUrlBuilder {

    internal var baseUrl: URL
    private let sharedDefaults = UserDefaults.standardDefaults.child(namespace: "webtrekk")
    private let pendingQueueStore = StorePendingRequest()
    private let campaign: Campaign

    internal init(serverUrl: URL, webtrekkId: String, campaign: Campaign) {
        self.baseUrl = RequestUrlBuilder.buildBaseUrl(serverUrl: serverUrl, webtrekkId: webtrekkId)
        self.serverUrl = serverUrl
        self.webtrekkId = webtrekkId
        self.campaign = campaign
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

    internal func append(arr: inout [URLQueryItem], name: String, value: String) {
        arr.append(URLQueryItem(name: name, value: value))
    }

    internal func urlForRequests(_ request: TrackerRequest, type: DefaultTracker.RequestType) -> [URL] {
        let event = request.event
        let pageNameOpt = event.pageName?.nonEmpty
        var urls = [URL]()

        if pageNameOpt == nil && type == .normal {
            logError("Tracking event must contain a page name: \(request)")
            return urls
        }

        let properties = request.properties
        let screenSize = "\(properties.screenSize?.width ?? 0)x\(properties.screenSize?.height ?? 0)"
        let libraryVersionOriginal = WebtrekkTracking.version
        let libraryVersionParced = libraryVersionOriginal.replacingOccurrences(of: ".", with: "").coded
        let sizeMonitor = URLSizeMonitor()
        let productsCount = (event as? TrackingEventWithEcommerceProperties)?.ecommerceProperties.products?.count ?? 0

        repeat {
            // begin cycle
            var parameters = [URLQueryItem]()
            sizeMonitor.currentRequestSize = 1024; //reserve for non product items

            switch type {
            case .normal:
                // it has to b not null based on previous check for normal
                guard let pageName = pageNameOpt?.coded else {
                    return urls
                }

                append(arr: &parameters,
                       name: "p",
                       value: libraryVersionParced + ",\(pageName),0,\(screenSize),32,0,\(Int64(properties.timestamp.timeIntervalSince1970 * 1000)),0,0,0")
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
                append(arr: &parameters,
                       name: "p",
                       value: libraryVersionParced + ",,0,,,0,\(Int64(properties.timestamp.timeIntervalSince1970 * 1000)),0,0,0")
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
            } else {
                parameters += request.crossDeviceProperties.asQueryItems()
            }

            if let actionProperties = (event as? TrackingEventWithActionProperties)?.actionProperties {
                guard let name = actionProperties.name?.nonEmpty else {
                    logError("Tracking event must contain an action name: \(request)")
                    return urls
                }

                append(arr: &parameters, name: "ct", value: name)

                if let details = actionProperties.details {
                    parameters += details.mapNotNil { URLQueryItem(name: "ck", property: $0, for: request) }
                }
            }

            if let advertisementProperties = (event as? TrackingEventWithAdvertisementProperties)?.advertisementProperties {
                self.addAdvCommonProperties(parameters: &parameters,
                                            mediaCode: advertisementProperties.id,
                                            action: advertisementProperties.action)

                if let details = advertisementProperties.details {
                    parameters += details.mapNotNil { URLQueryItem(name: "cc", property: $0, for: request) }
                }
            }

            if let mediaProperties = (event as? TrackingEventWithMediaProperties)?.mediaProperties {
                guard mediaProperties.name?.nonEmpty != nil else {
                    logError("Tracking event must contain a media name: \(request)")
                    return urls
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

            guard let size = getQuerySize(parameters: parameters, baseUrl: self.baseUrl) else {
                logError("Cannot build URL from components")
                return urls
            }

            sizeMonitor.currentRequestSize += size + 5 // 5 is size of eor=1

            if let ecommerceProperties = (event as? TrackingEventWithEcommerceProperties)?.ecommerceProperties {
                parameters += ecommerceProperties.asQueryItems(for: request, sizeMonitor: sizeMonitor)
            }

            if self.isCampaignFinished {
                if self.pendingQueueStore.exist {
                    if let parameters = self.pendingQueueStore.load() {
                        parameters.forEach({ (item) in
                            var pendingParameters = item
                            self.updateCampaign(parameters: &pendingParameters)

                            self.addLastParametersItem(parameters: &pendingParameters)
                            if let url = createURLFromParameters(parameters: pendingParameters) {
                                urls.append(url)
                            }
                        })
                    }
                    self.pendingQueueStore.clearQueue()
                } else {
                   self.updateCampaign(parameters: &parameters)
                }

                self.addLastParametersItem(parameters: &parameters)
                guard let url = createURLFromParameters(parameters: parameters) else {
                    return urls
                }

                urls.append(url)

            } else {
                // TODO: seems like it stores the params in a json for later usage (might get lost..)
                self.pendingQueueStore.save(parameters: parameters)
            }

        } while sizeMonitor.currentProduct < productsCount

        return urls
    }

    private func updateCampaign(parameters: inout [URLQueryItem]) {
        if let mc = self.campaign.getAndDeletSavedMediaCode() {
            self.addAdvCommonProperties(parameters: &parameters, mediaCode: mc, action: "c")
        }
    }

    private func addAdvCommonProperties(parameters: inout [URLQueryItem], mediaCode: String?, action: String?) {
        if let mediaCode = mediaCode {
            append(arr: &parameters, name: "mc", value: mediaCode)
        }
        if let action = action {
            append(arr: &parameters, name: "mca", value: action)
        }
    }

    private func addLastParametersItem(parameters: inout [URLQueryItem]) {
        parameters.append(URLQueryItem(name: "eor", value: "1"))
    }

    private var isCampaignFinished: Bool {
        return self.campaign.isCampaignProcessed()
    }

    private func createURLFromParameters(parameters: [URLQueryItem]) -> URL? {
        let urlComponents = URLComponents(url: self.baseUrl, resolvingAgainstBaseURL: true)

        guard var components = urlComponents else {
            logError("Could not parse baseUrl: \(self.baseUrl)")
            return nil
        }

        // do workaround to encode all characters in query
        components.applyQueryItemsWithAlternativeURLEncoding(parameters)

        guard let url = components.url else {
            logError("Cannot build URL from components: \(components)")
            return nil
        }
        return url
    }

    private func getQuerySize(parameters: [URLQueryItem], baseUrl: URL) -> Int? {
        let components = URLComponents(url: self.baseUrl, resolvingAgainstBaseURL: true)
        return components?.url?.absoluteString.count
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
                if let regex = try? NSRegularExpression(pattern: "str\\.?\\s*\\|",
                                                        options: NSRegularExpression.Options.caseInsensitive) {
                    result = regex.stringByReplacingMatches(in: value.toLine(),
                                                            options: .withTransparentBounds,
                                                            range: NSMakeRange(0, value.toLine().count),
                                                            withTemplate: "strasse|")
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
            for (key, value) in custom {
                if key > 0 && key <= numberOfCdbCustomParams {
                    items.append(URLQueryItem(name: "cdb\(key+customCdbParamBase)", value: value))
                } else {
                    logError("""
                            Custom CDB parameter key \(key) is out of range,
                            valid keys are between 1 and \(numberOfCdbCustomParams).
                        """)
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
        return [firstName,
                lastName,
                zipCode,
                street,
                streetNumber].filterNonNil()
                             .joined(separator: "|")
                             .lowercased()
                             .replacingOccurrences(of: " ", with: "")
                             .replacingOccurrences(of: "ä", with: "ae")
                             .replacingOccurrences(of: "ö", with: "oe")
                             .replacingOccurrences(of: "ü", with: "ue")
                             .replacingOccurrences(of: "ß", with: "ss")
                             .replacingOccurrences(of: "_", with: "")
                             .replacingOccurrences(of: "-", with: "")
    }
}

private extension EcommerceProperties {

    func asQueryItems(for request: TrackerRequest, sizeMonitor: URLSizeMonitor) -> [URLQueryItem] {
        var items = [URLQueryItem]()

        func addGetQueryItem(name: String, value: String, sizeMonitor: URLSizeMonitor) {
            let item = URLQueryItem(name: name, value: value)
            sizeMonitor.addSize(addSize: item.size)
            items.append(item)
        }

        if let currencyCode = self.currencyCode {
           addGetQueryItem(name: "cr", value: currencyCode, sizeMonitor: sizeMonitor)
        }
        if let orderNumber = self.orderNumber {
            addGetQueryItem(name: "oi", value: orderNumber, sizeMonitor: sizeMonitor)
        }

        if let paymentMethod = self.paymentMethod {
            addGetQueryItem(name: "cb761", value: paymentMethod, sizeMonitor: sizeMonitor)
        }

        if let shippingService = self.shippingService {
            addGetQueryItem(name: "cb762", value: shippingService, sizeMonitor: sizeMonitor)
        }

        if let shippingSpeed = self.shippingSpeed {
            addGetQueryItem(name: "cb763", value: shippingSpeed, sizeMonitor: sizeMonitor)
        }

        if let shippingCost = self.shippingCost {
            addGetQueryItem(name: "cb764", value: shippingCost.string, sizeMonitor: sizeMonitor)
        }

        if let orderStatus = self.orderStatus {
            addGetQueryItem(name: "cb766", value: orderStatus, sizeMonitor: sizeMonitor)
        }

        if let status = status {
            addGetQueryItem(name: "st", value: status.rawValue, sizeMonitor: sizeMonitor)
        }

        if let totalValue = self.totalValue {
            addGetQueryItem(name: "ov", value: "\(totalValue)", sizeMonitor: sizeMonitor)
        }

        var mergetItems = [String: String]()

        if let details = self.details {
            mergetItems = Dictionary (uniqueKeysWithValues: details.mapNotNil {
                let key = "cb\($0.key)"

                guard let value = $0.value.serialized(for: request) else {
                    return nil
                }

                sizeMonitor.addSize(addSize: getFieldSize(name: key, value: value))

                return (key, value)
            })
        }

        if let voucherValue = self.voucherValue {
            let key = "cb563"
            mergetItems[key] = voucherValue
            sizeMonitor.addSize(addSize: getFieldSize(name: key, value: voucherValue))
        }

        items += mergeProductQueryItems(for: request, sizeMonitor: sizeMonitor, mergedItems: mergetItems)

        return items
    }

    private func getFieldSize(name: String, value: String?) -> Int {
        return name.count + (value?.coded.count ?? 0) + 2
    }

    /** merge all products to as less request as possible with ";"*/
    private func mergeProductQueryItems(for request: TrackerRequest, sizeMonitor: URLSizeMonitor, mergedItems: [String: String]) -> [URLQueryItem] {

        var queryItems = [URLQueryItem]()
        var items = [String: String]()

        guard let products = self.products else {
            mergedItems.forEach({queryItems.append(URLQueryItem(name: $0, value: $1))})
            return queryItems
        }

        let separator = ";"

        enum ProductProperties: String {
            case productId = "ba"
            case cost = "co"
            case quantity = "qn"
            case categories = "ca"
            case details = "cb"
            case position = "plp"
            case grossMargin = "cb765"
            case variant = "cb767"
            case voucher = "cb563"
            case soldOut = "cb760"

            static let values = [productId, cost, quantity, categories, details, position, grossMargin, variant, voucher, soldOut]
        }

        func getAddValue(value: String?, valueToAdd: String?) -> String {
            let add = valueToAdd ?? ""
            if let value = value {
                return value + separator + add
            } else {
                return add
            }
        }

        func getProductSingleProperties(type: ProductProperties, product: Product) -> String? {
            switch type {
            case .productId:
                return product.name
            case .cost:
                return product.price ?? product.priceNum?.string
            case .quantity:
                return product.quantity == nil ? nil : String(describing: product.quantity!)
            case .position:
                return product.position == nil ? nil : String(describing: product.position!)
            case .grossMargin:
                return product.grossMargin?.string
            case .variant:
                return product.variant
            case .voucher:
                return product.voucher
            case .soldOut:
                return product.soldOutStr
            case .categories, .details:
                return nil
            }
        }

        func getProductMultipleProperties(type: ProductProperties, product: Product) -> [Int: TrackingValue]? {
            switch type {
            case .categories:
                return product.categories
            case .details:
                return product.details
            default:
                return nil
            }
        }

        //var items = [URLQueryItem]()
        let nextProductId = sizeMonitor.currentProduct

        //collect all key for categories and details
        var detailsKeys = Set<Int>()
        products.forEach { product in
            if let details = product.details {
                details.keys.forEach({detailsKeys.insert($0)})
            }
        }

        var categoriesKeys = Set<Int>()
        products.forEach { product in
            if let categories = product.categories {
                categories.keys.forEach({categoriesKeys.insert($0)})
            }
        }

        var productsSize = 0

        for ind in nextProductId ..< products.count {
            let product = products[ind]
            var itemsWithAddedProduct = items
            var isLengthMore255 = false
            var newProductsSize = 0

            productsLoop: for productType in ProductProperties.values {

                if productType == .categories || productType == .details {
                    let values = getProductMultipleProperties(type: productType, product: product)

                    let keys = productType == .categories ? categoriesKeys : detailsKeys
                    for key in keys {
                        let paramName = productType.rawValue + "\(key)"

                        if mergedItems[paramName] != nil {
                            continue
                        }

                        let value = values?[key]?.serialized(for: request)
                        let newValue = getAddValue(value: items[paramName], valueToAdd: value)

                        if newValue.count > 255 {
                            isLengthMore255 = true
                            break productsLoop
                        }

                        itemsWithAddedProduct[paramName] = newValue
                    }
                } else {
                    let key = productType.rawValue

                    if mergedItems[key] != nil {
                        continue
                    }

                    let value = getProductSingleProperties(type: productType, product: product)
                    let newValue = getAddValue(value: items[key], valueToAdd: value)

                    if newValue.count > 255 {
                        isLengthMore255 = true
                        break
                    }
                    itemsWithAddedProduct[key] = newValue
                }
            }
            itemsWithAddedProduct.forEach({if !$1.isEmpty {newProductsSize += getFieldSize(name: $0, value: $1)}})

            guard sizeMonitor.currentRequestSize + newProductsSize < URLSizeMonitor.maxRequestSize && !isLengthMore255 else {
                break
            }
            productsSize = newProductsSize
            items = itemsWithAddedProduct
            sizeMonitor.currentProduct = ind + 1 // save last processed product ID
        }

        sizeMonitor.addSize(addSize: productsSize)
        items.forEach({if !$1.isEmpty {queryItems.append(URLQueryItem(name: $0, value: $1))}})
        mergedItems.forEach({if !$1.isEmpty {queryItems.append(URLQueryItem(name: $0, value: $1))}})
        return queryItems
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
        } else {
            items.append(URLQueryItem(name: "mt2", value: "\(0)"))
        }
        items.append(URLQueryItem(name: "mi", value: name))

        if let position = position {
            items.append(URLQueryItem(name: "mt1", value: "\(Int64(position))"))
        } else {
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

    var size: Int {
        if let value = self.value {
            return value.coded.count + name.count + 2
        } else {
            return 0
        }
    }
}

extension URLComponents {
    mutating func applyQueryItemsWithAlternativeURLEncoding(_ queryItems: [URLQueryItem]) {

        let addQuery = queryItems.map {
            let value = $0.name == "p" ? $0.value! : $0.value!.coded
            return $0.name.coded + "=" + value
            }.joined(separator: "&")

        if self.percentEncodedQuery != nil {
            self.percentEncodedQuery = self.percentEncodedQuery! + "&" + addQuery
        } else {
            self.percentEncodedQuery = addQuery
        }

    }
}

#if !os(watchOS) && !os(tvOS)
extension UIInterfaceOrientation {

    var serialized: String {
        switch self {
        case .landscapeLeft, .landscapeRight: return "landscape"
        case .portrait, .portraitUpsideDown:  return "portrait"
        case .unknown:                        return "undefined"
        @unknown default:                     return "other"
        }
    }
}
#endif

private extension UserProperties.Birthday {

    var serialized: String {
        return String(format: "%04d%02d%02d", year, month, day)
    }
}

final class URLSizeMonitor {
    var currentRequestSize = 0
    var currentProduct = 0
    static let maxRequestSize = 8*1024

    func addSize(addSize: Int) {
        self.currentRequestSize += addSize
    }
}
