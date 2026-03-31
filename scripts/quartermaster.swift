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
    exitWithError("Not yet implemented")
}

func cmdInvList(_ args: [String]) {
    exitWithError("Not yet implemented")
}

func cmdInvUpdate(_ args: [String]) {
    exitWithError("Not yet implemented")
}

func cmdShopList(_ args: [String]) {
    exitWithError("Not yet implemented")
}

func cmdShopAdd(_ args: [String]) {
    exitWithError("Not yet implemented")
}

func cmdShopDone(_ args: [String]) {
    exitWithError("Not yet implemented")
}

main()
