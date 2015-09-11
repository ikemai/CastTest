//
//  ViewController.swift
//  CastTest2
//
//  Created by Mai Ikeda on 2015/09/10.
//  Copyright © 2015年 mai_ikeda. All rights reserved.
//

import UIKit
import GesturePacker

//@objc(HGCViewController)
class ViewController: UIViewController, GCKMediaControlChannelDelegate {
    
    private var sendColor: UIColor?
    private var chromecastButton : UIButton!
    
    // Properties for googleCast
    private let cancelTitle = "Cancel"
    private let disconnectTitle = "Disconnect"
    private let receiverAppID = kGCKMediaDefaultReceiverApplicationID
    private var applicationMetadata: GCKApplicationMetadata?
    private var selectedDevice: GCKDevice?
    private var deviceManager: GCKDeviceManager?
    private var mediaInformation: GCKMediaInformation?
    private var mediaControlChannel: GCKMediaControlChannel?
    private var deviceScanner: GCKDeviceScanner?
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        chromecastButton = UIButton(type: .Custom)
        chromecastButton.addTarget(self, action: "didDownCastButton:", forControlEvents: .TouchDown)
        chromecastButton.frame = CGRectMake(0, 20, 39, 34)
        chromecastButton.setImage(nil, forState: .Normal)
        view.addSubview(chromecastButton)
        
        // Establish filter criteria.
        let filterCriteria = GCKFilterCriteria(forAvailableApplicationWithID: receiverAppID)
        // Initialize device scanner.
        let scanner = GCKDeviceScanner(filterCriteria:filterCriteria)
        scanner.addListener(self)
        scanner.startScan()
        deviceScanner = scanner
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func showError(error: NSError) {
        apeerAlert("Error", message: error.description)
    }
    
    func updateStatsFromDevice() {
        print("updateStatsFromDevice()")
    }
    
    private func apeerAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    
    //Cast video
    @IBAction func castVideo(sender:AnyObject) {
        print("Cast Video")}
}

//
// MARK: - GCKDeviceScannerListener
//
extension ViewController: GCKDeviceScannerListener {
    
    func deviceDidComeOnline(device: GCKDevice) {
        print("Device found: \(device.friendlyName)")
        updateButtonStates()
    }
    
    func deviceDidGoOffline(device: GCKDevice) {
        print("Device went away: \(device.friendlyName)")
        updateButtonStates()
    }
    
    func deviceDidChange(device: GCKDevice) {
        print("deviceDidChange()")
    }
}

//
// MARK: - Change chromecastButton status. And set button Actions
//
extension ViewController {
    
    @IBAction func didDownCastButton(sender:AnyObject) {
        if selectedDevice == nil {
            showDeviceList()
        } else {
            showSelectedDevice()
        }
    }
    
    private func updateButtonStates() {
        if (deviceScanner?.devices.count > 0) {
            showCastButton()
            if (deviceManager != nil && deviceManager?.connectionState == GCKConnectionState.Connected) {
                // Show the Cast button in the enabled state.
                chromecastButton?.tintColor = UIColor.blueColor()
            } else {
                // Show the Cast button in the disabled state.
                chromecastButton?.tintColor = UIColor.grayColor()
            }
        } else{
            hideCastButton()
        }
    }
    
    private func showCastButton() {
        let buttonImage = UIImage(named: "ic_cast_black_24dp.png")
        chromecastButton.setImage(buttonImage, forState: .Normal)
    }
    private func hideCastButton() {
        chromecastButton.setImage(nil, forState: .Normal)
    }
}

//
// MARK: UIActionSheetDelegate
//
extension ViewController: UIActionSheetDelegate {
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        print("actionSheet() buttonIndex = \(buttonIndex)")
        if (buttonIndex == actionSheet.cancelButtonIndex) { return }
        
        if (selectedDevice == nil) {
            if (buttonIndex < deviceScanner?.devices.count) {
                selectedDevice = deviceScanner?.devices[buttonIndex] as? GCKDevice
                print("Selected device: \(selectedDevice!.friendlyName)")
                connectToDevice()
            }
        } else if (actionSheet.buttonTitleAtIndex(buttonIndex) == disconnectTitle) {
            // Disconnect button.
            deviceManager?.leaveApplication()
            deviceManager?.disconnect()
            deviceDisconnected()
            updateButtonStates()
        }
    }
    
    private func showDeviceList() {
        let sheet : UIActionSheet = UIActionSheet(title: "Connect to Device", delegate: self, cancelButtonTitle: nil, destructiveButtonTitle: nil)
        
        if let devices = deviceScanner?.devices {
            for device in devices  {
                sheet.addButtonWithTitle(device.friendlyName)
            }
        }
        // Add the cancel button at the end so that indexes of the titles map to the array index.
        sheet.addButtonWithTitle(cancelTitle)
        sheet.cancelButtonIndex = sheet.numberOfButtons - 1
        sheet.showInView(self.view)
    }
    
    private func showSelectedDevice() {
        updateStatsFromDevice()
        let friendlyName = "Casting to \(selectedDevice!.friendlyName)"
        
        let sheet : UIActionSheet = UIActionSheet(title: friendlyName, delegate: self, cancelButtonTitle: nil, destructiveButtonTitle: nil)
        var buttonIndex = 0
        
        if let info = mediaInformation {
            sheet.addButtonWithTitle(info.metadata.objectForKey(kGCKMetadataKeyTitle) as? String)
            buttonIndex++
        }
        
        // Offer disconnect option.
        sheet.addButtonWithTitle(disconnectTitle)
        sheet.addButtonWithTitle(cancelTitle)
        sheet.destructiveButtonIndex = buttonIndex++
        sheet.cancelButtonIndex = buttonIndex
        
        sheet.showInView(view)
    }
}

//
// MARK: GCKDeviceManagerDelegate
//
extension ViewController: GCKDeviceManagerDelegate {
    
    func deviceManagerDidConnect(deviceManager: GCKDeviceManager!) {
        print("deviceManagerDidConnect()")

        updateButtonStates()
        deviceManager.launchApplication(receiverAppID)
    }
    
    func deviceManager(deviceManager: GCKDeviceManager,
        didConnectToCastApplication applicationMetadata: GCKApplicationMetadata,
        sessionID: String,
        launchedApplication: Bool) {
            print("Application has launched.")
            mediaControlChannel = GCKMediaControlChannel()
            mediaControlChannel?.delegate = self
            deviceManager.addChannel(mediaControlChannel)
            mediaControlChannel?.requestStatus()
            connectDeviceAndSendDate()
    }
    
    func deviceManager(deviceManager: GCKDeviceManager!, didFailToConnectToApplicationWithError error: NSError) {
        print("Received notification that device failed to connect to application.")
        setDisConnecteView(error)
    }
    
    func deviceManager(deviceManager: GCKDeviceManager!, didFailToConnectWithError error: NSError!) {
        print("Received notification that device failed to connect.")
        setDisConnecteView(error)
    }
    
    func deviceManager(deviceManager: GCKDeviceManager!, didDisconnectWithError error: NSError!) {
        print("Received notification that device disconnected.")
        setDisConnecteView(error)
    }
    
    func deviceManager(deviceManager: GCKDeviceManager!, didReceiveApplicationMetadata metadata: GCKApplicationMetadata!) {
        applicationMetadata = metadata
    }
    
    private func setDisConnecteView(error: NSError?) {
        if let error = error { showError(error) }
        deviceDisconnected()
        updateButtonStates()
    }
    
    private func connectToDevice() {
        if (selectedDevice == nil) { return }
        let identifier = NSBundle.mainBundle().infoDictionary?["CFBundleIdentifier"] as! String
        deviceManager = GCKDeviceManager(device: selectedDevice, clientPackageName: identifier)
        print("connectToDevice() deviceManager = \(deviceManager)")
        deviceManager?.delegate = self
        deviceManager?.connect()
    }
    
    private func deviceDisconnected() {
        print("deviceDisconnected()")
        selectedDevice = nil
        deviceManager = nil
    }
    
    private func connectDeviceAndSendDate() {
        // Show alert if not connected.
        if (deviceManager?.connectionState != GCKConnectionState.Connected) {
            apeerAlert("Not Connected", message: "Please connect to Cast device")
            return
        }
        
        // Define Media Metadata.
        let metadata = GCKMediaMetadata()
        metadata.setString("Big Buck Bunny (2008)", forKey: kGCKMetadataKeyTitle)
        metadata.setString("Cast test.", forKey: kGCKMetadataKeySubtitle)
        
        let url = NSURL(string:"https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg")
        metadata.addImage(GCKImage(URL: url, width: 480, height: 360))
        
        // Define Media Information.
        let mediaInformation = GCKMediaInformation(
            contentID:
            "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            streamType: GCKMediaStreamType.None,
            contentType: "video/mp4",
            metadata: metadata,
            streamDuration: 0,
            mediaTracks: [],
            textTrackStyle: nil,
            customData: nil
        )
        // Cast the media
        mediaControlChannel?.loadMedia(mediaInformation, autoplay: true)
    }
}