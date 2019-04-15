import Foundation
import UIKit

#if !os(watchOS)
    import Reachability
#endif

internal final class RequestManager: NSObject, URLSessionDelegate {

	internal typealias Delegate = _RequestManagerDelegate

	private var currentFailureCount = 0
	private var currentRequest: URL?
	private var pendingTask: URLSessionDataTask?
	private var sendNextRequestTimer: Timer?
	private var urlSession: URLSession?
    private let manualStart: Bool

	#if !os(watchOS)
	private let reachability: Reachability?
	private var sendingInterruptedBecauseUnreachable = false
    var backgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
	#endif

	internal fileprivate(set) var queue = RequestQueue()
	internal fileprivate(set) var started = false
    private(set) var finishing = false
    var isPending: Bool {return pendingTask != nil}

	internal weak var delegate: Delegate?

    internal init(manualStart: Bool) {
		checkIsOnMainThread()

        self.manualStart = manualStart

 		#if !os(watchOS)
            self.reachability = Reachability.init()
        #endif

        super.init()

        #if !os(watchOS)
            self.reachability?.whenReachable = { [weak self] reachability in
                logDebug("Internet is reachable again!")

                reachability.stopNotifier()
                self?.sendNextRequest()
            }
        #endif
    }

	#if !os(watchOS)
	deinit {
		reachability?.stopNotifier()
	}
	#endif

	fileprivate func cancelCurrentRequest() {
		checkIsOnMainThread()

		guard let pendingTask = self.pendingTask else {
			return
		}

		pendingTask.cancel()

		self.currentRequest = nil
		self.currentFailureCount = 0
		self.pendingTask = nil
	}

	internal func clearPendingRequests() {
		checkIsOnMainThread()

		logInfo("Clearing queue of \(self.queue.size) requests.")

		self.queue.deleteAll()
	}

    internal static func createUrlSession(delegate: URLSessionDelegate? = nil) -> URLSession {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.httpCookieAcceptPolicy = .never
		configuration.httpShouldSetCookies = false
		configuration.urlCache = nil
		configuration.urlCredentialStorage = nil
		configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

		let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: OperationQueue.main)
		session.sessionDescription = "Webtrekk Tracking"

		return session
	}

	internal func enqueueRequest(_ request: URL, maximumDelay: TimeInterval) {
		checkIsOnMainThread()

        // add senNextRequest to closerue. So it will be called only after adding is done
		self.queue.addURL(url: request)

        logDebug("Queued: \(request.absoluteString.replacingOccurrences(of: "&", with: "  "))")

        if !manualStart {
            sendNextRequest(maximumDelay: maximumDelay)
        }
	}

    func fetch(url: URL, completion: @escaping (Data?, ConnectionError?) -> Void) -> URLSessionDataTask? {
		checkIsOnMainThread()

        guard let urlSession = self.urlSession else {
            WebtrekkTracking.defaultLogger.logError("Error: session is nil during fetch")
            return nil
        }

        let task = urlSession.dataTask(with: url, completionHandler: {data, response, error in
			if let error = error {
				let retryable: Bool
				let isCompletelyOffline: Bool

				switch (error as NSError).code {
				case NSURLErrorBadServerResponse,
				     NSURLErrorCallIsActive,
				     NSURLErrorCannotConnectToHost,
				     NSURLErrorCannotFindHost,
				     NSURLErrorDataNotAllowed,
				     NSURLErrorDNSLookupFailed,
				     NSURLErrorInternationalRoamingOff,
				     NSURLErrorNetworkConnectionLost,
				     NSURLErrorNotConnectedToInternet,
				     NSURLErrorTimedOut,
				     NSURLErrorZeroByteResource:

					retryable = true

				default:
					retryable = false
				}

				switch (error as NSError).code {
				case NSURLErrorCallIsActive,
				     NSURLErrorDataNotAllowed,
				     NSURLErrorInternationalRoamingOff,
				     NSURLErrorNotConnectedToInternet:

					isCompletelyOffline = true

				default:
					isCompletelyOffline = false
				}

				completion(nil, ConnectionError(message: error.localizedDescription, isTemporary: retryable, isCompletelyOffline: isCompletelyOffline, underlyingError: error))
				return
			}

			guard let response = response as? HTTPURLResponse else {
				completion(nil, ConnectionError(message: "No Response", isTemporary: false))
				return
			}
			guard !(500 ... 599).contains(response.statusCode) else {
				completion(nil, ConnectionError(message: "HTTP \(response.statusCode)", isTemporary: true))
				return
			}
			guard (200 ... 299).contains(response.statusCode), let data = data else {
				completion(nil, ConnectionError(message: "HTTP \(response.statusCode)", isTemporary: false))
				return
			}

			completion(data, nil)
		})
		task.resume()

		return task
	}

	fileprivate func maximumNumberOfFailures(with error: ConnectionError) -> Int {
		checkIsOnMainThread()

		if error.isCompletelyOffline {
			return 60
		} else {
			return 10
		}
	}

	internal func prependRequests(_ requests: [URL]) {
		checkIsOnMainThread()

        // it can be done only on after application update at first start
        guard self.queue.isEmpty else {
            return
        }

		self.queue.addArray(urls: requests)
	}

	internal func sendAllRequests() {
		checkIsOnMainThread()

		sendNextRequest()
	}

	fileprivate func sendNextRequest() {
		checkIsOnMainThread()

		sendNextRequestTimer?.invalidate()
		sendNextRequestTimer = nil

		guard started else {
			return
		}
		guard self.pendingTask == nil else {
			return
		}
		guard !self.queue.isEmpty else {
            WebtrekkTracking.defaultLogger.logDebug("queue is empty: finish send process")
			return
		}

		#if !os(watchOS)
			if let reachability = reachability {
				if reachability.connection == .none {
					if !sendingInterruptedBecauseUnreachable {
						sendingInterruptedBecauseUnreachable = true

						logDebug("Internet is unreachable. Pausing requests.")

						do {
							try reachability.startNotifier()
						} catch let error {
							logError("Cannot listen for reachability events: \(error)")
						}
					}

					return
				}

				sendingInterruptedBecauseUnreachable = false
				reachability.stopNotifier()
			}
		#endif

        do {
            try self.queue.getURL { url in

                if url != self.currentRequest {
                    self.currentFailureCount = 0
                    self.currentRequest = url
                }

                guard let url = url else {
                    return
                }

                guard !self.finishing else {
                    WebtrekkTracking.defaultLogger.logDebug("Interrupt get request. process is finishing")
                    return
                }

                self.pendingTask = self.fetch(url: url) { data, error in
                    self.pendingTask = nil

                    if let error = error {
                        guard error.isTemporary else {
                            logError("Request \(url) failed and will not be retried: \(error)")

                            self.currentFailureCount = 0
                            self.currentRequest = nil
                            _ = self.queue.deleteFirst()

                            self.delegate?.requestManager(self, didFailToSendRequest: url, error: error)
                            return
                        }
                        guard self.currentFailureCount < self.maximumNumberOfFailures(with: error) else {
                            logError("Request \(url) failed and will no longer be retried: \(error)")

                            self.currentFailureCount = 0
                            self.currentRequest = nil
                            _ = self.queue.deleteFirst()

                            self.delegate?.requestManager(self, didFailToSendRequest: url, error: error)
                            return
                        }

                        let retryDelay = Double(self.currentFailureCount * 5)
                        logWarning("Request \(url) failed temporarily and will be retried in \(retryDelay) seconds: \(error)")

                        self.currentFailureCount += 1
                        self.sendNextRequest(maximumDelay: retryDelay)
                        return
                    }

                    logDebug("Request has been sent successefully")

                    self.currentFailureCount = 0
                    self.currentRequest = nil
                    _ = self.queue.deleteFirst()

                    if let delegate = self.delegate {
                        delegate.requestManager(self, didSendRequest: url)
                    }

                    self.sendNextRequest()
                }
            }
        } catch let error {
            if let error = error as? TrackerError {
                WebtrekkTracking.defaultLogger.logError("catched exception: \(error.message)")
            }
        }
	}

	fileprivate func sendNextRequest(maximumDelay: TimeInterval) {
		checkIsOnMainThread()

		guard !self.queue.isEmpty else {
			return
		}

		if let sendNextRequestTimer = self.sendNextRequestTimer {
			let fireDate = Date(timeIntervalSinceNow: maximumDelay)
			if fireDate.compare(sendNextRequestTimer.fireDate) == ComparisonResult.orderedAscending {
				sendNextRequestTimer.fireDate = fireDate
			}
		} else {
			self.sendNextRequestTimer = Timer.scheduledTimerWithTimeInterval(maximumDelay) {
				self.sendNextRequestTimer = nil
				self.sendAllRequests()
			}
		}
	}

	internal func start() {
		checkIsOnMainThread()

		guard !started else {
			logWarning("Cannot start RequestManager which was already started.")
			return
		}

		self.started = true
        self.finishing = false

        if self.urlSession == nil {
            self.urlSession = RequestManager.createUrlSession(delegate: self)
        }

        if !manualStart {
            sendNextRequest()
        }
	}

	internal func stop() {
		checkIsOnMainThread()

		guard started else {
			logWarning("Cannot stop RequestManager which wasn't started.")
			return
		}

		started = false

		self.sendNextRequestTimer?.invalidate()
		self.sendNextRequestTimer = nil

		#if !os(watchOS)
			sendingInterruptedBecauseUnreachable = false
			reachability?.stopNotifier()
		#endif

        self.finishing = true

        WebtrekkTracking.defaultLogger.logDebug("stop. pending task is: \(self.pendingTask.simpleDescription)")
        self.urlSession?.finishTasksAndInvalidate()
        self.urlSession = nil
	}

	internal struct ConnectionError: Error {

		internal var isCompletelyOffline: Bool
		internal var isTemporary: Bool
		internal var message: String
		internal var underlyingError: Error?

		internal init(message: String, isTemporary: Bool, isCompletelyOffline: Bool = false, underlyingError: Error? = nil) {
			self.isCompletelyOffline = isCompletelyOffline
			self.isTemporary = isTemporary
			self.message = message
			self.underlyingError = underlyingError
		}
	}

    // implement URLSessionDelegate
    public func urlSession(
                    _ session: URLSession,
                    didBecomeInvalidWithError error: Error?) {
        logDebug("didBecomeInvalidWithError  call")

        DispatchQueue.global(qos: .background).async {
            if self.finishing {
                WebtrekkTracking.defaultLogger.logDebug("URL request has been finished. Save all")
                if let error = error {
                    WebtrekkTracking.defaultLogger.logError("URL session invalidated with error: \(error)")
                }
                self.queue.save()
                self.finishing = false

                #if !os(watchOS)
                if self.backgroundTaskIdentifier != UIBackgroundTaskIdentifier.invalid {
                    UIApplication.shared.endBackgroundTask(convertToUIBackgroundTaskIdentifier(self.backgroundTaskIdentifier.rawValue))
                    self.backgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
                }
                #endif
            }
        }
    }
}

internal protocol _RequestManagerDelegate: class {

	func requestManager (_ requestManager: RequestManager, didSendRequest request: URL)
	func requestManager (_ requestManager: RequestManager, didFailToSendRequest request: URL, error: RequestManager.ConnectionError)
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIBackgroundTaskIdentifier(_ input: Int) -> UIBackgroundTaskIdentifier {
	return UIBackgroundTaskIdentifier(rawValue: input)
}
