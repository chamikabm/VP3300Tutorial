//
//  ViewController.swift
//  VP3300_Tutorial
//
//  Created by IDTech on 7/13/16.
//  Copyright © 2016 IDTech. All rights reserved.
//

import UIKit
import CoreBluetooth

var deviceUUID:UUID? = nil;
var deviceAlreadyConnected:Bool = false;

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }
    
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}

extension String {
    func displayEntries() -> String{
        return self.replacingOccurrences(of: "AnyHashable(", with: "\n").replacingOccurrences(of: "):", with: ":")
    }
}


class ViewController: UIViewController, IDT_VP3300_Delegate, CBCentralManagerDelegate {
    
    var centralManager: CBCentralManager!
    
    @IBOutlet weak var connectionStatus: UILabel!
    @IBOutlet weak var lcdTextView: UITextView!
    @IBOutlet weak var logTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        centralManager = CBCentralManager(delegate: self, queue: .none, options: .none)
        IDT_VP3300.sharedController().delegate = self
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            IDT_VP3300.sharedController().device_enableBLEDeviceSearch(nil);
            break
        case .poweredOff:
            print("Bluetooth is Off.")
            showBluetoothEnableAlert ()
            break
        case .resetting:
            break
        case .unauthorized:
            break
        case .unsupported:
            break
        case .unknown:
            break
        }
    }
    
    func showBluetoothEnableAlert () {
        // create the alert
        let alert = UIAlertController(
            title: "Notice",
            message: "In order to work with Bluetooth Payment Device you need to enable bluetooth in the device",
            preferredStyle: UIAlertControllerStyle.alert)
        
        // add the actions (buttons)
        alert.addAction(UIAlertAction(title: "Enable Bluetooth", style: UIAlertActionStyle.default, handler: handleBluetoothEnableActoin))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        
        // show the alert
        present(alert, animated: true, completion: nil)
    }
    
    func handleBluetoothEnableActoin(action: UIAlertAction!) {
        switch action.style {
        case .default:
            print("default")
            openBluetooth()
            break
        case .cancel:
            print("cancel")
            break
        case .destructive:
            print("destructive")
            break
        }
    }
    
    func openBluetooth(){
        if let url = URL(string:UIApplicationOpenSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    let url = URL(string: "App-Prefs:root=Bluetooth") //for bluetooth setting
                    let app = UIApplication.shared
                    app.openURL(url!)
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setConnectionStatus(_ status: String, backgroundColor: UIColor) {
        connectionStatus.text = status;
        connectionStatus.backgroundColor = backgroundColor
    
    }
    
    func appendMessageToLog(_ message: String) {
        logTextView.text = "\n====================\n\(message)\(logTextView.text)"
        logTextView.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
    
    func displayReturnError(_ operation: String, rt: RETURN_CODE) {
        let message = "\(operation) ERROR: ID-\(rt.rawValue), Message: \(IDT_VP3300.sharedController().device_getResponseCodeString(Int32(rt.rawValue)))"
        
        appendMessageToLog(message)
    }
    
    func deviceMessage(_ message: String!) {
        print(message);
        if (message.contains("IDTECH-BTPay Mini") && !deviceAlreadyConnected) {
            deviceUUID = getUuidFromMessage(message)!;
            IDT_VP3300.sharedController().device_disableBLEDeviceSearch();
            if deviceUUID != nil {
                IDT_VP3300.sharedController().device_enableBLEDeviceSearch(deviceUUID);
                deviceAlreadyConnected = true
            }
        }
    }
    
    func getUuidFromMessage(_ message: String) -> UUID? {
        let matched = matches(for: "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}", in: message)
        if matched.count > 0 {
          return UUID.init(uuidString: matched[0])!;
        } else {
          return nil
        }
    }
    
    func matches(for regex: String, in text: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            return results.map {
                String(text[Range($0.range, in: text)!])
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    
    func deviceConnected() {
        setConnectionStatus("Connected", backgroundColor: UIColor.green)
        appendMessageToLog("VP3300 Connected\nFramework Version: \(IDT_Device.sdk_version())")
    }

    func deviceDisconnected() {
        setConnectionStatus("Disconnected", backgroundColor: UIColor.red)
    }
    
    func swipeMSRData(_ cardData: IDTMSRData!) {
        NSLog("--MSR event received, type: \(cardData.event), data: \(cardData.encTrack1)")
        switch cardData.event {
        case EVENT_MSR_CARD_DATA:
            switch cardData.captureEncodeType {
                case CAPTURE_ENCODE_TYPE_ISOABA:
                    appendMessageToLog("Encode Type: ISO/ABA")
                case CAPTURE_ENCODE_TYPE_AAMVA:
                    appendMessageToLog("Encode Type: AA/MVA")
                case CAPTURE_ENCODE_TYPE_Other:
                    appendMessageToLog("Encode Type: Other")
                case CAPTURE_ENCODE_TYPE_Raw:
                    appendMessageToLog("Encode Type: Raw")
                case CAPTURE_ENCODE_TYPE_JIS_I:
                    appendMessageToLog("Encode Type: CAPTURE_ENCODE_TYPE_JIS_I")
                case CAPTURE_ENCODE_TYPE_JIS_II:
                    appendMessageToLog("Encode Type: CAPTURE_ENCODE_TYPE_JIS_II")
                default:
                    appendMessageToLog("Encode Type: UNKWOWN")
            }
            
            switch cardData.captureEncryptType {
                case CAPTURE_ENCRYPT_TYPE_AES:
                    appendMessageToLog("Encrypt Type: AES")
                case CAPTURE_ENCRYPT_TYPE_TDES:
                    appendMessageToLog("Encrypt Type: TDES")
                case CAPTURE_ENCRYPT_TYPE_NO_ENCRYPTION:
                    appendMessageToLog("Encrypt Type: NONE")
                default:
                    appendMessageToLog("Encrypt Type: UNKNOWN")
            }
            
            appendMessageToLog("Full card data: \(cardData.cardData == nil ? "N/A" : cardData.cardData.hexEncodedString())")
            appendMessageToLog("Track 1: \(cardData.track1 == nil ? "N/A" : cardData.track1)")
            appendMessageToLog("Track 2: \(cardData.track2 == nil ? "N/A" : cardData.track2)")
            appendMessageToLog("Track 3: \(cardData.track3 == nil ? "N/A" : cardData.track3)")
            appendMessageToLog("Length Track 1: \(cardData.track1Length)")
            appendMessageToLog("Length Track 2: \(cardData.track2Length)")
            appendMessageToLog("Length Track 3: \(cardData.track3Length)")
            appendMessageToLog("Encoded Track 1: \(cardData.encTrack1 == nil ? "N/A" : cardData.encTrack1.hexEncodedString())")
            appendMessageToLog("Encoded Track 2: \(cardData.encTrack2 == nil ? "N/A" : cardData.encTrack2.hexEncodedString())")
            appendMessageToLog("Encoded Track 3: \(cardData.encTrack3 == nil ? "N/A" : cardData.encTrack3.hexEncodedString())")
            appendMessageToLog("Hash Track 1: \(cardData.hashTrack1 == nil ? "N/A" : cardData.hashTrack1.hexEncodedString())")
            appendMessageToLog("Hash Track 2: \(cardData.hashTrack2 == nil ? "N/A" : cardData.hashTrack2.hexEncodedString())")
            appendMessageToLog("Hash Track 3: \(cardData.hashTrack3 == nil ? "N/A" : cardData.hashTrack3.hexEncodedString())")
            appendMessageToLog("KSN: \(cardData.ksn == nil ? "N/A" : cardData.ksn.hexEncodedString())")
            appendMessageToLog("\nSessionID: \(cardData.sessionID == nil ? "N/A" : cardData.sessionID.hexEncodedString())")
            appendMessageToLog("\nReader Serial Number: \(cardData.rsn == nil ? "N/A" : cardData.rsn)")
            appendMessageToLog("\nRead Status: \(cardData.readStatus)")
            
            if cardData.unencryptedTags != nil {
                appendMessageToLog("Unencrypted Tags: \(cardData.unencryptedTags.description.displayEntries())")
            }
            
            if cardData.encryptedTags != nil {
                appendMessageToLog("Encrypted Tags: \(cardData.encryptedTags.description.displayEntries())")
            }
            
            if cardData.maskedTags != nil {
                appendMessageToLog("Masked Tags: \(cardData.maskedTags.description.displayEntries())")
            }
            
            NSLog("Track 1: \(cardData.track1 == nil ? "N/A" : cardData.track1)")
            NSLog("Track 2: \(cardData.track2 == nil ? "N/A" : cardData.track2)")
            NSLog("Track 3: \(cardData.track3 == nil ? "N/A" : cardData.track3)")
            NSLog("Encoded Track 1: \(cardData.encTrack1 == nil ? "N/A" : cardData.encTrack1.hexEncodedString())")
            NSLog("Encoded Track 2: \(cardData.encTrack2 == nil ? "N/A" : cardData.encTrack2.hexEncodedString())")
            NSLog("Encoded Track 3: \(cardData.encTrack3 == nil ? "N/A" : cardData.encTrack3.hexEncodedString())")
            NSLog("Hash Track 1: \(cardData.hashTrack1 == nil ? "N/A" : cardData.hashTrack1.hexEncodedString())")
            NSLog("Hash Track 2: \(cardData.hashTrack2 == nil ? "N/A" : cardData.hashTrack2.hexEncodedString())")
            NSLog("Hash Track 3: \(cardData.hashTrack3 == nil ? "N/A" : cardData.hashTrack3.hexEncodedString())")
            NSLog("SessionID: \(cardData.sessionID == nil ? "N/A" : cardData.sessionID.hexEncodedString())")
            NSLog("nReader Serial Number: \(cardData.rsn == nil ? "N/A" : cardData.rsn)")
            NSLog("Read Status: \(cardData.readStatus)")
            NSLog("KSN: \(cardData.ksn == nil ? "N/A" : cardData.ksn.hexEncodedString())")
            
        case EVENT_MSR_CANCEL_KEY:
            appendMessageToLog("(Event) MSR Cancel Key received: \(cardData.encTrack1)")
            
        case EVENT_MSR_BACKSPACE_KEY:
            appendMessageToLog("(Event) MSR Backspack Key received: \(cardData.encTrack1)")
            
        case EVENT_MSR_ENTER_KEY:
            appendMessageToLog("(Event) MSR Enter Key received: \(cardData.encTrack1)")
            
        case EVENT_MSR_UNKNOWN:
            appendMessageToLog("(Event) MSR unknown event, data: \(cardData.encTrack1)")
        case EVENT_MSR_TIMEOUT:
            appendMessageToLog("MSR Timeout")
            
        default:
            break
            
        }
    }
    

    
    func emvTransactionData(_ emvData: IDTEMVData!, errorCode error: Int32) {
        
        NSLog("EMV_RESULT_CODE_V2_response = \(error)")
        
        appendMessageToLog("EMV transaction data response: \(IDT_VP3300.sharedController().device_getResponseCodeString(error))\n")
        
        if emvData == nil {
            appendMessageToLog("EMV TRANSACTION ERROR. Refer to EMV_RESULT_CODE_V2_response = \(error)")
            return;
        }
        
        if emvData.resultCodeV2 != EMV_RESULT_CODE_V2_NO_RESPONSE {
            appendMessageToLog("EMV_RESULT_CODE_V2_RESPONSE: \(emvData.resultCodeV2.rawValue)")
        }
        
        if emvData.resultCodeV2 == EMV_RESULT_CODE_V2_GO_ONLINE {
            appendMessageToLog("ONLINE REQUEST")
        }
        
        if emvData.resultCodeV2 == EMV_RESULT_CODE_V2_START_TRANS_SUCCESS {
            appendMessageToLog("Start success: authentication required")
        }
        
        if emvData.resultCodeV2 == EMV_RESULT_CODE_V2_APPROVED || emvData.resultCodeV2 == EMV_RESULT_CODE_V2_APPROVED_OFFLINE {
            appendMessageToLog("APPROVED");
        }
        
        if emvData.resultCodeV2 == EMV_RESULT_CODE_V2_MSR_SUCCESS {
            appendMessageToLog("MSR Data Captured")
        }
        
        if emvData.cardType == 0 {
            appendMessageToLog("CONTACT")
        }
        
        if emvData.cardType == 1 {
            appendMessageToLog("CONTACTLESS")
        }
        
        if emvData.unencryptedTags != nil {
            appendMessageToLog("Unencrypted Tags: \(emvData.unencryptedTags.description.displayEntries())")
        }
        
        if emvData.encryptedTags != nil {
            appendMessageToLog("Encrypted Tags: \(emvData.encryptedTags.description.displayEntries())")
        }
        
        if emvData.maskedTags != nil {
            appendMessageToLog("Masked Tags: \(emvData.maskedTags.description.displayEntries())")
        }
        
        if emvData.hasAdvise {
            appendMessageToLog("Response has advise request")
        }
        
        if emvData.hasReversal {
            appendMessageToLog("Response has reversal request")
        }
    }
    
    func lcdDisplay(_ mode: Int32, lines: [AnyObject]!) {
        var str = ""
        
        if lines != nil {
            for s in lines {
                str += s as! String
                str += "\n"
            }
        }
        
        switch mode {
            case 0x10:
                lcdTextView.text = ""
            case 0x03:
                lcdTextView.text = str
            case 0x01, 0x02, 0x08:
                IDT_VP3300.sharedController().emv_callbackResponseLCD(mode, selection: 1)
            default:
                break
        }
    }

    @IBAction func getFirmware(_ sender: UIButton) {
        var result: NSString?
        let rt = IDT_VP3300.sharedController().device_getFirmwareVersion(&result)
        
        logTextView.text = ""

        if RETURN_CODE_DO_SUCCESS == rt {
            appendMessageToLog("Get firmware: \(result!)")
        } else {
            displayReturnError("Get firmware", rt: rt)
        }
    }

    @IBAction func startMSR_CTLS(_ sender: UIButton) {
        let rt = IDT_VP3300.sharedController().ctls_startTransaction()
        
        logTextView.text = ""
        
        if RETURN_CODE_DO_SUCCESS == rt {
            appendMessageToLog("Enabled MSR / CTLS")
        } else {
            displayReturnError("Start MSR / CTLS", rt: rt)
        }
    }
    
    @IBAction func startICCEMV(_ sender: UIButton) {
        let rt = IDT_VP3300.sharedController().emv_startTransaction(1.00, amtOther: 0, type: 0, timeout: 60, tags: nil, forceOnline: false, fallback: true)
        
        logTextView.text = ""
        
        if RETURN_CODE_DO_SUCCESS == rt {
            appendMessageToLog("Start Transaction Command Accepted")
        } else {
            displayReturnError("Start ICC EMV", rt: rt)
        }
    }
    
    @IBAction func completeICCEMV(_ sender: UIButton) {
        let rt = IDT_VP3300.sharedController().emv_completeOnlineEMVTransaction(true, hostResponseTags: IDTUtility.hex(toData: "8A023030"))
        
        logTextView.text = ""
        
        if RETURN_CODE_DO_SUCCESS == rt {
            appendMessageToLog("Complete Transaction Command Accepted")
        } else {
            displayReturnError("Complete ICC EMV", rt: rt)
        }
    }
    
    @IBAction func cancelTransaction(_ sender: UIButton) {
        let rt = IDT_VP3300.sharedController().ctls_cancelTransaction()
        
        logTextView.text = ""
        
        if RETURN_CODE_DO_SUCCESS == rt {
            appendMessageToLog("Canceled transaction")
        } else {
            displayReturnError("Cancel transaction", rt: rt)
        }
    }
}

