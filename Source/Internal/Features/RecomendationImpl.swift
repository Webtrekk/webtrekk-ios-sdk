import Foundation

class RecomendationImpl: Recommendation {

    private var callback: RecommendationCallback?
    private var recommendationURL: URL!
    private var productId: String?
    private let configuration: TrackerConfiguration

    init(configuration: TrackerConfiguration) {
        self.configuration = configuration
    }

    /**
     * returns recommendation URL configured for this product. List of recommendations are defined in
     * <recommendations> tag in config XML. Recommendation are returned as URL based on provided key value. If key isn't defined it returns nil*/
    func getRecomendationURL(key: String) -> URL? {
        return self.configuration.recommendations?[key]
    }

    /**
     * Init query for recommendation. Need call call() function to complete query.
     * name is name of recomendation in your config.xml
     * callback is callback for getting results.
     * returns link to self of current instance.
     */
    func queryRecommendation(callback: RecommendationCallback, name recomendationName: String) -> Recommendation? {

        guard let url = getRecomendationURL(key: recomendationName) else {
            logError("There is no recommendation found for name \(recomendationName). Please check your configuration xml")
            return nil
        }

        self.recommendationURL = url
        self.callback = callback

        return self
    }

    /**
     * Set product ID for request recommendation call. If product ID nil it will be ignored. Need call call() function to complete query.
     * returns link to self of current instance.
     */
    func setProductID(id: String?) -> Recommendation {
        self.productId = id
        return self
    }

    /**
     * Call recommendation. Result will be provided in callback that was set in queryRecommendation. Callback is provided in main queue.
     */
    func call() {
        guard self.callback != nil else {
            logError("call back is zero. Can't provide recommendation for this request. Call queryRecommendation first")
            return
        }

        guard let url = constructURL() else {
            logError("Can't create url. Call is canceled")
            return
        }

        let session = RequestManager.createUrlSession()

        logDebug("Sending reco request: \(url)")

        let task = session.dataTask(with: url) { (data, response, error) in

            var result: RecommendationQueryResult
            if let errorL = error {
                switch (errorL as NSError).code {
                case NSURLErrorBadURL, NSURLErrorUnsupportedURL:
                    result = .incorrect_url_format
                default :
                    result = .no_connection
                }
                logError("Request to getting recommendation error: \(errorL.localizedDescription)")
                self.callback?.onReceiveRecommendations(products: nil, result: result, error: error)
            } else {
                if let response = response as? HTTPURLResponse {
                    switch response.statusCode {
                    case 200:
                        result = .ok
                        logDebug("Recommendation request successfully done.")
                    case 400:
                        result = .no_placement_found
                    case 401:
                        result = .no_account_id_found
                    case 403:
                        result = .recommendation_api_deactivated
                    case 404:
                        result = .incorrect_url_format
                    default:
                        result = .incorrect_response
                        logError("Recommendation request incorrect response: \(response.statusCode)")
                    }
                } else {
                    result = .incorrect_response
                    logError("Not URL response type: \(response.simpleDescription)")
                }

                guard result == .ok else {
                    self.callback?.onReceiveRecommendations(products: nil, result: result, error: nil)
                    return
                }

                guard let data = data else {
                    self.callback?.onReceiveRecommendations(products: nil, result: .no_data_received, error: nil)
                    return
                }
                // parse JSON

                let dataResult = self.processResult(data: data)

                self.callback?.onReceiveRecommendations(products: dataResult.data, result: dataResult.result, error: dataResult.error)
            }

        }
        task.resume()
    }

    // returns array of recommendation or result == incorrect_response and nil in case of fail
    private func processResult(data: Data) -> (data: [RecommendationProduct]?, result: RecommendationQueryResult, error: NSError?) {
        var resultData: [RecommendationProduct] = []
        var resultStatus: RecommendationQueryResult = .ok
        var error: NSError? = nil

        do {

            let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)

            guard let items = json as? [[String: AnyObject]] else {
                logError("Recommendations: JSON root element incorrect")
                return (nil, .incorrect_response, nil)
            }

            for item in items {
                guard let recos = item["reco"] as? [[String: AnyObject]] else {
                    logError("Recommendations: JSON reco element incorrect or missed")
                    break
                }
                var recommendationsValues: RecommendationValuesMap = [:]
                var titleOpt: String? = nil
                var idOpt: String? = nil

                for reco in recos {
                    guard let value = reco["value"] as? String, let identifier = reco["identifier"] as? String,
                        let type = reco["type"] as? String else {
                            logError("Recommendations: incorrect reco item: \(reco)")
                            continue
                    }
                    switch identifier {
                    case "id":
                        idOpt = value
                    case "campaignTitle":
                        titleOpt = value
                    default:
                        recommendationsValues[identifier] = RecommendationProductValue(type: type, value: value)
                    }
                }

                guard let id = idOpt else {
                   logError("Recommendations: not id found for reco")
                   continue
                }

                let title = titleOpt ?? ""
                resultData.append(RecomendationProductImpl(id: id, title: title, values: recommendationsValues))
            }

        } catch let catchedError as NSError {

            resultStatus = .incorrect_response
            error = catchedError
        }

        return (resultData, resultStatus, error)
    }

    private func constructURL() -> URL? {
        let keys = ["userId", "product"]
        let values = [try! DefaultTracker.generateEverId(), self.productId]

        guard var url = URLComponents(url: recommendationURL, resolvingAgainstBaseURL: true) else {
            logError("Can't construct URL for recommendation")
            return nil
        }
        var queryItems = [URLQueryItem]()

        for i in 0..<2 {
            if let value = values[i] {
                queryItems.append(URLQueryItem(name: keys[i], value: value))
            }
        }

        url.applyQueryItemsWithAlternativeURLEncoding(queryItems)

        return url.url
    }

}

class RecomendationProductImpl: RecommendationProduct {

    let id: String
    let title: String
    let values: RecommendationValuesMap

    subscript(index: String) -> RecommendationProductValue? {
        return values[index]
    }

    init(id: String, title: String, values: RecommendationValuesMap) {
        self.id = id
        self.title = title
        self.values = values
    }
}
