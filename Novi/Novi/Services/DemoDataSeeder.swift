//
//  DemoDataSeeder.swift
//  Novi
//
//  Seeds the MockData branch with English journal entries for live demos.
//

import Foundation
import SwiftData

enum DemoDataSeeder {
    private static let marker = "[Demo]"

    static func seedIfNeeded(in container: ModelContainer) {
        let context = ModelContext(container)

        do {
            let existing = try context.fetch(FetchDescriptor<JournalEntryRecord>())
            let existingByTitle = Dictionary(
                existing.map { ($0.title, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            for note in notes {
                if let existing = existingByTitle[note.title] {
                    note.refresh(existing)
                } else {
                    context.insert(note.makeEntry())
                }
            }

            if context.hasChanges {
                try context.save()
            }
        } catch {
            assertionFailure("Could not seed demo data: \(error.localizedDescription)")
        }
    }

    private static let notes: [DemoNote] = [
        DemoNote(
            title: "\(marker) Morning Walk By The River",
            dayOffset: -1,
            text: """
            I woke up earlier than usual and walked along the river before work. The air felt cold, but the light on the water was soft and quiet. I bought a small coffee from the kiosk near the bridge and watched people ride their bikes past me. It made the whole day feel slower and more organized.

            On the way back, I noticed how many details I usually miss when I am in a hurry. A delivery driver was stacking boxes outside a bakery, and two older neighbors were talking beside a blue door. I took a different street home just to see something new. By the time I opened my laptop, I felt like I had already done something kind for myself.
            """
        ),
        DemoNote(
            title: "\(marker) Coffee Shop Surprise",
            dayOffset: -2,
            text: """
            I stopped at the coffee shop after lunch because I needed a short break from my screen. The barista remembered my name and asked how my project was going. That small moment made me feel seen. I sat by the window, answered two messages, and wrote down three ideas for tomorrow.

            The place was busy, but the corner table felt separate from everything. Someone beside me was sketching in a notebook, and the sound of cups moving behind the counter became almost relaxing. I stayed longer than planned and let myself think without rushing toward a result. When I returned to work, the problem that had felt messy seemed much easier to name.
            """
        ),
        DemoNote(
            title: "\(marker) Rainy Train Ride",
            dayOffset: -4,
            text: """
            The train was late today, and everyone looked tired. Rain covered the windows, so the city seemed blurry and far away. I listened to music and tried not to rush in my head. When I finally arrived, I felt strangely calm because there was nothing left to control.

            A student across from me kept checking the time, and I recognized that anxious feeling immediately. Instead of doing the same, I put my phone away and watched the drops move down the glass. The delay gave me a quiet pocket of time I would never have chosen on purpose. I want to remember that not every interruption is a failure.
            """
        ),
        DemoNote(
            title: "\(marker) Dinner With Friends",
            dayOffset: -5,
            text: """
            We cooked pasta together tonight and the kitchen became loud very quickly. Someone forgot the garlic, someone burned the bread, and we laughed about it for ten minutes. The food was simple, but the conversation felt warm. I should invite people over more often.

            After dinner we stayed at the table instead of moving to the sofa. We talked about childhood habits, old teachers, and the different ways we handle stress. Nobody checked the clock for a long time. When everyone left, the sink was full and the room was messy, but the apartment felt alive.
            """
        ),
        DemoNote(
            title: "\(marker) First Real Presentation",
            dayOffset: -7,
            text: """
            I gave a short presentation at work today. My hands were shaking at first, but after the first slide I started to breathe normally. People asked good questions and no one seemed impatient. I learned that confidence sometimes arrives after you begin, not before.

            I spent too much time worrying about whether my voice would sound nervous. In the room, most people were simply trying to understand the idea and decide what came next. That made the whole situation feel less personal. I wrote down the questions afterward because they showed me which parts of the project were actually interesting.
            """
        ),
        DemoNote(
            title: "\(marker) Lost In A Bookstore",
            dayOffset: -8,
            text: """
            I went into the bookstore only to buy a notebook, but I stayed for almost an hour. There was a table full of travel books and old maps. I read a few pages about cities I have never visited. It reminded me that curiosity is a kind of rest.

            I found a shelf of essays near the back and read the first paragraph of several books without choosing any of them. It felt good to browse without a plan or a deadline. The quiet made every small decision feel gentle. I left with the notebook, a short novel, and a stronger wish to make more room for wandering.
            """
        ),
        DemoNote(
            title: "\(marker) Sunday Cleaning",
            dayOffset: -10,
            text: """
            I cleaned my desk, washed the sheets, and threw away a pile of old receipts. The apartment feels lighter now. I found a birthday card in a drawer and it made me smile. Cleaning always starts as a boring task and ends as a small reset.

            I also rearranged the books beside my bed and cleared the kitchen counter completely. The change was small, but the room looked more patient afterward. I opened the window for a few minutes even though it was cold. By evening, I felt ready for the week in a way that planning alone never gives me.
            """
        ),
        DemoNote(
            title: "\(marker) New Recipe Attempt",
            dayOffset: -11,
            text: """
            I tried to make soup without following the recipe exactly. I added too much pepper, but the result was still good. The kitchen smelled like tomatoes, onions, and roasted carrots. I felt proud because I usually avoid cooking when I am tired.

            I chopped everything slowly and cleaned as I went, which made the process feel less chaotic. While the soup simmered, I called a friend and told them about my accidental experiment. They said mistakes often make food more memorable, and that made me laugh. I saved enough for tomorrow, so future me gets a small reward too.
            """
        ),
        DemoNote(
            title: "\(marker) Quiet Evening Call",
            dayOffset: -13,
            text: """
            I called my mother in the evening and we talked about ordinary things. She told me about her garden, the neighbor's renovation, and a cake she wants to bake next week. Nothing dramatic happened, but I felt grounded after the call. Familiar voices can change the room.

            I was walking around the apartment while we talked, picking up cups and folding a blanket without thinking. Her stories moved slowly, and that pace helped me slow down too. We did not solve any big problem or make any serious plan. Still, after we hung up, the evening felt less empty.
            """
        ),
        DemoNote(
            title: "\(marker) Long Walk Home",
            dayOffset: -14,
            text: """
            I decided to walk home instead of taking the bus. The route took longer, but I noticed a mural on a side street and a tiny bakery I had never seen before. My legs were tired when I arrived, but my mind felt clearer than it had all afternoon.

            The city looked different at walking speed. I passed a small courtyard with yellow lights and heard music coming from an open window. For once, I did not measure the day only by efficiency. I want to choose the slower route more often when I can afford it.
            """
        ),
        DemoNote(
            title: "\(marker) Learning A New Tool",
            dayOffset: -16,
            text: """
            I spent the afternoon learning a new design tool. At first every shortcut felt confusing, and I wanted to go back to what I already knew. After an hour, the workflow started to make sense. Being bad at something new is uncomfortable but useful.

            I made a tiny prototype just to test the basics, and it looked rough but functional. The important part was noticing when frustration turned into curiosity. I wrote down the commands that confused me most so I can practice them tomorrow. Progress felt small, but it was real.
            """
        ),
        DemoNote(
            title: "\(marker) Market On Saturday",
            dayOffset: -18,
            text: """
            The market was crowded this morning. I bought apples, fresh bread, and a bunch of flowers for the table. A musician played near the entrance, and children danced beside the vegetable stand. It was noisy in a good way, full of color and movement.

            I spoke with a vendor who explained which apples were best for baking and which were better for eating fresh. That small conversation made the purchase feel more personal. I carried everything home in one heavy bag and stopped twice to switch hands. The flowers are now beside the window, making the whole room look more awake.
            """
        ),
        DemoNote(
            title: "\(marker) Hard Conversation",
            dayOffset: -19,
            text: """
            I had a difficult conversation with a friend today. I was nervous before we met, but we both tried to listen carefully. There were a few awkward silences, and then things became honest. I left feeling tired, but also relieved that we did not avoid it.

            The hardest part was admitting what had hurt without turning it into an accusation. I had practiced the sentence in my head many times, but it still came out imperfectly. My friend understood enough, and that mattered more than saying it beautifully. Repair is slower than pretending, but it feels stronger.
            """
        ),
        DemoNote(
            title: "\(marker) Museum Afternoon",
            dayOffset: -21,
            text: """
            I visited the museum after lunch and spent most of my time in one quiet room. There was a painting of a small kitchen table with sunlight on a blue cup. I kept looking at it because it made ordinary life seem important. I want to notice more small details.

            I walked through the other rooms too quickly at first, trying to see everything. Then I realized one painting was enough for the day. I sat on the bench and let the room become familiar. Leaving with one clear memory felt better than collecting a hundred vague impressions.
            """
        ),
        DemoNote(
            title: "\(marker) Planning A Short Trip",
            dayOffset: -24,
            text: """
            I started planning a short trip for next month. I looked at train times, saved a few hotels, and made a list of places to see. The plan is not finished yet, but it already gives me something to look forward to. Anticipation can be its own kind of energy.

            I compared routes and realized the slower train might actually be more enjoyable. There is a small town on the way where I could stop for lunch and walk around for an hour. The trip does not need to be impressive to be useful. I mostly want a change of rhythm and a few days with fewer notifications.
            """
        )
    ]
}

private struct DemoNote {
    let title: String
    let dayOffset: Int
    let text: String

    func makeEntry() -> JournalEntryRecord {
        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
        return JournalEntryRecord(
            createdAt: date,
            journalDate: date,
            updatedAt: date,
            title: title,
            sourceText: text,
            sourceLanguage: "en",
            targetLanguage: "de"
        )
    }

    func refresh(_ entry: JournalEntryRecord) {
        guard entry.lessonSourceText.isEmpty,
              entry.vocabulary.isEmpty,
              entry.grammarNotes.isEmpty,
              entry.writingChallenge.isEmpty else { return }

        entry.sourceText = text
        entry.sourceLanguage = "en"
        entry.targetLanguage = "de"
        entry.lessonTranslation = ""
        entry.updatedAt = Date()
    }
}
