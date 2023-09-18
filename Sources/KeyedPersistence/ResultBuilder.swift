
@resultBuilder public struct ArrayBuilder<Element> {
    
    public static func buildBlock(_ components: Element...) -> [Element] {
        components
    }
    
    public static func buildBlock(_ components: [Element]...) -> [Element] {
        components.flatMap {
            $0
        }
    }
    
    public static func buildBlock() -> [Element] {
        []
    }
    
    public static func buildExpression(_ expression: Element?) -> [Element] {
        expression == nil ? [] : [expression!]
    }
    
    public static func buildExpression(_ expression: Element) -> [Element] {
        [expression]
    }
    
    public static func buildExpression(_ expression: [Element]) -> [Element] {
        expression
    }
    
    public static func buildArray(_ components: [[Element]]) -> [Element] {
        components.flatMap {
            $0
        }
    }
    
    public static func buildOptional(_ component: [Element]?) -> [Element] {
        component ?? []
    }
    
    public static func buildEither(first component: [Element]) -> [Element] {
        component
    }
    
    public static func buildEither(second component: [Element]) -> [Element] {
        component
    }
    
    public static func buildLimitedAvailability(_ component: [Element]) -> [Element] {
        component
    }
    
}


