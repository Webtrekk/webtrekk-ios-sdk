import Foundation
import UIKit

#if os(watchOS)
import WatchKit
#endif

public protocol ProductListTracker: class {
    /** add products to be tracked. Can be called several times. It isn't time consuming operation. Can be called during scrolling monitor.*/
    func addTrackingData(products: [EcommerceProperties.Product], type: EcommerceProperties.Status)

    /** track all data that was added by addTrackingData calls
     commonProperties - properties that are common for all products (like order status)
     viewController - if you use automatic tracking it defines page name(content Id) based on you ViewController
     */
    #if !os(watchOS)
        func track(commonProperties: PageViewEvent, viewController: UIViewController?)
    #else
        func track(commonProperties: PageViewEvent, viewController: WKInterfaceController?)
    #endif
}
/** that is extension to make possible optional parameter viewController for track*/
public extension ProductListTracker {

    #if !os(watchOS)
    func track(commonProperties: PageViewEvent, viewController: UIViewController? = nil) {
        self.track(commonProperties: commonProperties, viewController: viewController)
    }
    #else
    func track(commonProperties: PageViewEvent, viewController: WKInterfaceController? = nil) {
        self.track(commonProperties: commonProperties, viewController: viewController)
    }
    #endif
}
