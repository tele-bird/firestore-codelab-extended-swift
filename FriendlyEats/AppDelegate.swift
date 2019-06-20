//
//  Copyright (c) 2016 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    FirebaseApp.configure()
    DynamicLinks.performDiagnostics(completion: nil)

    // Globally set our navigation bar style
    let navigationStyles = UINavigationBar.appearance()
    navigationStyles.barTintColor =
      UIColor(red: 0x3d/0xff, green: 0x5a/0xff, blue: 0xfe/0xff, alpha: 1.0)
    navigationStyles.tintColor = UIColor(white: 0.8, alpha: 1.0)
    navigationStyles.titleTextAttributes = [ NSAttributedString.Key.foregroundColor: UIColor.white]
    return true
  }

    func handleIncomingDynamicLink (_ dynamicLink: DynamicLink) {
        guard let url = dynamicLink.url else {
            print("That's weird. My dynamic link object has no URL.")
            return
        }
        print("Your incoming link parameter is \(url.absoluteString)")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems else { return }
        for queryItem in queryItems {
            print("Parameter \(queryItem.name) has a value of \(queryItem.value ?? "")")
        }
        print("Dyanmic link match type is \(dynamicLink.matchType.rawValue)")
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let incomingURL = userActivity.webpageURL {
            print("Incoming URL is \(incomingURL)")
            let linkHandled = DynamicLinks.dynamicLinks().handleUniversalLink(incomingURL) { (dynamicLink, error) in
                guard error == nil else {
                    print("Found an error! \(error!.localizedDescription)")
                    return
                }
                if let dynamicLink = dynamicLink {
                    print(dynamicLink.url?.absoluteString)
                    self.handleIncomingDynamicLink(dynamicLink)
                }
            }
            if linkHandled {
                print("Link handled")
                return true
            } else {
                // Maybe do other things with incoming URLs?
                print("Link not handled")
                return false
            }
        }
        return false
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print("I have received a URL through a custom scheme! \(url.absoluteString)")
        if let dynamicLink = DynamicLinks.dynamicLinks().dynamicLink(fromCustomSchemeURL: url) {
            self.handleIncomingDynamicLink(dynamicLink)
            return true
        } else {
            // Maybe handle Google or Facebook sign-in here
            return false
        }
    }

}

