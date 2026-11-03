//
//  MotionLevel.swift
//  Lumiere
//
//  Roll angle for the horizon indicator. A level line is the cheapest way to
//  make handheld shots look like they were taken on a tripod.
//

import Combine
import CoreMotion

final class MotionLevel: ObservableObject {

    @Published private(set) var roll: Double = 0

    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 50.0

        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let gravity = motion?.gravity else { return }

            // Phones held flat give a meaningless roll — park the line.
            if abs(gravity.z) > 0.82 {
                self.roll = 0
                return
            }

            let radians = atan2(gravity.x, -gravity.y)
            var degrees = radians * 180 / .pi
            degrees = min(max(degrees, -35), 35)
            self.roll = degrees
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        roll = 0
    }
}
