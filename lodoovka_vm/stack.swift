struct Stack<T> {
    var array: [T] = []
    
    var tip: T? {
        return array.last
    }
    
    mutating func push(x: T) {
        array.append(x)
    }
    
    mutating func pop() -> T? {
        if array.count > 0 {
            return array.removeLast()
        } else {
            return nil
        }
    }
}