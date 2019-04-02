//
//  ViewController.swift
//  test
//
//  Created by XavierRoma on 08/03/2019.
//  Copyright © 2019 Salle URL. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import WebKit

extension ViewController: ARSCNViewDelegate{
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        DispatchQueue.main.async {
            self.updateFocusSquare(isObjectVisible: false)
        }
        
        if (self.operations.isMonitoring) {
                
                DispatchQueue.main.async {
                    for i in 0...3 {
                        print(self.data.jointData)
                        guard let x = Float(self.data.jointData[i].position[0]),
                            let y = Float(self.data.jointData[i].position[2]),
                            let z = Float(self.data.jointData[i].position[1])  else {continue}
                        self.jointsBalls[i].transform.m41 = x * -1 - 0.65
                        self.jointsBalls[i].transform.m42 = y + 0.152
                        self.jointsBalls[i].transform.m43 = z - 0.275
                        if (self.joinSelected != -1) {
                            self.joint.transform = self.jointsBalls[self.joinSelected].transform
                            self.joint.updateValues(temp: "\(self.data.jointData[i].jointTemp) ºC", current: "\(self.data.jointData[i].jointCurrent) A")
                        }
                    }
                }
        }
       
        if (self.operations.placeJointInfo) {
            self.joint.removeFromParentNode()
            self.joint.transform = self.jointsBalls[self.joinSelected].transform
            self.nodeHolder.addChildNode(self.joint)
            self.operations.placeJointInfo = false
        }
        
        if (self.operations.isWallChanging) {
            self.updateWalls()
            self.operations.isWallChanging = false
        }
        
        if (self.operations.isShowingCurrentProgram) {
            self.updateShowCurrentProgram()
            self.operations.isShowingCurrentProgram = false
        }
        
        if (self.operations.isInProgramMode) {
            self.updateProgramMode()
            self.operations.isInProgramMode = false
        }
        
        if (self.operations.isUpdatingOpacity) {
            self.updateRenderOpacity()
            self.operations.isUpdatingOpacity = false
        }
        
        if (self.operations.isAddingProgramPoint) {
            self.addProgramPoint()
            self.operations.isAddingProgramPoint = false
        }
        
        
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        guard operations.isSettingPosition, let imageAnchor = anchor as? ARImageAnchor
            else { return }
        
        switch imageAnchor.name {
        case "1":
            statusViewController.showMessage("Posición de inicio encontrada!", autoHide: true)
            if nodeHolder != nil, nodeHolder.parent != nil {
                nodeHolder.removeFromParentNode()
            }
            
            nodeHolder = SCNNode()
            nodeHolder = node
            nodeHolder.transform.m21 = 0.0
            nodeHolder.transform.m22 = 1.0
            nodeHolder.transform.m23 = 0.0
            
            //nodeHolder.transform.m42 = result.worldTransform.columns.3.y
            let scene = SCNScene(named: "art.scnassets/ship.scn")!
            for nodeInScene in scene.rootNode.childNodes as [SCNNode] {
                nodeHolder.addChildNode(nodeInScene)
            }
            
            sceneView.scene.rootNode.addChildNode(nodeHolder)
            break
        default:
            break
        }
        
        
    }
    
    func showJoint () {
        
    }
    
    func updateWalls() {
        if settings.robotWalls {
            let scene = SCNScene(named: "art.scnassets/walls.scn")!
            for nodeInScene in scene.rootNode.childNodes as [SCNNode] {
                nodeInScene.opacity = CGFloat(settings.robotWallsOpacity)
                nodeHolder.addChildNode(nodeInScene)
                sceneWalls.append(nodeInScene)
            }
        } else {
            setUpARConfirmation()
            for node in sceneWalls {
                node.removeFromParentNode()
            }
        }
    }
    
    func setUpARConfirmation() {
        let aux = SCNNode()
        
        for node in nodeHolder.childNodes {
            aux.addChildNode(node)
        }
        nodeHolder.removeFromParentNode()
        aux.transform = nodeHolder.transform
        nodeHolder = nil
        aux.transform.m21 = 0.0
        aux.transform.m22 = 1.0
        aux.transform.m23 = 0.0
        nodeHolder = aux
        
        sceneView.scene.rootNode.addChildNode(nodeHolder)
    }
    
    func updateProgramMode() {
        if settings.programingMode {
            DispatchQueue.main.async {
                self.crossHair.isHidden = false
                self.shooterProgramButton.isHidden = false
                self.undoProgramButton.isHidden = false
            }
            startAllJointMonitor()
        } else {
            DispatchQueue.main.async {
                self.crossHair.isHidden = true
                self.shooterProgramButton.isHidden = true
                self.undoProgramButton.isHidden = true
            }
            for node in programProgrammingMode.reversed() {
                node.removeFromParentNode()
                programPoints.append(programProgrammingMode.removeLast())
            }
        }
    }
    
    func updateRenderOpacity() {
        for nodeC in nodeHolder.childNodes {
            if let string = nodeC.name, string.contains("Wall") {
                nodeC.opacity = CGFloat(settings.robotWallsOpacity)
            }
        }
    }
    
    func addProgramPoint() {
        guard let result = sceneView.hitTest(CGPoint(x: screenCenter.x, y: screenCenter.y), types: [.existingPlaneUsingExtent, .featurePoint]).first else { return }
        
        let sphere = SCNSphere(radius: 0.005)
        let node = SCNNode(geometry: sphere)
        
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        node.position = SCNVector3(x: result.worldTransform.columns.3.x, y: result.worldTransform.columns.3.y, z: result.worldTransform.columns.3.z)
        
        
        
        sceneView.scene.rootNode.addChildNode(node)
        
        if programProgrammingMode.count >= 1 {
            let line = lineFrom(vector: (programProgrammingMode.last?.position)!, toVector: node.position)
            let lineNode = SCNNode(geometry: line)
            lineNode.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            sceneView.scene.rootNode.addChildNode(lineNode)
            
            programProgrammingMode.append(lineNode)
        }
        //It is important to do this append AFTER the line node is appended
        programProgrammingMode.append(node)
    }
    
    func updateShowCurrentProgram() {
        if settings.visualizeProgram {
            for node in programPoints {
                sceneView.scene.rootNode.addChildNode(node)
            }
        } else {
            for node in programPoints {
                node.removeFromParentNode()
            }
        }
    }
    
}
