import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - プロパティ
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral?
    var rxCharacteristic: CBCharacteristic?
    
    // MARK: - IBOutlet
    @IBOutlet weak var SSIDUILabel: UILabel!
    
    // MARK: - ライフサイクル
    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - CBCentralManagerDelegate メソッド
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            scanBLEModule()
        case .poweredOff:
            SSIDUILabel.text = "Bluetoothがオフです"
            print("Bluetooth is Off")
        default:
            SSIDUILabel.text = "Bluetooth使用不能"
            print("Bluetooth state is not supported: \(central.state.rawValue)")
        }
    }
    
    func scanBLEModule() {
        let serviceUUID = CBUUID(string: "DFB0")
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        SSIDUILabel.text = "スキャン中..."
        print("Scanning for BLE devices...")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("Discovered device: \(peripheral.name ?? "Unknown")")
        
        if connectedPeripheral == nil {
            connectedPeripheral = peripheral
            connectedPeripheral?.delegate = self
            centralManager.connect(peripheral, options: nil)
            centralManager.stopScan()
            SSIDUILabel.text = "接続中: \(peripheral.name ?? "Unknown Device")"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown Device")")
        SSIDUILabel.text = "接続済み: \(peripheral.name ?? "Unknown Device")"
        peripheral.discoverServices([CBUUID(string: "DFB0")])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print("Disconnected with error: \(error.localizedDescription)")
        } else {
            print("Disconnected from \(peripheral.name ?? "Unknown Device")")
        }
        SSIDUILabel.text = "切断されました"
        connectedPeripheral = nil
    }
    
    // MARK: - CBPeripheralDelegate メソッド
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Service discovery failed: \(error.localizedDescription)")
            return
        }
        
        if let services = peripheral.services {
            for service in services {
                if service.uuid == CBUUID(string: "DFB0") {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Characteristic discovery failed: \(error.localizedDescription)")
            return
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == CBUUID(string: "DFB1") {
                    rxCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("RX Characteristic discovered and notifications enabled: \(characteristic)")
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Failed to enable notifications: \(error.localizedDescription)")
            return
        }

        if characteristic.isNotifying {
            print("Notifications enabled for characteristic: \(characteristic)")
        } else {
            print("Notifications disabled for characteristic: \(characteristic)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Failed to receive data: \(error.localizedDescription)")
            return
        }
        
        if let data = characteristic.value {
            print("Data received: \(data as NSData)")
            processData(data)
        } else {
            print("No data received.")
        }
    }
    
    func processData(_ data: Data) {
        if data.count == 2 {
            let receivedValue = data.withUnsafeBytes { $0.load(as: UInt16.self) }
            print("Received 2-byte UInt16 value: \(receivedValue)")
            
            DispatchQueue.main.async {
                self.SSIDUILabel.text = "受信データ: \(receivedValue)"
            }
        } else {
            print("Invalid data size: \(data.count) bytes. Expected 2 bytes.")
            DispatchQueue.main.async {
                self.SSIDUILabel.text = "エラー: 不正なデータサイズ (\(data.count))"
            }
        }
    }
    
    // MARK: - デバイスへのデータ送信
    func sendCommand(value: Int) {
        guard let peripheral = connectedPeripheral,
              let characteristic = rxCharacteristic else {
            print("No connected device or RX characteristic.")
            return
        }
        
        var val = value
        let data = Data(bytes: &val, count: MemoryLayout<Int>.size)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("Sent Int value: \(value)")
    }
    
    // MARK: - IBAction
    @IBAction func sendButtonTapped(_ sender: UIButton) {
        sendCommand(value: 1)
    }
}
