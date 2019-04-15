import Foundation

class Campaign: NSObject {

    let trackID: String
    static let campaignHasProcessed = "campaignHasProcessed"
    static let savedMediaCode = "mediaCode"
    private let sharedDefaults = UserDefaults.standardDefaults.child(namespace: "webtrekk")
    private var campaignProcessTimeOut: Date?
    private var timer: Timer?
    static let timeoutValue =  TimeInterval(60)
    static let interval = TimeInterval(20)

    init(trackID: String) {
        self.trackID = trackID
    }

    deinit {
       self.timer?.invalidate()
    }

    func processCampaign() {
        if isCampaignProcessed() {
            WebtrekkTracking.logger.logError("campaign was already processed")
            return
        }

        WebtrekkTracking.logger.logDebug("Campaign process is starting")
        self.campaignProcessTimeOut = Date(timeIntervalSinceNow: Campaign.timeoutValue)

        // send request
        var urlComponents = URLComponents(string: "https://appinstall.webtrekk.net/appinstall/v1/install")

        guard urlComponents != nil else {
            WebtrekkTracking.logger.logError("can't initializate URL for campaign")
            return
        }
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "trackid", value: self.trackID))

        if let advID = Environment.advertisingIdentifierManager?.advertisingIdentifier,
            advID.uuidString != "00000000-0000-0000-0000-000000000000" {
            queryItems.append(URLQueryItem(name: "aid", value: advID.uuidString))
        }

        queryItems.append(URLQueryItem(name: "X-WT-UA", value: DefaultTracker.userAgent))

        urlComponents?.applyQueryItemsWithAlternativeURLEncoding(queryItems)

        guard let url = urlComponents?.url else {
            WebtrekkTracking.logger.logError("can't construct URL for campaign")
            return
        }

        sendInstallCampaignRequest(url: url)
    }

    @objc
    private func timerFireMethod(timer: Timer) {
        if let url = timer.userInfo as? URL {
            sendInstallCampaignRequest(url: url)
        }
    }

    private func sendInstallCampaignRequest(url: URL) {
        let session = RequestManager.createUrlSession()
        let task = session.dataTask(with: url, completionHandler: { data, response, error in
            if let error = error {
                WebtrekkTracking.logger.logError("Install campaign request error:\(error)")
            } else {
                guard let responseGuard = response as? HTTPURLResponse else {
                    WebtrekkTracking.logger.logError("Install campaign response error:\(response.simpleDescription)")
                    return
                }

                guard responseGuard.statusCode == 200 else {
                    WebtrekkTracking.logger.logDebug("Attempt to get campaign error. Response:\(response.simpleDescription)")

                    if self.campaignProcessTimeOut?.compare(Date()) == .orderedAscending {
                         WebtrekkTracking.logger.logDebug("getting campaign timeout")
                        self.timer?.invalidate()
                        self.sharedDefaults.set(key: Campaign.campaignHasProcessed, to: true)
                    } else if self.timer == nil {
                        self.timer = Timer.scheduledTimer(timeInterval: Campaign.interval, target: self, selector: #selector(Campaign.timerFireMethod(timer:)),
                                           userInfo: url, repeats: true)
                    }
                    return
                }

                self.timer?.invalidate()

                // parse response
                guard let dataG = data else {
                    return
                }
                guard let json = ((try? JSONSerialization.jsonObject(with: dataG, options: .allowFragments) as? [String: Any]) as [String: Any]??) else {
                    WebtrekkTracking.logger.logError("Incorrect JSON response for Campaign tracking:\(data.simpleDescription)")
                    return
                }
                guard let jsonMedia = json?["mediacode"] as? String else {
                    WebtrekkTracking.logger.logError("Incorrect JSON response for Campaign tracking:\(data.simpleDescription)")
                    return
                }

                WebtrekkTracking.logger.logDebug("Media code is received:\(jsonMedia)")

                let mc = String(jsonMedia.split(separator: "=", maxSplits: 1)[1])

                guard !mc.isEmpty else {
                    WebtrekkTracking.logger.logError("media code length is zero")
                    return
                }

                self.sharedDefaults.set(key: Campaign.savedMediaCode, to: mc)
                self.sharedDefaults.set(key: Campaign.campaignHasProcessed, to: true)
            }
        })

        WebtrekkTracking.logger.logDebug("Campaign request is sent:\(url)")
        task.resume()
    }

    func getAndDeletSavedMediaCode() -> String? {
        let mediaCode = self.sharedDefaults.stringForKey(Campaign.savedMediaCode)

        if let _ = mediaCode {
            self.sharedDefaults.remove(key: Campaign.savedMediaCode)
        }

        return mediaCode
    }

    func isCampaignProcessed() -> Bool {
        return self.sharedDefaults.boolForKey(Campaign.campaignHasProcessed) ?? false
    }

}
