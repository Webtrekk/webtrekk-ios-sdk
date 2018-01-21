Webtrekk Tracking Library
==========================

[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Webtrekk.svg?style=flat-square)](https://cocoapods.org/pods/Webtrekk) ![Carthage](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat) ![Platform support](https://img.shields.io/badge/platform-ios%20%7C%20tvos%20%7C%20watchos-lightgrey.svg?style=flat-square)

The Webtrekk SDK allows you to track user activities, screen flow and media usage for an App. All data is send to the Webtrekk tracking system for further analysis.

Requirements
============

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

tvOS support starting with version 4.2.0 with the following limitation:
No screen resolution and network status automatic tracing support.

watchOS support starting with version 4.3.0 with the following limiations:
1. No screen resolution and network status automatic trackinging support.
2. No deep link and campaign support.

Carthage support starting from version 4.6.0


Installation
============

[CocoaPods](htttp://cocoapods.org) (*Podfile*):

`pod 'Webtrekk'`

[Carthage](https://github.com/Carthage/Carthage) (*Cartfile*):

`github "Webtrekk/webtrekk-ios-sdk"`

SwiftLint
=========

We use Swiftlint from [Realm](https://realm.io/) to lint our code. SwiftLint has to be installed on your device. 
More info can be found on [SwiftLint](https://github.com/realm/SwiftLint). Details about the specific settings for this project can be found in the `.swiftlint.yml` file.


Migrating from Webtrekk SDK V3
==============================

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

SSL
===

As of iOS 9 Apple is more strictly enforcing the usage of SSL for network connections. Webtrekk highly recommends and offers the usage of a valid serverUrl with SSL support. In case there is a need to circumvent this. The App will need an exception entry within the `Info.plist`. Apple's regulations about this are well documented within the [iOS Developer Library](https://developer.apple.com/library/ios/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW33)

Examples & Unit Tests
=====================

The `Xcode` directory contains all files necessary to

-	manually build the library
-	run unit test
-	run examples

```shell
# install CocoaPods 1.2.0 or newer (unless you already did)
sudo gem install cocoapods

# clone this repository
https://github.com/Webtrekk/webtrekk-ios-sdk.git

# examples & tests are located in the directory 'Xcode' …
cd Xcode

# … and are set up with CocoaPods
pod install

# 'Examples.xcworkspace' is the file you'll use from now on
open Examples.xcworkspace
```

License
=======

See the [LICENSE](LICENSE.md) file for license rights and limitations (MIT).

