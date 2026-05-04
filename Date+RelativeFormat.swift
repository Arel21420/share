import Foundation

extension Date {
    
    /// ✅ Format de date relatif intelligent
    func relativeFormat(locale: Locale = .current) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Aujourd'hui
        if calendar.isDateInToday(self) {
            return localizedString("date.today", locale: locale)
        }
        
        // Hier
        if calendar.isDateInYesterday(self) {
            return localizedString("date.yesterday", locale: locale)
        }
        
        // Demain
        if calendar.isDateInTomorrow(self) {
            return localizedString("date.tomorrow", locale: locale)
        }
        
        // Cette semaine (futur)
        if let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
           let weekEnd = calendar.dateInterval(of: .weekOfYear, for: now)?.end,
           self >= now && self < weekEnd {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateFormat = "EEEE"  // "Lundi", "Monday"
            return formatter.string(from: self)
        }
        
        // Cette semaine (passé)
        if let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
           self >= weekStart && self < now {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateFormat = "EEEE"  // "Lundi", "Monday"
            return formatter.string(from: self)
        }
        
        // Semaine prochaine
        if let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: now),
           let nextWeekInterval = calendar.dateInterval(of: .weekOfYear, for: nextWeekStart),
           nextWeekInterval.contains(self) {
            return localizedString("date.nextWeek", locale: locale)
        }
        
        // Semaine dernière
        if let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
           let lastWeekInterval = calendar.dateInterval(of: .weekOfYear, for: lastWeekStart),
           lastWeekInterval.contains(self) {
            return localizedString("date.lastWeek", locale: locale)
        }
        
        // Dans X jours (futur proche)
        if self > now, let days = calendar.dateComponents([.day], from: now, to: self).day, days <= 7 {
            return String(format: localizedString("date.inDays", locale: locale), days)
        }
        
        // Il y a X jours (passé proche)
        if self < now, let days = calendar.dateComponents([.day], from: self, to: now).day, days <= 7 {
            return String(format: localizedString("date.daysAgo", locale: locale), days)
        }
        
        // Date complète pour le reste
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    /// ✅ Format court pour les rows (compact)
    func compactRelativeFormat(locale: Locale = .current) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(self) {
            return localizedString("date.today.short", locale: locale)
        }
        
        if calendar.isDateInYesterday(self) {
            return localizedString("date.yesterday.short", locale: locale)
        }
        
        if calendar.isDateInTomorrow(self) {
            return localizedString("date.tomorrow.short", locale: locale)
        }
        
        // Format court standard
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "d MMM"  // "1 janv"
        return formatter.string(from: self)
    }
    
    private func localizedString(_ key: String, locale: Locale) -> String {
        // Utilise le bundle avec la locale appropriée
        let bundle: Bundle
        if let languageCode = locale.language.languageCode?.identifier,
           let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let localeBundle = Bundle(path: path) {
            bundle = localeBundle
        } else {
            bundle = .main
        }
        
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }
}
