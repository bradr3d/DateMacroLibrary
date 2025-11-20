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
public struct LocalizedDateMacro: PeerMacro, AccessorMacro {
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
        let baseName: String
        let localPropertyName: String
        if identifier.hasSuffix("LocalDate") {
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
        
        // With @attached(accessor), we don't generate the computed property here
        // The accessors will be added to the user's property declaration
        // We only generate the supporting properties (GMT and cached)
        return properties
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        // Extract property name from declaration
        guard let variableDecl = declaration.as(VariableDeclSyntax.self),
              let binding = variableDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            throw MacroError.invalidDeclaration
        }
        
        // Extract baseName from property name
        let baseName: String
        if identifier.hasSuffix("LocalDate") {
            let endIndex = identifier.index(identifier.endIndex, offsetBy: -9)
            baseName = String(identifier[..<endIndex])
        } else if identifier.hasSuffix("Date") && !identifier.hasSuffix("LocalDate") {
            let endIndex = identifier.index(identifier.endIndex, offsetBy: -4)
            baseName = String(identifier[..<endIndex])
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
        
        let gmtPropertyName = "\(baseName)GMTDate"
        let cachedPropertyName = "_\(baseName)LocalDate"
        
        // Build getter code
        var getterCode = ""
        if let legacyPropertyName = legacyPropertyName {
            getterCode += """
            if \(cachedPropertyName) == nil && \(gmtPropertyName) == nil, let legacy = \(legacyPropertyName) {
                \(legacyPropertyName) = nil
                self.\(identifier) = legacy
            }
            """
        }
        let withTimeArg = withTimeProperty ?? "false"
        let isDueDateArg = isDueDate ? "true" : "false"
        getterCode += """
        if \(cachedPropertyName) == nil && \(gmtPropertyName) != nil {
            \(cachedPropertyName) = Self.localDate(from: \(gmtPropertyName), withTime: \(withTimeArg), isDueDate: \(isDueDateArg))
        }
        return \(cachedPropertyName)
        """
        
        // Build setter code
        var setterCode = """
        \(gmtPropertyName) = Self.gmtDate(from: newValue, withTime: \(withTimeArg), isDueDate: \(isDueDateArg))
        \(cachedPropertyName) = Self.localDate(from: \(gmtPropertyName), withTime: \(withTimeArg), isDueDate: \(isDueDateArg))
        """
        if let sideEffects = setterSideEffects {
            setterCode += "\n\(sideEffects)"
        }
        
        return [
            AccessorDeclSyntax("get { \(raw: getterCode) }"),
            AccessorDeclSyntax("set { \(raw: setterCode) }")
        ]
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
