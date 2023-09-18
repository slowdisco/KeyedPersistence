
public enum FileError: Swift.Error {
    case invalidPathString
    
}

public enum SelectError: Swift.Error {
    case notFound
    
}

public enum TypeError: Swift.Error {
    case errorType
    
}

public enum Unexpected: Swift.Error {
    case unknown
    
}
