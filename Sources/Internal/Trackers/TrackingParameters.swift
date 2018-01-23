import Foundation

enum PropertyName: String {
    case advertisementId = "ADVERTISEMENT"
    case advertisementAction = "ADVERTISEMENT_ACTION"
    case birthday = "BIRTHDAY"
    case city = "CITY"
    case country = "COUNTRY"
    case currencyCode = "CURRENCY"
    case customerId = "CUSTOMER_ID"
    case emailAddress = "EMAIL"
    case emailReceiverId = "EMAIL_RID"
    case firstName = "GNAME"
    case gender = "GENDER"
    case internalSearch = "INTERN_SEARCH"
    case ipAddress = "IP_ADDRESS"
    case lastName = "SNAME"
    case newsletterSubscribed = "NEWSLETTER"
    case orderNumber = "ORDER_NUMBER"
    case pageUrl = "PAGE_URL"
    case phoneNumber = "PHONE"
    case productName = "PRODUCT"
    case productPrice = "PRODUCT_COST"
    case productQuantity = "PRODUCT_COUNT"
    case productStatus = "PRODUCT_STATUS"
    case street = "STREET"
    case streetNumber = "STREETNUMBER"
    case totalValue = "ORDER_TOTAL"
    case voucherValue = "VOUCHER_VALUE"
    case zipCode = "ZIP"
}

enum CustomParType: String {
    case actionParameter, adParameter, ecomParameter, mediaCategories, pageCategories, pageParameter, productCategories, sessionParameter, userCategories
}

class TrackingParameter {
    var categories: [CustomParType: [Int: PropertyValue]]
    private var parameters: [PropertyName: PropertyValue]

    init(categories: [CustomParType: [Int: PropertyValue]], parameters: [PropertyName: PropertyValue]) {
        self.categories = categories
        self.parameters = parameters
    }

    private func resolved(elements: [Int: PropertyValue], variables: [String: String]) -> [Int: TrackingValue]? {
        var result = [Int: TrackingValue]()
        for (index, element) in elements {
            switch element {
            case let .key(key):
                switch key {
                case  "advertiserId":        result[index] = .defaultVariable(.advertisingId)
                case  "advertisingOptOut":   result[index] = .defaultVariable(.advertisingTrackingEnabled)
                case  "appVersion":          result[index] = .defaultVariable(.appVersion)
                case  "connectionType":      result[index] = .defaultVariable(.connectionType)
                case  "screenOrientation":   result[index] = .defaultVariable(.interfaceOrientation)
                case  "appUpdated":          result[index] = .defaultVariable(.isFirstEventAfterAppUpdate)
                case  "requestUrlStoreSize": result[index] = .defaultVariable(.requestQueueSize)
                case  "adClearId":           result[index] = .defaultVariable(.adClearId)
                default:                     if let variable = variables[key] {result[index] = .constant(variable)}
                }
            case let .value(value):
                result[index] = .constant(value)

            }
        }
        return result.isEmpty ? nil : result
    }

    func actionProperties(variables: [String: String]) -> ActionProperties {
        return ActionProperties(name: nil, details: categories[.actionParameter].flatMap { resolved(elements: $0, variables: variables) })
    }

    func advertisementProperties(variables: [String: String]) -> AdvertisementProperties {
        var advertisementId: String? = nil
        if let id = parameters[.advertisementId]?.serialized(variables: variables) {
            advertisementId = id
        }
        var advertisementAction: String? = nil
        if let action = parameters[.advertisementAction]?.serialized(variables: variables) {
            advertisementAction = action
        }
        var details: [Int: TrackingValue]? = nil
        if let elements = categories[.adParameter], let advertisementDetails = resolved(elements: elements, variables: variables) {
            details = advertisementDetails
        }

        return AdvertisementProperties(id: advertisementId, action: advertisementAction, details: details)
    }

    func resolveIPAddress(variables: [String: String]) -> String? {
            return parameters[.ipAddress]?.serialized(variables: variables)
    }

    func ecommerceProperties(variables: [String: String]) -> EcommerceProperties {

        var ecommerceProperties = EcommerceProperties()

        if let currencyCode = parameters[.currencyCode]?.serialized(variables: variables) {
            ecommerceProperties.currencyCode = currencyCode
        }

        if let orderNumber = parameters[.orderNumber]?.serialized(variables: variables) {
            ecommerceProperties.orderNumber = orderNumber
        }

        if let status = parameters[.productStatus]?.serialized(variables: variables) {
            ecommerceProperties.status = EcommerceProperties.Status(rawValue: status)
        }

        if let totalValue = parameters[.totalValue]?.serialized(variables: variables) {
            ecommerceProperties.totalValue = totalValue
        }

        if let voucherValue = parameters[.voucherValue]?.serialized(variables: variables) {
            ecommerceProperties.voucherValue = voucherValue
        }

        if let elements = categories[.ecomParameter], let ecommerceDetails = resolved(elements: elements, variables: variables) {
            ecommerceProperties.details = ecommerceDetails
        }

        if let product = productProperties(variables: variables) {
            ecommerceProperties.products = [product]
        }

        return ecommerceProperties
    }

    func mediaProperties(variables: [String: String]) -> MediaProperties {
        return MediaProperties(name: nil, groups: categories[.mediaCategories].flatMap { resolved(elements: $0, variables: variables) })
    }

    func pageProperties(variables: [String: String]) -> PageProperties {
        var pageProperties = PageProperties(name: nil)
        if let internalSearch = parameters[.internalSearch]?.serialized(variables: variables) {
            pageProperties.internalSearch = internalSearch
        }
        if let url = parameters[.pageUrl]?.serialized(variables: variables) {
            pageProperties.url = url
        }
        if let elements = categories[.pageParameter], let pageDetails = resolved(elements: elements, variables: variables) {
            pageProperties.details = pageDetails
        }
        if let elements = categories[.pageCategories], let pageGroups = resolved(elements: elements, variables: variables) {
            pageProperties.groups = pageGroups
        }

        return pageProperties
    }

    func productProperties(variables: [String: String]) -> EcommerceProperties.Product? {

        let productName = parameters[.productName]?.serialized(variables: variables)

        let productPrice = parameters[.productPrice]?.serialized(variables: variables)

        var productQuantity: Int? = nil
        if let productQuantityStr = parameters[.productQuantity]?.serialized(variables: variables), productQuantityStr.isQuantity {
            productQuantity = Int(productQuantityStr)
        }

        var productCategories: [Int: TrackingValue]? = nil
        if let elements = categories[.productCategories], let productCategoriesElements = resolved(elements: elements, variables: variables) {
            productCategories = productCategoriesElements
        }

        guard productName != nil || productPrice != nil || productQuantity != nil || productCategories != nil else {
            return nil
        }

        return EcommerceProperties.Product(name: productName ?? "", categories: productCategories, price: productPrice, quantity: productQuantity)
    }

    func sessionDetails(variables: [String: String]) -> [Int: TrackingValue] {
        return categories[.sessionParameter].flatMap { resolved(elements: $0, variables: variables) } ?? [:]
    }

    func userProperties(variables: [String: String]) -> UserProperties {
        var userProperties = UserProperties(birthday: nil)
        if let categoryElements = categories[.userCategories], let details = resolved(elements: categoryElements, variables: variables) {
            userProperties.details = details
        }
        if let bithday = parameters[.birthday]?.serialized(variables: variables) {
            userProperties.birthday = UserProperties.Birthday(raw: bithday)
        }
        if let city = parameters[.city]?.serialized(variables: variables) {
            userProperties.city = city
        }
        if let country = parameters[.country]?.serialized(variables: variables) {
            userProperties.country = country
        }
        if let id = parameters[.customerId]?.serialized(variables: variables) {
            userProperties.id = id
        }
        if let emailAddress = parameters[.emailAddress]?.serialized(variables: variables) {
            userProperties.emailAddress = emailAddress
        }
        if let emailReceiverId = parameters[.emailReceiverId]?.serialized(variables: variables) {
            userProperties.emailReceiverId = emailReceiverId
        }
        if let firstName = parameters[.firstName]?.serialized(variables: variables) {
            userProperties.firstName = firstName
        }
        if let gender = parameters[.gender]?.serialized(variables: variables) {
            userProperties.gender = UserProperties.Gender(raw: gender)
        }
        if let lastName = parameters[.lastName]?.serialized(variables: variables) {
            userProperties.lastName = lastName
        }
        if let newsletterSubscribed = parameters[.newsletterSubscribed]?.serialized(variables: variables) {
            userProperties.newsletterSubscribed = userProperties.convertNewsLetter(raw: newsletterSubscribed)
        }
        if let phoneNumber = parameters[.phoneNumber]?.serialized(variables: variables) {
            userProperties.phoneNumber = phoneNumber
        }
        if let street = parameters[.street]?.serialized(variables: variables) {
            userProperties.street = street
        }
        if let streetNumber = parameters[.streetNumber]?.serialized(variables: variables) {
            userProperties.streetNumber = streetNumber
        }
        if let zipCode = parameters[.zipCode]?.serialized(variables: variables) {
            userProperties.zipCode = zipCode
        }
        return userProperties
    }
}
