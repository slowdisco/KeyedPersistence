
import CoreData


@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct KeyedPersistence {
    
    /// #Core Data, Multithreading, and the Main Thread
    ///
    /// In Core Data, the managed object context can be used with two concurrency patterns, defined by NSMainQueueConcurrencyType and NSPrivateQueueConcurrencyType.
    ///
    /// NSMainQueueConcurrencyType is specifically for use with your application interface and can only be used on the main queue of an application.
    ///
    /// The NSPrivateQueueConcurrencyType configuration creates its own queue upon initialization and can be used only on that queue. Because the queue is private and internal to the NSManagedObjectContext instance, it can only be accessed through the performBlock: and the performBlockAndWait: methods.
    ///
    ///
    /// #Passing References Between Queues#
    ///
    /// NSManagedObject instances are not intended to be passed between queues. Doing so can result in corruption of the data and termination of the application. When it is necessary to hand off a managed object reference from one queue to another, it must be done through NSManagedObjectID instances.
    ///
    /// You retrieve the managed object ID of a managed object by calling the objectID method on the NSManagedObject instance.
    private struct Context {
        let root: NSManagedObjectContext
        let main: NSManagedObjectContext
        let `private`: NSManagedObjectContext
        
        init(_ root: NSManagedObjectContext, _ main: NSManagedObjectContext, _ `private`: NSManagedObjectContext) {
            self.root = root
            self.main = main
            self.private = `private`
        }
    }
    
    public var location: String {
        _persistenceCtrl.location
    }
    
    public var storeType: StoreType {
        _persistenceCtrl.storeType
    }
    
    private let _persistenceCtrl: PersistentCtrl
    private let _context: Context

    public init(location: String, storeType: StoreType) async throws {
        _persistenceCtrl = try PersistentCtrl(location: location, storeType: storeType)
        let rootContext = _persistenceCtrl.context
        let mainCtx = await Task { @MainActor in
            let mainCtx = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            mainCtx.parent = rootContext
            mainCtx.automaticallyMergesChangesFromParent = false
            return mainCtx
        }.value
        let privateCtx = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateCtx.parent = mainCtx
        privateCtx.automaticallyMergesChangesFromParent = true
        _context = Context(rootContext, mainCtx, privateCtx)
    }
    
    @MainActor internal var mainCtx: NSManagedObjectContext {
        _context.main
    }
    
    @MainActor public func pathOnMainActor(_ pathString: String) throws -> some KeyedPath {
        try InMemoryPath(_context.main, pathString)
    }
    
    public func withPathOnMainActor<Result>(_ pathString: String, _ body: @MainActor (any KeyedPath) async throws -> Result) async throws -> Result {
        let path = try await pathOnMainActor(pathString)
        return try await body(path)
    }
    
    public func withPath<Result>(_ pathString: String, _ body: (any KeyedPath) async throws -> Result) async throws -> Result {
        let path = try InMemoryPath(_context.private, pathString)
        return try await body(path)
    }
    
    /// Get a path to perform batch updates.
    /// This is only available when using a SQLite persistent store.
    /// No notification will be received from NotificationCenter or any Publisher when performing updates on this path.
    public func withPathForBatchProcess<Result>(_ pathString: String, _ body: (any KeyedPath) async throws -> Result) async throws -> Result {
        let path = try SqlitePath(_context.private, pathString)
        return try await body(path)
    }
    
    public func saveChanges() throws {
        /// When you save changes in a context, the changes are only committed “one store up.” If you save a child context, changes are pushed to its parent. Changes are not saved to the persistent store until the root context is saved. (A root managed object context is one whose parent context is nil.) In addition, a parent does not pull changes from children before it saves. You must save a child context if you want ultimately to commit the changes.
        var err: Swift.Error? = nil
        _context.private.performAndWait {
            if _context.private.hasChanges {
                do {
                    try _context.private.save()
                } catch {
                    err = error
                }
            }
        }
        if let error = err {
            throw error
        }
        _context.main.performAndWait {
            if _context.main.hasChanges {
                do {
                    try _context.main.save()
                } catch {
                    err = error
                }
            }
        }
        if let error = err {
            throw error
        }
        _context.root.performAndWait {
            if _context.root.hasChanges {
                do {
                    try _context.root.save()
                } catch {
                    err = error
                }
            }
        }
        if let error = err {
            throw error
        }
    }
    
}



