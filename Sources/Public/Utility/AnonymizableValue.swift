public enum AnonymizableValue<HashedType> {
    case plain(HashedType)
    case hashed(md5: String?, sha256: String?)
    
    func toJSONObj() -> [String: Any?] {
        
        switch self {
        case .plain(let plain):
            
            if let string = plain as? String {
                return ["plain": string]
            } else if let address = plain as? CrossDeviceProperties.Address {
                return ["plain":address.toJSONObj()]
            } else {
                logError("Cross device bridge information address couldn't be serialized")
                return [:]
            }
            
        case .hashed(let md5, let sha256):
            return ["md5":md5, "sha256":sha256]
        }
    }
}
