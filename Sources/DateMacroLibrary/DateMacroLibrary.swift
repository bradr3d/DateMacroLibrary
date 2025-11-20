// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A macro that generates GMT/local date conversion properties for date localization.
/// 
/// The property name you declare is used as the base name. If it doesn't end with "Date",
/// the macro automatically appends "Date" to create the public property name.
/// 
/// Examples:
/// - `dueLocal` → generates `dueLocalDate` (baseName: "dueLocal")
/// - `dueLocalDate` → generates `dueLocalDate` (baseName: "due")
/// - `recurringEnd` → generates `recurringEndDate` (baseName: "recurringEnd")
/// 
/// This macro generates:
/// - A GMT storage property: `{baseName}GMTDate: Date?`
/// - A private cached local date property: `_{baseName}LocalDate: Date?`
/// - A public computed property: `{propertyName}Date: Date?` with getter/setter
/// - Optional legacy property migration support
///
/// Example:
/// ```swift
/// @LocalizedDate(withTimeProperty: "hasDueTime", isDueDate: true, setterSideEffects: "sortDueDate = _dueLocalDate ?? Date.distantFuture; updateMinDate()")
/// var dueLocal: Date?  // Macro generates dueLocalDate as the public computed property
/// ```
@attached(peer, names: arbitrary)
public macro LocalizedDate(
    withTimeProperty: String? = nil,
    isDueDate: Bool = true,
    legacyPropertyName: String? = nil,
    setterSideEffects: String? = nil
) = #externalMacro(module: "DateMacroLibraryMacros", type: "LocalizedDateMacro")
