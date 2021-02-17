//
//  ViewController.swift
//  BodyDetection
//
//  Created by Oleksandr Polishchuk on 14.01.2021.
//  Copyright © 2021 Apple. All rights reserved.
//

import UIKit
import ARKit
import RealityKit

class ViewController: UIViewController {
    @IBOutlet var arView: ARView!
    @IBOutlet weak var joints2DButton: UIButton!
    @IBOutlet weak var joints3DButton: UIButton!
    @IBOutlet weak var bodyAnchorPresenceLabel: UILabel!
    var warningLabel: UILabel!
    
    var jointDots2D = [CAShapeLayer]()
    var jointDots3D = [Entity]()
    let sphereAnchor = AnchorEntity()
    
    private var jointTrackWarning: String? {
        didSet {
            warningLabel.text = jointTrackWarning
        }
    }
    
    private var isBodyAnchorPresent: Bool! {
        didSet {
            bodyAnchorPresenceLabel.text = "Body anchor presence: \(isBodyAnchorPresent!)"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addWarningLabel()
        isBodyAnchorPresent = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arView.session.delegate = self

        // If the iOS device doesn't support body tracking, raise a developer error for
        // this unhandled case.
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }

        // Run a body tracking configration.
        let configuration = ARBodyTrackingConfiguration()
        arView.session.run(configuration)
        
        // 3D Skeleton
        arView.scene.addAnchor(sphereAnchor)
    }

    @IBAction func showJoints2D(_ sender: Any) {
        joints2DButton.isSelected = !joints2DButton.isSelected
    }
    
    @IBAction func showJoints3D(_ sender: Any) {
        joints3DButton.isSelected = !joints3DButton.isSelected
    }
    
    @IBAction func clearSkeleton(_ sender: Any) {
        joints2DButton.isSelected = false
        joints3DButton.isSelected = false
    }
}

extension ViewController: ARSessionDelegate {
    // Soft validation in 2D
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let defaultDefinition = ARSkeletonDefinition.defaultBody2D
        guard let skeleton = frame.detectedBody?.skeleton else { return }

        var untrackedJointsAvailable = false
        var untrackedJoints = [String]()
        hideJoints2D()

        for jointName in defaultDefinition.jointNames {
            // From documentation:
            // ARKit names particular joints that are crucial to body tracking. You can access named joints by calling index(forJointName:) and passing in one of the available jointNames identifiers.
            let jointIndex = defaultDefinition.index(for: ARSkeleton.JointName(rawValue: jointName))

            if !skeleton.isJointTracked(jointIndex) {
                untrackedJointsAvailable = true
                untrackedJoints.append(jointName)
            } else {
                // If joint is tracked then draw it (but such option should also be enabled)
                if joints2DButton.isSelected {
                    drawJointPoint2D(with: jointIndex, from: skeleton, in: frame, color: UIColor.green)
                }
            }
        }

        if !untrackedJointsAvailable {
            jointTrackWarning = "Everything is fine!"
            isBodyAnchorPresent = true
            let configuration = ARBodyTrackingConfiguration()
            arView.session.run(configuration, options: .resetTracking)
        } else {
            jointTrackWarning = "Untracked joints:\n" + untrackedJoints.joined(separator: "\n")
            let configuration = ARBodyTrackingConfiguration()
            arView.session.run(configuration, options: .removeExistingAnchors)
        }
    }
    
    // Soft validation in 3D
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let defaultDefinition = ARSkeletonDefinition.defaultBody3D
        var isBodyAnchorPresent = false
        for anchor in anchors {
            guard anchor is ARBodyAnchor else { continue }
            
            isBodyAnchorPresent = true
            hideJoints3D()
            
            for jointName in defaultDefinition.jointNames {
                if joints3DButton.isSelected {
//                    drawJointPoint3D(with: jointName, bodyAnchor: bodyAnchor)
                }
            }
        }
        
        self.isBodyAnchorPresent = isBodyAnchorPresent
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if anchor is ARBodyAnchor {
                isBodyAnchorPresent = false
            }
        }
    }
}

private extension ViewController {
    func drawJointPoint2D(with index: Int, from skeleton: ARSkeleton2D, in frame: ARFrame, color: UIColor) {
        let transform = frame.displayTransform(for: .portrait, viewportSize: arView.frame.size)
        let normalizedCenter = CGPoint(x: CGFloat(skeleton.jointLandmarks[index][0]), y: CGFloat(skeleton.jointLandmarks[index][1])).applying(transform)
        let center = normalizedCenter.applying(CGAffineTransform.identity.scaledBy(x: arView.frame.width, y: arView.frame.height))
        let circleWidth: CGFloat = 10
        let circleHeight: CGFloat = 10
        let rect = CGRect(origin: CGPoint(x: center.x - circleWidth/2, y: center.y - circleHeight/2), size: CGSize(width: circleWidth, height: circleHeight))
        let circleLayer = CAShapeLayer()
        circleLayer.fillColor = color.cgColor
        circleLayer.path = UIBezierPath(ovalIn: rect).cgPath
        view.layer.addSublayer(circleLayer)
        jointDots2D.append(circleLayer)
    }
    
    func drawJointPoint3D(with jointName: String, bodyAnchor: ARBodyAnchor) {
        guard let transform = bodyAnchor.skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: jointName)) else { return }
        
        let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
        let bodyOrientation = Transform(matrix: bodyAnchor.transform).rotation
        
        let position = bodyPosition + simd_make_float3(transform.columns.3)
        let newSphere = CustomSphere(color: .blue, radius: 0.025)
        newSphere.transform = Transform(scale: [1, 1, 1], rotation: bodyOrientation, translation: position)
        
        sphereAnchor.addChild(newSphere, preservingWorldTransform: true)
        jointDots3D.append(newSphere)
    }

    func hideJoints2D() {
        jointDots2D.forEach {
            $0.removeFromSuperlayer()
        }
        jointDots2D.removeAll()
    }
    
    func hideJoints3D() {
        jointDots3D.forEach {
            $0.removeFromParent()
        }
        jointDots3D.removeAll()
    }

    func addWarningLabel() {
        warningLabel = UILabel()
        warningLabel.font = UIFont.preferredFont(forTextStyle: .body)
        warningLabel.textColor = .black
        warningLabel.textAlignment = .center
        warningLabel.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        warningLabel.numberOfLines = 0
        warningLabel.lineBreakMode = .byWordWrapping
        
        view.addSubview(warningLabel)
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        warningLabel.widthAnchor.constraint(equalToConstant:  350).isActive = true
        warningLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: warningLabel.bottomAnchor, constant: 10).isActive = true
    }
}
