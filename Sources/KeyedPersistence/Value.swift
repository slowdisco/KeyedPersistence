

/// Access value managed by a `NSManagedObject` instance.
/// An error of `TypeError.errorType` will be thrown if the `Type` mismatched with what actual contains.
protocol OpaqueValue {
    
    func tryGet<`Type`>(_: `Type`.Type) throws -> `Type`?
    
}



