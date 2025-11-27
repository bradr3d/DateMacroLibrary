import DateMacroLibrary

// Example usage of LocalizedDate macro would be in a SwiftData model:
// @LocalizedDate(withTimeProperty: "hasDueTime", isDueDate: true)
// public var dueLocalDate: Date?

// Example usage of IdentifiableEnum macro:
@IdentifiableEnum
enum Status {
    case active
    case inactive
    case pending
}

// The enum now conforms to Identifiable and has var id: Self { self }
let status: Status = .active
print("Status ID: \(status.id)") // Prints: Status ID: active

print("DateMacroLibrary macro plugin is ready to use!")
