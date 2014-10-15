import Foundation

struct Stream {
    let string: NSString
    var position: Int
    
    var matchingRange: NSRange {
        return NSRange(location: position, length: string.length - position)
    }
    
    var snippet: NSString {
        let length = min(string.length - position, 20)
        return string.substringWithRange(NSRange(location: position, length: length))
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
    case Macro(Swift.String)
    case String(Swift.String)
    case Number(Int)
    
    var description: Swift.String {
        switch self {
        case .Newline: return "NEWLINE"
        case .Arrow: return "ARROW"
        case .Label(let string): return "LABEL \(string):"
        case .Symbol(let string): return "SYMBOL \(string)"
        case .Macro(let string): return "MACRO \(string)"
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
                fatalError("No rule matched for stream:\"\(stream.snippet)\"…")
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