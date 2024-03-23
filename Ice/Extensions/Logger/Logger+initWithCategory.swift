//
//  Logger+initWithCategory.swift
//  Ice
//

import Foundation
import OSLog

extension Logger {
    /// Creates a logger using the default subsystem and the
    /// specified category.
    ///
    /// - Parameter category: The string that the system uses
    ///   to categorize emitted signposts.
    init(category: String) {
        self.init(subsystem: Constants.bundleIdentifier, category: category)
    }
}
