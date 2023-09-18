
import CoreData
import Combine
import SwiftUI


// MARK: - EnvironmentValues

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
struct KeyedPersistenceKey: EnvironmentKey {
    
    typealias Value = KeyedPersistence?
    
    static var defaultValue: Value {
        nil
    }
    
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension EnvironmentValues {
    
    var keyedPersistence: KeyedPersistence? {
        get {
            self[KeyedPersistenceKey.self]
        }
        set {
            self[KeyedPersistenceKey.self] = newValue
        }
    }
    
}

// MARK: - KeyedPathDeclare

/// Get a `KeyedPath` initialized with `KeyedPersistencee` retrieved from EnvironmentValues.
/// A `KeyedPersistence` must be set to environment using `environment(\.keyedPersistence, ...)` in some View first!
///
///     struct SomeView: View {
///
///         @KeyedPathDeclare(pathString: "a path string")
///         var path
///
///         var body: some View {
///             ...
///         }
///
///     }
///
/// A `KeyedPath` will be created by the time SwiftUI calls `update()` function before rendering view's body.
///
/// If fails, `wrappedValue` property will keep remaining nil.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper @MainActor struct KeyedPathDeclare {
    
    @Environment(\.keyedPersistence)
    private var _db
    private let _pathString: String
    var wrappedValue: (any KeyedPath)? = nil
    
    init(pathString: String) {
        _pathString = pathString
    }
    
    private mutating func getPath() {
        guard let db = _db else {
            return
        }
        do {
            wrappedValue = try db.pathOnMainActor(_pathString)
        } catch {
            return
        }
    }
    
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension KeyedPathDeclare: DynamicProperty {
    
    mutating func update() {
        if wrappedValue == nil {
            getPath()
        }
    }
    
}

// MARK: - ObservableKeyedValue

private struct ChangesOfValue<Pl> where Pl: Storable {
    
    enum Change {
        case delete
        case update(Pl)
        case insert(Pl)
    }
    
    let change: Change
    
    init?(observedPath path: ObjectId, valueKey: String, notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return nil
        }
        if let value = Self.filter(userInfo[NSInsertedObjectsKey], path, valueKey) {
            change = Change.insert(value)
            return
        }
        if let value = Self.filter(userInfo[NSUpdatedObjectsKey], path, valueKey) {
            change = Change.update(value)
            return
        }
        if let _ = Self.filter(userInfo[NSDeletedObjectsKey], path, valueKey) {
            change = Change.delete
            return
        }
        return nil
    }
    
    private static func filter(_ objs: Any?, _ path: ObjectId, _ valueKey: String) -> Pl? {
        guard let objs = objs as? Set<NSManagedObject> else {
            return nil
        }
        var received: Pl? = nil
        objs.forEach({ obj in
            guard let obj = obj as? PayloadData, obj.path == path, obj.name == valueKey else {
                return
            }
            if let value = try? obj.tryGet(Pl.self) {
                received = value
                return
            }
        })
        return received
    }
    
}

///
/// An object that updates View when data in db changed,
/// or receive new value from a View and save it to db.
///
///     struct SomeView: View {
///
///         @StateObject /// or @ObservedObject for views that get this object shared from other view.
///         var value: ObservableKeyedValue<String>
///
///         var body: some View {
///             ...
///         }
///
///     }
///
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@MainActor public final class ObservableKeyedValue<Wrapped>: ObservableObject where Wrapped: Storable {
    
    private var _path: (any KeyedPath)?
    private let _valueKey: String
    private let _initialValue: Wrapped
    private var _buffer: Wrapped
    private var _handler: AnyCancellable? = nil
    
    private func subscribeToObjectChanges() {
        guard let path = _path else {
            return
        }
        do {
            let value = try path.valueOfType(Wrapped.self, forKey: _valueKey)
            if value != _buffer {
                _buffer = value
            }
        } catch {
            /// There's no matter whether the value existings in db or not
            /// when 'ObservableKeyedValue' is being initialized.
        }
        let pathId = path.id
        let valueKey = _valueKey
        guard let path = path as? PersistentOperator else {
            return
        }
        _handler = NotificationCenter.default.publisher(for: NSManagedObjectContext.didChangeObjectsNotification, object: path.ctx)
            .map({ notification -> ChangesOfValue? in
                ChangesOfValue<Wrapped>(observedPath: pathId, valueKey: valueKey, notification: notification)
            })
            .sink { [weak self] changes in
                guard let changes = changes, let self = self else {
                    return
                }
                self.publishChanges(changes)
            }
    }
    
    private func publishChanges(_ changes: ChangesOfValue<Wrapped>) {
        switch changes.change {
        case .delete:
            objectWillChange.send()
            _buffer = _initialValue
        case .update(let pl):
            if pl == _buffer {
                return
            }
            objectWillChange.send()
            _buffer = pl
        case .insert(let pl):
            objectWillChange.send()
            _buffer = pl
        }
    }
    
    ///
    /// - Parameters:
    ///   - path: A `KeyedPath` created with `KeyedPersistence.pathOnMainActor()` in somewhere.
    ///   - valueKey: The key of value in specicied path.
    ///
    /// Pass a nil to `path` won't throw an error, but will get a instance that don't subscribe to object changes.
    ///
    public init(path: (any KeyedPath)?, valueKey: String, initialValue: Wrapped) {
        _path = path
        _valueKey = valueKey
        _initialValue = initialValue
        _buffer = initialValue
        subscribeToObjectChanges()
    }
    
    @MainActor public var value: Wrapped {
        get {
            _buffer
        }
        set {
            if _buffer == newValue {
                return
            }
            _buffer = newValue
            do {
                try _path?.putValueOfType(Wrapped.self, newValue, forKey: _valueKey)
            } catch {
                
            }
        }
    }
    
    @MainActor public var binding: Binding<Wrapped> {
        Binding { [weak self, _initialValue] in
            self?._buffer ?? _initialValue
        } `set`: { [weak self] newValue in
            self?.value = newValue
        }
    }
    
}

// MARK: - PublishedKeyedPath

private struct ChangesOfPath {
    
    struct Objects {
        var insert: [String]
        var update: [String]
        var delete: [String]
        
        init() {
            insert = []
            update = []
            delete = []
        }
    }
    
    let paths: Objects
    let values: Objects
    
    init?(observedPath path: ObjectId, notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return nil
        }
        var paths = Objects()
        var values = Objects()
        Self.filter(userInfo[NSInsertedObjectsKey], path, paths: &paths.insert, values: &values.insert)
        Self.filter(userInfo[NSUpdatedObjectsKey], path, paths: &paths.update, values: &values.update)
        Self.filter(userInfo[NSDeletedObjectsKey], path, paths: &paths.delete, values: &values.delete)
        self.paths = paths
        self.values = values
    }
    
    private static func filter(_ objs: Any?, _ path: ObjectId, paths: inout [String], values: inout [String]) {
        guard let objs = objs as? Set<NSManagedObject> else {
            return
        }
        objs.forEach({ obj in
            if let obj = obj as? PathData, obj.path == path {
                paths.append(obj.name)
                return
            }
            if let obj = obj as? PayloadData, obj.path == path {
                values.append(obj.name)
                return
            }
        })
    }
    
}

///
/// This object provides a `Publisher` to observe changes of a path.
///
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper public struct PublishedKeyedPath {
    
    /// The name of objects (which is the PathName/ValueKey) has changed.
    public enum Change {
        case deleteValues([String])
        case updateValues([String])
        case insertValues([String])
        case deleteSubpaths([String])
        case insertSubpaths([String])
    }
    
    public typealias Publisher = PassthroughSubject<Change, Never>
    
    private let _path: any KeyedPath
    private let _publisher: Publisher
    private var _handler: AnyCancellable? = nil
    
    public init(path: any KeyedPath) {
        _path = path
        _publisher = PassthroughSubject<Change, Never>()
        let pathId = _path.id
        let ctx = (path as! PersistentOperator).ctx
        _handler = NotificationCenter.default.publisher(for: NSManagedObjectContext.didChangeObjectsNotification, object: ctx)
            .map({ notification -> ChangesOfPath? in
                ChangesOfPath(observedPath: pathId, notification: notification)
            })
            .sink { [_publisher] changes in
                guard let changes = changes else {
                    return
                }
                /// updated values
                if !changes.values.delete.isEmpty {
                    _publisher.send(.deleteValues(changes.values.delete))
                }
                if !changes.values.update.isEmpty {
                    _publisher.send(.updateValues(changes.values.update))
                }
                if !changes.values.insert.isEmpty {
                    _publisher.send(.insertValues(changes.values.insert))
                }
                /// updated paths
                if !changes.paths.delete.isEmpty {
                    _publisher.send(.deleteSubpaths(changes.paths.delete))
                }
                if !changes.paths.insert.isEmpty {
                    _publisher.send(.insertSubpaths(changes.paths.insert))
                }
            }
    }
    
    public var wrappedValue: any KeyedPath {
        _path
    }
    
    public var projectedValue: Publisher {
        _publisher
    }
    
}



