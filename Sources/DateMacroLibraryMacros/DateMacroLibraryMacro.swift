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
        
        // Extract baseName from property name (remove "LocalDate" or "Date" suffix)
        // Handle placeholder properties ending with "Macro" (e.g., "_dueLocalDateMacro" -> "due")
        let baseName: String
        let localPropertyName: String
        
        // Check if it's a placeholder property ending with "Macro"
        if identifier.hasSuffix("Macro") {
            // Extract the part before "Macro" and check if it contains "LocalDate"
            let macroEndIndex = identifier.index(identifier.endIndex, offsetBy: -5) // "Macro".count
            let withoutMacro = String(identifier[..<macroEndIndex])
            
            if withoutMacro.hasSuffix("LocalDate") {
                let localDateEndIndex = withoutMacro.index(withoutMacro.endIndex, offsetBy: -9) // "LocalDate".count
                baseName = String(withoutMacro[..<localDateEndIndex])
                // Remove leading underscore and "Macro" suffix to get the public property name
                let publicName = withoutMacro.hasPrefix("_") ? String(withoutMacro.dropFirst()) : withoutMacro
                localPropertyName = publicName
            } else if withoutMacro.hasSuffix("Date") {
                let dateEndIndex = withoutMacro.index(withoutMacro.endIndex, offsetBy: -4) // "Date".count
                baseName = String(withoutMacro[..<dateEndIndex])
                let publicName = withoutMacro.hasPrefix("_") ? String(withoutMacro.dropFirst()) : withoutMacro
                localPropertyName = publicName
            } else {
                throw MacroError.invalidPropertyName(identifier)
            }
        } else if identifier.hasSuffix("LocalDate") {
            let endIndex = identifier.index(identifier.endIndex, offsetBy: -9) // "LocalDate".count
            baseName = String(identifier[..<endIndex])
            localPropertyName = identifier // Use the original name
        } else if identifier.hasSuffix("Date") && !identifier.hasSuffix("LocalDate") {
            let endIndex = identifier.index(identifier.endIndex, offsetBy: -4) // "Date".count
            baseName = String(identifier[..<endIndex])
            localPropertyName = identifier // Use the original name (e.g., "recurringEndDate")
        } else {
            throw MacroError.invalidPropertyName(identifier)
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
        
        // Generate the computed property - the user's declaration will be replaced/ignored
        // Build computed property with getter/setter
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
