import DimiCheckMacCore
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @State private var selectedTodayTab: TodayTab = .timetable

    private enum TodayTab: String, CaseIterable {
        case timetable = "시간표"
        case meal = "급식"
    }

    private let columns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity)),
        GridItem(.flexible(minimum: 0, maximum: .infinity))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let errorMessage = model.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            updateContent

            switch model.phase {
            case .booting, .signingIn:
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            case .signedOut:
                signedOutContent
            case .ready:
                readyContent
            }

            todayContent
            settingsContent

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 340)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DimiCheck")
                .font(.headline.weight(.semibold))
            Text(model.currentStatusLabel)
                .font(.title3.weight(.bold))
            if let favorite = model.favoriteStatus ?? .toilet as AppStatusCode? {
                Text("우클릭 즐겨찾기: \(favorite.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("메뉴바에서 바로 상태를 바꾸려면 로그인하세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: { Task { await model.signIn() } }) {
                Label("Google로 로그인", systemImage: "person.crop.circle.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(action: model.openInBrowser) {
                Label("브라우저로 열기", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var readyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(model.quickStatuses, id: \.rawValue) { status in
                    Button {
                        Task { await model.setStatus(status) }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: status.symbolName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(status == model.currentStatusCode ? Color.accentColor : Color.secondary)
                                .frame(width: 18, height: 18)
                                .padding(.top, 1)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(status.label)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(status == model.currentStatusCode ? "현재 상태" : "빠른 전환")
                                    .font(.caption2)
                                    .foregroundStyle(status == model.currentStatusCode ? .primary : .secondary)
                            }

                            Spacer(minLength: 0)

                            if model.pendingStatusCode == status {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.top, 2)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                        .padding(10)
                        .background(status == model.currentStatusCode ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isWorking || model.isUpdateRequired)
                }
            }

            HStack(spacing: 8) {
                Button {
                    Task { await model.toggleFavoriteShortcut() }
                } label: {
                    HStack {
                        if model.isWorking && model.pendingStatusCode == nil {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("즐겨찾기 토글", systemImage: "star")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.isWorking || model.isUpdateRequired)

                Button(action: model.openInBrowser) {
                    Label("브라우저", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.isWorking)
            }
        }
    }

    @ViewBuilder
    private var updateContent: some View {
        if let policy = model.versionPolicy, model.updateState == .optional || model.updateState == .required {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: model.updateState == .required ? "exclamationmark.triangle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(model.updateState == .required ? .orange : .accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.updateState == .required ? "업데이트 필요" : "업데이트 가능")
                            .font(.subheadline.weight(.semibold))
                        Text("현재 \(model.currentAppVersion) · 최신 \(policy.latestVersion)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                Text(policy.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button(action: model.copyHomebrewCommand) {
                        Label(model.didCopyUpdateCommand ? "복사됨" : "brew 복사", systemImage: model.didCopyUpdateCommand ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: model.openDownloadPage) {
                        Label("다운로드", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if model.updateState == .required {
                    Text("이 버전에서는 상태 변경이 잠시 제한됩니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(model.updateState == .required ? Color.orange.opacity(0.12) : Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var todayContent: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                if model.isSchoolLifeLoading && model.schoolLifeToday == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let schoolLife = model.schoolLifeToday {
                    Picker("", selection: $selectedTodayTab) {
                        ForEach(TodayTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    todayTabContent(for: schoolLife)

                    if let errors = schoolLife.errors, !errors.isEmpty {
                        Text("일부 정보를 불러오지 못했습니다.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        Task { await model.refreshSchoolLifeToday() }
                    } label: {
                        Label("오늘 정보 불러오기", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Label("오늘", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 0)

                if model.isSchoolLifeLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let schoolLife = model.schoolLifeToday {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nextLessonSummary(from: schoolLife))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(mealSummary(from: schoolLife))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.leading, 22)
            }
        }
        .disclosureGroupStyle(.automatic)
    }

    @ViewBuilder
    private func todayTabContent(for schoolLife: SchoolLifeTodayPayload) -> some View {
        switch selectedTodayTab {
        case .timetable:
            timetablePane(for: schoolLife)
        case .meal:
            mealPane(for: schoolLife)
        }
    }

    private func timetablePane(for schoolLife: SchoolLifeTodayPayload) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lessons = schoolLife.timetable?.lessons, !lessons.isEmpty {
                ForEach(Array(lessons.enumerated()), id: \.offset) { _, lesson in
                    HStack(spacing: 8) {
                        Text(lesson.period.map { "\($0)교시" } ?? "수업")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .leading)
                        Text(lesson.subject)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            } else {
                Text(schoolLife.timetable?.message ?? "오늘 등록된 시간표가 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func mealPane(for schoolLife: SchoolLifeTodayPayload) -> some View {
        let meal = selectedMeal(from: schoolLife)
        let items = mealItems(meal.text)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(meal.title, systemImage: meal.symbolName)
                    .font(.caption.weight(.semibold))
                Text(meal.hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            if items.isEmpty {
                Text("급식 정보가 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(item)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func nextLessonSummary(from schoolLife: SchoolLifeTodayPayload) -> String {
        guard let lessons = schoolLife.timetable?.lessons, !lessons.isEmpty else {
            return "다음 수업 · 정보 없음"
        }

        let currentMinute = Calendar.current.component(.hour, from: Date()) * 60 + Calendar.current.component(.minute, from: Date())
        let periodStartMinutes = [
            1: 9 * 60,
            2: 10 * 60,
            3: 11 * 60,
            4: 12 * 60,
            5: 13 * 60 + 50,
            6: 14 * 60 + 50,
            7: 15 * 60 + 50
        ]
        let sortedLessons = lessons.sorted { ($0.period ?? 99) < ($1.period ?? 99) }
        let nextLesson = sortedLessons.first { lesson in
            guard let period = lesson.period, let start = periodStartMinutes[period] else { return false }
            return start + 50 >= currentMinute
        } ?? sortedLessons.first

        guard let nextLesson else {
            return "다음 수업 · 정보 없음"
        }

        let periodText = nextLesson.period.map { "\($0)교시 " } ?? ""
        return "다음 수업 · \(periodText)\(nextLesson.subject)"
    }

    private func mealSummary(from schoolLife: SchoolLifeTodayPayload) -> String {
        let meal = selectedMeal(from: schoolLife)
        return "급식 · \(meal.title) \(compactMealText(meal.text) ?? "정보 없음")"
    }

    private func selectedMeal(from schoolLife: SchoolLifeTodayPayload) -> (title: String, text: String?, symbolName: String, hint: String) {
        let currentMinute = currentMinuteOfDay()
        if currentMinute < 8 * 60 {
            return ("아침", schoolLife.meal?.breakfast, "sunrise.fill", "08:00 전")
        }
        if currentMinute < 13 * 60 + 40 {
            return ("점심", schoolLife.meal?.lunch, "fork.knife", "13:40 전")
        }
        return ("저녁", schoolLife.meal?.dinner, "moon.stars.fill", "13:40 이후")
    }

    private func currentMinuteOfDay() -> Int {
        Calendar.current.component(.hour, from: Date()) * 60 + Calendar.current.component(.minute, from: Date())
    }

    private func compactMealText(_ text: String?) -> String? {
        let items = mealItems(text)
        guard let first = items.first else { return nil }
        if items.count <= 1 {
            return first
        }
        return "\(first) 외 \(items.count - 1)개"
    }

    private func mealItems(_ text: String?) -> [String] {
        let items = (text ?? "")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return items
    }

    private var settingsContent: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLoginEnabled($0) }
                )) {
                    Label("로그인 시 자동 시작", systemImage: "bolt.circle")
                }
                .toggleStyle(.switch)

                if model.launchAtLoginRequiresApproval {
                    Text("시스템 설정에서 승인이 필요합니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if model.phase == .ready {
                    HStack(spacing: 10) {
                        Label("즐겨찾기", systemImage: "star.fill")
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)

                        if let pendingFavoriteStatusCode = model.pendingFavoriteStatusCode {
                            ProgressView()
                                .controlSize(.small)
                            Text(pendingFavoriteStatusCode.label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker(
                                "",
                                selection: Binding<AppStatusCode>(
                                    get: { model.favoriteStatus ?? model.configuration.defaultFavoriteStatus },
                                    set: { status in
                                        Task { await model.setFavoriteStatus(status) }
                                    }
                                )
                            ) {
                                ForEach(model.favoriteStatuses, id: \.rawValue) { status in
                                    Text(status.label).tag(status)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 150)
                        }
                    }
                    .disabled(model.isWorking || model.pendingFavoriteStatusCode != nil)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } label: {
            Label("설정", systemImage: "gearshape")
                .font(.subheadline.weight(.semibold))
        }
        .disclosureGroupStyle(.automatic)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if model.phase == .ready {
                Button(role: .destructive) {
                    Task { await model.logOut() }
                } label: {
                    Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(.bordered)
            }

            Spacer(minLength: 0)

            Button(action: model.quit) {
                Label("Quit", systemImage: "xmark.circle")
            }
            .buttonStyle(.borderless)
        }
    }
}
