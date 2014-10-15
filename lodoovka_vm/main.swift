import Foundation

let asm = NSString(contentsOfFile: "test.txt", encoding: NSUTF8StringEncoding, error: nil)!

let lexer = Lexer(string: asm)

lexer.registerState("root", [
    // whitespace
    rule("\\n", { _ in .Newline }),
    rule("[^\\S\\n]+", { _ in nil }),
    // comment
    rule(";.*?(?=\\n|\\z)", { _ in nil }),
    // hex numbers
    rule("0x[0-9a-fA-F]+", {
        var number: UInt32 = 0
        let scanner = NSScanner(string: $0)
        scanner.scanHexInt(&number)
        return .Number(Int(number))
    }),
    // bin numbers
    rule("0b[01]+", {
        let bin: NSString = $0.substringFromIndex(2)
        return .Number(strtol(bin.UTF8String, nil, 2))
    }),
    // decimal numbers
    rule("\\d+", { .Number($0.integerValue) }),
    // arrow
    rule("->", { _ in .Arrow }),
    // strings
    rule("\"", .Push("string"), { _ in nil }),
    // labels
    rule("[a-zA-Z_]+:", {
        let string = $0 as NSString
        let label = string.substringToIndex(string.length - 1)
        return .Label(label)
    }),
    // macros
    rule("@[a-zA-Z_]+", {
        let string = $0 as NSString
        let name = string.substringFromIndex(1)
        return .Macro(name)
    }),
    // other word symbols
    rule("[a-zA-Z_]+", { .Symbol($0) })
    ])

lexer.registerState("string", [
    rule("[^\\\"]+", { .String($0) }),
    rule("\"", .Pop, { _ in nil })
    ])

lexer.lex()

for token in lexer.tokens {
    println(token.description)
}