
import CoreData


protocol Work {
    
    associatedtype Input
    associatedtype Output
    
    func perform(_: Input) throws -> Output
    
}

extension Work where Input == Void {
    
    func perform() throws -> Output {
        try perform(())
    }
    
}

extension Work {
    
    typealias Callable = (Input) throws -> Output
    
    func getCallable() -> Callable {
        return { [self](input: Input) -> Output in
            try self.perform(input)
        }
    }
    
}

extension Work where Output: Collection {
    
    typealias Element = Output.Element
    
}

protocol DownstreamWork where Self: Work {
    
    associatedtype Upstream: Work
    associatedtype Input = Self.Upstream.Input
    
    var up: Upstream { get }
    
}

protocol DbCtx {
    
    associatedtype Obj: NSManagedObject
    typealias Ctx = NSManagedObjectContext
    
    var ctx: Ctx { get }
    var filter: NSPredicate? { get nonmutating set }
    var sortDescriptors: [NSSortDescriptor]? { get nonmutating set }
    
}

extension DbCtx where Self: DownstreamWork, Self.Upstream: DbCtx {
    
    typealias Obj = Self.Upstream.Obj
    
    @inline(__always) var ctx: Ctx {
        up.ctx
    }
    
    var filter: NSPredicate? {
        @inline(__always) get {
            up.filter
        }
        @inline(__always) nonmutating set {
            up.filter = newValue
        }
    }
    
    var sortDescriptors: [NSSortDescriptor]? {
        @inline(__always) get {
            up.sortDescriptors
        }
        @inline(__always) nonmutating set {
            up.sortDescriptors = newValue
        }
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    func __performOnCtxQue(_ input: Input) throws -> Output {
        try ctx.performAndWait {
            try perform(input)
        }
    }
    
    func performOnCtxQue(_ input: Input) throws -> Output {
        var output: Output? = nil
        var err: Error? = nil
        ctx.performAndWait {
            do {
                output = try perform(input)
            } catch {
                err = error
            }
        }
        if let error = err {
            throw error
        }
        return output!
    }
    
}

typealias DbWork = Work & DbCtx
typealias DownstreamDbWork = DownstreamWork & DbCtx

struct Transform<Upstream, Output>: DownstreamWork where Upstream: Work {
        
    let up: Upstream
    private let _work: (Upstream.Output) throws -> Output
    
    init(_ up: Upstream, _ work: @escaping (Upstream.Output) throws -> Output) {
        self.up = up
        _work = work
    }
    
    func perform(_ input: Input) throws -> Output {
        let output = try up.perform(input)
        return try _work(output)
    }
    
}

extension Transform: DbCtx where Upstream: DbCtx {
    
}

struct If<Upstream>: DownstreamWork where Upstream: Work {
    
    typealias Output = Upstream.Output
    
    let up: Upstream
    private let _ifWhere: (Upstream.Output) -> Bool
    private let _work: (Upstream) throws -> Output
    
    init(_ up: Upstream, _ ifWhere: @escaping (Upstream.Output) -> Bool, _ work: @escaping (Upstream) throws -> Output) {
        self.up = up
        _ifWhere = ifWhere
        _work = work
    }
    
    func perform(_ input: Input) throws -> Output {
        let output = try up.perform(input)
        if _ifWhere(output) {
            return try _work(up)
        } else {
            return output
        }
    }
    
}

extension If: DbCtx where Self.Upstream: DbCtx {
    
}

struct Truncate<Upstream>: DownstreamWork where Upstream: Work {
    
    typealias Output = ()
    
    let up: Upstream
    
    init(_ up: Upstream) {
        self.up = up
    }
    
    @inline(__always) func perform(_ input: Input) throws -> Output {
        return
    }
    
}

extension Truncate: DbCtx where Self.Upstream: DbCtx {
    
}

extension Work {
    
    func transform<Output>(_ work: @escaping (Self.Output) throws -> Output) -> Transform<Self, Output> {
        Transform<Self, Output>(self, work)
    }
    
    func `if`(_ ifWhere: @escaping (Self.Output) -> Bool, `do` work: @escaping (Self) throws -> Output) -> If<Self> {
        If(self, ifWhere, work)
    }
    
    func emplace() -> Truncate<Self> {
        Truncate(self)
    }
    
}

struct Map<Upstream, Result>: DownstreamWork where Upstream: Work, Upstream.Output: Collection {
    
    typealias Output = [Result]
        
    let up: Upstream
    private let _work: (Upstream.Element) throws -> Result
    
    init(_ up: Upstream, _ work: @escaping (Upstream.Element) throws -> Result) {
        self.up = up
        _work = work
    }
    
    func perform(_ input: Input) throws -> Output {
        try up.perform(input).map {
            try _work($0)
        }
    }
    
}

extension Map: DbCtx where Upstream: DbCtx {
    
}

struct CompactMap<Upstream, Result>: DownstreamWork where Upstream: Work, Upstream.Output: Collection {
    
    typealias Output = [Result]
        
    let up: Upstream
    private let _work: (Upstream.Element) throws -> Result?
    
    init(_ up: Upstream, _ work: @escaping (Upstream.Element) throws -> Result?) {
        self.up = up
        _work = work
    }
    
    func perform(_ input: Input) throws -> Output {
        try up.perform(input).compactMap {
            try _work($0)
        }
    }
    
}

extension CompactMap: DbCtx where Upstream: DbCtx {
    
}

extension Work where Self.Output: Collection {
    
    func map<Result>(_ work: @escaping (Element) throws -> Result) -> Map<Self, Result> {
        Map<Self, Result>(self, work)
    }
    
    func compactMap<Result>(_ work: @escaping (Element) throws -> Result?) -> CompactMap<Self, Result> {
        CompactMap<Self, Result>(self, work)
    }
    
}

func withDbWorkOfType<Obj>(_ : Obj.Type, in ctx: NSManagedObjectContext) -> GoInCtx<Obj> where Obj: NSManagedObject {
    GoInCtx<Obj>(ctx: ctx)
}

class GoInCtx<Obj>: DbWork where Obj: NSManagedObject {
    
    typealias Input = ()
    typealias Output = ()
    
    let ctx: NSManagedObjectContext
    var filter: NSPredicate? = nil
    var sortDescriptors: [NSSortDescriptor]? = nil
    
    init(ctx: Ctx) {
        self.ctx = ctx
    }
    
    @inline(__always) func perform(_ ctx: Input) throws -> Output {
        return
    }
    
}

struct DbCtxSetter<Upstream>: DownstreamDbWork where Upstream: DbWork {
    
    typealias Output = ()
    
    let up: Upstream
    private let _filter: (() -> NSPredicate)?
    private let _sortDescriptors: (() -> [NSSortDescriptor])?
    
    init(_ up: Upstream, filter: (() -> NSPredicate)? = nil, sortDescriptors: (() -> [NSSortDescriptor])? = nil) {
        self.up = up
        _filter = filter
        _sortDescriptors = sortDescriptors
    }
    
    func perform(_ input: Input) throws -> Output {
        _ = try up.perform(input)
        if let filter = _filter {
            self.filter = filter()
        }
        if let sortDescriptors = _sortDescriptors {
            self.sortDescriptors = sortDescriptors()
        }
    }
    
}

extension Work where Self: DbCtx {
    
    func setFilter(_ filter: @autoclosure @escaping () -> NSPredicate) -> DbCtxSetter<Self> {
        DbCtxSetter(self, filter: filter)
    }
    
    func setSortDescriptors(_ sortDescriptors: @autoclosure @escaping () -> [NSSortDescriptor]) -> DbCtxSetter<Self> {
        DbCtxSetter(self, sortDescriptors: sortDescriptors)
    }
    
}

extension Work where Self: DbCtx, Self.Output: Collection, Self.Output.Element == Self.Obj {
    
    func deleteAll() -> DeleteAll<Self> {
        DeleteAll<Self>(self)
    }
    
    func delete(_ isDelete: @escaping (Element) -> Bool) -> Delete<Self> {
        Delete<Self>(self, isDelete)
    }
    
}

extension Work where Self: DbCtx {
    
    func insert(count: Int = 1, _ builder: @escaping (Int, Ctx) -> Self.Obj) -> Insert<Self> {
        Insert(self, count, builder)
    }
    
    func select(allowFaultsObj: Bool = false, limit: Int = 1) -> Select<Self> {
        Select<Self>(self, allowFaultsObj, limit)
    }
    
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    func batchDelete() -> BatchDelete<Self> {
        BatchDelete<Self>(self)
    }
    
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    func batchUpdate(_ propertiesToUpdate: [AnyHashable : Any]?) -> BatchUpdate<Self> {
        BatchUpdate<Self>(self, propertiesToUpdate)
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func batchInsert(_ objects: [[String : Any]], mergeObjects: Bool) -> BatchInsert<Self> {
        BatchInsert(self, objects, mergeObjects)
    }
    
}

struct DeleteAll<Upstream>: DownstreamDbWork where Upstream: DbWork, Upstream.Output: Collection, Upstream.Output.Element == Upstream.Obj {
    
    typealias Output = ()
    
    let up: Upstream
    
    init(_ up: Upstream) {
        self.up = up
    }
    
    func perform(_ input: Input) throws -> Output {
        let objs = try up.perform(input)
        objs.forEach { obj in
            if !obj.isDeleted {
                ctx.delete(obj)
            }
        }
    }
    
}

struct Delete<Upstream>: DownstreamDbWork where Upstream: DbWork, Upstream.Output: Collection, Upstream.Output.Element == Upstream.Obj {
    /// Return available objects after 'delete',
    typealias Output = [Upstream.Element]
        
    let up: Upstream
    private let _where: (Element) -> Bool
    
    init(_ up: Upstream, _ `where`: @escaping (Element) -> Bool) {
        self.up = up
        _where = `where`
    }
    
    func perform(_ input: Input) throws -> Output {
        let objs = try up.perform(input)
        return objs.compactMap({ obj in
            if obj.isDeleted {
                return nil
            }
            if _where(obj) {
                ctx.delete(obj)
                return nil
            }
            return obj
        })
    }
    
}

struct Select<Upstream>: DownstreamDbWork where Upstream: DbWork {
    
    typealias Output = [Obj]
    
    let up: Upstream
    private let _allowFaultsObj: Bool
    private let _limit: Int
    
    init(_ up: Upstream, _ allowFaultsObj: Bool, _ limit: Int) {
        self.up = up
        _allowFaultsObj = allowFaultsObj
        _limit = limit
    }
    
    func perform(_ input: Input) throws -> Output {
        _ = try up.perform(input)
        let selReq = NSFetchRequest<Obj>()
        selReq.entity = Obj.entity()
        selReq.predicate = filter
        selReq.sortDescriptors = sortDescriptors
        selReq.fetchLimit = _limit
        /// This value is true if the objects resulting from a fetch using the NSFetchRequest are faults; otherwise, it is false. The default value is true. This setting is not used if the result type (see resultType) is NSManagedObjectIDResultType, as object IDs do not have property values. You can set returnsObjectsAsFaults to false to gain a performance benefit if you know you will need to access the property values from the returned objects.
        ///
        /// When you execute a fetch, by default returnsObjectsAsFaults is true; Core Data fetches the object data for the matching records, fills the row cache with the information, and returns managed object as faults. These faults are managed objects, but all of their property data resides in the row cache until the fault is fired. When the fault is fired, Core Data retrieves the data from the row cache. Although the overhead for this operation is small, for large datasets it may not be trivial. If you need to access the property values from the returned objects (for example, if you iterate over all the objects to calculate the average value of a particular attribute), then it is more efficient to set returnsObjectsAsFaults to false to avoid the additional overhead.
        selReq.returnsObjectsAsFaults = _allowFaultsObj
        selReq.includesPropertyValues = !_allowFaultsObj
        return try ctx.fetch(selReq)
    }
    
}

struct Insert<Upstream>: DownstreamDbWork where Upstream: DbWork {
    
    typealias Output = [Obj]
    
    let up: Upstream
    private let _count: Int
    private let _work: (Int, Ctx) -> Obj
    
    init(_ up: Upstream, _ count: Int, _ builder: @escaping (Int, Ctx) -> Obj) {
        self.up = up
        _count = count
        _work = builder
    }
    
    func perform(_ input: Input) throws -> Output {
        _ = try up.perform(input)
        return (0..<_count).map { idx in
            _work(idx, ctx)
        }
    }
    
}

///
/// #Important: Batch deletes are only available when you are using a SQLite persistent store.
///
/// #Validation Rules
/// When you execute a batch delete, any validation rules that are part of the data model are not enforced. Therefore, ensure that any changes caused by the batch delete will continue to pass the validation rules. This naturally impacts validation rules on relationships.
///
@available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
struct BatchDelete<Upstream>: DownstreamDbWork where Upstream: DbWork {
    
    typealias Output = ()
    
    let up: Upstream
    
    init(_ up: Upstream) {
        self.up = up
    }
    
    func perform(_ input: Input) throws -> Output {
        _ = try up.perform(input)
        let selReq = Obj.fetchRequest()
        selReq.predicate = filter
        let batReq = NSBatchDeleteRequest(fetchRequest: selReq)
        batReq.resultType = .resultTypeObjectIDs
        let result = try ctx.execute(batReq) as? NSBatchDeleteResult
        if let objectIds = result?.result as? [NSManagedObjectID] {
            if objectIds.isEmpty {
                return
            }
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [
                NSDeletedObjectsKey: objectIds
            ], into: [ctx])
        }
    }
    
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
struct BatchInsert<Upstream>: DownstreamDbWork where Upstream: DbWork {
    
    typealias Output = ()
    
    let up: Upstream
    private let _objects: [[String : Any]]
    private let _mergeObjects: Bool
    
    init(_ up: Upstream, _ objects: [[String : Any]], _ mergeObjects: Bool) {
        self.up = up
        _objects = objects
        _mergeObjects = mergeObjects
    }
    
    func perform(_ input: Input) throws -> Output {
        _ = try up.perform(input)
        if _objects.isEmpty {
            return
        }
        let batReq = NSBatchInsertRequest(entity: Obj.entity(), objects: _objects)
        batReq.resultType = .objectIDs
        let result = try ctx.execute(batReq) as? NSBatchInsertResult
        if !_mergeObjects {
            return
        }
        if let objectIds = result?.result as? [NSManagedObjectID] {
            if objectIds.isEmpty {
                return
            }
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [
                NSInsertedObjectsKey: objectIds
            ], into: [ctx])
        }
    }
    
}

///
/// #Important: Batch updates are only available when you are using a SQLite persistent store.
///
/// #Validation Rules
/// When you use batch updates any validation rules that are a part of the data model are not enforced when the batch update is executed. Therefore, ensure that any changes caused by the batch update will continue to pass the validation rules.
///
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
struct BatchUpdate<Upstream>: DownstreamDbWork where Upstream: DbWork {
    /// Return count of objects updated.
    typealias Output = Int
    
    let up: Upstream
    private let _updates: [AnyHashable : Any]?
    
    init(_ up: Upstream, _ propertiesToUpdate: [AnyHashable : Any]?) {
        self.up = up
        _updates = propertiesToUpdate
    }
    
    func perform(_ input: Input) throws -> Output {
        _ = try up.perform(input)
        let batReq = NSBatchUpdateRequest(entity: Obj.entity())
        batReq.predicate = filter
        /// The dictionary keys are either NSPropertyDescription objects or strings that identify the property name.
        /// The dictionary values are either a constant value or an NSExpression that evaluates to a scalar value.
        batReq.propertiesToUpdate = _updates
        batReq.resultType = .updatedObjectIDsResultType
        let result = try ctx.execute(batReq) as? NSBatchUpdateResult
        if let objectIds = result?.result as? [NSManagedObjectID] {
            if objectIds.isEmpty {
                return 0
            }
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [
                NSUpdatedObjectsKey: objectIds
            ], into: [ctx])
            return objectIds.count
        }
        return 0
    }
    
}



