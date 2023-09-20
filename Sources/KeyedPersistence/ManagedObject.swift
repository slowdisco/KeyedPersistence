
import CoreData
import ObjectiveC


public typealias ObjectId = String

private func newObjectId() -> ObjectId {
    UUID().uuidString
}

@propertyWrapper struct ManagedProperty<Wrapped> where Wrapped: ExpressibleByNilLiteral {
        
    private let _key: String
    
    init<Key>(key: Key) where Key: CodingKey {
        self._key = key.stringValue
    }
    
    static subscript<Obj>(
        _enclosingInstance obj: Obj,
        wrapped _: KeyPath<Obj, Wrapped>,
        storage toself: KeyPath<Obj, Self>
    ) -> Wrapped where Obj: NSManagedObject {
        get {
            obj[keyPath: toself].get(obj)
        }
        set {
            obj[keyPath: toself].set(obj, newValue)
        }
    }
    
    func `get`<Obj>(_ obj: Obj) -> Wrapped where Obj: NSManagedObject {
        obj.willAccessValue(forKey: _key)
        defer {
            obj.didAccessValue(forKey: _key)
        }
        guard let value = obj.primitiveValue(forKey: _key) else {
            return Wrapped.init(nilLiteral: ())
        }
        guard let value = value as? Wrapped else {
            return Wrapped.init(nilLiteral: ())
        }
        return value
    }
    
    func `set`<Obj>(_ obj: Obj, _ value: Wrapped) where Obj: NSManagedObject {
        obj.willChangeValue(forKey: _key)
        defer {
            obj.didChangeValue(forKey: _key)
        }
        obj.setPrimitiveValue(value, forKey: _key)
    }
    
    var projectedValue: String {
        _key
    }
    
    @available(*, unavailable) 
    var wrappedValue: Wrapped {
        get {
            fatalError()
        }
        nonmutating set {
            fatalError()
        }
    }
    
}

// MARK: - ManagedObject

protocol ManagedObject where Self: NSManagedObject {
    
    static var managedObjectEntityName: String { get }
    static var managedObjectEntity: NSEntityDescription { get }
    
}

protocol PathData where Self: ManagedObject {
    
    var name: String { get }
    /// The parent path that's one level up from this path.
    var path: ObjectId { get }
    
}

protocol PayloadData where Self: ManagedObject, Self: OpaqueValue {
    
    var name: String { get }
    /// The parent path that 'contains' this payload.
    var path: ObjectId { get }
    
}

/// #Subclassing Notes
/// In combination with the entity description in the managed object model, NSManagedObject provides a rich set of default behaviors including support for arbitrary properties and value validation. If you decide to subclass NSManagedObject to implement custom features, make sure you don’t disrupt Core Data’s behavior.
///
/// #Methods and Properties You Must Not Override
/// NSManagedObject itself customizes many features of NSObject so that managed objects can be properly integrated into the Core Data infrastructure. Core Data relies on the NSManagedObject implementation of the following methods and properties, which you therefore absolutely must not override: <primitiveValue(forKey:), setPrimitiveValue(_:forKey:), isEqual(_:), hash, superclass, class, self(), isProxy(), isKind(of:), isMember(of:), conforms(to:), responds(to:), managedObjectContext, entity, objectID, isInserted, isUpdated, isDeleted, and isFault, alloc, allocWithZone:, new, instancesRespond(to:), instanceMethod(for:), method(for:), methodSignatureForSelector:, instanceMethodSignatureForSelector:, or isSubclass(of:)>.
///
/// #Methods and Properties You Shouldn't Override
/// As with any class, you are strongly discouraged from overriding the key-value observing methods such as <willChangeValue(forKey:)> and <didChangeValue(forKey:withSetMutation:using:)>. Avoid overriding <description>—if this method fires a fault during a debugging operation, the results may be unpredictable. Also avoid overriding <init(entity:insertInto:)>, or <dealloc>. Changing values in the <init(entity:insertInto:)> method won't be noticed by the context, and if you aren't careful, those changes may not be saved. Perform most initialization customization in one of the <awake…> methods. If you do override <init(entity:insertInto:)>, make sure you adhere to the requirements set out in the method description. See <init(entity:insertInto:)>.
/// Don’t override <dealloc> because <didTurnIntoFault()> is usually a better time to clear values—a managed object may not be reclaimed for some time after it has been turned into a fault. Core Data doesn’t guarantee that <dealloc> will be called in all scenarios (such as when the application quits). Therefore, don’t include required side effects (like saving or changes to the file system, user preferences, and so on) in these methods.
/// In summary, for <init(entity:insertInto:)> and dealloc, Core Data reserves exclusive control over the life cycle of the managed object (that is, raw memory management). This is so that the framework can provide features such as uniquing and by consequence, relationship maintenance, as well as much better performance than would be possible otherwise.
///
/// #Additional Override Considerations
/// The following methods are intended to be fine grained and aren’t suitable for large-scale operations. Don’t fetch or save in these methods. In particular, they shouldn’t have side effects on the managed object context.
/// init(entity:insertInto:)
/// didTurnIntoFault()
/// willTurnIntoFault()
/// dealloc
/// In addition, if you plan to override awakeFromInsert, awakeFromFetch, and validation methods, first invoke super.method(), the superclass’s implementation. Don’t modify relationships in awakeFromFetch()—see the method description for details.
///
/// #Custom Accessor Methods
/// Typically, you don’t need to write custom accessor methods for properties that are defined in the entity of a managed object’s corresponding managed object model. If you need to do so, follow the implementation patterns described in Managed Object Accessor Methods in Core Data Programming Guide.
/// Core Data automatically generates accessor methods (and primitive accessor methods) for you. For attributes and to-one relationships, Core Data generates the standard get and set accessor methods; for to-many relationships, Core Data generates the indexed accessor methods as described in Achieving Basic Key-Value Coding Compliance in Key-Value Coding Programming Guide. You do however need to declare the accessor methods or use Objective-C properties to suppress compiler warnings. For a full discussion, see Managed Object Accessor Methods in Core Data Programming Guide.
///
/// #Custom Instance Variables
/// By default, NSManagedObject stores its properties in an internal structure as objects, and in general Core Data is more efficient working with storage under its own control rather than by using custom instance variables.
/// NSManagedObject provides support for a range of common types for attribute values, including string, date, and number (see NSAttributeDescription for full details). If you want to use types that aren’t supported directly, like colors and C structures, you can either use transformable attributes or create a subclass of NSManagedObject.
/// Sometimes it’s convenient to represent variables as scalars—in drawing applications, for example, where variables represent dimensions and x and y coordinates and are frequently used in calculations. To represent attributes as scalars, you declare instance variables as you do in any other class. You also need to implement suitable accessor methods as described in Managed Object Accessor Methods.
/// If you define custom instance variables for example to store derived attributes or other transient properties, clean up these variables in didTurnIntoFault() rather than dealloc.
///
/// #Validation Methods
/// NSManagedObject provides consistent hooks for validating property and inter-property values. You typically shouldn’t override validateValue(_:forKey:). Instead implement methods of the form validate<Key>:error:, as defined by the NSKeyValueCoding protocol. If you want to validate inter-property values, you can override validateForUpdate() and/or related validation methods.
/// Don’t call validateValue:forKey:error: within custom property validation methods—if you do, you create an infinite loop when validateValue:forKey:error: is invoked at runtime. If you do implement custom validation methods, don’t call them directly. Instead, call validateValue:forKey:error: with the appropriate key. This ensures that any constraints defined in the managed object model are applied.
/// If you implement custom inter-property validation methods like validateForUpdate(), call the superclass’s implementation first. This ensures that individual property validation methods are also invoked. If there are multiple validation failures in one operation, collect them in an array and add the array—using the key NSDetailedErrorsKey—to the userInfo dictionary in the NSError object you return. For an example, see Managed Object Validation.

// MARK: - ManagedPathObject

final class ManagedPathObject: NSManagedObject, ManagedObject, PathData {
    @NSManaged
    fileprivate(set) var storeId: ObjectId
    @NSManaged
    fileprivate(set) var path: ObjectId
    @NSManaged
    fileprivate(set) var name: String
    
    @nonobjc func updateParentPath(_ newPath: ObjectId) {
        path = newPath
    }
        
    @nonobjc class var classNameString: String {
        let name = class_getName(ManagedPathObject.self)
        return String(cString: name)
    }
    
    @nonobjc class var managedObjectEntityName: String {
        "KEYEDPERSISTENCEPATH"
    }
    
    /// `NSManagedObject.entity()` can not retrieve a entity that has not yet been loaded by a `NSManagedObjectModel`.
    @nonobjc class var managedObjectEntity: NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = managedObjectEntityName
        entity.managedObjectClassName = classNameString
        entity.properties = []
        entity.properties.append({
            let attr = NSAttributeDescription()
            attr.name = StoreKeys.storeId.stringValue
            attr.attributeType = .stringAttributeType
            attr.isOptional = false
            return attr
        }())
        entity.properties.append({
            let attr = NSAttributeDescription()
            attr.name = StoreKeys.path.stringValue
            attr.attributeType = .stringAttributeType
            attr.isOptional = false
            return attr
        }())
        entity.properties.append({
            let attr = NSAttributeDescription()
            attr.name = StoreKeys.name.stringValue
            attr.attributeType = .stringAttributeType
            attr.isOptional = false
            return attr
        }())
        entity.indexes = [
            NSFetchIndexDescription(name: "NonrTreeIndex", elements: [
                NSFetchIndexElementDescription(property: entity.properties[1], collationType: .binary),
                NSFetchIndexElementDescription(property: entity.properties[2], collationType: .binary)
            ])
        ]
        return entity
    }
    
    @nonobjc static let rootPath: ObjectId = "B71DDD47-9EA7-406C-904B-31FAD8B18588"
    
}

extension ManagedPathObject {
    
    enum StoreKeys: String, CodingKey {
        case storeId = "storeId"
        case path = "path"
        case name = "name"
    }
    
}

@nonobjc extension ManagedPathObject {
    
    class func newObject(path: ObjectId, name: String, ctx: NSManagedObjectContext) -> Self {
        let obj = Self.init(entity: Self.entity(), insertInto: ctx)
        obj.storeId = newObjectId()
        obj.path = path
        obj.name = name
        return obj
    }
    
    class func newObjectForBatPut(path: ObjectId, name: String) -> [String : Any] {
        [StoreKeys.storeId.rawValue: newObjectId(),
         StoreKeys.path.rawValue: path,
         StoreKeys.name.rawValue: name
        ]
    }
    
}

// MARK: - ManagedPayloadObject

final class ManagedPayloadObject<Pl>: NSManagedObject, ManagedObject, PayloadData where Pl: Storable {
    @NSManaged
    fileprivate(set) var path: ObjectId
    @NSManaged
    fileprivate(set) var name: String
    @ManagedProperty(key: StoreKeys.payload)
    fileprivate(set) var value: Pl?
    
}

@nonobjc extension ManagedPayloadObject {
    
    func updateParentPath(_ newPath: ObjectId) {
        path = newPath
    }
    
    func updateValue(_ newValue: Pl) {
        value = newValue
    }
    
    class var classNameString: String {
        let name = class_getName(Self.self)
        return String(cString: name)
    }
    
    class var managedObjectEntityName: String {
        "KEYEDPERSISTENCEPAYLOAD\(Pl.attributeType.rawValue)"
    }
    
    class var managedObjectEntity: NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = managedObjectEntityName
        entity.managedObjectClassName = classNameString
        entity.properties = []
        entity.properties.append({
            let attr = NSAttributeDescription()
            attr.name = StoreKeys.path.stringValue
            attr.attributeType = .stringAttributeType
            attr.isOptional = false
            return attr
        }())
        entity.properties.append({
            let attr = NSAttributeDescription()
            attr.name = StoreKeys.name.stringValue
            attr.attributeType = .stringAttributeType
            attr.isOptional = false
            return attr
        }())
        entity.properties.append({
            let attr = NSAttributeDescription()
            attr.name = StoreKeys.payload.stringValue
            attr.attributeType = Pl.attributeType
            attr.isOptional = false
            return attr
        }())
        entity.indexes = [
            NSFetchIndexDescription(name: "NonrTreeIndex", elements: [
                NSFetchIndexElementDescription(property: entity.properties[0], collationType: .binary),
                NSFetchIndexElementDescription(property: entity.properties[1], collationType: .binary)
            ])
        ]
        return entity
    }
    
}

extension ManagedPayloadObject {
    
    enum StoreKeys: String, CodingKey {
        case path = "path"
        case name = "name"
        case payload = "payload"
    }
    
}

@nonobjc extension ManagedPayloadObject: OpaqueValue {
    
    func tryGet<Value>(_: Value.Type) throws -> Value? {
        if Value.self == Pl.self {
            guard let value = self.value else {
                return nil
            }
            return value as? Value
        } else {
            throw TypeError.errorType
        }
    }
    
}

@nonobjc extension ManagedPayloadObject {
    
    class func newObject(path: ObjectId, name: String, value: Pl, ctx: NSManagedObjectContext) -> Self {
        let obj = Self.init(entity: Self.entity(), insertInto: ctx)
        obj.path = path
        obj.name = name
        obj.value = value
        return obj
    }
    
    static func newObjectForBatPut(path: ObjectId, name: String, value: Pl) -> [String : Any] {
        [StoreKeys.path.rawValue: path,
         StoreKeys.name.rawValue: name,
         StoreKeys.payload.rawValue: value
        ]
    }
    
}

// MARK: - Type Define

typealias MgObj = ManagedObject
typealias MgPathObj = ManagedPathObject
typealias MgPlObj<Pl> = ManagedPayloadObject<Pl> where Pl: Storable



