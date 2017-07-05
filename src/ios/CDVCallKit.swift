/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

@available(iOS 9.0, *)
@objc(CDVCallKit) class CDVCallKit : CDVPlugin {
    var callbackId: String?
    private var _callManager: AnyObject?
    private var _providerDelegate: AnyObject?

    @available(iOS 10.0, *)
    var callManager: CDVCallManager? {
        get {
            return _callManager as? CDVCallManager
        }
        set {
            _callManager = newValue
        }
    }

    @available(iOS 10.0, *)
    var providerDelegate: CDVProviderDelegate? {
        get {
            return _providerDelegate as? CDVProviderDelegate
        }
        set {
            _providerDelegate = newValue
        }
    }

    @available(iOS 10.0, *)
    func register(_ command:CDVInvokedUrlCommand) {
        self.commandDelegate.run(inBackground: {
            var pluginResult = CDVPluginResult(
                status : CDVCommandStatus_ERROR
            )

            self.callManager = CDVCallManager()

            self.providerDelegate = CDVProviderDelegate(callManager: self.callManager!)

            self.callbackId = command.callbackId

            NotificationCenter.default.addObserver(self, selector: #selector(self.handle(withNotification:)), name: Notification.Name("CDVCallKitCallsChangedNotification"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.handle(withNotification:)), name: Notification.Name("CDVCallKitAudioNotification"), object: nil)

            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_OK
            )
            pluginResult?.setKeepCallbackAs(true)

            self.commandDelegate!.send(
                pluginResult,
                callbackId: command.callbackId
            )
        });
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func reportIncomingCall(_ command:CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status : CDVCommandStatus_ERROR
        )

        let uuid = UUID()
        let name = command.arguments[0] as? String ?? ""
        let hasVideo = command.arguments[1] as? Bool ?? false
        let supportsGroup = command.arguments[2] as? Bool ?? false
        let supportsUngroup = command.arguments[3] as? Bool ?? false
        let supportsDTMF = command.arguments[4] as? Bool ?? false
        let supportsHold = command.arguments[5] as? Bool ?? false

        if #available(iOS 10.0, *) {
            // when CallKit is available
            providerDelegate?.reportIncomingCall(uuid,handle: name,hasVideo: hasVideo,supportsGroup: supportsGroup, supportsUngroup: supportsUngroup,supportsDTMF: supportsDTMF, supportsHold: supportsHold)
        } else {
            // iOS 9: if the application is in background, show a notification
            if (UIApplication.shared.applicationState == UIApplicationState.background) {
                let localNotification = UILocalNotification()
                localNotification.fireDate = NSDate(timeIntervalSinceNow: 1) as Date
                localNotification.alertTitle = name
                localNotification.alertBody = "따르르릉! 전화가 오고 있습니다!" // TODO: i18n
                localNotification.soundName = "default"
                UIApplication.shared.scheduleLocalNotification(localNotification)
            }
        }

        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs : uuid.uuidString
        )
        pluginResult?.setKeepCallbackAs(false)

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    func askNotificationPermission(_ command:CDVInvokedUrlCommand) {
        UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [.alert], categories: nil))
    }

    @available(iOS 10.0, *)
    func startCall(_ command:CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status : CDVCommandStatus_ERROR
        )

        let name = command.arguments[0] as? String ?? ""
        let isVideo = (command.arguments[1] as! Bool)

        let uuid = UUID()
        self.callManager?.startCall(uuid, handle: name, video: isVideo)

        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs : uuid.uuidString
        )
        pluginResult?.setKeepCallbackAs(false)

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    func finishRing(_ command:CDVInvokedUrlCommand) {
        let pluginResult = CDVPluginResult(
            status : CDVCommandStatus_OK
        )

        pluginResult?.setKeepCallbackAs(false)
        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
        /* does nothing on iOS */
    }

    @available(iOS 10.0, *)
    func endCall(_ command:CDVInvokedUrlCommand) {
        self.commandDelegate.run(inBackground: {
            let uuid = UUID(uuidString: command.arguments[0] as? String ?? "")
            let notify = command.arguments[1] as? Bool ?? false

            if (uuid != nil) {
                let call = self.callManager?.callWithUUID(uuid!)

                if (notify) {
                    let localNotification = UILocalNotification()
                    localNotification.alertTitle = call!.handle
                    localNotification.alertBody = "부재중 전화" // TODO: i18n
                    UIApplication.shared.scheduleLocalNotification(localNotification)
                }

                if (call != nil) {
                    self.callManager?.end(call!)
                }
            }
        });
    }

    @available(iOS 10.0, *)
    func callConnected(_ command:CDVInvokedUrlCommand) {
        self.commandDelegate.run(inBackground: {
            let uuid = UUID(uuidString: command.arguments[0] as? String ?? "")

            if (uuid != nil) {
                let call = self.callManager?.callWithUUID(uuid!)

                if (call != nil) {
                    call?.connectedCDVCall()
                }
            }
        });
    }

    @available(iOS 10.0, *)
    @objc func handle(withNotification notification : NSNotification) {
        if (notification.name == Notification.Name("CDVCallKitCallsChangedNotification")) {
            let notificationObject = notification.object as? CDVCallManager
            var resultMessage = [String: Any]()

            if (((notificationObject?.calls) != nil) && (notificationObject!.calls.count>0)) {
                let call = (notificationObject?.calls[0])! as CDVCall

                resultMessage = [
                    "callbackType" : "callChanged",
                    "uuid" : call.uuid.uuidString as String? ?? "",
                    "handle" : call.handle as String? ?? "",
                    "isOutgoing" : call.isOutgoing as Bool,
                    "isOnHold" : call.isOnHold as Bool,
                    "hasConnected" : call.hasConnected as Bool,
                    "hasEnded" : call.hasEnded as Bool,
                    "hasStartedConnecting" : call.hasStartedConnecting as Bool,
                    "endDate" : call.endDate?.string("yyyy-MM-dd'T'HH:mm:ssZ") as String? ?? "",
                    "connectDate" : call.connectDate?.string("yyyy-MM-dd'T'HH:mm:ssZ") as String? ?? "",
                    "connectingDate" : call.connectingDate?.string("yyyy-MM-dd'T'HH:mm:ssZ") as String? ?? "",
                    "duration" : call.duration as Double
                ]
            }
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: resultMessage)
            pluginResult?.setKeepCallbackAs(true)

            print("RECEIVED CALL CHANGED NOTIFICATION: \(notification)")

            self.commandDelegate!.send(
                pluginResult, callbackId: self.callbackId
            )
        } else if (notification.name == Notification.Name("CDVCallKitAudioNotification")) {
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: [ "callbackType" : "audioSystem", "message" : notification.object as? String ?? "" ])
            pluginResult?.setKeepCallbackAs(true)

            self.commandDelegate!.send(
                pluginResult, callbackId: self.callbackId
            )

            print("RECEIVED AUDIO NOTIFICATION: \(notification)")
        } else {
            print("INVALID NOTIFICATION RECEIVED: \(notification)")
        }
    }
}
