//
//  CustomSphere.swift
//  BodyDetection
//
//  Created by Oleksandr Polishchuk on 14.01.2021.
//  Copyright © 2021 Apple. All rights reserved.
//

import UIKit
import RealityKit

class CustomSphere: Entity, HasModel {
     required init(color: UIColor, radius: Float) {
       super.init()
       self.components[ModelComponent] = ModelComponent(
         mesh: .generateSphere(radius: radius),
         materials: [SimpleMaterial(
           color: color,
           isMetallic: false)
         ]
       )
     }
    
    required init() {
        fatalError("init() has not been implemented")
    }
}
