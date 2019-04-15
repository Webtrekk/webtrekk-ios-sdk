import UIKit

private var hookIntoLifecycleToken = Int()

internal extension UIViewController {

	private struct AssociatedKeys {

		fileprivate static var applicationDidBecomeActiveObserver = UInt8()
		fileprivate static var automaticTracker = UInt8()
	}

	@nonobjc
	private static var swizzled = false

	@nonobjc
    var applicationDidBecomeActiveObserver: NSObjectProtocol? {
		get { return objc_getAssociatedObject(self,
                                              &AssociatedKeys.applicationDidBecomeActiveObserver) as? NSObjectProtocol }
		set { objc_setAssociatedObject(self,
                                       &AssociatedKeys.applicationDidBecomeActiveObserver,
                                       newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
	}

	@nonobjc
	private func applicationDidBecomeActiveWhileAppeared() {
		automaticTracker.trackPageView()
	}

	@nonobjc
    var automaticTracker: PageTracker {
		return objc_getAssociatedObject(self, &AssociatedKeys.automaticTracker) as? PageTracker ?? {
			let tracker = DefaultPageTracker(handler: DefaultTracker.autotrackingEventHandler,
                                             viewControllerType: type(of: self))
			objc_setAssociatedObject(self, &AssociatedKeys.automaticTracker,
                                     tracker,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
			return tracker
		}()
	}

	@nonobjc
    static func setUpAutomaticTracking() {
		guard !swizzled else {
			return
		}

		swizzled = true

		_ = swizzleMethod(ofType: UIViewController.self,
                          fromSelector: #selector(viewDidAppear(_:)),
                          toSelector: #selector(swizzled_viewDidAppear(_:)))
		_ = swizzleMethod(ofType: UIViewController.self,
                          fromSelector: #selector(viewWillDisappear(_:)),
                          toSelector: #selector(swizzled_viewWillDisappear(_:)))
	}

	@objc(Webtrekk_viewDidAppear:)
	private dynamic func swizzled_viewDidAppear(_ animated: Bool) {
		self.swizzled_viewDidAppear(animated)

		automaticTracker.trackPageView()

		if applicationDidBecomeActiveObserver == nil {
			applicationDidBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                                                        object: nil,
                                                                                        queue: nil) { [weak self] _ in
				self?.applicationDidBecomeActiveWhileAppeared()
			}
		}
	}

	@objc(Webtrekk_viewWillDisappear:)
	private dynamic func swizzled_viewWillDisappear(_ animated: Bool) {
		self.swizzled_viewWillDisappear(animated)

		if let applicationDidBecomeActiveObserver = applicationDidBecomeActiveObserver {
			NotificationCenter.default.removeObserver(applicationDidBecomeActiveObserver)
			self.applicationDidBecomeActiveObserver = nil
		}
	}
}
