/** Enhance tracking by adding properties to track users across different devices. */
public struct CrossDeviceProperties {

    public var address: AnonymizableValue<Address>?
    public var androidId: String?
    public var emailAddress: AnonymizableValue<String>?
    public var facebookId: String?
    public var googlePlusId: String?
    public var iosId: String?
    public var linkedInId: String?
    public var phoneNumber: AnonymizableValue<String>?
    public var twitterId: String?
    public var windowsId: String?
    // custom CDB parameters, valid keys are 1 to 29:
    public var custom: [Int: String]?

    public init(
        address: AnonymizableValue<Address>? = nil,
        androidId: String? = nil,
        emailAddress: AnonymizableValue<String>? = nil,
        facebookId: String? = nil,
        googlePlusId: String? = nil,
        iosId: String? = nil,
        linkedInId: String? = nil,
        phoneNumber: AnonymizableValue<String>? = nil,
        twitterId: String? = nil,
        windowsId: String? = nil,
        custom: [Int: String]? = nil
        ) {
        self.address = address
        self.androidId = androidId
        self.emailAddress = emailAddress
        self.facebookId = facebookId
        self.googlePlusId = googlePlusId
        self.iosId = iosId
        self.linkedInId = linkedInId
        self.phoneNumber = phoneNumber
        self.twitterId = twitterId
        self.windowsId = windowsId
        self.custom = custom
        }

    init (_ json: [String: Any?]) {
        self.androidId = json["androidId"] as? String
        self.facebookId = json["facebookId"] as? String
        self.googlePlusId = json["googlePlusId"] as? String
        self.iosId = json["iosId"] as? String
        self.linkedInId = json["linkedInId"] as? String
        self.twitterId = json["twitterId"] as? String
        self.windowsId = json["windowsId"] as? String

        // setting the address
        if let jsonAdress = json["address"] as? [String: Any?] {
            if (jsonAdress["md5"] ?? jsonAdress["sha256"]) != nil {
                self.address = .hashed(md5: json["md5"] as? String, sha256: json["sha256"] as? String)
            } else if let plain = jsonAdress["plain"] as? [String: Any?] {
                self.address = .plain(Address(plain))
            }
        }

        // setting the emailAddress
        if let jsonEmailAdress = json["emailAddress"] as? [String: String?] {
            if (jsonEmailAdress["md5"] ?? jsonEmailAdress["sha256"]) != nil {
                self.emailAddress = .hashed(md5: json["md5"] as? String, sha256: json["sha256"] as? String)
            } else if let plain = jsonEmailAdress["plain"] {
                self.emailAddress = AnonymizableValue<String>.plain(plain!)
            }
        }

        // setting the phoneNumber
        if let jsonPhoneNumber = json["phoneNumber"] as? [String: String?] {
            if (jsonPhoneNumber["md5"] ?? jsonPhoneNumber["sha256"]) != nil {
                self.phoneNumber = .hashed(md5: jsonPhoneNumber["md5"] as? String, sha256: jsonPhoneNumber["sha256"] as? String)
            } else if let plain = jsonPhoneNumber["plain"] {
                self.phoneNumber = AnonymizableValue<String>.plain(plain!)
            }
        }

        // setting the custom CDB parameters
        if let jsonCustom = json["custom"] as? [String: String?] {
            self.custom = [:]
            for (key, value) in jsonCustom {
                self.custom?[Int(key)!] = value
            }
        }
    }

    func isEmpty() -> Bool {
        return address == nil &&
            androidId == nil &&
            emailAddress == nil &&
            facebookId == nil &&
            googlePlusId == nil &&
            iosId == nil &&
            linkedInId == nil &&
            phoneNumber == nil &&
            twitterId == nil &&
            windowsId == nil &&
            custom == nil
    }

    public struct Address {

        public var firstName: String?
        public var lastName: String?
        public var street: String?
        public var streetNumber: String?
        public var zipCode: String?

        public init(
            firstName: String? = nil,
            lastName: String? = nil,
            street: String? = nil,
            streetNumber: String? = nil,
            zipCode: String? = nil
        ) {
            self.firstName = firstName
            self.lastName = lastName
            self.street = street
            self.streetNumber = streetNumber
            self.zipCode = zipCode
        }

        init (_ json: [String: Any?]) {
            self.firstName = json["firstName"] as? String
            self.lastName = json["lastName"] as? String
            self.street = json["street"] as? String
            self.streetNumber = json["streetNumber"] as? String
            self.zipCode = json["zipCode"] as? String
        }

        func toJSONObj() -> [String: Any?] {
            let jsonObj: [String: Any?] = [
                "firstName": firstName,
                "lastName": lastName,
                "street": street,
                "streetNumber": streetNumber,
                "zipCode": zipCode
            ]
            return jsonObj
        }
    }

    // merges other CDB properties into it (the other properties have lower priority during merging)
    internal func merged(over other: CrossDeviceProperties) -> CrossDeviceProperties {
        return CrossDeviceProperties(
            address: address ?? other.address,
            androidId: androidId ?? other.androidId,
            emailAddress: emailAddress ?? other.emailAddress,
            facebookId: facebookId ?? other.facebookId,
            googlePlusId: googlePlusId ?? other.googlePlusId,
            iosId: iosId ?? other.iosId,
            linkedInId: linkedInId ?? other.linkedInId,
            phoneNumber: phoneNumber ?? other.phoneNumber,
            twitterId: twitterId ?? other.twitterId,
            windowsId: windowsId ?? other.windowsId,
            custom: custom.merged(over: other.custom)
        )
    }

    private func toJSONObj() -> [String: Any?] {
        var jsonObj: [String: Any?] = [
            "address": address?.toJSONObj(),
            "androidId": androidId,
            "emailAddress": emailAddress?.toJSONObj(),
            "facebookId": facebookId,
            "googlePlusId": googlePlusId,
            "iosId": iosId,
            "linkedInId": linkedInId,
            "phoneNumber": phoneNumber?.toJSONObj(),
            "twitterId": twitterId,
            "windowsId": windowsId
        ]

        // add the custom cdb variables (they just need to be coverted from [Int:String] to [String:String?])
        if let c = custom, !c.isEmpty {
            var customDict = [String: String?]()
            for (key, value) in c {
                customDict[String(key)] = value
            }
            jsonObj["custom"] = customDict
        }
        return jsonObj
    }

    func saveToDevice() {
        let cdbJsonObject = toJSONObj()
        let valid = JSONSerialization.isValidJSONObject(cdbJsonObject)

        if valid {
            if let jsonData = try? JSONSerialization.data(withJSONObject: cdbJsonObject, options: []) {
                UserDefaults.standardDefaults.child(namespace: "webtrekk").set(key: DefaultsKeys.crossDeviceProperties, to: jsonData)
            } else {
                logError("Cross device bridge information couldn't be serialized")
            }
        } else {
            logError("Cross device bridge information wasn't a valid JSON")
        }
    }

    static func loadFromDevice() -> CrossDeviceProperties? {

       let crossDevicePropertiesObj = UserDefaults.standardDefaults.child(namespace: "webtrekk").dataForKey(DefaultsKeys.crossDeviceProperties)

        if let data = crossDevicePropertiesObj,
            let cdbJsonObj = ((try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any?]) as [String: Any?]??) {
                return CrossDeviceProperties(cdbJsonObj!)
        }

        return nil
    }
}
