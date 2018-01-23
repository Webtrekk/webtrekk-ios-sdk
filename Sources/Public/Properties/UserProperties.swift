import Foundation

public struct UserProperties {

    public var birthday: Birthday?
    public var city: String?
    public var country: String?
    public var details: [Int: TrackingValue]?
    public var emailAddress: String?
    public var emailReceiverId: String?
    public var firstName: String?
    public var gender: Gender?
    public var id: String?
    public var lastName: String?
    public var newsletterSubscribed: Bool?
    public var phoneNumber: String?
    public var street: String?
    public var streetNumber: String?
    public var zipCode: String?

    public init(
        birthday: Birthday? = nil,
        city: String? = nil,
        country: String? = nil,
        details: [Int: TrackingValue]? = nil,
        emailAddress: String? = nil,
        emailReceiverId: String? = nil,
        firstName: String? = nil,
        gender: Gender? = nil,
        id: String? = nil,
        lastName: String? = nil,
        newsletterSubscribed: Bool? = nil,
        phoneNumber: String? = nil,
        street: String? = nil,
        streetNumber: String? = nil,
        zipCode: String? = nil
        ) {
        self.birthday = birthday
        self.city = city
        self.country = country
        self.details = details
        self.emailAddress = emailAddress
        self.emailReceiverId = emailReceiverId
        self.firstName = firstName
        self.gender = gender
        self.id = id
        self.lastName = lastName
        self.newsletterSubscribed = newsletterSubscribed
        self.phoneNumber = phoneNumber
        self.street = street
        self.streetNumber = streetNumber
        self.zipCode = zipCode
    }

    internal func merged(over other: UserProperties) -> UserProperties {
         return UserProperties(
            birthday: birthday ?? other.birthday,
            city: city ?? other.city,
            country: country ?? other.country,
            details: details.merged(over: other.details),
            emailAddress: emailAddress ?? other.emailAddress,
            emailReceiverId: emailReceiverId ?? other.emailReceiverId,
            firstName: firstName ?? other.firstName,
            gender: gender ?? other.gender,
            id: id ?? other.id,
            lastName: lastName ?? other.lastName,
            newsletterSubscribed: newsletterSubscribed ?? other.newsletterSubscribed,
            phoneNumber: phoneNumber ?? other.phoneNumber,
            street: street ?? other.street,
            streetNumber: streetNumber ?? other.streetNumber,
            zipCode: zipCode ?? other.zipCode
        )
    }

    public struct Birthday {

        public var day: Int
        public var month: Int
        public var year: Int

        public init(day: Int = 1, month: Int, year: Int) {
            self.day = day
            self.month = month
            self.year = year
        }

        init?(raw: String?) {
            guard let rawValue = raw else {
                return nil
            }

            if rawValue.isBirthday {
                let yearIndex = rawValue.index(rawValue.startIndex, offsetBy: 4)
                self.year = Int(rawValue[..<yearIndex])!

                let monthRange = rawValue.index(rawValue.startIndex, offsetBy: 4)..<rawValue.index(rawValue.startIndex, offsetBy: 6)
                self.month = Int(rawValue[monthRange])!
                self.day = Int(rawValue[rawValue.index(rawValue.startIndex, offsetBy: 6)...])!
            } else {
                WebtrekkTracking.logger.logWarning("Incorrect bithday format. Birthday won't be tracked")
                return nil
            }
        }
    }

    public enum Gender: Int {
        case male = 1
        case female
        case unknown

        init?(raw: String?) {

            guard let rawValue = raw else {
                return nil
            }

            if rawValue.isGender {
                self = Gender(rawValue: Int(rawValue)!)!
            } else {
                WebtrekkTracking.logger.logWarning("Incorrect gender format. Gender won't be tracked")
                return nil
            }
        }
    }

    func convertNewsLetter(raw: String) -> Bool {
        return raw == "1"
    }

}

private extension String {
    var isBirthday: Bool {
        get {
            return self.count == 8 && self.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
        }
    }

    var isGender: Bool {
        get {
            return self.count == 1 && (self == "1" || self == "2" || self == "3")
        }
    }
}
