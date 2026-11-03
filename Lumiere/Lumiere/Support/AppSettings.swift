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

    private let defaults: UserDefaults

    private init() {
        // Read through a local first: touching `self.defaults` here would be a
        // use of `self` before every stored property is initialised.
        let store = UserDefaults.standard
        defaults = store

        saveToLibrary = store.object(forKey: Key.saveToLibrary) as? Bool ?? true
        mirrorFrontCamera = store.object(forKey: Key.mirror) as? Bool ?? false
        showGrid = store.object(forKey: Key.grid) as? Bool ?? true
        showLevel = store.object(forKey: Key.level) as? Bool ?? true
        haptics = store.object(forKey: Key.haptics) as? Bool ?? true
    }
}
