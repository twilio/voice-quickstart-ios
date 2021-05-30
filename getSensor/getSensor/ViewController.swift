//
//  ViewController.swift
//  getSensor
//
//  Created by 湯浅健太 on 2021/05/29.
//

import UIKit
import CoreMotion

class ViewController: UIViewController {

    //motion manager
    let motionManager = CMMotionManager()
    var sensorList:[Double] = []
    
    //@IBOutlet weak var attitudeX: UILabel!
    //@IBOutlet weak var attitudeY: UILabel!
    //@IBOutlet weak var attitudeZ: UILabel!
    //@IBOutlet var accelerometerX: UILabel!
    //@IBOutlet var accelerometerY: UILabel!
    //@IBOutlet var accelerometerZ: UILabel!
    @IBOutlet weak var gravityX: UILabel!
    @IBOutlet weak var gravityY: UILabel!
    @IBOutlet weak var gravityZ: UILabel!
    @IBOutlet weak var gyroX: UILabel!
    @IBOutlet weak var gyroY: UILabel!
    @IBOutlet weak var gyroZ: UILabel!
    
    @IBOutlet weak var button: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let intervalSeconds = 0.4
        // Do any additional setup after loading the view.
        if motionManager.isDeviceMotionAvailable{
            motionManager.deviceMotionUpdateInterval = TimeInterval(intervalSeconds)

            motionManager.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: {(motion:CMDeviceMotion?, error:Error?) in
                self.getMotionData(deviceMotion: motion!)

            })
        }
        
    }

    func getMotionData(deviceMotion: CMDeviceMotion){
        // 加速度センサー [G]
        //accelerometerX.text = String(format: "%06f", deviceMotion.userAcceleration.x)
        //accelerometerY.text = String(format: "%06f", deviceMotion.userAcceleration.y)
        //accelerometerZ.text = String(format: "%06f", deviceMotion.userAcceleration.z)
        //重力センサー [G]
        gravityX.text = String(format: "%06f", deviceMotion.gravity.x)
        gravityY.text = String(format: "%06f", deviceMotion.gravity.y)
        gravityZ.text = String(format: "%06f", deviceMotion.gravity.z)
        //print(String(format: "%06f", deviceMotion.gravity.x),",",String(format: "%06f", deviceMotion.gravity.y),",",String(format: "%06f", deviceMotion.gravity.z),",",String(format: "%06f", deviceMotion.rotationRate.x),",",String(format: "%06f", deviceMotion.rotationRate.y),",",String(format: "%06f", deviceMotion.rotationRate.z),",",String(format: "%06f", deviceMotion.attitude.pitch),",",String(format: "%06f", deviceMotion.attitude.roll),",",String(format: "%06f", deviceMotion.attitude.yaw))
        //print(String(format: "%06f", deviceMotion.gravity.y))
        //print(String(format: "%06f", deviceMotion.gravity.z))
        // 角速度センサー [G]
        gyroX.text = String(format: "%06f", deviceMotion.rotationRate.x)
        gyroY.text = String(format: "%06f", deviceMotion.rotationRate.y)
        gyroZ.text = String(format: "%06f", deviceMotion.rotationRate.z)
        //print(String(format: "%06f", deviceMotion.rotationRate.x),String(format: "%06f", deviceMotion.rotationRate.y),String(format: "%06f", deviceMotion.rotationRate.z))
        //print(String(format: "%06f", deviceMotion.rotationRate.x))
        //print(String(format: "%06f", deviceMotion.rotationRate.x))
        
        
        // 姿勢センサー [G]
        //attitudeX.text = String(format: "%06f", deviceMotion.attitude.pitch)
        //attitudeY.text = String(format: "%06f", deviceMotion.attitude.roll)
        //attitudeZ.text = String(format: "%06f", deviceMotion.attitude.yaw)
        //print(String(format: "%06f", deviceMotion.attitude.pitch),String(format: "%06f", deviceMotion.attitude.roll),String(format: "%06f", deviceMotion.attitude.yaw))
        //print(String(format: "%06f", deviceMotion.attitude.roll))
        //print(String(format: "%06f", deviceMotion.attitude.yaw))
        self.sensorList = []
        //重力センサ
        self.sensorList.append(deviceMotion.gravity.x)
        self.sensorList.append(deviceMotion.gravity.y)
        self.sensorList.append(deviceMotion.gravity.z)
        
        self.sensorList.append(deviceMotion.rotationRate.x)
        self.sensorList.append(deviceMotion.rotationRate.y)
        self.sensorList.append(deviceMotion.rotationRate.z)
        
        self.sensorList.append(deviceMotion.attitude.pitch)
        self.sensorList.append(deviceMotion.attitude.roll)
        self.sensorList.append(deviceMotion.attitude.yaw)
        
        
        let intercept = -1.80131316
        var sum = intercept
        let coefficient =  [0.30223284, -2.62991929, 1.52691657, -1.28418032, -0.1064995,-0.02088443, 3.26271071, 0.46824078, 0.22321698]

        for i in 0..<9{
            sum = sum + coefficient[i] * self.sensorList[i]
        }
        
        //print(sum)
        
        if sum > 2{
            print("stand up")
        }else{
            print("sit down")
        }
    }
 
    // センサー取得を止める場合
    func stopDevicemotion(){
        if (motionManager.isDeviceMotionActive) {
            motionManager.stopDeviceMotionUpdates()
            
        }
    }
    
    @IBAction func buttonAction(_ sender: Any) {
        
        
    }
    
    
}

func saveCSV(list:[String]) {
    var dataList:[String] = []
    var userPath:String!
    let fileManager = FileManager()
    
    //CSVファイルのパスを取得する。
    //let csvPath = Bundle.main.path(forResource: "sensor", ofType: "csv")
    
    
    //ファイルの作成
    let fm = FileManager.default

    //print(dataList)
    let outputStr = list.joined(separator: "\n")
    //print(outputStr)
    do {
        if(outputStr == "") {
        //部活配列が空の場合はユーザーが保存したCSVファイルを削除する。
            //try fileManager.removeItem(atPath: csvPath!)
        } else {
        //ファイルを出力する。
            //try outputStr.write(toFile: csvPath!, atomically: true, encoding: String.Encoding.utf8 )
        }
    } catch {
    print(error)
    }
}
