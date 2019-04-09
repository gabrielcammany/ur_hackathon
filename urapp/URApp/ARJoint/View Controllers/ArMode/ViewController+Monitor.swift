//
//  File.swift
//  URApp
//
//  Created by XavierRoma on 29/03/2019.
//  Copyright © 2019 x.roma_gabriel.cammany. All rights reserved.
//

import Foundation
import ARKit

extension ViewController {
    
    func jointBallsNodesDestroy () {
        
        for joint in jointsBalls {
            joint.removeFromParentNode()
        }
        jointsBalls.removeAll()
        self.joint.removeFromParentNode()
        
    }
    
    func actualJointBallsNodesDestroy () {
        
        for joint in actualJointsBalls {
            joint.removeFromParentNode()
        }
        for joint in targetJointsBalls {
            joint.removeFromParentNode()
        }
        actualJointsBalls.removeAll()
        targetJointsBalls.removeAll()
        
    }
    
    func jointBallsNodesInit() {
        for i in 0...(self.data.MAX_JOINTS - 1) {
            let node = SCNNode(geometry: SCNSphere(radius: 0.05))
            node.opacity = 0.1
            node.name = "Joint-\(i)"
            jointsBalls.append(node)
            self.nodeHolder.addChildNode(node)
        }
    }
    
    func actualJointBallsNodesInit() {
        for _ in 0...(self.data.MAX_JOINTS - 1) {
            let node = SCNNode(geometry: SCNSphere(radius: 0.02))
            let node1 = SCNNode(geometry: SCNSphere(radius: 0.02))
            node.geometry?.firstMaterial?.diffuse.contents = UIColor.orange
            node1.geometry?.firstMaterial?.diffuse.contents = UIColor.orange
            node.opacity = 0.5
            node1.opacity = 0.5
            actualJointsBalls.append(node)
            targetJointsBalls.append(node1)
            self.nodeHolder.addChildNode(node)
            self.nodeHolder.addChildNode(node1)
        }
    }
    
    func startAllJointMonitor() {
        DispatchQueue.global(qos: .userInitiated).async {
            while (self.operations.isMonitoring) {
                
                let out =  self.robotSockets[RobotSockets.joints_pos.rawValue].read(information.get_all_joint_positions_json)
                
                do {
                    var json = try JSONSerialization.jsonObject(with: out as Data) as? [[Any]]
                    print("json: \(json)")
                    for i in 1...(self.data.MAX_JOINTS) {
                        var j = 0
                        for pos in json?[0][i - 1] as! [NSNumber] {
                            self.data.jointData[i - 1].position[j] = "\(pos)"
                            j += 1
                            if j == 3 {
                                break
                            }
                        }
                        j = 0
                        for pos in json?[1][i - 1] as! [NSNumber] {
                            self.data.targetJointData[i - 1].position[j] = "\(pos)"
                            j += 1
                            if j == 3 {
                                break
                            }
                        }
                    }
                   
                    usleep(9000)
                }
                catch {
                    usleep(3000)
                }
            }
        }
        
        DispatchQueue.global(qos: .background).async {
            while (self.operations.isMonitoring) {
                
                let out = self.robotSockets[RobotSockets.current.rawValue]
                    .read(information.get_info_json)
                
                
                do {
                    let json = try JSONSerialization.jsonObject(with: out as Data) as? [[Any]]
                    
                    for i in 1...((self.data.MAX_JOINTS - 1)) {
                        let curr_str = "\(json?[0][i - 1] ?? self.data.jointData[i - 1].jointCurrent)"
                        print ("curr_str \(curr_str)");
                        let temp_str = "\(json?[1][i - 1] ?? self.data.jointData[i - 1].jointTemp)"
                        print ("temp_str \(temp_str)");
                        let volt_str = "\(json?[2][i - 1] ?? self.data.jointData[i - 1].jointTemp)"
                        print ("volt_str \(temp_str)");
                        let speed_str = "\(json?[3][i - 1] ?? self.data.jointData[i - 1].jointTemp)"
                        print ("volt_str \(temp_str)");
                        
                        guard curr_str.count >= 6, temp_str.count >= 6, volt_str.count >= 6 else {continue}
                        
                        self.data.jointData[i - 1].jointCurrent = String(curr_str[curr_str.startIndex ..< (curr_str.index(curr_str.startIndex, offsetBy: 5))])
                        
                        self.data.jointData[i - 1].jointTemp = String(temp_str[temp_str.startIndex ..< (temp_str.index(temp_str.startIndex, offsetBy: 4))])
                        
                        print(self.data.jointData[i - 1].jointTemp);
                        let temp = Int(Float(self.data.jointData[i - 1].jointTemp) ?? 30.0)
                        self.data.jointData[i - 1].jointColor = self.tempBarColor[temp > 35 ? temp - (temp % 3): temp + (temp % 3)]
                        print(self.data.jointData[i - 1].jointColor);
                        
                        self.data.jointData[i - 1].jointVolatge = String(volt_str[volt_str.startIndex ..< (volt_str.index(volt_str.startIndex, offsetBy: 5))])
                        
                        self.data.jointData[i - 1].jointSpeed = String(speed_str[speed_str.startIndex ..< (speed_str.index(speed_str.startIndex, offsetBy: 5))])
                        
                    }
                    
                    
                    usleep(1000000)
                } catch {
                    usleep(10000)
                }
            }
        }
        
    }
    
    func monitorWalls () {
        let client = RobotMonitoring(settings.robotIP, Int32(settings.robotPort))
        client.connect()
        var nothing = true
        if client.init_succeed {
            
            while nothing {
                do {
                    let out = client.read(.get_walls_json) as Data
                    print(out)
                    let json = try JSONSerialization.jsonObject(with: out) as? [[Any]]
                    print("Walls: \(json)")
                    
                    for wall in json ?? [[]] {
                        let x = Float("\(wall[0])")
                        let y = Float("\(wall[1])")
                        let z = Float("\(wall[2])")
                        
                        print("Got a wall: \(wall)");
                        if  x == 1 {
                        } else if y == 1 {
                            
                        } else if z == 1 {
                            
                        }
                    }
                    
                    nothing = false
                    operations.isWallChanging = true
                } catch {
                    usleep(1000000)
                }
                
            }
            client.close()
        }
        
    }
    
}
