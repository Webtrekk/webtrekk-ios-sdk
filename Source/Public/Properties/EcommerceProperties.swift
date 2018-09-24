import Foundation

public struct EcommerceProperties {

    public var currencyCode: String?
    public var details: [Int: TrackingValue]?
    public var orderNumber: String?
    public var products: [Product]?
    public var status: Status?
    public var totalValue: String?
    public var voucherValue: String?
    public var paymentMethod: String?
    public var shippingService: String?
    public var shippingSpeed: String?
    public var shippingCost: Float?
    public var orderStatus: String?

    public init(
        currencyCode: String? = nil,
        details: [Int: TrackingValue]? = nil,
        orderNumber: String? = nil,
        products: [Product]? = nil,
        status: Status? = nil,
        totalValue: String? = nil,
        voucherValue: String? = nil,
        paymentMethod: String? = nil,
        shippingService: String? = nil,
        shippingSpeed: String? = nil,
        shippingCost: Float? = nil,
        orderStatus: String? = nil
    ) {
        self.currencyCode = currencyCode
        self.details = details
        self.orderNumber = orderNumber
        self.products = products
        self.status = status
        self.totalValue = totalValue
        self.voucherValue = voucherValue
        self.paymentMethod = paymentMethod
        self.shippingService = shippingService
        self.shippingSpeed = shippingSpeed
        self.shippingCost = shippingCost
        self.orderStatus = orderStatus
    }

    internal func merged(over other: EcommerceProperties) -> EcommerceProperties {
        return EcommerceProperties(
            currencyCode: self.currencyCode ?? other.currencyCode,
            details: self.details.merged(over: other.details),
            orderNumber: self.orderNumber ?? other.orderNumber,
            products: self.mergedProducts(products: products, over: other.products),
            status: self.status ?? other.status,
            totalValue: self.totalValue ?? other.totalValue,
            voucherValue: self.voucherValue ?? other.voucherValue,
            paymentMethod: self.paymentMethod ?? other.paymentMethod,
            shippingService: self.shippingService ?? other.shippingService,
            shippingSpeed: self.shippingSpeed ?? other.shippingSpeed,
            shippingCost: self.shippingCost ?? other.shippingCost,
            orderStatus: self.orderStatus ?? other.orderStatus
        )
    }

    /** merge products informaiton from different source of information*/
    internal func mergedProducts(products: [Product]?, over: [Product]?) -> [Product]? {

        guard let products = products else {
            return over
        }

        guard let over = over else {
            return products
        }

        var names: [String] = [],
            overNames: [String] = [],
            mergedNames: [String]
        var prices: [String?] = [],
            overPrices: [String?] = [],
            mergedPrices: [String?]
        var quantities: [Int?] = [],
            overQuantities: [Int?] = [],
            mergedQuantities: [Int?]
        var positions: [Int?] = [],
            overPositions: [Int?] = [],
            mergedPositions: [Int?]
        var margins: [Float?] = [],
            overMargins: [Float?] = [],
            mergedMargins: [Float?]
        var variants: [String?] = [],
            overVariants: [String?] = [],
            mergedVariants: [String?]
        var vouchers: [String?] = [],
            overVouchers: [String?] = [],
            mergedVouchers: [String?]
        var soldOuts: [Bool?] = [],
            overSoldOuts: [Bool?] = [],
            mergedSoldOuts: [Bool?]
        var categories: [[Int: TrackingValue]?] = [],
            overCategories: [[Int: TrackingValue]?] = [],
            mergedCategories: [[Int: TrackingValue]?] = []
        var details: [[Int: TrackingValue]?] = [],
            overDetails: [[Int: TrackingValue]?] = [],
            mergedDetails: [[Int: TrackingValue]?] = []

        transformFromProductList(products: products,
                                 names: &names,
                                 prices: &prices,
                                 quantities: &quantities,
                                 categories: &categories,
                                 positions: &positions,
                                 details: &details,
                                 margins: &margins,
                                 variants: &variants,
                                 vouchers: &vouchers,
                                 soldOuts: &soldOuts)
        transformFromProductList(products: over,
                                 names: &overNames,
                                 prices: &overPrices,
                                 quantities: &overQuantities,
                                 categories: &overCategories,
                                 positions: &overPositions,
                                 details: &overDetails,
                                 margins: &overMargins,
                                 variants: &overVariants,
                                 vouchers: &overVouchers,
                                 soldOuts: &overSoldOuts)

        mergedNames = !names.isEmpty ? names : overNames
        mergedPrices = !prices.isEmpty ? prices : overPrices
        mergedQuantities = !quantities.isEmpty ? quantities : overQuantities

        mergedPositions = !positions.isEmpty ? positions : overPositions
        mergedMargins = !margins.isEmpty ? margins : overMargins
        mergedVariants = !variants.isEmpty ? variants : overVariants
        mergedVouchers = !vouchers.isEmpty ? vouchers : overVouchers
        mergedSoldOuts = !soldOuts.isEmpty ? soldOuts : overSoldOuts

        let sizeCategories = max(overCategories.count, categories.count)

        for i1 in 0..<sizeCategories {
            if i1 >= overCategories.count {
                mergedCategories.append(categories[i1])
            } else {
                mergedCategories.append(i1 < categories.count ? categories[i1].merged(over: overCategories[i1]) : overCategories[i1])
            }
        }

        let sizeDetails = max(overDetails.count, details.count)

        for i2 in 0..<sizeDetails {
            if i2 >= overDetails.count {
                mergedDetails.append(details[i2])
            } else {
                mergedDetails.append(i2 < details.count ? details[i2].merged(over: overDetails[i2]) : overDetails[i2])
            }
        }

        return transformToProductList(names: mergedNames,
                                      prices: mergedPrices,
                                      quantities: mergedQuantities,
                                      categories: mergedCategories,
                                      positions: mergedPositions,
                                      details: mergedDetails,
                                      margins: mergedMargins,
                                      variants: mergedVariants,
                                      vouchers: mergedVouchers,
                                      soldOuts: mergedSoldOuts)
    }

    private func transformFromProductList(products: [Product],
                                          names: inout [String],
                                          prices: inout [String?],
                                          quantities: inout [Int?],
                                          categories localCategories: inout [[Int: TrackingValue]?],
                                          positions: inout [Int?],
                                          details localDetails: inout [[Int: TrackingValue]?],
                                          margins: inout [Float?],
                                          variants: inout [String?],
                                          vouchers: inout [String?],
                                          soldOuts: inout [Bool?]) {

        guard products.isEmpty else {
            return
        }

        for product in products {
            guard let name = product.name else {
                continue
            }
            names.append(name)
            prices.append(product.price ?? product.priceNum?.string)
            quantities.append(product.quantity)
            positions.append(product.position)
            margins.append(product.grossMargin)
            variants.append(product.variant)
            vouchers.append(product.voucher)
            soldOuts.append(product.soldOut)
            localDetails.append(product.details)
            localCategories.append(product.categories)
        }
    }

    // assume that array is size of names size
    private func transformToProductList(names: [String], prices: [String?],
                                        quantities: [Int?],
                                        categories: [[Int: TrackingValue]?],
                                        positions: [Int?],
                                        details: [[Int: TrackingValue]?],
                                        margins: [Float?],
                                        variants: [String?],
                                        vouchers: [String?],
                                        soldOuts: [Bool?]) -> [Product]? {

        let size = max (names.count,
                        prices.count,
                        quantities.count,
                        !categories.isEmpty ? 1 : 0,
                        !details.isEmpty ? 1 : 0,
                        margins.count,
                        variants.count,
                        vouchers.count,
                        soldOuts.count)

        guard size > 0 else {
            return nil
        }

        var products: [Product] = []

        for i in 0..<size {
            products.append(Product(name: names.count > i ? names[i] : "",
                categories: categories.count > i ? categories[i] : nil,
                price: prices.count > i ? prices[i]: nil,
                quantity: quantities.count > i ? quantities[i] : nil,
                position: positions.count > i ? positions[i]: nil,
                details: details.count > i ? details[i] : nil,
                grossMargin: margins.count > i ? margins[i]: nil,
                productVariant: variants.count > i ? variants[i]: nil,
                voucherValue: vouchers.count > i ? vouchers[i]: nil,
                soldOut: soldOuts.count > i ? soldOuts[i]: nil))
        }

        return products
    }

    public struct Product {

        public var categories: [Int: TrackingValue]?
        public var name: String?
        public var price: String?
        public var priceNum: Float?
        public var quantity: Int?
        public var position: Int?
        public var details: [Int: TrackingValue]?
        public var grossMargin: Float?
        public var variant: String?
        public var voucher: String?
        public var soldOut: Bool?

        public init(
            name: String,
            categories: [Int: TrackingValue]? = nil,
            price: String? = nil,
            priceNum: Float? = nil,
            quantity: Int? = nil,
            position: Int? = nil,
            details: [Int: TrackingValue]? = nil,
            grossMargin: Float? = nil,
            productVariant: String? = nil,
            voucherValue: String? = nil,
            soldOut: Bool? = nil
        ) {
            self.categories = categories
            self.name = name
            self.price = price
            self.priceNum = priceNum
            self.quantity = quantity
            self.position = position
            self.details = details
            self.grossMargin = grossMargin
            self.variant = productVariant
            self.voucher = voucherValue
            self.soldOut = soldOut
        }

        var soldOutStr: String? {
            guard let soldOut = self.soldOut else {
                return nil
            }

            return soldOut ? "1" : "0"
        }
    }

    /**
     Shopping basket Status mapping enum
     
     **case** addedToBasket: *add*
     
     **case** purchased: *conf*
     
     **case** viewed: *view*
     
     **case** list: *list*
     
    */
    public enum Status: String {
        case addedToBasket = "add"
        case purchased = "conf"
        case viewed = "view"
        case list = "list"
    }
}

extension String {
    var isQuantity: Bool {
        get {
            return self.isEmpty && self.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
        }
    }
}

extension Float {
    var string: String {
        return String(describing: self)
    }
}
