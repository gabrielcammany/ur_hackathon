//
//  ViewController.swift
//  test
//
//  Created by XavierRoma on 08/03/2019.
//  Copyright © 2019 Salle URL. All rights reserved.
//

import Foundation
import ARKit
import WebKit
import MapKit

class Joint: SCNNode{
    
    
    
    var nameTimer: Timer?
    var time = 0
    
    let Flipped_Rotation = SCNVector4Make(0, 1, 0, GLKMathDegreesToRadians(180))
    var interactiveButtons = [SCNNode]()
    var jointRoot: SCNNode!
    var businessCardTarget: SCNNode!
    var cardHolderImage: SCNNode!       { didSet { cardHolderImage.name = "imageDetected" } }
    var currentLabel: SCNText!
    var tempLabel: SCNText!
    var speedButton: SCNNode!   { didSet { speedButton.name = "speed" } }
    var tempButton: SCNNode!          { didSet { tempButton.name = "temp" } }
    var moreButton: SCNNode!         { didSet { moreButton.name = "more"} }
    
    //---------------------
    //MARK: - Intialization
    //---------------------
    
    /// Creates The Business Card
    ///
    /// - Parameters:
    ///   - data: BusinessCardData
    ///   - cardType: CardTemplate
    override init() {
        
        super.init()
        
        //1. Set The Data For The Card
        
        //2. Extrapolate All The Nodes & Geometries
        guard let template = SCNScene(named: "art.scnassets/JointTemplate.scn"),
            let jointRoot = template.rootNode.childNode(withName: "RootNode", recursively: false),
            let currentLabel = jointRoot.childNode(withName: "current_label", recursively: false)?.geometry as? SCNText,
            let tempLabel = jointRoot.childNode(withName: "temp_label", recursively: false)?.geometry as? SCNText,
            let speedButton = jointRoot.childNode(withName: "current", recursively: false),
            let tempButton = jointRoot.childNode(withName: "temp", recursively: false),
            let moreButton = jointRoot.childNode(withName: "more", recursively: false)
            
        else { fatalError("Error Getting Joint Node Data") }
        
        self.addChildNode(jointRoot)
        //4. Assign These To The BusinessCard Node
        //self.jointName.flatness = 0
        self.speedButton = speedButton
        self.tempButton = tempButton
        self.moreButton = moreButton
        self.currentLabel = currentLabel
        self.tempLabel = tempLabel
        self.jointRoot = jointRoot
        
        self.eulerAngles.x = -.pi / 2
        
        //5. Store All The Interactive Elements
        interactiveButtons.append(moreButton)
      
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("Business Card Coder Not Implemented") }
    
    deinit { flushFromMemory() }
    
    func updateValues(temp: String, current: String) {
        tempLabel.string = temp
        currentLabel.string = current
        //currentLabel.font = UIFont(name: "Helvatica", size: 106)
    }
    
    //---------------
    //MARK: - Cleanup
    //---------------

    /// Removes All SCNMaterials & Geometries From An SCNNode
    func flushFromMemory(){
        
        print("Cleaning Business Card")
        
        if let parentNodes = self.parent?.childNodes{ parentNodes.forEach {
            $0.geometry?.materials.forEach({ (material) in material.diffuse.contents = nil })
            $0.geometry = nil
            $0.removeFromParentNode()
            }
        }
        
        for node in self.childNodes{
            node.geometry?.materials.forEach({ (material) in material.diffuse.contents = nil })
            node.geometry = nil
            node.removeFromParentNode()
        }
    }
}
