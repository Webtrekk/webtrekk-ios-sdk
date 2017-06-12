//The MIT License (MIT)
//
//Copyright (c) 2016 Webtrekk GmbH
//
//Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
//"Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish,
//distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject
//to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//  Created by arsen.vartbaronov on 17/08/16.
//

import UIKit
@testable import Webtrekk

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    static let isAfterCrashSettings: String = "isAfterCrashSettings"


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions:[UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        if ProcessInfo.processInfo.environment["XCInjectBundleInto"] == nil {
            if isAfterCrashStart() {
                NSLog("Start after crash. Initialize crash configuration.")
                initWithConfig(configName: "webtrekk_config_error_log_integration_test")
            } else {
                initWithConfig()
            }
        }
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                                          restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        
        print("Original Selector is called")
        
        
        // test if this is deep link
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let queryItems = components.queryItems{
            
            var everID: String? = nil
            var mediaCode: String? = nil
            let everIDName = "wt_everID", mediaCodeName = "wt_mediaCode"
            //loop for all parameters
            for queryItem in queryItems {
                let item = (queryItem.name, queryItem.value)
                switch item {
                case ("downloadTest", let value) where value == "true":
                    WebtrekkTracking.defaultLogger.logDebug("download test command is received")
                    DownloadManager.shared.start()
                case ("checkSession", let value) where value != nil:
                    WebtrekkTracking.defaultLogger.logDebug("started in checkSessionMode")
                    //setup session paramter to be checked by external script
                    WebtrekkTracking.instance()["sessionCheck"]=value
                case (everIDName, let value):
                    everID = value
                case (mediaCodeName, let value):
                    mediaCode = value
                default:
                    break;
                    
                }
             }
            
            if let id = everID, let code = mediaCode {
                WebtrekkTracking.defaultLogger.logDebug("\(everIDName)=\(id), \(mediaCodeName)=\(code)")
            } else {
                WebtrekkTracking.defaultLogger.logDebug("no deep link info")
            }
        }
        return true
    }
    
    func initWithConfig(configName name: String? = nil) {
        
        if let _ = WebtrekkTracking.tracker {
            releaseWebtrekkInstance()
        }
        
        do {
            WebtrekkTracking.defaultLogger.minimumLevel = .debug
            if let name = name {
                let configFileURL = Bundle.main.url(forResource: name, withExtension: "xml", subdirectory: "Configurations/")
                try WebtrekkTracking.initTrack(configFileURL)
            } else {
                try WebtrekkTracking.initTrack()
            }
        }catch let error as TrackerError {
        WebtrekkTracking.defaultLogger.logError("Error Webtrekk SDK initialization: \(error.message)")
        }catch {
        WebtrekkTracking.defaultLogger.logError("Unkown error during Webtrekk SDK initialization")
        }
    }

    private func releaseWebtrekkInstance(){
        weak var weakTracker = WebtrekkTracking.tracker
        WebtrekkTracking.tracker = nil
        
        while weakTracker != nil {
             RunLoop.current.run(mode: .defaultRunLoopMode, before: Date(timeIntervalSinceNow:2))
        }
    }
    
    private func isAfterCrashStart() -> Bool{
        if let value = UserDefaults.standard.object(forKey: AppDelegate.isAfterCrashSettings) as? Bool, value {
            UserDefaults.standard.removeObject(forKey: AppDelegate.isAfterCrashSettings)
            return true
        } else {
            return false
        }
    }
    
    func setAfterCrashMode(){
         UserDefaults.standard.set(true, forKey: AppDelegate.isAfterCrashSettings)
    }
}
