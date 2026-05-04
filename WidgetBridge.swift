import Foundation
import WidgetKit

enum WidgetBridge {
    static func reloadDashboard() {
        WidgetCenter.shared.reloadTimelines(ofKind: "HandToDoDashboardWidget")
    }
}
