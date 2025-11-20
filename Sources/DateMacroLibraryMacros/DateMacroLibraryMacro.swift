import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `LocalizedDate` macro, which generates GMT/local date conversion properties
/// 
/// Usage:
/// ```swift
/// #LocalizedDate(baseName: "due", withTimeProperty: "hasDueTime", isDueDate: true, setterSideEffects: "sortDueDate = _dueLocalDate ?? Date.distantFuture; updateMinDate()")
/// ```
public struct LocalizedDateMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract baseName from macro arguments (required parameter)
        let arguments = node.argumentList
        
        var baseName: String?
        var withTimeProperty: String?
        var isDueDate: Bool = true
        var legacyPropertyName: String?
        var setterSideEffects: String?
        var includeLegacyComputedProperty: Bool = false
        
        for argument in arguments {
            let label = argument.label?.text
            if label == "baseName", let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                baseName = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
            } else if label == "withTimeProperty", let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                withTimeProperty = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
            } else if label == "isDueDate", let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                isDueDate = boolLiteral.literal.text == "true"
            } else if label == "legacyPropertyName", let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                legacyPropertyName = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
            } else if label == "setterSideEffects", let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                setterSideEffects = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
            } else if label == "includeLegacyComputedProperty", let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                includeLegacyComputedProperty = boolLiteral.literal.text == "true"
            }
        }
        
        guard let baseName = baseName else {
            throw MacroError.missingBaseName
        }
        
        // Generate property names
        let gmtPropertyName = "\(baseName)GMTDate"
        let cachedPropertyName = "_\(baseName)LocalDate"
        let localPropertyName = "\(baseName)LocalDate"
        
        var properties: [DeclSyntax] = []
        
        // Build legacy property if needed
        if let legacyPropertyName = legacyPropertyName {
            let legacyProperty = try VariableDeclSyntax(
                "private var \(raw: legacyPropertyName): Date?"
            )
            properties.append(DeclSyntax(legacyProperty))
        }
        
        // Build GMT storage property
        let gmtProperty = try VariableDeclSyntax(
            "public var \(raw: gmtPropertyName): Date?"
        )
        properties.append(DeclSyntax(gmtProperty))
        
        // Build private cached local date property
        let cachedProperty = try VariableDeclSyntax(
            "private(set) var \(raw: cachedPropertyName): Date?"
        )
        properties.append(DeclSyntax(cachedProperty))
        
        // Build getter statements
        var getterCode = ""
        
        // Legacy migration logic
        if let legacyPropertyName = legacyPropertyName {
            getterCode += """
            if \(cachedPropertyName) == nil && \(gmtPropertyName) == nil, let legacy = \(legacyPropertyName) {
                \(legacyPropertyName) = nil
                self.\(localPropertyName) = legacy
            }
            """
        }
        
        // Cache population logic
        // If withTimeProperty is provided, read it at runtime; otherwise use false
        let withTimeExpression: String
        if let withTimeProperty = withTimeProperty {
            withTimeExpression = "self.\(withTimeProperty)"
        } else {
            withTimeExpression = "false"
        }
        let isDueDateArg = isDueDate ? "true" : "false"
        
        // If withTimeProperty is provided, we need to always recalculate based on current value
        // since it can change at runtime. The cache is still used but always recalculated
        // to ensure it reflects the current withTime value.
        if withTimeProperty != nil {
            // Always recalculate when withTime can change at runtime
            // This ensures that if hasDueTime/hasStartTime changes, the conversion uses the new value
            getterCode += """
            if \(gmtPropertyName) != nil {
                // Always recalculate to use current withTime value (can change at runtime)
                \(cachedPropertyName) = Self.localDate(from: \(gmtPropertyName), withTime: \(withTimeExpression), isDueDate: \(isDueDateArg))
            } else {
                \(cachedPropertyName) = nil
            }
            return \(cachedPropertyName)
            """
        } else {
            // Cache when withTime is constant
            getterCode += """
            if \(cachedPropertyName) == nil && \(gmtPropertyName) != nil {
                \(cachedPropertyName) = Self.localDate(from: \(gmtPropertyName), withTime: \(withTimeExpression), isDueDate: \(isDueDateArg))
            }
            return \(cachedPropertyName)
            """
        }
        
        // Build setter statements  
        var setterCode = """
        \(gmtPropertyName) = Self.gmtDate(from: newValue, withTime: \(withTimeExpression), isDueDate: \(isDueDateArg))
        \(cachedPropertyName) = Self.localDate(from: \(gmtPropertyName), withTime: \(withTimeExpression), isDueDate: \(isDueDateArg))
        """
        
        // Add setter side effects
        if let sideEffects = setterSideEffects {
            setterCode += "\n\(sideEffects)"
        }
        
        // Generate the computed property with @Transient attribute
        // This is a computed property derived from GMT date and shouldn't be persisted
        let computedProperty = try VariableDeclSyntax(
            """
            @Transient
            public var \(raw: localPropertyName): Date? {
                get {
                    \(raw: getterCode)
                }
                set {
                    \(raw: setterCode)
                }
            }
            """
        )
        properties.append(DeclSyntax(computedProperty))
        
        // Optionally generate a legacy computed property without "Local" in the name
        // This forwards to the LocalDate property for backward compatibility
        if includeLegacyComputedProperty {
            let legacyComputedPropertyName = "\(baseName)Date"
            let legacyComputedProperty = try VariableDeclSyntax(
                """
                @Transient
                public var \(raw: legacyComputedPropertyName): Date? {
                    get {
                        return \(raw: localPropertyName)
                    }
                    set {
                        \(raw: localPropertyName) = newValue
                    }
                }
                """
            )
            properties.append(DeclSyntax(legacyComputedProperty))
        }
        
        return properties
    }
}

enum MacroError: Error {
    case invalidDeclaration
    case invalidPropertyName(String)
    case missingBaseName
}

@main
struct DateMacroLibraryPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LocalizedDateMacro.self,
    ]
}
