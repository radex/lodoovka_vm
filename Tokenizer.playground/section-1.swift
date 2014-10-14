import Foundation

struct Stream {
    let string: NSString
    var position: Int
    
    var matchingRange: NSRange {
        return NSRange(location: position, length: string.length - position)
    }
}

struct Stack<T> {
    var array: [T] = []
    var tip: T? { return array.last }
    mutating func push(x: T) { array.append(x) }
    mutating func pop() -> T? {
        if array.count > 0 {
            return array.removeLast()
        } else {
            return nil
        }
    }
}


func matchRegexAt(#pattern: String, stream: Stream) -> String? {
    let regex = NSRegularExpression(pattern: "^" + pattern, options: nil, error: nil)!
    let match = regex.firstMatchInString(stream.string, options: nil, range: stream.matchingRange)
    
    if let range = match?.rangeAtIndex(0) {
        return stream.string.substringWithRange(range)
    } else {
        return nil
    }
}

enum NextState {
    case Stay
    case Pop
    case Push(String)
}

typealias Rule = Stream -> (Stream, Token?, NextState)?

func rule(regex: String, tokenizer: NSString -> Token?) -> Rule {
    return rule(regex, .Stay, tokenizer)
}

func rule(regex: String, next: NextState, tokenizer: NSString -> Token?) -> Rule {
    return { stream in
        if let match: NSString = matchRegexAt(pattern: regex, stream) {
            var newStream = stream
            newStream.position += match.length
            return (newStream, tokenizer(match), next)
        } else {
            return nil
        }
    }
}

enum Token: Printable {
    case Newline
    case Arrow
    case Label(Swift.String)
    case Symbol(Swift.String)
    case String(Swift.String)
    case Number(Int)
    
    var description: Swift.String {
        switch self {
        case .Newline: return "\\n"
        case .Arrow: return "->"
        case .Label(let string): return "LABEL \(string):"
        case .Symbol(let string): return "SYMBOL \(string)"
        case .String(let string): return "STRING \"\(string)\""
        case .Number(let number): return "NUMBER \(number)"
        }
    }
}

class Lexer {
    var stream: Stream
    var tokens: [Token] = []
    var states: [String: [Rule]] = [:]
    var stack = Stack<String>()
    
    init(string: String) {
        stream = Stream(string: string, position: 0)
        stack.push("root")
    }
    
    func registerState(name: String, _ ruleset: [Rule]) {
        states[name] = ruleset
    }
    
    func lex() {
        while true {
            let ruleset = states[stack.tip!]!
            
            switch matchRuleset(ruleset) {
            case .Some(.Pop):
                stack.pop()
            case .Some(.Push(let state)):
                stack.push(state)
            default: return
            }
        }
    }
    
    func matchRuleset(ruleset: [Rule]) -> NextState? {
        while stream.position < stream.string.length {
            if let nextState = matchRulesetOnce(ruleset) {
                switch nextState {
                case .Stay: continue
                default: return nextState
                }
            } else {
                fatalError("No rule matched :(")
            }
        }
        
        return nil
    }
    
    func matchRulesetOnce(ruleset: [Rule]) -> NextState? {
        for rule in ruleset {
            if let nextState = matchRule(rule) {
                return nextState
            }
        }
        
        return nil
    }
    
    func matchRule(rule: Rule) -> NextState? {
        if let (outputStream, token, next) = rule(stream) {
            stream = outputStream
            
            if let token = token {
                tokens.append(token)
            }
            
            return next
        } else {
            return nil
        }
    }
}

let lexer = Lexer(string:
    "main:\n" +
    "load 0xFFAA -> A ; some memory loading\n" +
    "add A 10 -> A\n" +
    "or A 0b001101 -> B\n" +
    "\n" +
    "DATA\n" +
    "test_string: DS \"Some string 0 0xFF 0b11\""
)

lexer.registerState("root", [
    // whitespace
    rule("\\n", { _ in .Newline }),
    rule("[^\\S\\n]+", { _ in nil }),
    // comment
    rule(";.*?\n", { _ in .Newline }),
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
lexer.stream.position