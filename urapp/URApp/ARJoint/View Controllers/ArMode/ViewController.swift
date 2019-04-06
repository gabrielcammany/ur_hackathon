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
 
    //---------------------------------------
    // Programming Mode View with its buttons
    @IBOutlet weak var programmingView: UIView!
    @IBOutlet weak var undoProgramButton: UIButton!
    @IBOutlet weak var confirmPointButton: UIButton!
    @IBOutlet weak var sliderProgramView: RoundUIView!
    @IBOutlet weak var crossHair: UIButton!
    @IBOutlet weak var shooterProgramButton: UIButton!
    @IBOutlet weak var zSlider: UISlider!
    @IBOutlet weak var endefectorButton: UIButton!
    var isGrabbing = false
    @IBOutlet weak var saveButton: UIButton!
    var programPointsRobotData = [RobotPos]()
    var lastPPoint: RobotPos!
    var programProgrammingMode = [SCNNode]()
    var lastARLine: SCNNode!
    var lastARPPoint: SCNNode!
    var programOperationsQueue = [OperationType]()
    //---------------------------------------
    
    //---------------------------------------
    // Monitor Sockets
    var robotSockets = [RobotMonitoring]()
    enum RobotSockets: Int, CaseIterable{
        typealias RawValue = Int
        case joints_pos = 0;
        case temp = 1;
        case current = 2;
        case comunication = 3;
        case info = 4;
    }
    //---------------------------------------
    
    
    @IBOutlet weak var okCalibrateButton: UIButton!
    
    var focusSquare = FocusSquare()
    var settings = Settings()
    var operations = Operations()
    var movement: Movement!
    
    
    let configuration = ARWorldTrackingConfiguration()
    
    var programPoints = [SCNNode]()
    var chatProtocol: ChatProtocol?

    @IBOutlet var sceneView: VirtualObjectARView!
    @IBOutlet weak var settingsButton: UIButton!
    
    var nodeHolder: SCNNode!
    
    var chartNode: ARBarChart!
    var startingRotation: Float = 0.0
    
    var selectedNode: SCNNode!
    var sceneWalls: [SCNNode] = []
    var currentTrackingPosition: CGPoint!
    
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
    
    var init_failed = false
    
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
        
        self.setUpSettingsView()
        self.setUpChatView()
        self.setUpNotifications()
        self.joint = Joint()
        
        
        self.statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
        self.setupARSession()
        self.view.clipsToBounds = true
        zSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2))
        
        initRobotCommunication()
        
        //let planeNormal = [-0.029094979874907195, 0.9994991577256024, -0.01244651966977037]
        //let distanceToOrigin = 0.22029730328640826
        
    }
    
    func initRobotCommunication () {
        
        for rob in robotSockets {
            if rob.isOpen {
                rob.close()
            }
        }
        robotSockets.removeAll()
        
        
        for _ in RobotSockets.allCases {
            robotSockets.append(RobotMonitoring(self.settings.robotIP, Int32(self.settings.robotPort))
            )
            if let sock = robotSockets.last {
                if !sock.init_succeed {
                    init_failed = true
                    break
                }
            }
        }
        let title: String!
        let body: String!
        
        if init_failed {
            title = "Connection Error";
            body = "Porfavor, compruebe la connexión con el robot";
        } else {
            title = "Calibrate";
            body = "Porfavor, localiza la mesa de trabajo del robot";
        }
        
        messageBox(messageTitle: title, messageAlert: body, messageBoxStyle: .alert, alertActionStyle: UIAlertAction.Style.default, completionHandler: {})
        
    }
    
    @IBAction func calibrateEndedAction(_ sender: Any) {
        
        
        if (nodeHolder == nil) {
            messageBox(messageTitle: "Error de calibración", messageAlert: "Porfavor, localiza la mesa de trabajo del robot", messageBoxStyle: .alert, alertActionStyle: UIAlertAction.Style.default, completionHandler: {})
            return
        }
        
        let aux = SCNNode()
        
        for node in nodeHolder.childNodes {
            aux.addChildNode(node)
        }
        let anchor = ARAnchor(transform: nodeHolder.simdTransform)
        sceneView.session.add(anchor: anchor)
        
        nodeHolder.removeFromParentNode()
        aux.transform = nodeHolder.transform
        nodeHolder = nil
        aux.transform.m21 = 0.0
        aux.transform.m22 = 1.0
        aux.transform.m23 = 0.0
        nodeHolder = aux
        
        sceneView.scene.rootNode.addChildNode(nodeHolder)
        
        okCalibrateButton.isHidden = true
        self.operations.isSettingPosition = false;
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
            interactionConfiguration = InteractionConfiguration(presentingViewController: self, completionThreshold: 0.05, dragMode: .edge)
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
        
        // Pause the view's session
        //sceneView.session.pause()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        RobotSockets.allCases.forEach { cas in
            if robotSockets[cas.rawValue].isOpen {
                robotSockets[cas.rawValue].close()
            }
        }
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
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "webViewer",
            let mapWebView =  segue.destination as? MapWebViewController{
            //mapWebView.webAddress = joint.jointData.moreInfo.link
        }
    }
    
    func messageBox(messageTitle: String, messageAlert: String, messageBoxStyle: UIAlertController.Style, alertActionStyle: UIAlertAction.Style, completionHandler: @escaping () -> Void)
    {
        let alert = UIAlertController(title: messageTitle, message: messageAlert, preferredStyle: messageBoxStyle)
        
        let okAction = UIAlertAction(title: "OK", style: alertActionStyle) { _ in
            completionHandler() // This will only get called after okay is tapped in the alert
        }
        
        alert.addAction(okAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    //-----------------------------------------
    //     PROGRAMING MODE BUTTONS ACTION
    //-----------------------------------------
    @IBAction func confirmButtonPressed(_ sender: Any) {
        if lastPPoint != nil {
            programPointsRobotData.append(lastPPoint)
            lastPPoint = lastPPoint.clone()
            
            programOperationsQueue.append(.confirm)
            
        }
    }
    @IBAction func grabButtonPressed(_ sender: Any) {
        isGrabbing = !isGrabbing
        
        if isGrabbing {
            endefectorButton.setImage(#imageLiteral(resourceName: "noGrabP"), for: .normal)
            endefectorButton.setImage(#imageLiteral(resourceName: "grabPPressed"), for: .highlighted)
            robotSockets[RobotSockets.comunication.rawValue].send("set_tool_digital_out(1, False)\n")
            robotSockets[RobotSockets.comunication.rawValue].send("set_tool_digital_out(0, True)\n")
            lastPPoint.grab = true
            lastPPoint.release = false
        } else {
            endefectorButton.setImage(#imageLiteral(resourceName: "grabP"), for: .normal)
            endefectorButton.setImage(#imageLiteral(resourceName: "noGrabPPressed"), for: .highlighted)
            robotSockets[RobotSockets.comunication.rawValue].send("set_tool_digital_out(0, False)\n")
            robotSockets[RobotSockets.comunication.rawValue].send("set_tool_digital_out(1, True)\n")
            lastPPoint.grab = false
            lastPPoint.release = true
        }
        
    }
    @IBAction func saveButtonPressed(_ sender: Any) {
        if lastPPoint != nil {
            programPointsRobotData.append(lastPPoint)
        }
        //start movement
        
        robotSockets[RobotSockets.comunication.rawValue].send("def M():\n")
        robotSockets[RobotSockets.comunication.rawValue].send("  move = True\n")
        robotSockets[RobotSockets.comunication.rawValue].send("  while move:\n")
        
        for pose in programPointsRobotData {
            robotSockets[RobotSockets.comunication.rawValue].movel_to(pose.toPosition())
        
            robotSockets[RobotSockets.comunication.rawValue].send("  while is_steady() == False:\n")
            robotSockets[RobotSockets.comunication.rawValue].send("      sleep(0.01)\n")
            robotSockets[RobotSockets.comunication.rawValue].send("  end\n")
            
            if pose.grab {
                robotSockets[RobotSockets.comunication.rawValue].send("  set_tool_digital_out(1, False)\n")
                robotSockets[RobotSockets.comunication.rawValue].send("  set_tool_digital_out(0, True)\n")
                robotSockets[RobotSockets.comunication.rawValue].send("  sleep(0.5)\n")
            }
            if pose.release {
                robotSockets[RobotSockets.comunication.rawValue].send("  set_tool_digital_out(0, False)\n")
                robotSockets[RobotSockets.comunication.rawValue].send("  set_tool_digital_out(1, True)\n")
                robotSockets[RobotSockets.comunication.rawValue].send("  sleep(0.5)\n")
                
            }
            
        }
        robotSockets[RobotSockets.comunication.rawValue].send("  end\n")
        robotSockets[RobotSockets.comunication.rawValue].send("end\n")
        
        
    }
    @IBAction func zSliderChanged(_ sender: Any) {
        if lastPPoint != nil {
            
            if (abs(Float(lastPPoint.z) ?? zSlider.value - zSlider.value) > 0.05) {
                lastPPoint.z = String(zSlider.value)
                lastPPoint.reproducePosition(com: robotSockets[RobotSockets.comunication.rawValue])
                programOperationsQueue.append(.update)
                
            }
            
        }
        
    }
    
    @IBAction func addProgramPoint(_ sender: Any) {
        programOperationsQueue.append(.create)
    }
    
    @IBAction func undoProgramPoint(_ sender: Any) {
        
        programOperationsQueue.append(.remove)
        lastPPoint = programPointsRobotData.popLast()
        
        if lastPPoint != nil {
            lastPPoint.reproduceInversePosition(com: robotSockets[RobotSockets.comunication.rawValue])
        }
        

    }
    
    //-----------------------------------------
    
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

@IBDesignable
class RoundUIView: UIView {
    
    @IBInspectable var borderColor: UIColor = UIColor.white {
        didSet {
            self.layer.borderColor = borderColor.cgColor
        }
    }
    
    @IBInspectable var borderWidth: CGFloat = 2.0 {
        didSet {
            self.layer.borderWidth = borderWidth
        }
    }
    
    @IBInspectable var cornerRadius: CGFloat = 0.0 {
        didSet {
            self.layer.cornerRadius = cornerRadius
        }
    }
}

