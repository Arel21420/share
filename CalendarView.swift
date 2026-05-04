import SwiftUI
import CoreData

/// ✨ CalendarView REDESIGNED - Version WOW avec gradients
/// ✅ Conserve toutes les fonctionnalités
struct CalendarView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var loc: LocalizationManager
    
    @Binding var isPresented: Bool
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(key: "dueDate", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ],
        animation: .snappy
    )
    private var tasks: FetchedResults<TaskItem>
    
    @State private var selectedDate = Date()
    @State private var selectedTask: TaskItem?
    @State private var currentMonth = Date()
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ✨ Month header avec gradient
                monthHeader
                
                Divider()
                    .background(Color.secondaryText(colorScheme).opacity(0.2))
                
                // Calendar grid
                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 20) {
                            calendarGrid
                            
                            // Tasks for selected date
                            tasksSection
                        }
                        .padding(20)
                    }
                }
            }
            .background(LinearGradient.backgroundGradient(colorScheme))
            #if os(macOS)
            .frame(minWidth: 900, minHeight: 700)
            #else
            .navigationTitle(loc.tr("view.calendar"))
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // ✨ Close button avec gradient
                    Button {
                        isPresented = false
                    } label: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.primaryGradient)
                                .frame(width: 32, height: 32)
                                .shadow(color: Color.primaryStart.opacity(0.3), radius: 6, y: 2)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task, selectionID: .constant(nil))
            }
        }
    }
    
    // MARK: - Month Header (REDESIGNED)
    
    private var monthHeader: some View {
        HStack(spacing: 20) {
            // ✨ Previous button avec gradient
            Button {
                withAnimation {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient.primaryGradient)
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.primaryStart.opacity(0.3), radius: 8, y: 4)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // ✨ Month/Year avec style
            Text(monthYearString)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.primaryText(colorScheme))
            
            Spacer()
            
            // ✨ Next button avec gradient
            Button {
                withAnimation {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient.primaryGradient)
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.primaryStart.opacity(0.3), radius: 8, y: 4)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth).capitalized
    }
    
    // MARK: - Calendar Grid (REDESIGNED)
    
    private var calendarGrid: some View {
        VStack(spacing: 10) {
            // Weekday headers
            HStack(spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.secondaryText(colorScheme))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)
            
            // Days grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        dayCell(for: date)
                            .id("\(index)-\(date.timeIntervalSince1970)")
                    } else {
                        Color.clear
                            .frame(minHeight: 50)
                            .id("empty-\(index)")
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.secondaryBackground(colorScheme))
                .shadow(
                    color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.08),
                    radius: 16,
                    y: 8
                )
        )
    }
    
    // ✨ Day cell avec gradients
    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let tasksCount = tasksForDate(date).count
        
        return Button {
            withAnimation(.snappy) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 6) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isToday ? .white : Color.primaryText(colorScheme))
                
                if tasksCount > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(tasksCount, 3), id: \.self) { index in
                            Circle()
                                .fill(isSelected || isToday ? .white : Color.primaryStart)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .frame(height: 8)
                } else {
                    Spacer()
                        .frame(height: 8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isToday ? LinearGradient.primaryGradient :
                        isSelected ? LinearGradient.todoGradient :
                        LinearGradient(colors: [Color.clear, Color.clear], startPoint: .top, endPoint: .bottom)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isToday ? Color.clear :
                        isSelected ? Color.todoStart :
                        Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: (isToday || isSelected) ? Color.primaryStart.opacity(0.3) : .clear,
                radius: isToday || isSelected ? 8 : 0,
                y: isToday || isSelected ? 4 : 0
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tasks Section (REDESIGNED)
    
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                // ✨ Icon gradient
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient.primaryGradient)
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.primaryStart.opacity(0.3), radius: 8, y: 4)
                    
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                Text(selectedDate.relativeFormat())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.primaryText(colorScheme))
                
                Spacer()
                
                // ✨ Count badge gradient
                Text("\(tasksForDate(selectedDate).count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LinearGradient.primaryGradient)
                    .clipShape(Capsule())
                    .shadow(color: Color.primaryStart.opacity(0.3), radius: 6, y: 2)
            }
            
            Divider()
                .background(Color.secondaryText(colorScheme).opacity(0.2))
            
            let dayTasks = tasksForDate(selectedDate)
            
            if dayTasks.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.doneGradient)
                            .frame(width: 60, height: 60)
                            .shadow(color: Color.doneStart.opacity(0.3), radius: 8, y: 4)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    Text("Aucune tâche")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.secondaryText(colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(dayTasks) { task in
                        CalendarTaskCard(task: task)
                            .onTapGesture {
                                selectedTask = task
                            }
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.secondaryBackground(colorScheme))
                .shadow(
                    color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.08),
                    radius: 16,
                    y: 8
                )
        )
    }
    
    // MARK: - Helpers
    
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        return formatter.veryShortWeekdaySymbols
    }
    
    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        let days = calendar.generateDates(
            inside: monthInterval,
            matching: DateComponents(hour: 0, minute: 0, second: 0)
        )
        
        var result: [Date?] = []
        
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let emptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        result.append(contentsOf: Array(repeating: nil, count: emptyDays))
        
        result.append(contentsOf: days.map { $0 as Date? })
        
        return result
    }
    
    private func tasksForDate(_ date: Date) -> [TaskItem] {
        tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
    }
}

// MARK: - Calendar Task Card (REDESIGNED)

private struct CalendarTaskCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var task: TaskItem
    
    var body: some View {
        HStack(spacing: 12) {
            // ✨ Status icon avec gradient
            ZStack {
                Circle()
                    .fill(statusGradient)
                    .frame(width: 36, height: 36)
                    .shadow(color: statusGradient.shadowColor, radius: 6, y: 2)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            titleView
                .lineLimit(2)
            
            Spacer()
            
            if task.color != .none, let c = task.color.uiColor {
                Circle()
                    .fill(Color(c))
                    .frame(width: 10, height: 10)
                    .shadow(color: Color(c).opacity(0.5), radius: 4, y: 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardBackground(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primaryText(colorScheme).opacity(0.05), lineWidth: 1)
        )
        .shadow(
            color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.06),
            radius: 8,
            y: 4
        )
    }
    
    private var statusGradient: LinearGradient {
        switch task.status {
        case .todo: return .todoGradient
        case .doing: return .doingGradient
        case .done: return .doneGradient
        }
    }
    
    private var statusIcon: String {
        switch task.status {
        case .done: return "checkmark"
        case .doing: return "bolt.fill"
        case .todo: return "circle"
        }
    }
    
    @ViewBuilder
    private var titleView: some View {
        #if os(iOS)
        if shouldShowHandwrittenTitle, let data = task.titleDrawingData, !data.isEmpty {
            HandwrittenTitleRowView(drawingData: data, height: 24)
        } else {
            Text(task.effectiveTitle.isEmpty ? "—" : task.effectiveTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primaryText(colorScheme))
        }
        #elseif os(macOS)
        if shouldShowHandwrittenTitle, let png = task.titleDrawingPreviewPNG, let nsImage = NSImage(data: png) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 24)
        } else {
            Text(task.effectiveTitle.isEmpty ? "—" : task.effectiveTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primaryText(colorScheme))
        }
        #else
        Text(task.effectiveTitle.isEmpty ? "—" : task.effectiveTitle)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.primaryText(colorScheme))
        #endif
    }
    
    private var shouldShowHandwrittenTitle: Bool {
        let typed = (task.typedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard typed.isEmpty else { return false }
        
        #if os(iOS)
        return (task.titleDrawingData?.isEmpty == false)
        #elseif os(macOS)
        return (task.titleDrawingPreviewPNG?.isEmpty == false)
        #else
        return false
        #endif
    }
}

// MARK: - Calendar Helper

private extension Calendar {
    func generateDates(
        inside interval: DateInterval,
        matching components: DateComponents
    ) -> [Date] {
        var dates: [Date] = []
        dates.append(interval.start)
        
        enumerateDates(
            startingAfter: interval.start,
            matching: components,
            matchingPolicy: .nextTime
        ) { date, _, stop in
            if let date = date {
                if date < interval.end {
                    dates.append(date)
                } else {
                    stop = true
                }
            }
        }
        
        return dates
    }
}
