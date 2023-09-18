
import CoreData


public protocol Storable: Equatable {
    
    static var attributeType: NSAttributeType { get }
    
}

extension Swift.Int16: Storable {
    
    public static var attributeType: NSAttributeType {
        .integer16AttributeType
    }
}

extension Swift.Int32: Storable {
    
    public static var attributeType: NSAttributeType {
        .integer32AttributeType
    }
}

extension Swift.Int64: Storable {
    
    public static var attributeType: NSAttributeType {
        .integer64AttributeType
    }
}

extension Swift.Float: Storable {
    
    public static var attributeType: NSAttributeType {
        .floatAttributeType
    }
}

extension Swift.Double: Storable {
    
    public static var attributeType: NSAttributeType {
        .doubleAttributeType
    }
}

extension Swift.String: Storable {
    
    public static var attributeType: NSAttributeType {
        .stringAttributeType
    }
}

extension Foundation.Data: Storable {
    
    public static var attributeType: NSAttributeType {
        .binaryDataAttributeType
    }
}

extension Foundation.Date: Storable {
    
    public static var attributeType: NSAttributeType {
        .dateAttributeType
    }
}

extension NSAttributeType {
    
    init(_: Int8.Type) {
        self = .integer16AttributeType
    }
    
    init(_: UInt8.Type) {
        self = .integer16AttributeType
    }
    
    init(_: Int16.Type) {
        self = .integer16AttributeType
    }
    
    init(_: UInt16.Type) {
        self = .integer32AttributeType
    }
    
    init(_: Int32.Type) {
        self = .integer32AttributeType
    }
    
    init(_: UInt32.Type) {
        self = .integer64AttributeType
    }
    
    init(_: Int64.Type) {
        self = .integer64AttributeType
    }
    
    init(_: UInt64.Type) {
        self = .integer64AttributeType
    }
    
    init(_: Float.Type) {
        self = .floatAttributeType
    }
    
    init(_: Double.Type) {
        self = .doubleAttributeType
    }
    
    init(_: String.Type) {
        self = .stringAttributeType
    }
    
    init(_: Data.Type) {
        self = .binaryDataAttributeType
    }
    
    init(_: Date.Type) {
        self = .dateAttributeType
    }
    
    init(_: UUID.Type) {
        self = .UUIDAttributeType
    }
    
}

enum TypeEncode: String {
    case int8 = "c"
    case uint8 = "C"
    case int16 = "s"
    case uint16 = "S"
    case int32 = "i"
    case uint32 = "I"
    case int64 = "q"
    case uint64 = "Q"
    case float = "f"
    case double = "d"
    case string = "{NSString=#}"
    case data = "{NSData=#}"
    case date = "{NSDate=#}"
    
    init(_: Int8.Type) {
        self = .int8
    }
    
    init(_: UInt8.Type) {
        self = .uint8
    }
    
    init(_: Int16.Type) {
        self = .int16
    }
    
    init(_: UInt16.Type) {
        self = .uint16
    }
    
    init(_: Int32.Type) {
        self = .int32
    }
    
    init(_: UInt32.Type) {
        self = .uint32
    }
    
    init(_: Int64.Type) {
        self = .int64
    }
    
    init(_: UInt64.Type) {
        self = .uint64
    }
    
    init(_: Float.Type) {
        self = .float
    }
    
    init(_: Double.Type) {
        self = .double
    }
    
    init(_: String.Type) {
        self = .string
    }
    
    init(_: Data.Type) {
        self = .data
    }
    
    init(_: Date.Type) {
        self = .date
    }
    
}

enum PrimitiveValue {
    case int8(Int8)
    case uint8(UInt8)
    case int16(Int16)
    case uint16(UInt16)
    case int32(Int32)
    case uint32(UInt32)
    case int64(Int64)
    case uint64(UInt64)
    case float(Float)
    case double(Double)
    case string(String)
    case date(Date)
    case data(Data)
    
}

