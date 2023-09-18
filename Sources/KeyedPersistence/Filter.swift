
import Foundation


enum TextFilter {
    case equal(String)
    case prefixed(String)
    case suffixed(String)
    
    func predicate(propertyName: String) -> NSPredicate {
        switch self {
        case .equal(let string):
            return NSPredicate(format: "%K == %@",
                               propertyName,
                               NSExpression(forConstantValue: string)
            )
        case .prefixed(let string):
            return NSPredicate(format: "%K BEGINSWITH %@",
                               propertyName,
                               NSExpression(forConstantValue: string)
            )
        case .suffixed(let string):
            return NSPredicate(format: "%K ENDSWITH %@",
                               propertyName,
                               NSExpression(forConstantValue: string)
            )
        }
    }
    
}

@nonobjc extension MgPathObj {
    
    static func filterBy(id: ObjectId? = nil, parent: ObjectId? = nil, name: String? = nil) -> NSPredicate {
        var predicates = [NSPredicate]()
        if let id = id {
            predicates.append(NSPredicate(format: "%K == %@",
                                          StoreKeys.storeId.rawValue,
                                          NSExpression(forConstantValue: id)))
        }
        if let parent = parent {
            predicates.append(NSPredicate(format: "%K == %@",
                                          StoreKeys.path.rawValue,
                                          NSExpression(forConstantValue: parent)))
        }
        if let name = name {
            predicates.append(NSPredicate(format: "%K == %@",
                                          StoreKeys.name.rawValue,
                                          NSExpression(forConstantValue: name)))
        }
        if predicates.isEmpty {
            fatalError()
        }
        if predicates.count == 1 {
            return predicates.first!
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    
}

@nonobjc extension MgPlObj {
    
    static func filterBy(parent: ObjectId? = nil, name: String? = nil) -> NSPredicate {
        var predicates = [NSPredicate]()
        if let parent = parent {
            predicates.append(NSPredicate(format: "%K == %@",
                                          StoreKeys.path.rawValue,
                                          NSExpression(forConstantValue: parent)))
        }
        if let name = name {
            predicates.append(NSPredicate(format: "%K == %@",
                                          StoreKeys.name.rawValue,
                                          NSExpression(forConstantValue: name)))
        }
        if predicates.isEmpty {
            fatalError()
        }
        if predicates.count == 1 {
            return predicates.first!
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    
}
