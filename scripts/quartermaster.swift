import Foundation
import EventKit

// MARK: - Version

let VERSION = "0.1.0"

// MARK: - JSON Output Helpers

func jsonString(_ dict: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
          let str = String(data: data, encoding: .utf8) else { return "{}" }
    return str
}

func jsonString(_ array: [[String: Any]]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: array, options: [.sortedKeys]),
          let str = String(data: data, encoding: .utf8) else { return "[]" }
    return str
}

func printJSON(_ dict: [String: Any]) {
    print(jsonString(dict))
}

func printJSON(_ array: [[String: Any]]) {
    print(jsonString(array))
}

func exitWithError(_ message: String, extras: [String: Any] = [:]) -> Never {
    var err: [String: Any] = ["error": message]
    for (k, v) in extras { err[k] = v }
    if let data = try? JSONSerialization.data(withJSONObject: err, options: [.sortedKeys]),
       let str = String(data: data, encoding: .utf8) {
        FileHandle.standardError.write(Data((str + "\n").utf8))
    }
    exit(1)
}

// MARK: - Argument Parsing Helpers

func flagValue(_ flag: String, in args: [String]) -> String? {
    guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
    return args[idx + 1]
}

func hasFlag(_ flag: String, in args: [String]) -> Bool {
    return args.contains(flag)
}

// MARK: - Path Helpers

let fm = FileManager.default
let homeDir = fm.homeDirectoryForCurrentUser

func resolvePath(_ path: String) -> URL {
    if path.hasPrefix("~/") {
        return homeDir.appendingPathComponent(String(path.dropFirst(2)))
    }
    return URL(fileURLWithPath: path)
}

func isPathSafe(_ path: String) -> Bool {
    return !path.contains("..")
}

// MARK: - ID Helpers

func slugify(_ name: String) -> String {
    let slug = name.lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return slug.isEmpty ? "item" : slug
}

func uniqueId(_ baseName: String, existingIds: [String]) -> String {
    let base = slugify(baseName)
    if !existingIds.contains(base) { return base }
    var counter = 2
    while existingIds.contains("\(base)-\(counter)") { counter += 1 }
    return "\(base)-\(counter)"
}

// MARK: - Config Management

let configDir = homeDir.appendingPathComponent(".config/quartermaster")
let configFile = configDir.appendingPathComponent("config.json")
let inventoryFile = configDir.appendingPathComponent("inventory.json")
let listsFile = configDir.appendingPathComponent("lists.json")

func ensureConfigDir() {
    try? fm.createDirectory(at: configDir, withIntermediateDirectories: true)
    try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: configDir.path)
}

func readJSON(_ file: URL) -> [String: Any] {
    guard let data = try? Data(contentsOf: file),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return [:]
    }
    return json
}

func writeJSON(_ dict: [String: Any], to file: URL) {
    ensureConfigDir()
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) else { return }
    try? data.write(to: file)
    try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
}

func readConfig() -> [String: Any] {
    let config = readJSON(configFile)
    if config.isEmpty { return defaultConfig() }
    return config
}

func writeConfig(_ config: [String: Any]) {
    writeJSON(config, to: configFile)
}

func defaultConfig() -> [String: Any] {
    return [
        "version": 1,
        "lists_dir": "~/quartermaster/lists",
        "briefs_dir": "~/quartermaster/briefs",
        "sync_reminder_list": "Shopping",
        "last_sync": NSNull(),
        "categories": ["Groceries", "Household", "Personal Care", "Electronics"]
    ] as [String: Any]
}

// MARK: - Inventory Data

func readInventory() -> [String: Any] {
    let inv = readJSON(inventoryFile)
    if inv.isEmpty { return ["items": [] as [[String: Any]]] }
    return inv
}

func writeInventory(_ inv: [String: Any]) {
    writeJSON(inv, to: inventoryFile)
}

func inventoryItems(_ inv: [String: Any]) -> [[String: Any]] {
    return inv["items"] as? [[String: Any]] ?? []
}

// MARK: - Shopping List Data

func readLists() -> [String: Any] {
    let lists = readJSON(listsFile)
    if lists.isEmpty { return ["lists": [] as [[String: Any]]] }
    return lists
}

func writeLists(_ data: [String: Any]) {
    writeJSON(data, to: listsFile)
}

func shoppingLists(_ data: [String: Any]) -> [[String: Any]] {
    return data["lists"] as? [[String: Any]] ?? []
}

// MARK: - Usage Rate Calculations

func daysUntilRestock(_ item: [String: Any]) -> Int? {
    guard let qty = item["quantity"] as? Int,
          let threshold = item["restock_threshold"] as? Int,
          let rate = item["usage_rate"] as? Int,
          let period = item["usage_period"] as? String,
          rate > 0 else { return nil }

    let excess = qty - threshold
    if excess <= 0 { return 0 }

    let daysPerPeriod: Double
    switch period {
    case "day": daysPerPeriod = 1
    case "week": daysPerPeriod = 7
    case "month": daysPerPeriod = 30
    default: return nil
    }

    return Int((Double(excess) / Double(rate)) * daysPerPeriod)
}

func isLowStock(_ item: [String: Any]) -> Bool {
    guard let qty = item["quantity"] as? Int,
          let threshold = item["restock_threshold"] as? Int else { return false }
    return qty <= threshold
}

// MARK: - Brief Helpers

func ensureOutputDir(_ path: String) {
    let url = resolvePath(path)
    try? fm.createDirectory(at: url, withIntermediateDirectories: true)
}

func saveBrief(_ content: String, config: [String: Any]) {
    let briefsDir = config["briefs_dir"] as? String ?? "~/quartermaster/briefs"
    ensureOutputDir(briefsDir)
    let dateStr = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
    let fileURL = resolvePath(briefsDir).appendingPathComponent("\(dateStr).md")
    try? content.write(to: fileURL, atomically: true, encoding: .utf8)
}

// MARK: - EventKit Store

let store = EKEventStore()

func requestReminderAccess() {
    let semaphore = DispatchSemaphore(value: 0)
    var accessGranted = false

    if #available(macOS 14.0, *) {
        store.requestFullAccessToReminders { granted, error in
            accessGranted = granted
            semaphore.signal()
        }
    } else {
        store.requestAccess(to: .reminder) { granted, error in
            accessGranted = granted
            semaphore.signal()
        }
    }

    semaphore.wait()
    if !accessGranted {
        exitWithError("Reminders access denied. Grant permission in System Settings > Privacy & Security > Reminders. All non-sync commands still work in local-only mode.")
    }
}

func findOrCreateReminderList(_ name: String) -> EKCalendar {
    if let existing = store.calendars(for: .reminder).first(where: { $0.title == name }) {
        return existing
    }
    let newList = EKCalendar(for: .reminder, eventStore: store)
    newList.title = name
    newList.source = store.defaultCalendarForNewReminders()?.source ?? store.sources.first(where: { $0.sourceType == .local })!
    do {
        try store.saveCalendar(newList, commit: true)
    } catch {
        exitWithError("Failed to create reminder list '\(name)': \(error.localizedDescription)")
    }
    return newList
}

func fetchReminders(from list: EKCalendar, includeCompleted: Bool = true) -> [EKReminder] {
    let semaphore = DispatchSemaphore(value: 0)
    var fetched: [EKReminder] = []

    let predicate = store.predicateForReminders(in: [list])
    store.fetchReminders(matching: predicate) { reminders in
        fetched = reminders ?? []
        semaphore.signal()
    }
    semaphore.wait()

    if !includeCompleted {
        fetched = fetched.filter { !$0.isCompleted }
    }
    return fetched
}

// MARK: - Main Dispatch

func printUsage() {
    let usage = """
    Usage: quartermaster <command> [options]

    Commands:
      qm-config         Configure categories, directories, sync settings
      inv-list           View inventory items
      inv-update         Add, adjust, or remove inventory items
      shop-list          View, create, archive, sync shopping lists
      shop-add           Add items to a shopping list
      shop-done          Mark items purchased

    Options:
      --version          Show version
    """
    print(usage)
}

func main() {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first else {
        printUsage()
        exit(1)
    }
    let remaining = Array(args.dropFirst())

    switch command {
    case "qm-config":
        cmdQmConfig(remaining)
    case "inv-list":
        cmdInvList(remaining)
    case "inv-update":
        cmdInvUpdate(remaining)
    case "shop-list":
        cmdShopList(remaining)
    case "shop-add":
        cmdShopAdd(remaining)
    case "shop-done":
        cmdShopDone(remaining)
    case "--version":
        print(VERSION)
    default:
        exitWithError("Unknown command: \(command)")
    }
}

// MARK: - Command Stubs (implemented in subsequent tasks)

func cmdQmConfig(_ args: [String]) {
    var config = readConfig()

    if hasFlag("--show", in: args) {
        printJSON(config)
        return
    }

    if hasFlag("--reset", in: args) {
        writeConfig(defaultConfig())
        printJSON(["status": "reset", "message": "Config reset to defaults"])
        return
    }

    if let path = flagValue("--set-lists-dir", in: args) {
        guard isPathSafe(path) else { exitWithError("Path contains unsafe components") }
        config["lists_dir"] = path
        writeConfig(config)
        printJSON(["status": "updated", "lists_dir": path])
        return
    }

    if let path = flagValue("--set-briefs-dir", in: args) {
        guard isPathSafe(path) else { exitWithError("Path contains unsafe components") }
        config["briefs_dir"] = path
        writeConfig(config)
        printJSON(["status": "updated", "briefs_dir": path])
        return
    }

    if let name = flagValue("--set-sync-list", in: args) {
        config["sync_reminder_list"] = name
        writeConfig(config)
        printJSON(["status": "updated", "sync_reminder_list": name])
        return
    }

    if let name = flagValue("--add-category", in: args) {
        var cats = config["categories"] as? [String] ?? []
        if cats.contains(name) {
            exitWithError("Category '\(name)' already exists")
        }
        cats.append(name)
        config["categories"] = cats
        writeConfig(config)
        printJSON(["status": "added", "category": name, "categories": cats])
        return
    }

    if let name = flagValue("--remove-category", in: args) {
        var cats = config["categories"] as? [String] ?? []
        guard cats.contains(name) else {
            exitWithError("Category '\(name)' not found")
        }
        cats.removeAll { $0 == name }
        config["categories"] = cats
        writeConfig(config)
        printJSON(["status": "removed", "category": name, "categories": cats])
        return
    }

    if hasFlag("--list-reminder-lists", in: args) {
        requestReminderAccess()
        let calendars = store.calendars(for: .reminder)
        let result = calendars.map { cal -> [String: Any] in
            return [
                "title": cal.title,
                "allows_modification": cal.allowsContentModifications
            ] as [String: Any]
        }
        printJSON(["reminder_lists": result])
        return
    }

    exitWithError("Usage: qm-config [--show | --reset | --set-lists-dir <path> | --set-briefs-dir <path> | --set-sync-list <name> | --add-category <name> | --remove-category <name> | --list-reminder-lists]")
}

func cmdInvList(_ args: [String]) {
    let config = readConfig()
    let inv = readInventory()
    var items = inventoryItems(inv)

    let categoryFilter = flagValue("--category", in: args)
    let lowOnly = hasFlag("--low-only", in: args)
    let isSummary = hasFlag("--summary", in: args)
    let wantBrief = hasFlag("--save-brief", in: args)

    if let cat = categoryFilter {
        items = items.filter { ($0["category"] as? String) == cat }
    }
    if lowOnly {
        items = items.filter { isLowStock($0) }
    }

    let enriched: [[String: Any]] = items.map { item in
        var result = item
        if let days = daysUntilRestock(item) {
            result["days_until_restock"] = days
        }
        result["low_stock"] = isLowStock(item)
        return result
    }

    if isSummary {
        let total = inventoryItems(inv).count
        let lowItems = inventoryItems(inv).filter { isLowStock($0) }
        let lowEnriched: [[String: Any]] = lowItems.map { item in
            var result: [String: Any] = [
                "name": item["name"] ?? "",
                "quantity": item["quantity"] ?? 0,
                "unit": item["unit"] ?? "",
                "restock_threshold": item["restock_threshold"] ?? 0
            ]
            if let days = daysUntilRestock(item) {
                result["days_until_restock"] = days
            }
            if let rate = item["usage_rate"] as? Int, let period = item["usage_period"] as? String {
                result["usage"] = "\(rate)/\(period)"
            }
            return result
        }
        var summaryResult: [String: Any] = [
            "total_items": total,
            "low_stock_count": lowItems.count,
            "low_stock_items": lowEnriched
        ]
        if wantBrief {
            var lines = ["# Quartermaster Inventory Brief — \(ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate]))", ""]
            lines.append("\(total) items tracked, \(lowItems.count) low stock")
            if !lowItems.isEmpty {
                lines.append("\n## Restock Alerts")
                for item in lowEnriched {
                    let name = item["name"] as? String ?? "?"
                    let qty = item["quantity"] as? Int ?? 0
                    let unit = item["unit"] as? String ?? ""
                    let days = item["days_until_restock"] as? Int
                    let daysStr = days != nil ? ", ~\(days!) days" : ""
                    lines.append("- \(name): \(qty) \(unit)\(daysStr)")
                }
            }
            saveBrief(lines.joined(separator: "\n"), config: config)
            summaryResult["brief_saved"] = true
        }
        printJSON(summaryResult)
        return
    }

    var result: [String: Any] = ["items": enriched, "count": enriched.count]
    if let cat = categoryFilter { result["filter_category"] = cat }
    if lowOnly { result["filter"] = "low_stock_only" }

    if wantBrief {
        var lines = ["# Quartermaster Inventory Brief — \(ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate]))", ""]
        lines.append("\(enriched.count) items")
        for item in enriched {
            let name = item["name"] as? String ?? "?"
            let qty = item["quantity"] as? Int ?? 0
            let unit = item["unit"] as? String ?? ""
            let low = item["low_stock"] as? Bool ?? false
            let days = item["days_until_restock"] as? Int
            var line = "- \(name): \(qty) \(unit)"
            if low { line += " ⚠ LOW" }
            if let d = days { line += " (~\(d) days)" }
            lines.append(line)
        }
        saveBrief(lines.joined(separator: "\n"), config: config)
        result["brief_saved"] = true
    }

    printJSON(result)
}

func cmdInvUpdate(_ args: [String]) {
    var inv = readInventory()
    var items = inventoryItems(inv)
    let now = ISO8601DateFormatter().string(from: Date())

    if hasFlag("--add", in: args) {
        guard let name = flagValue("--name", in: args) else {
            exitWithError("--add requires --name <name>, --qty <N>, --unit <unit>, --category <cat>")
        }
        guard let qtyStr = flagValue("--qty", in: args), let qty = Int(qtyStr) else {
            exitWithError("--add requires --qty <N>")
        }
        guard let unit = flagValue("--unit", in: args) else {
            exitWithError("--add requires --unit <unit>")
        }
        guard let category = flagValue("--category", in: args) else {
            exitWithError("--add requires --category <cat>")
        }

        let existingIds = items.compactMap { $0["id"] as? String }
        let id = uniqueId(name, existingIds: existingIds)

        var newItem: [String: Any] = [
            "id": id,
            "name": name,
            "category": category,
            "quantity": qty,
            "unit": unit,
            "last_updated": now
        ]

        if let threshStr = flagValue("--threshold", in: args), let thresh = Int(threshStr) {
            newItem["restock_threshold"] = thresh
        }
        if let rateStr = flagValue("--usage-rate", in: args), let rate = Int(rateStr) {
            guard rate > 0 else { exitWithError("Usage rate must be positive") }
            guard let period = flagValue("--usage-period", in: args),
                  ["day", "week", "month"].contains(period) else {
                exitWithError("--usage-rate requires --usage-period <day|week|month>")
            }
            newItem["usage_rate"] = rate
            newItem["usage_period"] = period
        }

        items.append(newItem)
        inv["items"] = items
        writeInventory(inv)
        printJSON(["status": "added", "item": newItem])
        return
    }

    if let id = flagValue("--set", in: args) {
        guard let idx = items.firstIndex(where: { ($0["id"] as? String) == id }) else {
            exitWithError("Item '\(id)' not found")
        }

        if let qtyStr = flagValue("--qty", in: args), let qty = Int(qtyStr) {
            items[idx]["quantity"] = qty
            items[idx]["last_updated"] = now
        }
        if let threshStr = flagValue("--threshold", in: args), let thresh = Int(threshStr) {
            items[idx]["restock_threshold"] = thresh
        }
        if let rateStr = flagValue("--usage-rate", in: args), let rate = Int(rateStr) {
            guard rate > 0 else { exitWithError("Usage rate must be positive") }
            guard let period = flagValue("--usage-period", in: args),
                  ["day", "week", "month"].contains(period) else {
                exitWithError("--usage-rate requires --usage-period <day|week|month>")
            }
            items[idx]["usage_rate"] = rate
            items[idx]["usage_period"] = period
        }

        inv["items"] = items
        writeInventory(inv)
        printJSON(["status": "updated", "item": items[idx]])
        return
    }

    if let id = flagValue("--remove", in: args) {
        let before = items.count
        items.removeAll { ($0["id"] as? String) == id }
        guard items.count < before else { exitWithError("Item '\(id)' not found") }
        inv["items"] = items
        writeInventory(inv)
        printJSON(["status": "removed", "id": id])
        return
    }

    exitWithError("Usage: inv-update [--add --name <name> --qty <N> --unit <unit> --category <cat> [--threshold <N>] [--usage-rate <N> --usage-period <day|week|month>] | --set <id> [--qty <N>] [--threshold <N>] [--usage-rate <N> --usage-period <period>] | --remove <id>]")
}

func cmdShopList(_ args: [String]) {
    let config = readConfig()
    var listsData = readLists()
    var lists = shoppingLists(listsData)
    let now = ISO8601DateFormatter().string(from: Date())

    if let name = flagValue("--create", in: args) {
        let existingIds = lists.compactMap { $0["id"] as? String }
        let id = uniqueId(name, existingIds: existingIds)

        let newList: [String: Any] = [
            "id": id,
            "name": name,
            "created": now,
            "archived": false,
            "items": [] as [[String: Any]]
        ]

        lists.append(newList)
        listsData["lists"] = lists
        writeLists(listsData)
        printJSON(["status": "created", "list": newList])
        return
    }

    if let id = flagValue("--view", in: args) {
        guard let list = lists.first(where: { ($0["id"] as? String) == id }) else {
            exitWithError("List '\(id)' not found")
        }
        printJSON(list)
        return
    }

    if let id = flagValue("--archive", in: args) {
        guard let idx = lists.firstIndex(where: { ($0["id"] as? String) == id }) else {
            exitWithError("List '\(id)' not found")
        }
        lists[idx]["archived"] = true
        listsData["lists"] = lists
        writeLists(listsData)
        printJSON(["status": "archived", "id": id])
        return
    }

    if let id = flagValue("--export", in: args) {
        guard let list = lists.first(where: { ($0["id"] as? String) == id }) else {
            exitWithError("List '\(id)' not found")
        }
        let listsDir = config["lists_dir"] as? String ?? "~/quartermaster/lists"
        ensureOutputDir(listsDir)
        let listItems = list["items"] as? [[String: Any]] ?? []
        let name = list["name"] as? String ?? id

        var lines = ["# \(name)", ""]
        for item in listItems {
            let itemName = item["name"] as? String ?? "?"
            let qty = item["quantity"] as? Int ?? 1
            let unit = item["unit"] as? String ?? ""
            let purchased = item["purchased"] as? Bool ?? false
            let checkbox = purchased ? "[x]" : "[ ]"
            lines.append("- \(checkbox) \(itemName) (\(qty) \(unit))")
        }

        let fileURL = resolvePath(listsDir).appendingPathComponent("\(id).md")
        let content = lines.joined(separator: "\n")
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        printJSON(["status": "exported", "path": fileURL.path])
        return
    }

    if hasFlag("--sync", in: args) {
        requestReminderAccess()
        let syncListName = config["sync_reminder_list"] as? String ?? "Shopping"
        let syncList = findOrCreateReminderList(syncListName)
        let isSummary = hasFlag("--summary", in: args)

        let lastSyncStr = config["last_sync"] as? String
        let lastSyncDate: Date?
        if let str = lastSyncStr {
            let fmt = ISO8601DateFormatter()
            lastSyncDate = fmt.date(from: str)
            if let d = lastSyncDate, d > Date() {
                exitWithError("Invalid last_sync timestamp (future date): \(str)")
            }
        } else {
            lastSyncDate = nil
        }

        let reminders = fetchReminders(from: syncList, includeCompleted: true)
        var purchasedItems: [[String: Any]] = []

        for reminder in reminders {
            guard reminder.isCompleted,
                  let completionDate = reminder.completionDate,
                  lastSyncDate == nil || completionDate > lastSyncDate! else { continue }

            let title = reminder.title ?? ""
            for listIdx in 0..<lists.count {
                var listItems = lists[listIdx]["items"] as? [[String: Any]] ?? []
                for itemIdx in 0..<listItems.count {
                    let itemName = listItems[itemIdx]["name"] as? String ?? ""
                    let synced = listItems[itemIdx]["synced"] as? Bool ?? false
                    let purchased = listItems[itemIdx]["purchased"] as? Bool ?? false
                    let listName = lists[listIdx]["name"] as? String ?? ""
                    let expectedPrefix = "[\(listName)] \(itemName)"

                    if synced && !purchased && title.lowercased().hasPrefix(expectedPrefix.lowercased()) {
                        listItems[itemIdx]["purchased"] = true
                        purchasedItems.append([
                            "name": itemName,
                            "list": listName,
                            "list_id": lists[listIdx]["id"] as? String ?? "",
                            "from_inventory": listItems[itemIdx]["from_inventory"] ?? NSNull()
                        ])
                        break
                    }
                }
                lists[listIdx]["items"] = listItems
            }
        }

        var pushedCount = 0
        for listIdx in 0..<lists.count {
            let archived = lists[listIdx]["archived"] as? Bool ?? false
            if archived { continue }

            var listItems = lists[listIdx]["items"] as? [[String: Any]] ?? []
            let listName = lists[listIdx]["name"] as? String ?? ""

            for itemIdx in 0..<listItems.count {
                let synced = listItems[itemIdx]["synced"] as? Bool ?? false
                let purchased = listItems[itemIdx]["purchased"] as? Bool ?? false
                if synced || purchased { continue }

                let itemName = listItems[itemIdx]["name"] as? String ?? ""
                let qty = listItems[itemIdx]["quantity"] as? Int ?? 1
                let unit = listItems[itemIdx]["unit"] as? String ?? ""

                let reminder = EKReminder(eventStore: store)
                reminder.title = "[\(listName)] \(itemName) (\(qty) \(unit))"
                reminder.calendar = syncList

                do {
                    try store.save(reminder, commit: true)
                    listItems[itemIdx]["synced"] = true
                    pushedCount += 1
                } catch {
                    // Skip failed items, continue with rest
                }
            }
            lists[listIdx]["items"] = listItems
        }

        listsData["lists"] = lists
        writeLists(listsData)

        var updatedConfig = config
        updatedConfig["last_sync"] = ISO8601DateFormatter().string(from: Date())
        writeConfig(updatedConfig)

        if isSummary {
            let activeLists = lists.filter { !($0["archived"] as? Bool ?? false) }
            let listSummaries: [[String: Any]] = activeLists.map { list in
                let items = list["items"] as? [[String: Any]] ?? []
                let syncedCount = items.filter { $0["synced"] as? Bool ?? false }.count
                return [
                    "name": list["name"] ?? "",
                    "id": list["id"] ?? "",
                    "item_count": items.count,
                    "synced": syncedCount == items.count && !items.isEmpty
                ] as [String: Any]
            }
            printJSON([
                "status": "synced",
                "pushed": pushedCount,
                "purchased_since_last_sync": purchasedItems,
                "active_lists": listSummaries
            ])
        } else {
            printJSON([
                "status": "synced",
                "pushed": pushedCount,
                "purchased_since_last_sync": purchasedItems,
                "lists": lists
            ])
        }
        return
    }

    let showAll = hasFlag("--all", in: args)
    let wantBrief = hasFlag("--save-brief", in: args)

    var filtered = lists
    if !showAll {
        filtered = filtered.filter { !($0["archived"] as? Bool ?? false) }
    }

    let summaries: [[String: Any]] = filtered.map { list in
        let items = list["items"] as? [[String: Any]] ?? []
        let purchasedCount = items.filter { $0["purchased"] as? Bool ?? false }.count
        return [
            "id": list["id"] ?? "",
            "name": list["name"] ?? "",
            "item_count": items.count,
            "purchased_count": purchasedCount,
            "archived": list["archived"] ?? false,
            "created": list["created"] ?? ""
        ] as [String: Any]
    }

    var result: [String: Any] = ["lists": summaries, "count": summaries.count]
    if !showAll { result["filter"] = "active_only" }

    if wantBrief {
        var lines = ["# Quartermaster Shopping Brief — \(ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate]))", ""]
        lines.append("\(summaries.count) lists")
        for s in summaries {
            let name = s["name"] as? String ?? "?"
            let count = s["item_count"] as? Int ?? 0
            lines.append("- \(name): \(count) items")
        }
        saveBrief(lines.joined(separator: "\n"), config: config)
        result["brief_saved"] = true
    }

    printJSON(result)
}

func cmdShopAdd(_ args: [String]) {
    guard let listId = flagValue("--list", in: args) else {
        exitWithError("Usage: shop-add --list <id> [--name <name> --qty <N> --unit <unit> [--category <cat>] | --from-inventory <inv-id> [--qty <N>] | --restock]")
    }

    var listsData = readLists()
    var lists = shoppingLists(listsData)

    guard let listIdx = lists.firstIndex(where: { ($0["id"] as? String) == listId }) else {
        exitWithError("List '\(listId)' not found")
    }

    let archived = lists[listIdx]["archived"] as? Bool ?? false
    if archived {
        exitWithError("Cannot add items to archived list '\(listId)'")
    }

    var listItems = lists[listIdx]["items"] as? [[String: Any]] ?? []

    // Bulk restock mode: add all inventory items below restock threshold
    if hasFlag("--restock", in: args) {
        let inv = readInventory()
        let items = inventoryItems(inv)
        let lowItems = items.filter { isLowStock($0) }

        if lowItems.isEmpty {
            printJSON(["status": "no_restock_needed", "message": "No inventory items below restock threshold"])
            return
        }

        var added: [[String: Any]] = []
        for item in lowItems {
            let name = item["name"] as? String ?? ""
            let threshold = item["restock_threshold"] as? Int ?? 0
            let qty = item["quantity"] as? Int ?? 0
            let restockQty = threshold - qty + 1
            let unit = item["unit"] as? String ?? ""
            let category = item["category"] as? String ?? ""
            let invId = item["id"] as? String ?? ""

            let newItem: [String: Any] = [
                "name": name,
                "category": category,
                "quantity": max(restockQty, 1),
                "unit": unit,
                "from_inventory": invId,
                "synced": false,
                "purchased": false
            ]
            listItems.append(newItem)
            added.append(newItem)
        }

        lists[listIdx]["items"] = listItems
        listsData["lists"] = lists
        writeLists(listsData)
        printJSON(["status": "restock_added", "added": added, "count": added.count])
        return
    }

    // From-inventory mode: link a shopping item to an inventory entry
    if let invId = flagValue("--from-inventory", in: args) {
        let inv = readInventory()
        let items = inventoryItems(inv)
        guard let item = items.first(where: { ($0["id"] as? String) == invId }) else {
            exitWithError("Inventory item '\(invId)' not found")
        }

        let name = item["name"] as? String ?? ""
        let unit = item["unit"] as? String ?? ""
        let category = item["category"] as? String ?? ""
        let qty: Int
        if let qtyStr = flagValue("--qty", in: args), let q = Int(qtyStr) {
            qty = q
        } else {
            let threshold = item["restock_threshold"] as? Int ?? 1
            let currentQty = item["quantity"] as? Int ?? 0
            qty = max(threshold - currentQty + 1, 1)
        }

        let newItem: [String: Any] = [
            "name": name,
            "category": category,
            "quantity": qty,
            "unit": unit,
            "from_inventory": invId,
            "synced": false,
            "purchased": false
        ]

        listItems.append(newItem)
        lists[listIdx]["items"] = listItems
        listsData["lists"] = lists
        writeLists(listsData)
        printJSON(["status": "added", "item": newItem])
        return
    }

    // Manual mode: add an item by name, quantity, and unit
    guard let name = flagValue("--name", in: args) else {
        exitWithError("Provide --name <name> --qty <N> --unit <unit>, or --from-inventory <id>, or --restock")
    }
    guard let qtyStr = flagValue("--qty", in: args), let qty = Int(qtyStr) else {
        exitWithError("--qty <N> is required")
    }
    guard let unit = flagValue("--unit", in: args) else {
        exitWithError("--unit <unit> is required")
    }

    let category = flagValue("--category", in: args) ?? ""

    let newItem: [String: Any] = [
        "name": name,
        "category": category,
        "quantity": qty,
        "unit": unit,
        "from_inventory": NSNull(),
        "synced": false,
        "purchased": false
    ]

    listItems.append(newItem)
    lists[listIdx]["items"] = listItems
    listsData["lists"] = lists
    writeLists(listsData)
    printJSON(["status": "added", "item": newItem])
}

func cmdShopDone(_ args: [String]) {
    exitWithError("Not yet implemented")
}

main()
