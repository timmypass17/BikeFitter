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
        imageView.layer.borderColor = UIColor.blue.cgColor
        imageView.layer.borderWidth = 2
        return imageView
    }()
    
    let overlayView: OverlayView = {
        let view = OverlayView()
        view.backgroundColor = UIColor.clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let stackView: UIStackView = {
        let vstack = UIStackView()
        vstack.axis = .vertical
        vstack.translatesAutoresizingMaskIntoConstraints = false
        return vstack
    }()
    
    let kneeAngleText: UILabel = {
        let label = UILabel()
        label.text = "Knee:"
        return label
    }()
    
    let hipAngleText: UILabel = {
        let label = UILabel()
        label.text = "Hip:"
        return label
    }()
    // arm, armpit
    
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
        
        stackView.addArrangedSubview(kneeAngleText)
        stackView.addArrangedSubview(hipAngleText)

        view.addSubview(imageView)
        view.addSubview(overlayView)
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 300),
            
            overlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: imageView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
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
        observations.forEach { processObservation($0) } // Should only be 1 for image?
        
        DispatchQueue.main.async {
            self.jointPoints.keys.forEach { self.jointPoints[$0] = self.convertPointToOverlay(point: self.jointPoints[$0]!) }
            self.overlayView.jointPoints = self.jointPoints
            self.overlayView.setNeedsDisplay()
            
            for (joint, point) in self.jointPoints {
                print("\(joint.rawValue) - \(point)")
            }
            
            guard let knee = self.jointPoints[.rightKnee],
                  let hip = self.jointPoints[.rightHip],
                  let foot = self.jointPoints[.rightAnkle],
                  let shoulder = self.jointPoints[.rightShoulder]
            else {
                return
            }
            
            let kneeAngle = self.angleBetween(jointA: hip, jointB: knee, jointC: foot)
            let hipAngle = self.angleBetween(jointA: shoulder, jointB: hip, jointC: knee)
            self.kneeAngleText.text = "Knee: \(kneeAngle)"  // 141
            self.hipAngleText.text = "Hip: \(hipAngle)"
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
    
    func angleBetween(jointA: CGPoint, jointB: CGPoint, jointC: CGPoint) -> CGFloat {
        // Create vectors
        let thigh = CGVector(dx: jointA.x - jointB.x, dy: jointA.y - jointB.y)
        let shin = CGVector(dx: jointC.x - jointB.x, dy: jointC.y - jointB.y)

        // Dot product and magnitudes
        let dotProduct = thigh.dx * shin.dx + thigh.dy * shin.dy
        let magnitudeThigh = sqrt(thigh.dx * thigh.dx + thigh.dy * thigh.dy)
        let magnitudeShin = sqrt(shin.dx * shin.dx + shin.dy * shin.dy)

        // Clamp the value between -1 and 1 to avoid NaN from acos
        let cosAngle = max(-1.0, min(1.0, dotProduct / (magnitudeThigh * magnitudeShin)))

        // Angle in radians
        let angle = acos(cosAngle)

        // Convert to degrees
        return angle * 180 / .pi
    }
}

class OverlayView: UIView {
    
    // Points detected that need to be drawn.
    var jointPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    
    override func draw(_ rect: CGRect) {
        print("Draw")
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext(), jointPoints.count > 0 else {
            return
        }
        
        drawLegArc(context)
        drawHipArc(context)
        drawArmArc(context)
        drawJointConnections(context)
        drawJointPoints(context)
    }
    
    func drawJointPoints(_ context: CGContext) {
        // Draw circles for each joint.
        context.setFillColor(UIColor.white.cgColor)
        let radius: CGFloat = 3.0
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
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
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
    
    func drawLegArc(_ context: CGContext) {
        print("Draw leg")
        guard let hip = jointPoints[.rightHip],
              let knee = jointPoints[.rightKnee],
              let foot = jointPoints[.rightAnkle] else {
            return
        }
        
        let result = drawAngleArc(context: context, jointA: hip, jointB: knee, jointC: foot, clockwise: false)
        drawAngleText(context: context, centerPoint: knee, startAngle: result.startAngle, sweepAngle: result.sweepAngle, radius: result.radius, offset: 30)
    }
    
    func drawHipArc(_ context: CGContext) {
        print("Draw hip")
        guard let shoulder = jointPoints[.rightShoulder],
              let hip = jointPoints[.rightHip],
              let knee = jointPoints[.rightKnee] else {
            return
        }
        
        let result = drawAngleArc(context: context, jointA: shoulder, jointB: hip, jointC: knee, clockwise: true)
        drawAngleText(context: context, centerPoint: hip, startAngle: result.startAngle, sweepAngle: result.sweepAngle, radius: result.radius, offset: 10)
    }
    
    func drawArmArc(_ context: CGContext) {
        print("Draw Arm")
        guard let shoulder = jointPoints[.rightShoulder],
              let elbow = jointPoints[.rightElbow],
              let wrist = jointPoints[.rightWrist] else {
            return
        }
        
        let result = drawAngleArc(context: context, jointA: shoulder, jointB: elbow, jointC: wrist, clockwise: true)
        drawAngleText(context: context, centerPoint: elbow, startAngle: result.startAngle, sweepAngle: result.sweepAngle, radius: result.radius, offset: 10)
    }
    
    func drawAngleArc(context: CGContext, jointA: CGPoint, jointB: CGPoint, jointC: CGPoint, clockwise: Bool) -> ArcResult {
        // Compute raw angles (in radians) for the vectors: jointB -> jointA and jointB -> jointC.
        // atan2 gives the angle from the x-axis to the line connecting the points, in the range (−π, π].
        print("jointA: \(jointA)")
        print("jointB: \(jointB)")
        print("jointC: \(jointC)")
        let angleA = atan2(jointA.y - jointB.y, jointA.x - jointB.x)
        let angleC = atan2(jointC.y - jointB.y, jointC.x - jointB.x)
        print("angleA: \(angleA) -> \(convertToDegrees(radians: angleA))")
        print("angleC: \(angleC) -> \(convertToDegrees(radians: angleC))")
        // Helper: Normalize an angle to [0, 2π)
        // Ensures the angle is in the range [0, 2π), making it easier to reason about direction and compare angles.
        func normalizeAngle(_ angle: CGFloat) -> CGFloat {
            var a = angle
            while a < 0 {
                a += 2 * .pi
            }
            while a >= 2 * .pi {
                a -= 2 * .pi
            }
            return a
        }
        
        // These are the normalized angles to ensure they’re always positive and within 0 to 2π.
        let normAngleA = normalizeAngle(angleA)
        let normAngleC = normalizeAngle(angleC)
        
        print("normalAngleA: \(normAngleA) -> \(convertToDegrees(radians: normAngleA))")
        print("normalAngleC: \(normAngleC) -> \(convertToDegrees(radians: normAngleC))")

        // Compute the difference (the sweep) in the clockwise direction.
        // The sweep angle is how much the arc should "sweep" from the start angle to the end.
        // - It calculates the interior angle at jointB between the limbs.
        // - Ensures it’s the smaller angle (always ≤ 180° or π radians).
        var sweepAngle = normAngleC - normAngleA    // sweepAngle (radians) is actual angle of joints
        if sweepAngle < 0 {
            sweepAngle += 2 * .pi
        }
        // To get the smaller (interior) angle, adjust if needed.
        if sweepAngle > .pi {
            sweepAngle = 2 * .pi - sweepAngle
        }
        
        print("sweepAngle: \(sweepAngle) -> \(convertToDegrees(radians: sweepAngle))")
        // Choose radius based on smaller limb length
        let limbLength = distanceBetweenPoints(jointA, jointB)
        let otherLimbLength = distanceBetweenPoints(jointC, jointB)
        let radius: CGFloat = min(limbLength, otherLimbLength) * 0.75

        // Filled wedge path
        let fillPath = UIBezierPath()
        fillPath.move(to: jointB)
        fillPath.addArc(withCenter: jointB,
                        radius: radius,
                        startAngle: normAngleA,
                        endAngle: normAngleC,
                        clockwise: clockwise)
        fillPath.close()

        let fillColor = UIColor.green.withAlphaComponent(0.4)
        fillColor.setFill()
        fillPath.fill()

        // Outer arc stroke only
        let arcPath = UIBezierPath(arcCenter: jointB,
                                   radius: radius,
                                   startAngle: normAngleA,
                                   endAngle: normAngleC,
                                   clockwise: clockwise)
        UIColor.green.setStroke()
        arcPath.lineWidth = 2.0
        arcPath.stroke()

        return ArcResult(startAngle: clockwise ? normAngleA : normAngleC, sweepAngle: sweepAngle, radius: radius)
    }
    
    struct ArcResult {
        var startAngle: CGFloat
        var sweepAngle: CGFloat
        var radius: CGFloat
    }
    
    func drawAngleText(context: CGContext, centerPoint: CGPoint, startAngle: CGFloat, sweepAngle: CGFloat, radius: CGFloat, offset: CGFloat = 0) {
        // Calculate the mid angle from the start angle and half the sweep.
        let midAngle = startAngle + (sweepAngle / 2)
        print("midAngle: \(midAngle) -> \(convertToDegrees(radians: midAngle))")
        
        // Compute the preliminary label position along the polar coordinate.
        // You can adjust the multiplier (here it's divided by 2) to position the label as needed.
        let labelRadius = radius / 2
        let preliminaryLabelPoint = CGPoint(x: centerPoint.x + (labelRadius * cos(midAngle)),
                                            y: centerPoint.y + (labelRadius * sin(midAngle)))
        
        // Create the angle text.
        let angleText = "\(Int(convertToDegrees(radians: sweepAngle)))°"
        
        // Define text attributes.
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        
        // Measure the size of the text.
        let textSize = angleText.size(withAttributes: attributes)
        
        // Adjust the label point so that the text is centered at the preliminaryLabelPoint.
        let centeredLabelPoint = CGPoint(x: preliminaryLabelPoint.x - (textSize.width / 2),
                                         y: preliminaryLabelPoint.y - (textSize.height / 2))
        
        // Draw the text at the adjusted point.
        angleText.draw(at: centeredLabelPoint, withAttributes: attributes)
    }
    
    func distanceBetweenPoints(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        // Calculate the horizontal and vertical differences.
        let deltaX = point1.x - point2.x
        let deltaY = point1.y - point2.y
        
        // Use the Pythagorean theorem to return the distance.
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
    
    func convertToDegrees(radians: CGFloat) -> CGFloat {
        return radians * (180 / .pi)
    }
}
