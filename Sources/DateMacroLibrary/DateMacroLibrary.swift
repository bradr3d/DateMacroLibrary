// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A freestanding macro that generates GMT/local date conversion properties for date localization.
/// 
/// This macro generates:
/// - A GMT storage property: `{baseName}GMTDate: Date?`
/// - A private cached local date property: `_{baseName}LocalDate: Date?`
/// - A public computed property: `{baseName}LocalDate: Date?` with getter/setter (marked @Transient)
/// - Optionally, a legacy computed property: `{baseName}Date: Date?` that forwards to the LocalDate property
/// - Optional legacy property migration support
///
/// Example:
/// ```swift
/// #LocalizedDate(baseName: "due", withTimeProperty: "hasDueTime", isDueDate: true, setterSideEffects: "sortDueDate = _dueLocalDate ?? Date.distantFuture; updateMinDate()")
/// // Generates: dueGMTDate, _dueLocalDate, and dueLocalDate
/// 
/// #LocalizedDate(baseName: "recurringEnd", includeLegacyComputedProperty: true)
/// // Generates: recurringEndGMTDate, _recurringEndLocalDate, recurringEndLocalDate, and recurringEndDate (forwards to recurringEndLocalDate)
/// ```
@freestanding(declaration, names: arbitrary)
public macro LocalizedDate(
    baseName: String,
    withTimeProperty: String? = nil,
    isDueDate: Bool = true,
    legacyPropertyName: String? = nil,
    setterSideEffects: String? = nil,
    includeLegacyComputedProperty: Bool = false
) = #externalMacro(module: "DateMacroLibraryMacros", type: "LocalizedDateMacro")

/// An attached macro that adds Identifiable conformance and an id property to an enum.
///
/// This macro:
/// - Adds `Identifiable` protocol conformance to the enum
/// - Adds `var id: Self { self }` property
///
/// Example:
/// ```swift
/// @IdentifiableEnum
/// enum Status {
///     case active
///     case inactive
/// }
/// // The enum now conforms to Identifiable and has var id: Self { self }
/// ```
@attached(member, names: named(id))
@attached(extension, conformances: Identifiable)
public macro IdentifiableEnum() = #externalMacro(module: "DateMacroLibraryMacros", type: "IdentifiableEnumMacro")
