//
//  EntryInputPane.swift
//  Novi
//
//  Left pane of the editor: title, journal text, languages, last-saved status.
//

import SwiftUI

/// The input side of the editor. Binds directly to the record so edits
/// auto-save through the view model.
struct EntryInputPane: View {
    @Bindable var entry: JournalEntryRecord
    let viewModel: EntryEditorViewModel
    let onDelete: () -> Void
    @State private var isDatePickerPresented = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .top, spacing: Spacing.small) {
                TextField("Title", text: $entry.title)
                    .font(Typography.title)
                    .textFieldStyle(.plain)
                    .foregroundStyle(DesignColors.textPrimary)

                if !entry.isEmpty {
                    deleteButton
                }
            }

            HStack(spacing: Spacing.xSmall) {
                journalDateButton

                if !entry.isEmpty {
                    Text(savedStatus)
                        .font(Typography.caption)
                        .foregroundStyle(DesignColors.textMuted)
                }
            }

            Divider()
                .overlay(DesignColors.separator)

            TextEditor(text: $entry.sourceText)
                .font(Typography.body)
                .foregroundStyle(DesignColors.textPrimary)
                .scrollContentBackground(.hidden)
                .background(DesignColors.surfaceInset.opacity(0.72), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
                .frame(maxHeight: .infinity)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(DesignColors.glassStroke, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(DesignColors.focusRing.opacity(0.26), lineWidth: 1)
                        .padding(2)
                )
                .shadow(color: DesignColors.shadow, radius: 14, x: 0, y: 8)

            languagePickers
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignColors.cardGradient, in: RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(DesignColors.glassStroke, lineWidth: 1)
        )
        .shadow(color: DesignColors.cardShadowStrong.opacity(0.55), radius: 22, x: 0, y: 14)
        .confirmationDialog(
            "Delete this note?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Note", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var deleteButton: some View {
        Button {
            isDeleteConfirmationPresented = true
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignColors.error)
                .frame(width: 34, height: 34)
                .background(DesignColors.surfaceInset.opacity(0.68), in: Circle())
                .overlay(
                    Circle()
                        .stroke(DesignColors.error.opacity(0.28), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help("Delete note")
    }

    private var journalDateButton: some View {
        Button {
            isDatePickerPresented.toggle()
        } label: {
            Label {
                Text(entry.journalDate.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(Typography.caption.weight(.semibold))
            } icon: {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(DesignColors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DesignColors.surfaceInset.opacity(0.62), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(DesignColors.glassStroke.opacity(0.85), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isDatePickerPresented, arrowEdge: .bottom) {
            journalDatePopover
        }
        .help("Change journal date")
    }

    private var journalDatePopover: some View {
        NoviDatePickerPopover(date: $entry.journalDate, createdAt: entry.createdAt)
    }

    private var savedStatus: String {
        if viewModel.isGeneratingTitle {
            return "Generating title…"
        }
        return "Last saved \(viewModel.lastSavedAt.formatted(date: .omitted, time: .standard))"
    }

    private var languagePickers: some View {
        HStack(spacing: Spacing.small) {
            LanguagePickerTile(
                title: "From",
                code: $entry.sourceLanguage,
                autoDetectedCode: viewModel.detectedSourceLanguage,
                allowsAutoDetect: true,
                languages: Self.languages
            )

            ZStack {
                Circle()
                    .fill(DesignColors.accentGradient)
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DesignColors.selectionText)
            }
            .frame(width: 38, height: 38)
            .shadow(color: DesignColors.cardShadowStrong.opacity(0.65), radius: 10, x: 0, y: 5)

            LanguagePickerTile(
                title: "To",
                code: $entry.targetLanguage,
                autoDetectedCode: nil,
                allowsAutoDetect: false,
                languages: Self.languages
            )
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity)
    }

    /// A small set of languages offered in the UI. Codes match LibreTranslate.
    private static let languages: [(code: String, name: String)] = [
        ("en", "English"),
        ("de", "German"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("nl", "Dutch"),
        ("ru", "Russian"),
        ("zh", "Chinese"),
        ("ja", "Japanese"),
        ("ar", "Arabic")
    ]
}

private struct NoviDatePickerPopover: View {
    @Binding var date: Date
    let createdAt: Date
    @State private var visibleMonth: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.fixed(34), spacing: 6), count: 7)

    init(date: Binding<Date>, createdAt: Date) {
        _date = date
        self.createdAt = createdAt
        _visibleMonth = State(initialValue: Self.monthStart(for: date.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Journal Date")
                        .font(Typography.cardTitle)
                        .foregroundStyle(DesignColors.textPrimary)
                    Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                        .font(Typography.caption)
                        .foregroundStyle(DesignColors.textMuted)
                }

                Spacer()

                HStack(spacing: 6) {
                    monthButton(systemName: "chevron.left") { shiftMonth(-1) }
                    monthButton(systemName: "chevron.right") { shiftMonth(1) }
                }
            }

            calendarCard

            HStack(spacing: Spacing.xSmall) {
                quickButton("Today") {
                    date = Date()
                    visibleMonth = Self.monthStart(for: date)
                }

                quickButton("Created") {
                    date = createdAt
                    visibleMonth = Self.monthStart(for: date)
                }
            }
        }
        .padding(Spacing.medium)
        .frame(width: 360)
        .background(DesignColors.cardGradient)
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                .font(Typography.sectionTitle)
                .foregroundStyle(DesignColors.textPrimary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(Typography.metadata.weight(.semibold))
                        .foregroundStyle(DesignColors.textMuted)
                        .frame(width: 34, height: 18)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayButton(day)
                    } else {
                        Color.clear.frame(width: 34, height: 34)
                    }
                }
            }
        }
        .padding(14)
        .background(DesignColors.surfaceInset.opacity(0.58), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(DesignColors.glassStroke.opacity(0.82), lineWidth: 1)
        )
    }

    private var weekdayLabels: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let start = max(0, calendar.firstWeekday - 1)
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: visibleMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstDay) }
        let cells = Array(repeating: Optional<Date>.none, count: leading) + days.map(Optional.some)
        let trailing = (7 - cells.count % 7) % 7
        return cells + Array(repeating: Optional<Date>.none, count: trailing)
    }

    private func dayButton(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: date)
        let isToday = calendar.isDateInToday(day)

        return Button {
            date = mergedDate(day: day, preservingTimeFrom: date)
        } label: {
            Text(day.formatted(.dateTime.day()))
                .font(Typography.bodyEmphasized)
                .foregroundStyle(isSelected ? DesignColors.selectionText : DesignColors.textPrimary)
                .frame(width: 34, height: 34)
                .background(
                    isSelected ? AnyShapeStyle(DesignColors.accentGradient) : AnyShapeStyle(Color.clear),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(isToday && !isSelected ? DesignColors.accentPrimary.opacity(0.7) : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignColors.textPrimary)
                .frame(width: 30, height: 30)
                .background(DesignColors.surfaceInset.opacity(0.72), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func quickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(DesignColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(DesignColors.surfaceInset.opacity(0.72), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(DesignColors.glassStroke.opacity(0.8), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(_ value: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
    }

    private func mergedDate(day: Date, preservingTimeFrom timeSource: Date) -> Date {
        let dayParts = calendar.dateComponents([.year, .month, .day], from: day)
        let timeParts = calendar.dateComponents([.hour, .minute, .second], from: timeSource)
        var components = DateComponents()
        components.year = dayParts.year
        components.month = dayParts.month
        components.day = dayParts.day
        components.hour = timeParts.hour
        components.minute = timeParts.minute
        components.second = timeParts.second
        return calendar.date(from: components) ?? day
    }

    private static func monthStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}

private struct LanguagePickerTile: View {
    let title: String
    @Binding var code: String
    let autoDetectedCode: String?
    let allowsAutoDetect: Bool
    let languages: [(code: String, name: String)]

    private var displayCode: String {
        if code == "auto", let autoDetectedCode, !autoDetectedCode.isEmpty {
            return autoDetectedCode
        }
        return code
    }

    private var selectedName: String {
        if code == "auto" {
            guard let autoDetectedCode, !autoDetectedCode.isEmpty else { return "Auto-detect" }
            let name = languages.first(where: { $0.code == autoDetectedCode })?.name ?? autoDetectedCode.uppercased()
            return "Detected \(name)"
        }
        return languages.first(where: { $0.code == code })?.name ?? code.uppercased()
    }

    private var badgeText: String {
        switch displayCode.lowercased() {
        case "auto":
            return "AUTO"
        case "en":
            return "EN"
        case "de":
            return "DE"
        case "es":
            return "SP"
        case "fr":
            return "FR"
        case "it":
            return "IT"
        case "pt":
            return "PT"
        case "nl":
            return "NL"
        case "ru":
            return "RU"
        case "zh":
            return "ZH"
        case "ja":
            return "JA"
        case "ar":
            return "AR"
        default:
            return String(code.prefix(3)).uppercased()
        }
    }

    var body: some View {
        Menu {
            if allowsAutoDetect {
                Button {
                    code = "auto"
                } label: {
                    Label("Auto-detect", systemImage: code == "auto" ? "checkmark" : "sparkles")
                }

                Divider()
            }

            ForEach(languages, id: \.code) { language in
                Button {
                    code = language.code
                } label: {
                    Label(language.name, systemImage: code == language.code ? "checkmark" : "text.bubble")
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(DesignColors.accentGradient.opacity(title == "From" ? 0.9 : 0.72))
                    Text(badgeText)
                        .font(.system(size: badgeText.count > 2 ? 11 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignColors.selectionText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Typography.metadata.weight(.semibold))
                        .foregroundStyle(DesignColors.textMuted)
                        .textCase(.uppercase)
                    Text(selectedName)
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(DesignColors.textPrimary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignColors.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(DesignColors.cardGradient, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(DesignColors.glassStroke.opacity(0.95), lineWidth: 1.2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(DesignColors.accentPrimary.opacity(0.16), lineWidth: 1)
                    .padding(1)
            )
            .shadow(color: DesignColors.cardShadowStrong.opacity(0.38), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}
