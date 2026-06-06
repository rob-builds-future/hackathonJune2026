//
//  TitleGenerating.swift
//  Novi
//
//  Abstraction for generating a short title from a journal entry.
//

import Foundation

/// Produces a short, human-readable title for a journal entry.
///
/// Used to fill in a title automatically when the user leaves the title field
/// empty. ``AILessonService`` provides the real implementation;
/// ``MockLessonService`` provides an offline fallback.
protocol TitleGenerating {
    /// Generates a concise title (a few words) for the given entry text.
    func generateTitle(from entry: String) async throws -> String
}
