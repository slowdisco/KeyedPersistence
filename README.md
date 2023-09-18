# KeyedPersistence

A free-configuration Key-Value style persistent store implement with CoreData.


###Usage


```swift

let db = try await KeyedPersistence(location: "a localtion file path", storeType: .sqlite)

try db.withPath("/Library/Books/OfTimeandtheRiver") { book in
            try book.putValueOfType(String.self, "Thomas Wolfe", forKey: "Author")
            try book.putValueOfType(Date.self, date, forKey: "PublicationDate")
            try book.putValueOfType(Int16.self, 20, forKey: "ReadingProgress")
            try book.putValueOfType(Date.self, date, forKey: "LastReadDate")
            
        }

try db.withPath("/Schools") { schools in
            let aSchool = try schools.subpathWithName("BrightSparks")
            let numberOfStudents = try aSchool.valueOfType(Int32.self, forKey: "StudentsCount")
            let allGrades = try someSchool.subpaths()
            
        }
        
```


KeyedPersistence organize data by path, like how a file system manage folder and it's files. 
A path (which is represented by a "KeyedPersistence.KeyedPath" instance) was treated as a folder, and values are files in the folder.

The relationship between different paths is organized like this:
```

Path1
└─Subpath
|   └─Subpath
|   |   ├─Subpath
|   |   ├─Subpath
|   |   |   └─...
|   |   ...
|   └─Subpath
|   |   ├─...
|   |   ...
|   ...
└─...
|
Path2
|
...

```


Each path/subpath "contains" itself's keyed-values. Different type of values with the same key was allowed.
However, with a specified value type, a key will uniquely determines a value.
Depending on the data put into each path, different paths at the same level of a path tree could "contains" absolute different data. 


There's no need to create path explicitly, just get a path with absolute path string or a subpath with name, and it will be there!


Use "ObservableKeyedValue<T>" to create a two-way connection between values in database, and a SwiftUI.View that displays and changes the data:


```swift

@StateObject
var volume = ObservableKeyedValue<Float>(path: audioSettings, valueKey: "Volume", initialValue: 0.0)

```
