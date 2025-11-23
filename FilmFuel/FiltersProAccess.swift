//
//  FiltersProAccess.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/22/25.
//

import Foundation
import Combine

@MainActor
final class FiltersProAccess: ObservableObject {
    static let shared = FiltersProAccess()

    @Published private(set) var isUnlocked: Bool

    private let key = "ff.filters.proUnlocked"

    private init() {
        self.isUnlocked = UserDefaults.standard.bool(forKey: key)
    }

    func markUnlocked() {
        isUnlocked = true
        UserDefaults.standard.set(true, forKey: key)
    }
}
