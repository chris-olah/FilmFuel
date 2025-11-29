//
//  AppRoute.swift
//  FilmFuel
//
//  Enhanced with more routing options
//

import Foundation
import UserNotifications

// MARK: - App Route

enum AppRoute: Hashable, Codable {
    case home
    case quiz
    case discover
    case stats
    case settings
    case tipJar
    case paywall
    case achievements
    case profile
    case movieDetail(movieId: Int)
    
    var deepLinkPath: String {
        switch self {
        case .home: return "home"
        case .quiz: return "quiz"
        case .discover: return "discover"
        case .stats: return "stats"
        case .settings: return "settings"
        case .tipJar: return "tipjar"
        case .paywall: return "plus"
        case .achievements: return "achievements"
        case .profile: return "profile"
        case .movieDetail(let id): return "movie/\(id)"
        }
    }
    
    static func from(deepLink: String) -> AppRoute? {
        let path = deepLink.lowercased()
        
        switch path {
        case "home", "": return .home
        case "quiz": return .quiz
        case "discover": return .discover
        case "stats": return .stats
        case "settings": return .settings
        case "tipjar": return .tipJar
        case "plus", "upgrade", "paywall": return .paywall
        case "achievements": return .achievements
        case "profile": return .profile
        default:
            // Check for movie detail
            if path.hasPrefix("movie/"),
               let idString = path.split(separator: "/").last,
               let id = Int(idString) {
                return .movieDetail(movieId: id)
            }
            return nil
        }
    }
}

// MARK: - Route Inbox (for cold launch routing)

final class FFRouteInbox {
    static let shared = FFRouteInbox()
    
    private let key = "ff.pendingRoute"
    
    private init() {}
    
    func store(_ route: String) {
        UserDefaults.standard.set(route, forKey: key)
    }
    
    func consume() -> String? {
        guard let route = UserDefaults.standard.string(forKey: key) else { return nil }
        UserDefaults.standard.removeObject(forKey: key)
        return route
    }
    
    func peek() -> String? {
        UserDefaults.standard.string(forKey: key)
    }
}

// MARK: - Notification Manager

final class FFNotificationManager {
    static let shared = FFNotificationManager()
    
    private init() {}
    
    func configure() {
        // Setup notification categories and actions
        let quizAction = UNNotificationAction(
            identifier: "OPEN_QUIZ",
            title: "Start Quiz",
            options: [.foreground]
        )
        
        let shareAction = UNNotificationAction(
            identifier: "SHARE_QUOTE",
            title: "Share Quote",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Later",
            options: []
        )
        
        let quizCategory = UNNotificationCategory(
            identifier: "QUIZ_REMINDER",
            actions: [quizAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        let quoteCategory = UNNotificationCategory(
            identifier: "QUOTE_REMINDER",
            actions: [shareAction, quizAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        let streakCategory = UNNotificationCategory(
            identifier: "STREAK_WARNING",
            actions: [quizAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            quizCategory,
            quoteCategory,
            streakCategory
        ])
    }
    
    func handleNotificationAction(_ actionIdentifier: String) {
        switch actionIdentifier {
        case "OPEN_QUIZ":
            FFRouteInbox.shared.store("quiz")
            NotificationCenter.default.post(name: .filmFuelOpenQuiz, object: nil)
            
        case "SHARE_QUOTE":
            FFRouteInbox.shared.store("share-quote")
            NotificationCenter.default.post(name: .filmFuelShareQuote, object: nil)
            
        default:
            break
        }
    }
}
