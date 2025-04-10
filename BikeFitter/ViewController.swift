//
//  ViewController.swift
//  BikeFitter
//
//  Created by Timmy Nguyen on 4/9/25.
//

import UIKit
import Vision

class ViewController: UIViewController {

    let imageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "sample"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let overlayView: OverlayView = {
        let view = OverlayView()
        view.backgroundColor = UIColor.clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    var jointPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [
        .rightEar: .zero,
        .rightHip: .zero,
        .rightKnee: .zero,
        .rightAnkle: .zero,
        .rightElbow: .zero,
        .rightWrist: .zero,
        .rightShoulder: .zero,
//        .root, .neck
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(imageView)
        view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),
            
            overlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
        ])
        
        startBikeFitting()
    }
    
    func startBikeFitting() {
        guard let uiImage = imageView.image,
              let cgImage = uiImage.cgImage else { return }
        
        // Create a new image-request handler.
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        // Create a new request to recognize a human body pose.
        let request = VNDetectHumanBodyPoseRequest(completionHandler: bodyPoseHandler)
        do {
            // Perform the body pose-detection request.
            try requestHandler.perform([request])
        } catch {
            print("Unable to perform the request: \(error).")
        }
    }

    func bodyPoseHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNHumanBodyPoseObservation] else { return }
        
        // Process each observation to find the recognized body pose points.
        observations.forEach { processObservation($0) }
        
        DispatchQueue.main.async {
            self.jointPoints.keys.forEach { self.jointPoints[$0] = self.convertPointToOverlay(point: self.jointPoints[$0]!) }
            self.overlayView.jointPoints = self.jointPoints
            self.overlayView.setNeedsDisplay()
        }
    }
    
    /// Processes a body pose observation to extract torso points.
    func processObservation(_ observation: VNHumanBodyPoseObservation) {
        guard let width = imageView.image?.size.width, let height = imageView.image?.size.height else { return }
        // Retrieve all points.
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
        
        // Retrieve the image points by converting normalized points to image coordinates.
        for joint in jointPoints.keys {
            guard let point = recognizedPoints[joint], point.confidence > 0 else { continue }
            // Can't convert here, layout not finished
            jointPoints[joint] = VNImagePointForNormalizedPoint(point.location, Int(width), Int(height))
        }
    }
    
    /// Converts image-based points into overlay view (imageView) coordinates.
    /// Since the imageView is set to .scaleAspectFit, we need to perform a coordinate conversion.
    func convertPointToOverlay(point: CGPoint) -> CGPoint {
        guard let width = imageView.image?.size.width, let height = imageView.image?.size.height else { return .zero }
        let imageViewSize = imageView.bounds.size
        let scale = min(imageViewSize.width / width,
                        imageViewSize.height / height)
        let imageWidthScaled = width * scale
        let imageHeightScaled = height * scale

        // Calculate offsets to center the image.
        let xOffset = (imageViewSize.width - imageWidthScaled) / 2.0
        let yOffset = (imageViewSize.height - imageHeightScaled) / 2.0

        // Map the point to the overlay's coordinate system.
        let x = point.x * scale + xOffset
        let y = (height - point.y) * scale + yOffset
        return CGPoint(x: x, y: y)
    }
}

class OverlayView: UIView {
    
    // Points detected that need to be drawn.
    var jointPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext(), jointPoints.count > 0 else {
            return
        }
                
        drawJointConnections(context)
        drawJointPoints(context)
    }
    
    func drawJointPoints(_ context: CGContext) {
        // Draw circles for each joint.
        context.setFillColor(UIColor.red.cgColor)
        let radius: CGFloat = 4.0
        for point in jointPoints.values {
            let circleRect = CGRect(x: point.x - radius,
                                    y: point.y - radius,
                                    width: radius * 2,
                                    height: radius * 2)
            context.fillEllipse(in: circleRect)
        }
    }
    
    func drawJointConnections(_ context: CGContext) {

        guard let rightEar = jointPoints[.rightEar] else {
            print("Missing right ear")
            return
        }

        guard let rightHip = jointPoints[.rightHip] else {
            print("Missing right hip")
            return
        }

        guard let rightKnee = jointPoints[.rightKnee] else {
            print("Missing right knee")
            return
        }

        guard let rightAnkle = jointPoints[.rightAnkle] else {
            print("Missing right ankle")
            return
        }

        guard let rightElbow = jointPoints[.rightElbow] else {
            print("Missing right elbow")
            return
        }

        guard let rightWrist = jointPoints[.rightWrist] else {
            print("Missing right wrist")
            return
        }

        guard let rightShoulder = jointPoints[.rightShoulder] else {
            print("Missing right shoulder")
            return
        }
        
        // Draw lines connecting each joint in order.
        context.setStrokeColor(UIColor.green.cgColor)
        context.setLineWidth(2.0)
        context.beginPath()
        // Move to the first point.
        context.move(to: rightEar)
        context.addLine(to: rightShoulder)
        context.addLine(to: rightElbow)
        context.addLine(to: rightWrist)
        
        context.move(to: rightShoulder)
        context.addLine(to: rightHip)
        context.addLine(to: rightKnee)
        context.addLine(to: rightAnkle)
        
        context.strokePath()
    }
}
