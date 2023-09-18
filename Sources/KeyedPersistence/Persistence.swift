
import CoreData


/// The XML store is not available in iOS.
public enum StoreType: String {
    
    case sqlite
    case binary
    case inMemory
#if os(macOS)
    case xml
#endif
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    fileprivate var type: NSPersistentStore.StoreType {
        switch self {
        case .sqlite:
            return .sqlite
        case .binary:
            return .binary
        case .inMemory:
            return .inMemory
#if os(macOS)
        case .xml:
            return .xml
#endif
        }
    }
    
    fileprivate var typeString: String {
        switch self {
        case .sqlite:
            return NSSQLiteStoreType
        case .binary:
            return NSBinaryStoreType
        case .inMemory:
            return NSInMemoryStoreType
#if os(macOS)
        case .xml:
            return NSXMLStoreType
#endif
        }
    }
    
}

typealias EntityBuilder = ArrayBuilder<NSEntityDescription>

struct ManagedObjectModel {
    
    static let `default`: Self = ManagedObjectModel()
    
    let model: NSManagedObjectModel
    
    init() {
        let objectModel = NSManagedObjectModel()
        objectModel.entities = Self.entities()
        model = objectModel
    }
    
    @EntityBuilder private static func entities() -> [NSEntityDescription] {
        MgPlObj<Int16>.managedObjectEntity
        MgPlObj<Int32>.managedObjectEntity
        MgPlObj<Int64>.managedObjectEntity
        MgPlObj<Float>.managedObjectEntity
        MgPlObj<Double>.managedObjectEntity
        MgPlObj<String>.managedObjectEntity
        MgPlObj<Data>.managedObjectEntity
        MgPlObj<Date>.managedObjectEntity
        MgPathObj.managedObjectEntity
    }
    
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
struct PersistentCtrl {
    
    let location: String
    let storeType: StoreType
    private(set) var persistentStore: NSPersistentStore
    private(set) var coordinator: NSPersistentStoreCoordinator
    private var _ctx: NSManagedObjectContext
    
    var context: NSManagedObjectContext {
        _ctx
    }
        
    init(location: String, storeType: StoreType) throws {
        let url: URL
        switch storeType {
        case .inMemory:
            url = URL(fileURLWithPath: "/dev/null")
        default:
            if location.isEmpty {
                throw FileError.invalidPathString
            }
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                url = URL(filePath: location, directoryHint: .notDirectory)
            } else {
                // Fallback on earlier versions
                url = URL(fileURLWithPath: location, isDirectory: false)
            }
        }
        let objectModel = ManagedObjectModel.default.model
        coordinator = NSPersistentStoreCoordinator(managedObjectModel: objectModel)
        if #available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *) {
            persistentStore = try coordinator.addPersistentStore(type: storeType.type, configuration: nil, at: url)
        } else {
            // Fallback on earlier versions
            persistentStore = try coordinator.addPersistentStore(ofType: storeType.typeString, configurationName: nil, at: url)
        }
        _ctx = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        _ctx.persistentStoreCoordinator = coordinator
        self.location = location
        self.storeType = storeType
        #if DEBUG
        print("Persistant store initialized successfully at <\(url)>")
        #endif
    }
    
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension PersistentCtrl {
    
}
