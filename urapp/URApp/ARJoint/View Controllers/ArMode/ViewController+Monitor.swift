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
    
    func jointBallsNodesInit() {
        for i in 0...(MAX_JOINTS - 1) {
            let node = SCNNode(geometry: SCNSphere(radius: 0.05))
            node.opacity = 0.1
            node.name = "Joint-\(i)"
            jointsBalls.append(node)
            self.nodeHolder.addChildNode(node)
        }
    }
    
    func startAllJointMonitor() {
        DispatchQueue.global(qos: .userInitiated).async {
            while (self.operations.isMonitoring) {
                
                let out =  self.robotSockets[RobotSockets.joints_pos.rawValue].read(information.get_all_joint_positions_json)
                
                do {
                    var json = try JSONSerialization.jsonObject(with: out as Data) as? [[[Any]]]
                    
                    self.semaphore.wait()
                    for i in 1...MAX_JOINTS {
                        var j = 0
                        for pos in json?[0][i - 1] as! [NSNumber] {
                            self.data.jointData[i - 1].position[j] = "\(pos)"
                            j += 1
                            if j == 3 {
                                break
                            }
                        }
                    }
                    self.semaphore.signal()
                   
                    usleep(10000)
                }
                catch {
                    usleep(4000)
                }
            }
        }
        
        DispatchQueue.global(qos: .background).async {
            while (self.operations.isMonitoring) {
                
                let out = self.robotSockets[RobotSockets.info.rawValue]
                    .read(information.get_info_json)
                
                
                do {
                    let json = try JSONSerialization.jsonObject(with: out as Data) as? [[Any]]
                    
                    for i in 1...(MAX_JOINTS - 1) {
                        let curr_str = "\(json?[0][i - 1] ?? self.data.jointData[i - 1].jointCurrent)"
                        
                        let temp_str = "\(json?[1][i - 1] ?? self.data.jointData[i - 1].jointTemp)"
                        
                        let volt_str = "\(json?[2][i - 1] ?? self.data.jointData[i - 1].jointTemp)"
                        
                        let speed_str = "\(json?[2][i - 1] ?? self.data.jointData[i - 1].jointTemp)"
                        
                        
                        guard curr_str.count >= 6, temp_str.count >= 6, volt_str.count >= 6 else {continue}
                        self.semaphore.wait()
                        self.data.jointData[i - 1].jointCurrent = String(curr_str[curr_str.startIndex ..< (curr_str.index(curr_str.startIndex, offsetBy: 5))])
                        
                        self.data.jointData[i - 1].jointTemp = String(temp_str[temp_str.startIndex ..< (temp_str.index(temp_str.startIndex, offsetBy: 4))])
                        
                        print(self.data.jointData[i - 1].jointTemp);
                        let temp = Int(Float(self.data.jointData[i - 1].jointTemp) ?? 30.0)
                        self.data.jointData[i - 1].jointColor = self.tempBarColor[temp > 35 ? temp - (temp % 3): temp + (temp % 3)]
                        print(self.data.jointData[i - 1].jointColor);
                        
                        self.data.jointData[i - 1].jointVolatge = String(volt_str[volt_str.startIndex ..< (volt_str.index(volt_str.startIndex, offsetBy: 5))])
                        
                        self.data.jointData[i - 1].jointSpeed = String(speed_str[speed_str.startIndex ..< (speed_str.index(speed_str.startIndex, offsetBy: 5))])
                        self.semaphore.signal()
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
                        let x = Int(roundf(Float("\(wall[0])")!))
                        let y = Int(roundf(Float("\(wall[1])")!))
                        let z = Int(roundf(Float("\(wall[2])")!))
                        let distance = Float("\(wall[3])")
                        print("Got a wall: \(x), \(y), \(z)");
                        let wall = SCNNode()
                        
                        if  x == 1 || x == -1 {
                            wall.position.x = distance!
                            wall.position.z += 1
                            wall.geometry = SCNBox(width: 0.02, height: 2, length: 2, chamferRadius: 0)
                        } else if y == 1 || y == -1 {
                            wall.position.y = distance!
                            wall.position.z += 0.7
                            wall.geometry = SCNBox(width: 2, height: 2, length: 0.02, chamferRadius: 0)
                        } else if z == 1 || z == -1 {
                            wall.position.z = distance!
                            wall.geometry = SCNBox(width: 1, height: 0.02, length: 1, chamferRadius: 0)
                        }
                        wall.position = Utilities.robotToARCoord(robot_position: wall.position)
                        wall.geometry?.firstMaterial?.diffuse.contents = UIColor.red
                        wall.opacity = CGFloat(settings.robotWallsOpacity/100)
                        sceneWalls.append(wall)
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
