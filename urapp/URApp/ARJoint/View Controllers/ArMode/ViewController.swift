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
import LocalAuthentication
import ARCharts
import Jelly

class ViewController: UIViewController {
 
    
    /// Marks if the AR experience is available for restart.
    var isRestartAvailable = true
    var focusSquare = FocusSquare()
    var settings = Settings()
    var operations = Operations()
    
    let configuration = ARWorldTrackingConfiguration()
    
    @IBOutlet weak var shooterProgramButton: UIButton!
    @IBOutlet weak var undoProgramButton: UIButton!
    @IBOutlet weak var crossHair: UIButton!
    var programProgrammingMode = [SCNNode]()
    var programPoints = [SCNNode]()
    var chatProtocol: ChatProtocol?

    @IBOutlet var sceneView: VirtualObjectARView!
    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet weak var settingsButton: UIButton!
    
    var nodeHolder: SCNNode!
    var auxNodeHolder: SCNNode!
    
    var chartNode: ARBarChart!
    var chartNode1: ARBarChart!
    var startingRotation: Float = 0.0
    
    var selectedNode: SCNNode!
    var sceneWalls: [SCNNode] = []
    var currentTrackingPosition: CGPoint!
    var robotMonitor = [RobotMonitoring]()
    
    // Card
    var joint : Joint!
    var joinSelected = -1 //-1 if any selected
    var data = RobotData()
    
    var jointsBalls = [SCNNode()]
    
    var animator: Jelly.Animator?
    var settingsAnimator: Jelly.Animator?
    let storyBoard = UIStoryboard.init(name: "Main", bundle: nil)
    var viewControllerToPresent: ChatViewController!
    var settingsViewController: SettingsViewController!
    
    enum BodyType : Int {
        case ObjectModel = 2;
    }
    
    lazy var statusViewController: StatusViewController = {
        return children.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()
    
    let updateQueue = DispatchQueue(label: "serialSceneKitQueue")
    var screenCenter: CGPoint {
        let bounds = UIScreen.main.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    //----------------------
    //MARK: - View LifeCycle
    //----------------------
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //MIDINotification()
        
        self.setupCamera()
        self.robotMonitor.append(RobotMonitoring(self.settings.robotIP, Int32(self.settings.robotPort)))
        self.robotMonitor.append(RobotMonitoring(self.settings.robotIP, Int32(self.settings.robotPort)))
        self.robotMonitor.append(RobotMonitoring(self.settings.robotIP, Int32(self.settings.robotPort)))
        
        self.setUpSettingsView()
        self.setUpChatView()
        self.setUpNotifications()
        self.joint = Joint()
        
        self.statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
        self.setupARSession()
        
        /*setUpSettingsView()
        setUpChatView()
        setUpNotifications()
        self.setupARSession()
        joint = Joint()
        robotMonitor.append(RobotMonitoring(settings.robotIP, Int32(settings.robotPort)))
        robotMonitor.append(RobotMonitoring(settings.robotIP, Int32(settings.robotPort)))
        robotMonitor.append(RobotMonitoring(settings.robotIP, Int32(settings.robotPort)))*/
        
        
    }
    
    func setUpSettingsView () {
        settingsViewController = (self.storyboard!.instantiateViewController(withIdentifier: "settingsIdentifier") as! SettingsViewController)
        settingsViewController.settings = self.settings;
        
        //let uiConfiguration = PresentationUIConfiguration(backgroundStyle: .dimmed(alpha: 0.5))
        let uiConfiguration = PresentationUIConfiguration(cornerRadius: 10, backgroundStyle: .dimmed(alpha: 0.5))
        var size: PresentationSize!
        var interactionConfiguration: InteractionConfiguration!

        if UIDevice.current.userInterfaceIdiom == .pad {
            size = PresentationSize(width: .custom(value: CGFloat((UIScreen.main.bounds.width / 2) - (UIScreen.main.bounds.width / 10))), height: .fullscreen)
            interactionConfiguration = InteractionConfiguration(presentingViewController: self, completionThreshold: 0.05, dragMode: .edge)
        }else{
             size = PresentationSize(width: .fullscreen, height: .fullscreen)
            interactionConfiguration = InteractionConfiguration(presentingViewController: self, completionThreshold: 0.05, dragMode: .edge)
        }
        
        let marginGuards = UIEdgeInsets(top: 50, left: 16, bottom: 50, right: 16)
        let alignment = PresentationAlignment(vertical: .center, horizontal: .left)
        let presentation = CoverPresentation(directionShow: .left, directionDismiss: .left, uiConfiguration: uiConfiguration, size: size, alignment: alignment, marginGuards: marginGuards, interactionConfiguration: interactionConfiguration)
        //let presentation = SlidePresentation(uiConfiguration: uiConfiguration, direction: .right, size: .halfscreen, interactionConfiguration: interactionConfiguration)
        let animator = Animator(presentation: presentation)
        animator.prepare(presentedViewController: settingsViewController)
        self.settingsAnimator = animator
        
    }
    
    func setUpChatView () {
        viewControllerToPresent = (self.storyboard!.instantiateViewController(withIdentifier: "PresentMe") as! ChatViewController)
        
        self.chatProtocol = viewControllerToPresent
        
        
        let uiConfiguration = PresentationUIConfiguration(cornerRadius: 10, backgroundStyle: .dimmed(alpha: 0.5))
        
        var size: PresentationSize!
        var interactionConfiguration: InteractionConfiguration!
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            size = PresentationSize(width: .custom(value: CGFloat((UIScreen.main.bounds.width / 2) - (UIScreen.main.bounds.width / 8))), height: .halfscreen)
            interactionConfiguration = InteractionConfiguration(presentingViewController: self, completionThreshold: 0.05, dragMode: .edge)
        }else{
            size = PresentationSize(width: .fullscreen, height: .fullscreen)
            interactionConfiguration = InteractionConfiguration(presentingViewController: self, completionThreshold: 0.05, dragMode: .canvas)
        }
        
        let marginGuards = UIEdgeInsets(top: 50, left: 16, bottom: 50, right: 16)
        
        let alignment = PresentationAlignment(vertical: .center, horizontal: .right)
        
        let presentation = CoverPresentation(directionShow: .right, directionDismiss: .right, uiConfiguration: uiConfiguration, size: size, alignment: alignment, marginGuards: marginGuards, interactionConfiguration: interactionConfiguration)
        let animator = Animator(presentation: presentation)
        animator.prepare(presentedViewController: viewControllerToPresent)
        self.animator = animator

    }
    @IBAction func displaySettingsView(_ sender: Any) {
        settingsViewController.settings = self.settings
        present(settingsViewController, animated: true, completion: nil)
        
    }
    
    @IBAction func recordAudio(_ sender: Any) {
        self.chatProtocol?.microphoneClick(sender)
    }
    @IBAction func displayChatView(_ sender: Any) {
        self.chatProtocol?.microphoneReleased(sender)
        //present(viewControllerToPresent, animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.isNavigationBarHidden = true
        
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        robotMonitor[0].close()
        robotMonitor[1].close()
        robotMonitor[2].close()
        // Pause the view's session
        //sceneView.session.pause()
    }
    
    func showGraphs() {
        guard (nodeHolder != nil) else {return}
        if (chartNode != nil) {
            chartNode.removeFromParentNode()
        }
        
        chartNode = ChartCreator.createBarChart(at: SCNVector3(x: -0.5, y: 0, z: -0.5), seriesLabels: ["Montados", "Fracasos"], indexLabels: ["Mobil", "Cajas"], values: [[23, 20],[4,3]])
        chartNode.animationType = .progressiveGrow
        chartNode.animationDuration = 3.0
        
        nodeHolder.addChildNode(chartNode);
    }
    
    func updateFocusSquare(isObjectVisible: Bool) {
        if isObjectVisible {
            self.focusSquare.hide()
        } else {
            self.focusSquare.unhide()
            statusViewController.scheduleMessage("Try moving left or right", inSeconds: 5.0, messageType: .focusSquare)
        }
        
        // Perform hit testing only when ARKit tracking is in a good state.
        if let camera = sceneView.session.currentFrame?.camera, case .normal = camera.trackingState,
            let result = self.sceneView.smartHitTest(screenCenter) {
            updateQueue.async {
                self.sceneView.scene.rootNode.addChildNode(self.focusSquare)
                self.focusSquare.state = .detecting(hitTestResult: result, camera: camera)
            }
            statusViewController.cancelScheduledMessage(for: .focusSquare)
        } else {
            updateQueue.async {
                self.focusSquare.state = .initializing
                self.sceneView.pointOfView?.addChildNode(self.focusSquare)
            }
        }
    }
    
    func lineFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> SCNGeometry {
        
        let indices: [Int32] = [0, 1]
        
        let source = SCNGeometrySource(vertices: [vector1, vector2])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        
        return SCNGeometry(sources: [source], elements: [element])
        
    }
    
    @IBAction func undoProgramPoint(_ sender: Any) {
        
        print("Undo zero - \(programProgrammingMode.count)")
        if programProgrammingMode.count > 0 {
            print("Undo one - \(programProgrammingMode.count)")
            var node = programProgrammingMode.removeLast()
            node.removeFromParentNode()
            print("Undo one - \(programProgrammingMode.count)")
            if programProgrammingMode.count > 0 {
                print("Undo two - \(programProgrammingMode.count)")
                node = programProgrammingMode.removeLast()
                print("Undo two - \(programProgrammingMode.count)")
                node.removeFromParentNode()
            }
        }
    }
    
    @IBAction func addProgramPoint(_ sender: Any) {
        self.operations.isAddingProgramPoint = true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "webViewer",
            let mapWebView =  segue.destination as? MapWebViewController{
            //mapWebView.webAddress = joint.jointData.moreInfo.link
        }
    }
    
    
    func authenticateUser() {
        // Get the local authentication context.
        let context = LAContext()
        
        // Declare a NSError variable.
        var error: NSError?
        
        // Set the reason string that will appear on the authentication alert.
        let reasonString = "Authentication is needed to verify your identity."
        
        // Check if the device can evaluate the policy.
        if context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            
            [context .evaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, localizedReason: reasonString, reply: { (success: Bool, evalPolicyError: Error?) -> Void in
                if success {
                    
                    DispatchQueue.main.async(execute: {
                    });
                    
                }
                else{
                    
                    switch evalPolicyError!._code {
                        
                    case LAError.systemCancel.rawValue:
                        print( "Authentication was cancelled by the user")
                        
                    case LAError.userCancel.rawValue:
                        print( "Authentication was cancelled by the user")
                        
                    default:
                        print("Authentication failed")
                    }
                }
                
            })]
        }
        else{
            
            if (LAError.biometryNotEnrolled.rawValue == 1) {
                print("TouchID not available")
            }
        }
    }
    
}
