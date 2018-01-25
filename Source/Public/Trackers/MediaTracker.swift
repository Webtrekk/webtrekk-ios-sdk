import UIKit

public protocol MediaTracker: class {

    var mediaProperties: MediaProperties { get set }
    var pageName: String? { get set }
    var variables: [String: String] { get set }
    var viewControllerType: AnyObject.Type? { get set }

    func trackAction (_ action: MediaEvent.Action)
}
