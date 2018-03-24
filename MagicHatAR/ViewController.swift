//
//  ViewController.swift
//  MagicHatAR
//
//  Created by Kongphop Suriyawanakul on 23/3/2561 BE.
//  Copyright © 2561 bestspang. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var mainText: UILabel!
    @IBOutlet weak var cornerText: UILabel!
    
    private var planeNode: SCNNode?
    var isHatPlaced = false
    var isBallVisibled = true
    var trackingTimer: Timer?
    var balls = [SCNNode]()
    var planes = [SCNNode]()
    var hatNodes: SCNNode?
    var hatBound: SCNNode?
    var scoreSound: SCNAudioSource!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // show feature points
        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        //self.sceneView.debugOptions = [.showPhysicsShapes]
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        //let scene = SCNScene(named: "art.scnassets/magichat.scn")!
        let scene = SCNScene()
        // Set the scene to the view
        sceneView.scene = scene
        
        scoreSound = SCNAudioSource(fileNamed: "art.scnassets/TreasureOpen.mp3")
        scoreSound.load()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        print("Session is supported: \(ARConfiguration.isSupported)")
        print("World Tracking is supported: \(ARWorldTrackingConfiguration.isSupported)")
        if ARWorldTrackingConfiguration.isSupported {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = .horizontal
            // Run the view's session
            sceneView.session.run(configuration)
        }
        else  {
            let configuration = AROrientationTrackingConfiguration()
            sceneView.session.run(configuration)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if let lightEstimate = self.sceneView.session.currentFrame?.lightEstimate {
            
            let light = sceneView.scene.rootNode.childNode(withName: "omni", recursively: true)
            let light2 = sceneView.scene.rootNode.childNode(withName: "omni2", recursively: true)
            light?.light?.intensity = lightEstimate.ambientIntensity
            light2?.light?.intensity = lightEstimate.ambientIntensity
            //self.sceneView.scene.rootNode.light?.intensity = lightEstimate.ambientIntensity/1000
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    @IBAction func resetButton(){
        if isHatPlaced == true {
            hatNodes?.removeFromParentNode()
            for i in balls {
                i.removeFromParentNode()
            }
            isHatPlaced = false
            self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        } else {print("not start yet!")}
    }
    
    @IBAction func magicHide(){
        if isHatPlaced == true {
            //add effect and sound
            addParticleEffects("mainHat")
            let hat = sceneView.scene.rootNode.childNode(withName: "hat", recursively: true)
            playScoreSound(toNode: (hat?.childNode(withName: "mainHat", recursively: true))!)
            //add invisible
            for i in balls {
                if (hatBound?.boundingBoxContains(point: i.presentation.position))! {
                    //i.removeFromParentNode()
                    if isBallVisibled {
                        i.opacity = 0
                        isBallVisibled = false
                    } else {
                        i.opacity = 1
                        isBallVisibled = true
                    }
                }
            }
            
        }
    }
    
    private func playScoreSound(toNode node: SCNNode) {
        let action = SCNAction.playAudio(scoreSound, waitForCompletion: false)
        node.runAction(action)
    }
    
    @IBAction func didTap(_ sender: UITapGestureRecognizer) {
        //guard let hatNodes = hatNodes?.presentation else { return }
        //print("Tapped")
        if isHatPlaced == false {
            if planes.count > 0 {
            // Get tap location
            let tapLocation = sender.location(in: sceneView)
            
            // Perform hit test
            let results = sceneView.hitTest(tapLocation, types: .existingPlaneUsingExtent)
            
            // If a hit was received, get position of
            if let result = results.first {
                placeHat(result)
            }
            isHatPlaced = true
            cornerText.text = "tap to shoot!"
            self.sceneView.debugOptions = []
            for i in planes {
                i.removeFromParentNode()
            }
            } else {print("no plane detected")}
            
        } else {
            //print("hat is placed")
            cornerText.text = ""
            placeBall()
        }
        
    }
    
    private func placeHat(_ result: ARHitTestResult) {
        
        // Get transform of result
        let transform = result.worldTransform
        
        // Get position from transform (4th column of transformation matrix)
        let planePosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        
        // Add door
        let hatNode = createHatFromScene(planePosition)!
        hatNodes = hatNode
        sceneView.scene.rootNode.addChildNode(hatNode)
        bodyAppear("hat")
        let mainhat = sceneView.scene.rootNode.childNode(withName: "mainHat", recursively: true)
        hatBound = mainhat?.presentation
    }
    
    private func bodyAppear(_ name: String) {
        let node = sceneView.scene.rootNode.childNode(withName: name, recursively: true)
        SCNTransaction.begin()
        node?.opacity = 1
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.commit()
    }
    
    private func createHatFromScene(_ position: SCNVector3) -> SCNNode? {
        guard let url = Bundle.main.url(forResource: "art.scnassets/magichat", withExtension: "scn") else {
            NSLog("Could not find door scene")
            return nil
        }
        guard let node = SCNReferenceNode(url: url) else { return nil }
        
        node.load()
        // Position scene
        node.position = position
        
        return node
    }
    
    private func placeBall() {

        
        let camera = self.sceneView.pointOfView!
        let sphereNode = createBall()
        let position = SCNVector3(x: 0, y: 0, z: -0.1)
        sphereNode?.position = camera.convertPosition(position, to: nil)
        sphereNode?.rotation = camera.rotation
        
        sphereNode?.physicsBody?.applyForce(getBallDirection(-3.5)!, asImpulse: true)
        balls.append(sphereNode!)
        sceneView.scene.rootNode.addChildNode(sphereNode!)
        
    }
    
    private func getBallDirection(_ speed: Float) -> SCNVector3? {
                let camera = sceneView.session.currentFrame?.camera
                let cameraTransform = camera?.transform
                var translation = matrix_identity_float4x4
                translation.columns.3.z = speed
                let result = matrix_multiply(cameraTransform!,translation)
                let newResult = SCNVector3Make(result.columns.3.x, result.columns.3.y, result.columns.3.z)
                return newResult
    }
    
    private func createBall() -> SCNNode? {
        let sphere = SCNSphere(radius: 0.02)
        let node = SCNNode(geometry: sphere)
        node.physicsBody = SCNPhysicsBody.dynamic()
        node.physicsBody?.rollingFriction = 0.2
        //node.position = position
        return node
    }
    
    private func addParticleEffects(_ object: String){
        let hat = sceneView.scene.rootNode.childNode(withName: object, recursively: true)
        let bink = SCNParticleSystem(named: "binkEffect", inDirectory: nil)
        hat?.addParticleSystem(bink!)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // Create an SCNNode for a detect ARPlaneAnchor
        guard let _ = anchor as? ARPlaneAnchor else {
            return nil
        }
        planeNode = SCNNode()
        return planeNode
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Create an SNCPlane on the ARPlane
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        
        let planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.3)
        plane.materials = [planeMaterial]
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
        // if plane > 1 deletes get only the lastest one
        if planes.count > 1 {
            for i in planes {
                i.removeFromParentNode()
            }
        }
        if isHatPlaced == false {
        planes.append(planeNode)
        node.addChildNode(planeNode)
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.cornerText.text = "plane detected!"
            self.mainText.text = "tap to place Magic Hat"
        }
        textDelay(3.0, "", mainText, true)
        }
    }
    
    private func textDelay(_ time: Double, _ text: String, _ uiText: UILabel, _ hidden: Bool = false) {
        let delayInSeconds = time
        DispatchQueue.main.asyncAfter(deadline: .now() + delayInSeconds) {
            uiText.text = text
            uiText.isHidden = true
        }
    }
    
    // MARK: - ARSCNViewDelegate
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .notAvailable:
            print("error")
            cornerText.text = "AR tracking is not Available"
        case .limited:
            trackingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false, block: { _ in
                session.run(AROrientationTrackingConfiguration())
                self.trackingTimer?.invalidate()
                self.trackingTimer = nil
            })
        case .normal:
            if trackingTimer != nil {
                trackingTimer!.invalidate()
                trackingTimer = nil
            }
        }
    }
    
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}

extension SCNNode {
    func boundingBoxContains(point: SCNVector3, in node: SCNNode) -> Bool {
        let localPoint = self.convertPosition(point, from: node)
        return boundingBoxContains(point: localPoint)
    }
    
    func boundingBoxContains(point: SCNVector3) -> Bool {
        return BoundingBox(self.boundingBox).contains(point)
    }
}
struct BoundingBox {
    let min: SCNVector3
    let max: SCNVector3
    
    init(_ boundTuple: (min: SCNVector3, max: SCNVector3)) {
        min = boundTuple.min
        max = boundTuple.max
    }
    
    func contains(_ point: SCNVector3) -> Bool {
        let contains =
            min.x <= point.x &&
                min.y <= point.y &&
                min.z <= point.z &&
                
                max.x > point.x &&
                max.y > point.y &&
                max.z > point.z
        
        return contains
    }
}
