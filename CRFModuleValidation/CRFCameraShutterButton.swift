//
//  CRFCameraShutterButton.swift
//  CRFModuleValidation
//
//  Copyright © 2017 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import UIKit

@IBDesignable
public class CRFCameraShutterButton: UIButton {
    
    @IBInspectable
    public var ringColor: UIColor = UIColor.appDarkGrayText {
        didSet {
            ringLayer?.strokeColor = ringColor.cgColor
        }
    }
    
    @IBInspectable
    public var ringWidth: CGFloat = 2 {
        didSet {
            ringLayer?.lineWidth = ringWidth
        }
    }
    
    // MARK: Initialize with constraints
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        layer.masksToBounds = false
        self.backgroundColor = UIColor.white
        self.heightAnchor.constraint(equalTo: self.widthAnchor, multiplier: 1.0, constant: 0.0).isActive = true
    }
    
    // MARK: Draw the dial
    
    private var ringLayer: CAShapeLayer!
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        layer.cornerRadius = bounds.width / 2
        
        if (ringLayer == nil) {
            let inset: CGFloat = 6
            let ringBounds = layer.bounds.insetBy(dx: inset, dy: inset)
            ringLayer = CAShapeLayer()
            ringLayer.path = UIBezierPath(ovalIn: ringBounds).cgPath
            layer.addSublayer(ringLayer)
        }
        
        ringLayer.frame = layer.bounds
        
        _updateLayerProperties()
    }
    
    private func _updateLayerProperties() {
        
        layer.masksToBounds = true
        backgroundColor = UIColor.white
        
        ringLayer?.lineWidth = ringWidth
        ringLayer?.strokeColor = ringColor.cgColor
        ringLayer?.fillColor = UIColor.clear.cgColor
    }
}
