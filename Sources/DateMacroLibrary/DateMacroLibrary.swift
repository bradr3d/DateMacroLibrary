// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A freestanding macro that generates GMT/local date conversion properties for date localization.
/// 
/// This macro generates:
/// - A GMT storage property: `{baseName}GMTDate: Date?`
/// - A private cached local date property: `_{baseName}LocalDate: Date?`
/// - A public computed property: `{baseName}LocalDate: Date?` with getter/setter (marked @Transient)
/// - Optional legacy property migration support
///
/// Example:
/// ```swift
/// #LocalizedDate(baseName: "due", withTimeProperty: "hasDueTime", isDueDate: true, setterSideEffects: "sortDueDate = _dueLocalDate ?? Date.distantFuture; updateMinDate()")
/// // Generates: dueGMTDate, _dueLocalDate, and dueLocalDate
/// ```
@freestanding(declaration, names: arbitrary)
public macro LocalizedDate(
    baseName: String,
    withTimeProperty: String? = nil,
    isDueDate: Bool = true,
    legacyPropertyName: String? = nil,
    setterSideEffects: String? = nil
) = #externalMacro(module: "DateMacroLibraryMacros", type: "LocalizedDateMacro")
