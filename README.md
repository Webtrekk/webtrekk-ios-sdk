# Webtrekk Tracking Library

[![Build Status](https://travis-ci.org/Webtrekk/webtrekk-ios-sdk.svg?branch=master)](https://travis-ci.org/Webtrekk/webtrekk-ios-sdk)

[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Webtrekk.svg?style=flat-square)](https://cocoapods.org/pods/Webtrekk) ![Carthage](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat) ![Platform support](https://img.shields.io/badge/platform-ios%20%7C%20tvos%20%7C%20watchos-lightgrey.svg?style=flat-square)

The Webtrekk SDK allows you to track user activities, screen flow and media usage for an App. All data is send to the Webtrekk tracking system for further analysis.

# Requirements

| Plattform | Version            |
|-----------|-------------------:|
| `iOS`     |             `8.0+` |
| `tvOS`    |             `9.0+` |
| `watchOs` |             `2.0+` |

Xcode 7.3+ and Swift 2.2 for versions below and equal to 4.0.1

Xcode 8.0+ and Swift 3.0 starting with version 4.1.0

Xcode 8.3+ and Swift 3.1 starting with version 4.5.1

Starting with version 4.7.0 library can be included and compiled with XCode 9.0 beta6.

Xcode 9.0+ and Swift 4.0 starting with version 4.8.0

Xcode 9.3+ and Swift 4.1 starting with version 4.11.0

Xcode 10+ and Swift 4.2 starting with version 4.12.1 (Uses `Legacy Build System` )

Xcode 10.2+ and Swift 4.2 starting with version 4.13.2 (Uses `Legacy Build System` )

Xcode 10.2+ and Swift 5 starting with version 4.14.0 (Uses `New Build System`)

### Cocoapod Swift 4.2 trouble (< 4.14.0):
To resolve when you cannot lint with Cocoapods, use:

`pod spec lint --allow-warnings`

### Use the Legacy Build System for building (< 4.14.0):
- File
    - Project/Workspace Settings
      - Shared Workspace Settings
        - Build System -> `Legacy Build System`

There are a few warnings with the new API in Swift 4.2, all will still work. It's just warnings and we will work to make them disappear by the time a new Swift version is out.

tvOS support starting with version 4.2.0 with the following limitation:
No screen resolution and automatic network status tracking support.

watchOS support starting with version 4.3.0 with the following limiations:
1. No screen resolution and automatic network status tracking support.
2. No deep link and campaign support.

Carthage support starting from version 4.6.0


# Installation

[CocoaPods](htttps://www.cocoapods.org) (*Podfile*):

`pod 'Webtrekk'`

[Carthage](https://github.com/Carthage/Carthage) (*Cartfile*):

`github "Webtrekk/webtrekk-ios-sdk"`

## xcframework

Run the following (adjusted) commands in the command line.

1. Create the framework for devices' architectures:

```xcodebuild archive -scheme "Webtrekk-iOS" -destination="iOS" -archivePath "/tmp/webtrekk/wt-ios.xcarchive" -sdk "iphoneos" SKIP_INSTALL=NO```

2. Create the framework for the simulator's architectures:

```xcodebuild archive -scheme "Webtrekk-iOS" -destination="iOS Simulator" -archivePath "/tmp/webtrekk/wt-simulator.xcarchive" -sdk "iphonesimulator" SKIP_INSTALL=NO```

3. Combine both into a xcframework:

```xcodebuild -create-xcframework -framework /tmp/webtrekk/wt-simulator.xcarchive/Products/Library/Frameworks/Webtrekk.framework -framework /tmp/webtrekk/wt-ios.xcarchive/Products/Library/Frameworks/Webtrekk.framework -output Webtrekk.xcframework```

4. Copy the xcframework to a path of your choice and link (and copy) it in your iOS target.

# SwiftLint

We use Swiftlint from [Realm](https://realm.io/) to lint our code. SwiftLint has to be installed on your device. 
More info can be found on [SwiftLint](https://github.com/realm/SwiftLint). 
Details about the specific settings for this project can be found in the `.swiftlint.yml` file.

# Travis CI

We use [Travis CI](https://travis-ci.org/) to check the code for inconsistencies and running the linter & tests. 
Details about the specific settings for this project can be found in the `.travis.yml` file.


# Migrating from Webtrekk SDK V3

The Webtrekk SDK V4 offers the possibility to migrate some stored information to the new SDK. This option is enabled as per default but in case the old data should be neglected and deleted the value of the `migratesFromLibraryV3` variable needs to be set to `false` before creating the first tracker. The code snippet below shows this case.

```swift
WebtrekkTracking.migratesFromLibraryV3 = false
```

Following properties are part of the migration.

| Option           | Description                                                       |
|------------------|-------------------------------------------------------------------|
| `everId`         | previously generated everId for the user                          |
| `appVersion`     | previously stored appVersion used to detect app updates           |
| `optedOut`       | previously stored status which is only migrated if not set before |
| `samplingState`  | previously stored samplingState                                   |
| `unsentRequests` | previously saved unsent requests                                  |

# SSL

As of iOS 9 Apple is more strictly enforcing the usage of SSL for network connections. Webtrekk highly recommends and offers the usage of a valid serverUrl with SSL support. In case there is a need to circumvent this. The App will need an exception entry within the `Info.plist`. Apple's regulations about this are well documented within the [iOS Developer Library](https://developer.apple.com/library/ios/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW33)

# Example App with functionality

For an example app of the functionality in this SDK see: https://github.com/Webtrekk/iOS-SDK-Example-App

# License

See the [LICENSE](LICENSE.md) file for license rights and limitations (MIT).
