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

/// An attached macro that adds an id property to an enum for Identifiable conformance.
///
/// This macro:
/// - Adds `var id: Self { self }` property (with matching access level)
///
/// Note: You must manually add `: Identifiable` to your enum declaration.
/// The macro will add the required `id` property with the same access level as the enum.
/// Private enums are not supported - use `fileprivate`, `internal`, or `public` instead.
///
/// Example:
/// ```swift
/// @IdentifiableEnum
/// enum Status: Identifiable {
///     case active
///     case inactive
/// }
/// // The enum has var id: Self { self }
/// ```
@attached(member, names: named(id))
public macro IdentifiableEnum() = #externalMacro(module: "DateMacroLibraryMacros", type: "IdentifiableEnumMacro")
