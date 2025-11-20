// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A macro that generates GMT/local date conversion properties for date localization.
/// 
/// The baseName is automatically extracted from the property name by removing the "LocalDate" suffix.
/// For example, `dueLocalDate` will extract "due" as the baseName.
/// 
/// This macro generates:
/// - A GMT storage property: `{baseName}GMTDate: Date?`
/// - A private cached local date property: `_{baseName}LocalDate: Date?`
/// - A public computed property: `{baseName}LocalDate: Date?` with getter/setter
/// - Optional legacy property migration support
///
/// Example:
/// ```swift
/// @LocalizedDate(withTimeProperty: "hasDueTime", isDueDate: true, setterSideEffects: "sortDueDate = _dueLocalDate ?? Date.distantFuture; updateMinDate()")
/// public var dueLocalDate: Date?
/// ```
@attached(peer, names: arbitrary)
@attached(accessor)
public macro LocalizedDate(
    withTimeProperty: String? = nil,
    isDueDate: Bool = true,
    legacyPropertyName: String? = nil,
    setterSideEffects: String? = nil
) = #externalMacro(module: "DateMacroLibraryMacros", type: "LocalizedDateMacro")
