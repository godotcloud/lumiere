//
//  AppSettings.swift
//  Lumiere
//

import Combine
import Foundation

final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    @Published var saveToLibrary: Bool {
        didSet { defaults.set(saveToLibrary, forKey: Key.saveToLibrary) }
    }

    @Published var mirrorFrontCamera: Bool {
        didSet { defaults.set(mirrorFrontCamera, forKey: Key.mirror) }
    }

    @Published var showGrid: Bool {
        didSet { defaults.set(showGrid, forKey: Key.grid) }
    }

    @Published var showLevel: Bool {
        didSet { defaults.set(showLevel, forKey: Key.level) }
    }

    @Published var haptics: Bool {
        didSet { defaults.set(haptics, forKey: Key.haptics) }
    }

    private enum Key {
        static let saveToLibrary = "settings.saveToLibrary"
        static let mirror = "settings.mirrorFrontCamera"
        static let grid = "settings.showGrid"
        static let level = "settings.showLevel"
        static let haptics = "settings.haptics"
    }

    private var defaults: UserDefaults { .standard }

    private init() {
        saveToLibrary = defaults.object(forKey: Key.saveToLibrary) as? Bool ?? true
        mirrorFrontCamera = defaults.object(forKey: Key.mirror) as? Bool ?? false
        showGrid = defaults.object(forKey: Key.grid) as? Bool ?? true
        showLevel = defaults.object(forKey: Key.level) as? Bool ?? true
        haptics = defaults.object(forKey: Key.haptics) as? Bool ?? true
    }
}
