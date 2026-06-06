//
//  LessonGenerating.swift
//  Novi
//
//  Abstraction over whatever produces a Lesson from a journal entry.
//

import Foundation

/// Produces a ``Lesson`` from a raw journal entry.
///
/// The UI depends only on this protocol, never on a concrete implementation.
/// Today the app ships ``MockLessonService``; later an `OpenAILessonService`
/// or `LocalLLMLessonService` can conform to the same contract and be swapped
/// in with zero changes to the views or view model.
///
/// The method is `async throws` from day one so that adding a real network or
/// on-device model call does not change the call site.
protocol LessonGenerating {
    /// Generates a lesson for the given journal entry.
    /// - Parameter entry: The user's raw, multiline journal text.
    /// - Returns: A fully populated ``Lesson``.
    func generateLesson(from entry: String) async throws -> Lesson
}
