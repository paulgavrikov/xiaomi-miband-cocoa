/*
Copyright (c) 2014 Paul Gavrikov
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa
import CoreBluetooth

class ViewController: NSViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager:CBCentralManager!
    var discovered = false
    var connectingPeripheral: CBPeripheral!
    
    
    @IBOutlet weak var stepsView: NSTextField!
    @IBOutlet weak var spinnerView: NSProgressIndicator!
    @IBOutlet weak var batteryView: NSTextField!

    @IBAction func refreshButton(sender: AnyObject) {
                discoverDevices()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        spinnerView.startAnimation(nil)
        startUpCentralManager()
        
    }
    
    func startUpCentralManager() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func discoverDevices() {
        
        if(connectingPeripheral != nil) {
            centralManager.cancelPeripheralConnection(connectingPeripheral)
        }
        
        stepsView.stringValue = "Searching"
        batteryView.stringValue = ""
        spinnerView.hidden = false
        print("discovery", terminator: "")
        centralManager.scanForPeripheralsWithServices(nil, options: nil)
    }
  
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber)
    {
        
        //println("Discovered: " + peripheral.name)
        if(peripheral.name == "MI") {
            stepsView.stringValue = "Connecting to MI"
            self.connectingPeripheral = peripheral
            centralManager.stopScan()
            self.centralManager.connectPeripheral(peripheral, options: nil)
        } else {
            print("skipped " + peripheral.name!, terminator: "" )
        }
        
    }
    
    func centralManagerDidUpdateState(central: CBCentralManager) { //BLE status
        var msg = ""
        switch (central.state) {
        case .PoweredOff:
            msg = "CoreBluetooth BLE hardware is powered off"
            print("\(msg)", terminator: "")
            stepsView.stringValue = "Please turn on Bluetooth and retry"
            
        case .PoweredOn:
            msg = "CoreBluetooth BLE hardware is powered on and ready"
            if(!discovered) {
                discovered = true
                discoverDevices()
            }
            
        case .Resetting:
            msg = "CoreBluetooth BLE hardware is resetting"
            
        case .Unauthorized:
            msg = "CoreBluetooth BLE state is unauthorized"
            
        case .Unknown:
            msg = "CoreBluetooth BLE state is unknown"
            
        case .Unsupported:
            msg = "CoreBluetooth BLE hardware is unsupported on this platform"
            stepsView.stringValue = "Your Mac does not support BLE"
            
        }
        output("State", data: msg)
    }
    
    func centralManager(central: CBCentralManager,didConnectPeripheral peripheral: CBPeripheral)
    {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?)
    {
        print("peripherial services", terminator: "")
        if let servicePeripherals = peripheral.services as [CBService]!
        {
            for servicePeripheral in servicePeripherals
            {
                peripheral.discoverCharacteristics(nil, forService: servicePeripheral)
                
            }
            
        }
    }
    
    func refreshBLE() {
        centralManager.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
      
        if let charactericsArr = service.characteristics  as [CBCharacteristic]!
        {
            for cc in charactericsArr
            {
                peripheral.setNotifyValue(true, forCharacteristic: cc)
                
                if cc.UUID.UUIDString == "FF0F"{
                    output("Characteristic", data: cc)
                    let data: NSData = "2".dataUsingEncoding(NSUTF8StringEncoding)!
                    peripheral.writeValue(data, forCharacteristic: cc, type: CBCharacteristicWriteType.WithoutResponse)
                    output("Characteristic", data: cc)
                } else if cc.UUID.UUIDString == "FF06" {
                    print("READING STEPS")
                    peripheral.readValueForCharacteristic(cc)
                } else if cc.UUID.UUIDString == "FF0C" {
                    print("READING BATTERY")
                    peripheral.readValueForCharacteristic(cc)
                }
            }
            
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        output("Data for "+characteristic.UUID.UUIDString, data: characteristic.value!)
        
        if(characteristic.UUID.UUIDString == "FF06") {
            spinnerView.hidden = true
            let u16 = UnsafePointer<Int>(characteristic.value!.bytes).memory
            stepsView.stringValue = ("\(u16) steps")
        } else if(characteristic.UUID.UUIDString == "FF0C") {
            spinnerView.hidden = true
            var u16 = UnsafePointer<Int32>(characteristic.value!.bytes).memory
            u16 =  u16 & 0xff
            batteryView.stringValue = ("\(u16) % charged")
        }
        
        
    }
    
    func output(description: String, data: AnyObject){
        print("\(description): \(data)", terminator: "")
       // textField.text = textField.text + "\(description): \(data)\n"
    }
    
    
    

    override var representedObject: AnyObject? {
        didSet {
        }
    }
}

