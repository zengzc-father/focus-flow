import UIKit
import Flutter

// 注意: 这是iOS的入口文件，实际功能在AppDelegate.swift中
// 此文件通常由Flutter自动生成

@main
@objc class AppMain: NSObject {
    static func main() {
        UIApplicationMain(
            CommandLine.argc,
            CommandLine.unsafeArgv,
            NSStringFromClass(UIApplication.self),
            NSStringFromClass(AppDelegate.self)
        )
    }
}
