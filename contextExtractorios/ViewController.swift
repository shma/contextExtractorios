//
//  ViewController.swift
//  contextExtractorios
//
//  Created by Shunya Matsuno on 2016/08/03.
//  Copyright © 2016年 Shunya Matsuno. All rights reserved.
//

import UIKit
import CoreBluetooth
import AVFoundation
import SystemConfiguration
import CoreMotion
import CoreLocation

class ViewController: UIViewController, MEMELibDelegate, CBCentralManagerDelegate, CBPeripheralDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var timeLabel: UILabel!
    
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var memeLabel: UILabel!
    @IBOutlet weak var tempLabel: UILabel!
    @IBOutlet weak var heartLabel: UILabel!
    
    var isScanning = false
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    var peripheral1: CBPeripheral!
    
    var locationManager: CLLocationManager!
    
    var rate: Int8!
    var beforeRate: Int8!
    
    var rates: [Int8] = []
    var average_rates: [Int] = [0,0,0,0,0,0,0,0,0,0]
    
    let session: NSURLSession = NSURLSession.sharedSession()
    
    // ファイル管理系
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
    let rateFile = "rate.json"
    let rriFile = "rri.json"
    let placeFile = "place.json"
    let taionFile = "taion.json"
    let memeFile = "meme.json"
    
    let formatter = NSDateFormatter()
    let formatterDate = NSDateFormatter()
    
    var currentTime : String!
    var currentDate : String!
    
    var beforeMemeTime : String = "meme";
    
    var latitude : String!
    var longitude : String!
    
    // 加速度
    let manager = CMMotionManager()
    
    // カメラ系
    var shatterInterval = 0;
    
    // 音声
    var audioRecorder: AVAudioRecorder?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        MEMELib.sharedInstance().delegate = self
        
        rate = 0
        beforeRate = 0
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager = CLLocationManager()
            locationManager.delegate = self
            locationManager.startUpdatingLocation()
            locationManager.allowsBackgroundLocationUpdates = true
        }
        formatter.dateFormat = "HH:mm:ss"
        formatterDate.dateFormat = "yyyyMMdd"
        
        // セントラルマネージャ初期化
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // =========================================================================
    // MARK:MEMELibDelegate
    // JINS MEME
    
    func memeAppAuthorized(status: MEMEStatus) {
        MEMELib.sharedInstance().startScanningPeripherals()
    }
    
    func memePeripheralFound(peripheral: CBPeripheral!, withDeviceAddress address: String!) {
        MEMELib.sharedInstance().connectPeripheral(peripheral)
    }
    
    func memePeripheralConnected(peripheral: CBPeripheral!) {
        let status = MEMELib.sharedInstance().startDataReport()
        print(status)
    }
    
    func memeRealTimeModeDataReceived(data: MEMERealTimeData!) {
        let now = NSDate()
        let memeDate = formatterDate.stringFromDate(now)
        let memeTime = formatter.stringFromDate(now)
        
        memeLabel.text = "\(data.blinkStrength)"
        let memeOutput = NSOutputStream(toFileAtPath: documentsPath + "/" + memeDate + "_" + memeFile, append: true)
        memeOutput?.open()
        let text = "[\"\(memeTime)\", \(data.accZ),\(data.accY),\(data.accX),\(data.yaw),\(data.pitch),\(data.roll),\(data.blinkStrength),\(data.blinkSpeed),\(data.eyeMoveRight),\(data.eyeMoveLeft),\(data.eyeMoveDown),\(data.eyeMoveUp),\(data.powerLeft),\(data.isWalking),\(data.fitError)],\r\n "
        let cstring = text.cStringUsingEncoding(NSUTF8StringEncoding)
        let bytes = UnsafePointer<UInt8>(cstring!)
        let size = text.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        memeOutput?.write(bytes, maxLength: size)
        memeOutput?.close()
            
    }
    
    // セントラルマネージャの状態が変化すると呼ばれる
    func centralManagerDidUpdateState(central: CBCentralManager) {
        
        print("state: \(central.state)")
    }
    
    // ペリフェラルを発見すると呼ばれる
    func centralManager(central: CBCentralManager,
                        didDiscoverPeripheral peripheral: CBPeripheral,
                                              advertisementData: [String : AnyObject],
                                              RSSI: NSNumber)
    {
        print("発見したBLEデバイス: \(peripheral)")
        
        if peripheral.name == "Polar H7 B6B3C416" {
            self.peripheral = peripheral
            
            // 接続開始
            self.centralManager.connectPeripheral(self.peripheral, options: nil)
        }
        
        if peripheral.name == "BLESerial2" {
            self.peripheral1 = peripheral
            
            // 接続開始
            self.centralManager.connectPeripheral(self.peripheral1, options: nil)
        }
        
    }
    
    // ペリフェラルへの接続が成功すると呼ばれる
    func centralManager(central: CBCentralManager,
                        didConnectPeripheral peripheral: CBPeripheral)
    {
        print("接続成功！")
        
        // サービス探索結果を受け取るためにデリゲートをセット
        peripheral.delegate = self
        
        // サービス探索開始
        peripheral.discoverServices(nil)
        
        // self.centralManager.stopScan()
    }
    
    // ペリフェラルへの接続が失敗すると呼ばれる
    func centralManager(central: CBCentralManager,
                        didFailToConnectPeripheral peripheral: CBPeripheral,
                                                   error: NSError?)
    {
        print("接続失敗・・・")
    }
    
    // =========================================================================
    // MARK:CBPeripheralDelegate
    // サービス発見時に呼ばれる
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
        if (error != nil) {
            print("エラー: \(error)")
            return
        }
        
        if !(peripheral.services?.count > 0) {
            print("no services")
            return
        }
        
        let services = peripheral.services!
        
        print("\(services.count) 個のサービスを発見！ \(services)")
        
        for service in services {
            print(service.UUID);
            // キャラクタリスティック探索開始
            peripheral.discoverCharacteristics(nil, forService: service)
        }
    }
    
    // キャラクタリスティック発見時に呼ばれる
    func peripheral(peripheral: CBPeripheral,
                    didDiscoverCharacteristicsForService service: CBService,
                                                         error: NSError?)
    {
        if (error != nil) {
            print("エラー: \(error)")
            return
        }
        
        if !(service.characteristics?.count > 0) {
            print("no characteristics")
            return
        }
        
        let characteristics = service.characteristics!
        
        for characteristic in characteristics {
            print("Cha UUID : \(characteristic.UUID)")
            
            peripheral.readValueForCharacteristic(characteristic)
            
            if characteristic.UUID.isEqual(CBUUID(string: "2A37")) {
                // 更新通知受け取りを開始する
                peripheral.setNotifyValue(
                    true,
                    forCharacteristic: characteristic)
            }
            
            if characteristic.UUID.isEqual(CBUUID(string: "2A750D7D-BD9A-928F-B744-7D5A70CEF1F9")) {
                // 更新通知受け取りを開始する
                peripheral.setNotifyValue(
                    true,
                    forCharacteristic: characteristic)
            }
        }
    }
    
    // Notify開始／停止時に呼ばれる
    func peripheral(peripheral: CBPeripheral,
                    didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic,
                                                                error: NSError?)
    {
        if error != nil {
            print("Notify状態更新失敗...error: \(error)")
        }
        else {
            print("Notify状態更新成功！characteristic UUID:\(characteristic.UUID), isNotifying: \(characteristic.isNotifying)")
            
            //var byte: CUnsignedChar = 0
            // 1バイト取り出す
            var aBuffer = Array<Int8>(count: 16, repeatedValue: 0)
            // aBufferにバイナリデータを格納。
            characteristic.value?.getBytes(&aBuffer, length: 16)
            for aChar in aBuffer {
                print("\(aChar)") // 各文字のutf-8の文字コードが出力される。
            }
        }
    }
    
    // データ更新時に呼ばれる
    func peripheral(peripheral: CBPeripheral,
                    didUpdateValueForCharacteristic characteristic: CBCharacteristic,
                                                    error: NSError?)
    {
        if error != nil {
            print("データ更新通知エラー: \(error)")
            return
        }
        
        let now = NSDate()
        currentDate = formatterDate.stringFromDate(now)
        currentTime = formatter.stringFromDate(now)
        
        if (characteristic.UUID.isEqual(CBUUID(string: "2A750D7D-BD9A-928F-B744-7D5A70CEF1F9"))) {
            var aBuffer = Array<Int8>(count: 8, repeatedValue: 0)
            characteristic.value?.getBytes(&aBuffer, length: 8)
            let a = NSString(bytes: aBuffer, length: aBuffer.count, encoding: NSUTF8StringEncoding)!
            let num: Double = a.doubleValue
            
            tempLabel.text = "\(num)"
            
            let taionOutput = NSOutputStream(toFileAtPath: documentsPath + "/" + currentDate + "_" + taionFile, append: true)
            taionOutput?.open()
            let text = "[\"\(currentTime)\", \(num)],\r\n "
            let cstring = text.cStringUsingEncoding(NSUTF8StringEncoding)
            let bytes = UnsafePointer<UInt8>(cstring!)
            let size = text.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
            taionOutput?.write(bytes, maxLength: size)
            taionOutput?.close()
        }
        
        if (characteristic.UUID.isEqual(CBUUID(string: "2A37"))) {
            
            //print("データ更新！ characteristic UUID: \(characteristic.UUID), value: \(characteristic.value)")
            var aBuffer = Array<Int8>(count: 8, repeatedValue: 0)
            
            // aBufferにバイナリデータを格納。
            characteristic.value?.getBytes(&aBuffer, length: 8)
            
            rate = abs(aBuffer[1])
            
            timeLabel.text = currentTime
            heartLabel.text = "\(rate)";
            
            // ログ出力用の処理へ
            let rateOutput = NSOutputStream(toFileAtPath: documentsPath + "/" + currentDate + "_" + rateFile, append: true)
            rateOutput?.open()
            let text = "[\"\(currentTime)\", \(rate)],\r\n "
            var cstring = text.cStringUsingEncoding(NSUTF8StringEncoding)
            var bytes = UnsafePointer<UInt8>(cstring!)
            var size = text.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
            rateOutput?.write(bytes, maxLength: size)
            rateOutput?.close()
            
            let rri1 : Int = abs(numericCast(aBuffer[2]))
            let rri2 : Int = abs(numericCast(aBuffer[3]))
            let rriBinary : String = (toBinary(rri2) + toBinary(rri1))
            
            let rriSec = Int(rriBinary, radix: 2) ?? 0
            
            if (rriSec > 0) {
                var rri : Float;
                rri = Float(rriSec) / 1024
                
                let rriOutput = NSOutputStream(toFileAtPath: documentsPath + "/" + currentDate + "_" + rriFile, append: true)
                let rriText = "[\"\(currentTime)\", \(rri) ],\r\n"
                
                rriOutput?.open()
                cstring = rriText.cStringUsingEncoding(NSUTF8StringEncoding)
                bytes = UnsafePointer<UInt8>(cstring!)
                size = rriText.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
                rriOutput?.write(bytes, maxLength: size)
                rriOutput?.close()
            }
        }
    }
    
    @IBAction func scanBtnTapped(sender: UIButton) {
        if !isScanning {
            
            isScanning = true
            
            self.centralManager.scanForPeripheralsWithServices(nil, options: nil)
            
            sender.setTitle("STOP SCAN", forState: UIControlState.Normal)
        }
        else {
            self.centralManager.stopScan()
            sender.setTitle("START SCAN", forState: UIControlState.Normal)
            isScanning = false
        }
    }

    func toBinary(value: Int) -> String {
        let str = String(value, radix:2)
        let size = 8
        let padd = String(count: (size - str.characters.count),
                          repeatedValue: Character("0"))
        return padd + str
    }
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status {
        case .NotDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .Restricted, .Denied:
            break
        case .Authorized, .AuthorizedWhenInUse:
            break
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateToLocation newLocation: CLLocation, fromLocation oldLocation: CLLocation) {
        latitude = "".stringByAppendingFormat("%.5f", newLocation.coordinate.latitude)
        longitude = "".stringByAppendingFormat("%.5f", newLocation.coordinate.longitude)
        
        print("".stringByAppendingFormat("%.5f", newLocation.coordinate.latitude))
        print("".stringByAppendingFormat("%.5f", newLocation.coordinate.longitude))
        
        locationLabel.text = "\(self.latitude), \(self.longitude)"
        
        let now = NSDate()
        let date = self.formatterDate.stringFromDate(now)
        let time = self.formatter.stringFromDate(now)
        let placeOutput = NSOutputStream(toFileAtPath: self.documentsPath + "/" + date + "_" + self.placeFile, append: true)
        placeOutput?.open()
        let text = "[\"\(time)\", \(self.latitude), \(self.longitude)],\r\n "
        let cstring = text.cStringUsingEncoding(NSUTF8StringEncoding)
        let bytes = UnsafePointer<UInt8>(cstring!)
        let size = text.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        placeOutput?.write(bytes, maxLength: size)
        placeOutput?.close()
    }
}

