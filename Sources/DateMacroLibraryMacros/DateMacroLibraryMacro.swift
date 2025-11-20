import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `LocalizedDate` macro, which generates GMT/local date conversion properties
/// 
/// Usage:
/// ```swift
/// @LocalizedDate(baseName: "due", withTimeProperty: "hasDueTime", isDueDate: true, setterSideEffects: "sortDueDate = _dueLocalDate ?? Date.distantFuture; updateMinDate()")
/// ```
public struct LocalizedDateMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract property name from declaration
        guard let variableDecl = declaration.as(VariableDeclSyntax.self),
              let binding = variableDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            throw MacroError.invalidDeclaration
        }
        
        // Extract baseName from property name and generate the public property name
        // If property ends with "LocalDate" or "Date", use it as-is
        // Otherwise, append "Date" to the property name (e.g., "dueLocal" -> "dueLocalDate")
        let baseName: String
        let localPropertyName: String
        
        if identifier.hasSuffix("LocalDate") {
            // Property already ends with "LocalDate" (e.g., "dueLocalDate")
            let endIndex = identifier.index(identifier.endIndex, offsetBy: -9) // "LocalDate".count
            baseName = String(identifier[..<endIndex])
            localPropertyName = identifier
        } else if identifier.hasSuffix("Date") && !identifier.hasSuffix("LocalDate") {
            // Property ends with "Date" but not "LocalDate" (e.g., "recurringEndDate")
            let endIndex = identifier.index(identifier.endIndex, offsetBy: -4) // "Date".count
            baseName = String(identifier[..<endIndex])
            localPropertyName = identifier
        } else {
            // Property doesn't end with "Date" - append "Date" to create the public property name
            // e.g., "dueLocal" -> baseName "due", public property "dueLocalDate"
            // e.g., "startLocal" -> baseName "start", public property "startLocalDate"
            // e.g., "recurringEnd" -> baseName "recurringEnd", public property "recurringEndDate"
            baseName = identifier
            localPropertyName = "\(identifier)Date"
        }
        
        // Extract macro arguments
        let arguments = node.arguments?.as(LabeledExprListSyntax.self) ?? LabeledExprListSyntax([])
        
        var withTimeProperty: String?
        var isDueDate: Bool = true
        var legacyPropertyName: String?
        var setterSideEffects: String?
        
        for argument in arguments {
            let label = argument.label?.text
            if label == "withTimeProperty", let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                withTimeProperty = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
            } else if label == "isDueDate", let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                isDueDate = boolLiteral.literal.text == "true"
            } else if label == "legacyPropertyName", let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                legacyPropertyName = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
            } else if label == "setterSideEffects", let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                setterSideEffects = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
            }
        }
        
        // Generate property names
        let gmtPropertyName = "\(baseName)GMTDate"
        let cachedPropertyName = "_\(baseName)LocalDate"
        
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
        let withTimeArg = withTimeProperty ?? "false"
        let isDueDateArg = isDueDate ? "true" : "false"
        getterCode += """
        if \(cachedPropertyName) == nil && \(gmtPropertyName) != nil {
            \(cachedPropertyName) = Self.localDate(from: \(gmtPropertyName), withTime: \(withTimeArg), isDueDate: \(isDueDateArg))
        }
        return \(cachedPropertyName)
        """
        
        // Build setter statements  
        let setterWithTimeArg = withTimeProperty ?? "false"
        var setterCode = """
        \(gmtPropertyName) = Self.gmtDate(from: newValue, withTime: \(setterWithTimeArg), isDueDate: \(isDueDateArg))
        \(cachedPropertyName) = Self.localDate(from: \(gmtPropertyName), withTime: \(setterWithTimeArg), isDueDate: \(isDueDateArg))
        """
        
        // Add setter side effects
        if let sideEffects = setterSideEffects {
            setterCode += "\n\(sideEffects)"
        }
        
        // Generate the computed property with the "Date" suffix appended if needed
        // The user's declaration (e.g., "dueLocal") is just a placeholder for the macro
        let computedProperty = try VariableDeclSyntax(
            """
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
        
        return properties
    }
}

enum MacroError: Error {
    case invalidDeclaration
    case invalidPropertyName(String)
}

@main
struct DateMacroLibraryPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LocalizedDateMacro.self,
    ]
}
