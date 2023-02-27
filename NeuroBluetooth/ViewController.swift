import UIKit
import CoreBluetooth
import Firebase
import FirebaseFirestore

class ViewController: UIViewController, UITableViewDataSource {
    
    var dataArray: [String] = []
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray.count
    }
    
    func scrollToBottom(){
        DispatchQueue.main.async {
            let indexPath = IndexPath(row: self.dataArray.count-1, section: 0)
            self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            
        // Set the text label for the cell
        cell.textLabel?.text = dataArray[indexPath.row]
            
        return cell
    }
    
    var db: Firestore!
    var ref: CollectionReference!
    
    // MARK: - Properties
    
    @IBOutlet weak var tableView: UITableView!
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral?
    var transferCharacteristic: CBCharacteristic?
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var statusLabel: UILabel!
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        tableView.dataSource = self
        // Configure Firebase
        self.db = Firestore.firestore()
        self.ref = db.collection("neurodata")
    }

    // MARK: - IBActions
    
    @IBAction func startScanButtonTapped(_ sender: Any) {
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        dataArray.append("Scanning...")
        self.tableView.reloadData()
        scrollToBottom()

    }
    
    // MARK: - Private Methods
    
    private func connect(to peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        centralManager.connect(connectedPeripheral!, options: nil)
    }
    
    private func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
            dataArray.append("Disconnected")
            self.tableView.reloadData()
            scrollToBottom()

        }
    }
}

// MARK: - CBCentralManagerDelegate

extension ViewController: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            dataArray.append("Ready")
            self.tableView.reloadData()
        case .poweredOff:
            dataArray.append("Bluetooth is not available")
            self.tableView.reloadData()
        case .unsupported:
            dataArray.append("Bluetooth is not supported")
            self.tableView.reloadData()
        default:
            dataArray.append("Bluetooth is not available")
            self.tableView.reloadData()
        }
        scrollToBottom()

    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == "iPhone (2)" {
            connect(to: peripheral)
            dataArray.append("Discovered peripheral: \(peripheral.name ?? "Unknown")")
            tableView.reloadData()
            scrollToBottom()

        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral?.delegate = self
        connectedPeripheral?.discoverServices(nil)
        // Save a reference to the connected peripheral
        self.connectedPeripheral = peripheral

        // Set the peripheral's delegate to self
        connectedPeripheral?.delegate = self
        dataArray.append("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        tableView.reloadData()
        scrollToBottom()

    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        disconnect()
        dataArray.append("Disconnected from peripheral: \(peripheral.name ?? "Unknown")")
        tableView.reloadData()
        scrollToBottom()

    }
}


// MARK: - CBPeripheralDelegate

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics for service: \(service.uuid.uuidString), error: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in characteristics {
            if characteristic.uuid == CBUUID(string: "2EA5E5C0-47D9-4EA9-8E58-2C2E09ACF6F0") {
                transferCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: transferCharacteristic!)
                dataArray.append("Subscribed to characteristic")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            // Convert the data to a string
            let dataString = String(data: data, encoding: .utf8)
            
            dataArray.append((dataString ?? "") + " Received")
            self.tableView.reloadData()
            scrollToBottom()
            
            // Update the Firestore with the received data
                    let value = dataString ?? "nil"
            let timestamp = Timestamp()
            let documentData: [String: Any] = ["value": value, "timestamp": timestamp]

            self.ref.addDocument(data: documentData)
        }
    }
}
