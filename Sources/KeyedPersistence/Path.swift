
import CoreData

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public protocol KeyedPath: Identifiable where ID == ObjectId {
    
    /// The name of path, typically is the last path components in a absolute path string.
    var name: String { get }
    
    /// Select value with specified key.
    /// If no such value exists, an error of `SelectError.notFound` will be thrown.
    func valueOfType<T>(_: T.Type, forKey key: String) throws -> T where T: Storable
    /// Select value with specified key.
    /// If no such value exists, an empty array will be returned.
    /// It's expected to have either 0 or 1 value in the returned array.
    func valuesOfType<T>(_: T.Type, forKey key: String) throws -> [T] where T: Storable
    /// Try to delete value with specified key, there's no matter whether the value existings or not.
    func dropValueOfType<T>(_: T.Type, forKey key: String) throws where T: Storable
    /// Insert or Update a value with specified key.
    func putValueOfType<T>(_: T.Type, _ value: T, forKey key: String) throws where T: Storable
    
    /// Move 'CurrentPath'(the path on which 'move()' was called) into destination path.
    func move(_ intoPath: any KeyedPath) throws
    /// Move contents of 'CurrentPath'(the path on which 'merge()' was called) into destination path.
    /// The 'CurrentPath' itself won't be moved.
    func merge(_ intoPath: any KeyedPath) throws
    
    /// Select subpath with specified path name.
    /// If not exists, a subpath with the provided name will be created and then returned.
    func subpathWithName(_ name: String) throws -> any KeyedPath
    /// Select all subpaths.
    /// If 'CurrentPath'(the path on which 'subpaths()' was called) has no subpath, an empty array will be returned.
    func subpaths() throws -> [any KeyedPath]
    
    /// Delete 'CurrentPath'(the path on which 'dropPath()' was called).
    /// All content values and subpaths will be deleted too.
    func dropPath() throws
    
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
protocol PersistentOperator {
    
    var ctx: NSManagedObjectContext { get }
    
    init(_ ctx: NSManagedObjectContext, _ obj: MgPathObj)
    
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension PersistentOperator {
    
    func drop<Obj>(_: Obj.Type, filter: NSPredicate) throws where Obj: MgObj {
        _ = try withDbWorkOfType(Obj.self, in: ctx)
            .setFilter(filter)
            .select(allowFaultsObj: true, limit: 0)
            .deleteAll()
            .performOnCtxQue(())
    }
    
    func update(filter: NSPredicate, _ newParent: ObjectId) throws -> [MgPathObj] {
        try withDbWorkOfType(MgPathObj.self, in: ctx)
            .setFilter(filter)
            .select(limit: 1)
            .map({ obj in
                obj.updateParentPath(newParent)
                return obj
            })
            .performOnCtxQue(())
    }
    
    func update<Pl>(_: MgPlObj<Pl>.Type, filter: NSPredicate, _ newParent: ObjectId) throws -> [MgPlObj<Pl>] {
        try withDbWorkOfType(MgPlObj<Pl>.self, in: ctx)
            .setFilter(filter)
            .select(limit: 1)
            .map({ obj in
                obj.updateParentPath(newParent)
                return obj
            })
            .performOnCtxQue(())
    }
    
    func update<Pl>(_ newValue: Pl, filter: NSPredicate) throws -> [MgPlObj<Pl>] where Pl: Storable {
        try withDbWorkOfType(MgPlObj<Pl>.self, in: ctx)
            .setFilter(filter)
            .select(limit: 1)
            .map({ obj in
                obj.updateValue(newValue)
                return obj
            })
            .performOnCtxQue(())
    }
    
    func put(parent: ObjectId, name: String) throws -> [MgPathObj] {
        try withDbWorkOfType(MgPathObj.self, in: ctx)
            .insert({ _, ctx in
                MgPathObj.newObject(path: parent, name: name, ctx: ctx)
            })
            .performOnCtxQue(())
    }
    
    func put<Pl>(_ value: Pl, parent: ObjectId, name: String) throws -> [MgPlObj<Pl>] where Pl: Storable {
        typealias Object = MgPlObj<Pl>
        return try withDbWorkOfType(Object.self, in: ctx)
            .insert({ _, ctx in
                Object.newObject(path: parent, name: name, value: value, ctx: ctx)
            })
            .performOnCtxQue(())
    }
    
}

protocol PersistentBatchOperator {
    
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension PersistentBatchOperator where Self: PersistentOperator {
    
    func batDrop<Obj>(_ : Obj.Type, filter: NSPredicate) throws where Obj: MgObj {
        try withDbWorkOfType(Obj.self, in: ctx)
            .setFilter(filter)
            .batchDelete()
            .performOnCtxQue(())
    }
    
    func batUpd(filter: NSPredicate, _ newParent: ObjectId) throws {
        _ = try withDbWorkOfType(MgPathObj.self, in: ctx)
            .setFilter(filter)
            .batchUpdate([MgPathObj.StoreKeys.path.rawValue: newParent])
            .performOnCtxQue(())
    }
    
    func batUpd<Pl>(_: MgPlObj<Pl>.Type, filter: NSPredicate, _ newParent: ObjectId) throws {
        typealias Object = MgPlObj<Pl>
        _ = try withDbWorkOfType(Object.self, in: ctx)
            .setFilter(filter)
            .batchUpdate([Object.StoreKeys.path.rawValue: newParent])
            .performOnCtxQue(())
    }
    
    func batUpd<Pl>(_ newValue: Pl, filter: NSPredicate) throws where Pl: Storable {
        typealias Object = MgPlObj<Pl>
        _ = try withDbWorkOfType(Object.self, in: ctx)
            .setFilter(filter)
            .batchUpdate([Object.StoreKeys.payload.rawValue: newValue])
            .performOnCtxQue(())
    }
    
    func batPut(parent: ObjectId, name: String) throws {
        try withDbWorkOfType(MgPathObj.self, in: ctx)
            .batchInsert([MgPathObj.newObjectForBatPut(path: parent, name: name)], mergeObjects: true)
            .performOnCtxQue(())
    }
    
    func batPut<Pl>(_ value: Pl, parent: ObjectId, name: String) throws where Pl: Storable {
        typealias Object = MgPlObj<Pl>
        try withDbWorkOfType(Object.self, in: ctx)
            .batchInsert([Object.newObjectForBatPut(path: parent, name: name, value: value)], mergeObjects: true)
            .performOnCtxQue(())
    }
    
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension PersistentOperator where Self: KeyedPath {
    
    func valueOfType<Pl>(_ t: Pl.Type, forKey key: String) throws -> Pl where Pl: Storable {
        typealias Object = MgPlObj<Pl>
        let filter = Object.filterBy(parent: id, name: key)
        let values = try withDbWorkOfType(Object.self, in: ctx)
            .setFilter(filter)
            .select(limit: 1)
            .compactMap({ obj in
                obj.value
            })
            .performOnCtxQue(())
        guard let value = values.first else {
            throw SelectError.notFound
        }
        return value
    }
    
    func valuesOfType<Pl>(_: Pl.Type, forKey key: String) throws -> [Pl] where Pl: Storable {
        typealias Object = MgPlObj<Pl>
        let filter = Object.filterBy(parent: id, name: key)
        return try withDbWorkOfType(Object.self, in: ctx)
            .setFilter(filter)
            .select(limit: 0)
            .compactMap({ obj in
                obj.value
            })
            .performOnCtxQue(())
    }
    
    func dropValueOfType<Pl>(_: Pl.Type, forKey key: String) throws where Pl: Storable {
        typealias Object = MgPlObj<Pl>
        let filter = Object.filterBy(parent: id, name: key)
        try drop(Object.self, filter: filter)
    }
    
    func putValueOfType<Pl>(_: Pl.Type, _ value: Pl, forKey key: String) throws where Pl: Storable {
        typealias Object = MgPlObj<Pl>
        let filter = Object.filterBy(parent: id, name: key)
        _ = try withDbWorkOfType(Object.self, in: ctx)
            .setFilter(filter)
            .select(limit: 1)
            .if({
                $0.isEmpty
            }, do: { work in
                _ = try work.emplace()
                    .insert { _, ctx in
                        Object.newObject(path: id, name: key, value: value, ctx: ctx)
                    }
                    .perform()
                return []
            })
            .map({ obj in
                obj.updateValue(value)
                return obj
            })
            .performOnCtxQue(())
    }
    
    func move(_ intoPath: any KeyedPath) throws {
        let filter = MgPathObj.filterBy(id: id)
        _ = try update(filter: filter, intoPath.id)
    }
    
    func merge(_ intoPath: any KeyedPath) throws {
        /// Currently the 'filter' can be used on all tables.
        let filter = MgPathObj.filterBy(parent: id)
        let newPath = intoPath.id
        _ = try update(filter: filter, newPath)
        _ = try update(MgPlObj<Int16>.self, filter: filter, newPath)
        _ = try update(MgPlObj<Int32>.self, filter: filter, newPath)
        _ = try update(MgPlObj<Int64>.self, filter: filter, newPath)
        _ = try update(MgPlObj<Float>.self, filter: filter, newPath)
        _ = try update(MgPlObj<Double>.self, filter: filter, newPath)
        _ = try update(MgPlObj<String>.self, filter: filter, newPath)
        _ = try update(MgPlObj<Data>.self, filter: filter, newPath)
        _ = try update(MgPlObj<Date>.self, filter: filter, newPath)
    }
    
    func subpathWithName(_ name: String) throws -> any KeyedPath {
        let obj = try Self.selectPathObj(name, id, ctx)
        return Self(ctx, obj)
    }
    
    static func selectPathObj(_ name: String, _ parent: ObjectId, _ ctx: NSManagedObjectContext) throws -> MgPathObj {
        let filter = MgPathObj.filterBy(parent: parent, name: name)
        let objs = try withDbWorkOfType(MgPathObj.self, in: ctx)
            .setFilter(filter)
            .select(limit: 1)
            .if({
                $0.isEmpty
            }, do: { work in
                try work.emplace()
                    .insert { _, ctx in
                        MgPathObj.newObject(path: parent, name: name, ctx: ctx)
                    }
                    .perform()
            })
            .performOnCtxQue(())
        guard let obj = objs.first else {
            throw Unexpected.unknown
        }
        return obj
    }
    
    func subpaths() throws -> [any KeyedPath] {
        let filter = MgPathObj.filterBy(parent: id)
        return try withDbWorkOfType(MgPathObj.self, in: ctx)
            .setFilter(filter)
            .select(limit: 0)
            .map({ obj in
                Self(ctx, obj)
            })
            .performOnCtxQue(())
    }
    
    func dropPath() throws {
        try subpaths().forEach { sp in
            try sp.dropPath()
        }
        /// Currently the 'filter' can be used on all tables.
        let filter = MgPathObj.filterBy(parent: id)
        try drop(MgPlObj<Int16>.self, filter: filter)
        try drop(MgPlObj<Int32>.self, filter: filter)
        try drop(MgPlObj<Int64>.self, filter: filter)
        try drop(MgPlObj<Float>.self, filter: filter)
        try drop(MgPlObj<Double>.self, filter: filter)
        try drop(MgPlObj<String>.self, filter: filter)
        try drop(MgPlObj<Data>.self, filter: filter)
        try drop(MgPlObj<Date>.self, filter: filter)
        /// Drop self
        try drop(MgPathObj.self, filter: MgPathObj.filterBy(id: id))
    }
    
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension PersistentOperator where Self: KeyedPath {
    
    init(_ ctx: NSManagedObjectContext, _ pathString: String) throws {
        if pathString.isEmpty {
            throw FileError.invalidPathString
        }
        let coms = pathString.components(separatedBy: "/").compactMap { each in
            each.isEmpty ? nil : each
        }
        if coms.isEmpty {
            throw FileError.invalidPathString
        }
        var parent = MgPathObj.rootPath
        var obj: MgPathObj? = nil
        try coms.forEach({ name in
            obj = try Self.selectPathObj(name, parent, ctx)
            parent = obj!.storeId
        })
        guard let obj = obj else {
            throw Unexpected.unknown
        }
        self.init(ctx, obj)
    }
    
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
struct InMemoryPath: KeyedPath, PersistentOperator {
    
    let ctx: NSManagedObjectContext
    let id: ObjectId
    let name: String
    
    init(_ ctx: NSManagedObjectContext, _ obj: MgPathObj) {
        self.ctx = ctx
        self.id = obj.storeId
        self.name = obj.name
    }
    
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
struct SqlitePath: KeyedPath, PersistentOperator, PersistentBatchOperator {
    
    let ctx: NSManagedObjectContext
    let id: ObjectId
    let name: String
    
    init(_ ctx: NSManagedObjectContext, _ obj: MgPathObj) {
        self.ctx = ctx
        self.id = obj.storeId
        self.name = obj.name
    }
    
    init(_ ctx: NSManagedObjectContext, _ id: ObjectId, _ name: String) {
        self.ctx = ctx
        self.id = id
        self.name = name
    }
    
    func dropValueOfType<Pl>(_: Pl.Type, forKey key: String) throws where Pl: Storable {
        typealias Object = MgPlObj<Pl>
        let filter = Object.filterBy(parent: id, name: key)
        try batDrop(Object.self, filter: filter)
    }
    
    func putValueOfType<Pl>(_: Pl.Type, _ value: Pl, forKey key: String) throws where Pl: Storable {
        typealias Object = MgPlObj<Pl>
        let filter = Object.filterBy(parent: id, name: key)
        _ = try withDbWorkOfType(Object.self, in: ctx)
            .setFilter(filter)
            .batchUpdate([Object.StoreKeys.payload.rawValue: value])
            .if({
                $0 == 0
            }, do: { work in
                try work.emplace()
                    .batchInsert([Object.newObjectForBatPut(path: id, name: key, value: value)], mergeObjects: true)
                    .perform()
                return 1
            })
            .performOnCtxQue(())
    }
    
    func subpathWithName(_ name: String) throws -> any KeyedPath {
        let filter = MgPathObj.filterBy(parent: id, name: name)
        let ids = try withDbWorkOfType(MgPathObj.self, in: ctx)
            .setFilter(filter)
            .select(limit: 1)
            .map({
                $0.storeId
            })
            .if({
                $0.isEmpty
            }, do: { work in
                let obj = MgPathObj.newObjectForBatPut(path: id, name: name)
                try work.emplace()
                    .batchInsert([obj], mergeObjects: false)
                    .perform()
                return [obj[MgPathObj.StoreKeys.storeId.rawValue] as! ObjectId]
            })
            .performOnCtxQue(())
        guard let objId = ids.first else {
            throw Unexpected.unknown
        }
        return Self(ctx, objId, name)
    }
    
    func merge(_ intoPath: any KeyedPath) throws {
        let filter = MgPathObj.filterBy(parent: id)
        let newPath = intoPath.id
        _ = try batUpd(filter: filter, newPath)
        _ = try batUpd(MgPlObj<Int16>.self, filter: filter, newPath)
        _ = try batUpd(MgPlObj<Int32>.self, filter: filter, newPath)
        _ = try batUpd(MgPlObj<Int64>.self, filter: filter, newPath)
        _ = try batUpd(MgPlObj<Float>.self, filter: filter, newPath)
        _ = try batUpd(MgPlObj<Double>.self, filter: filter, newPath)
        _ = try batUpd(MgPlObj<String>.self, filter: filter, newPath)
        _ = try batUpd(MgPlObj<Data>.self, filter: filter, newPath)
        _ = try batUpd(MgPlObj<Date>.self, filter: filter, newPath)
    }
    
    func dropPath() throws {
        try subpaths().forEach { sp in
            try sp.dropPath()
        }
        let filter = MgPathObj.filterBy(parent: id)
        try batDrop(MgPlObj<Int16>.self, filter: filter)
        try batDrop(MgPlObj<Int32>.self, filter: filter)
        try batDrop(MgPlObj<Int64>.self, filter: filter)
        try batDrop(MgPlObj<Float>.self, filter: filter)
        try batDrop(MgPlObj<Double>.self, filter: filter)
        try batDrop(MgPlObj<String>.self, filter: filter)
        try batDrop(MgPlObj<Data>.self, filter: filter)
        try batDrop(MgPlObj<Date>.self, filter: filter)
        /// Drop self
        try batDrop(MgPathObj.self, filter: MgPathObj.filterBy(id: id))
    }
    
}

