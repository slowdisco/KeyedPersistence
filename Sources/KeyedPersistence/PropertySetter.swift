

protocol PropertySetter {
    
    associatedtype Root
    
    func apply(_ obj: inout Self.Root)
    
}

struct VoidPropSetter<Root>: PropertySetter {
    
    @inline(__always) func apply(_ obj: inout Root) {
        return
    }
    
}

struct MutatingPropSetter<Root, `Type`>: PropertySetter {
    
    let keyPath: Swift.WritableKeyPath<Root, `Type`>
    let value: `Type`
    
    init(_ keyPath: Swift.WritableKeyPath<Root, `Type`>, _ value: `Type`) {
        self.keyPath = keyPath
        self.value = value
    }
    
    @inline(__always) func apply(_ obj: inout Self.Root) {
        obj[keyPath: keyPath] = value
    }
    
}

struct NonmutatingPropSetter<Root, `Type`>: PropertySetter {
    
    let keyPath: ReferenceWritableKeyPath<Root, `Type`>
    let value: `Type`
    
    init(_ keyPath: Swift.ReferenceWritableKeyPath<Root, `Type`>, _ value: `Type`) {
        self.keyPath = keyPath
        self.value = value
    }
    
    @inline(__always) func apply(_ obj: inout Root) {
        obj[keyPath: keyPath] = value
    }
    
    @inline(__always) func apply(_ obj: Root) {
        obj[keyPath: keyPath] = value
    }
    
}

struct ChainedPropSetter<Root, Setr1, Setr2> where Setr1: PropertySetter, Setr2: PropertySetter, Setr1.Root == Root, Setr2.Root == Root {
    
    let element1: Setr1
    let element2: Setr2
    
    init(_ s1: Setr1, _ s2: Setr2) {
        self.element1 = s1
        self.element2 = s2
    }
    
}

extension ChainedPropSetter: PropertySetter {
    
    @inline(__always) func apply(_ obj: inout Root) {
        element1.apply(&obj)
        element2.apply(&obj)
    }
    
}



