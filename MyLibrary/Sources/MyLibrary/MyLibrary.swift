import Foundation

public protocol FileCachable {
    var id: String { get }
    var json: Any { get }
    var csv: String { get }
    var csvHeadLine: String { get }
    
    static func parse(json: Any) -> Self?
    static func parse(csv: String) -> Self?
}


public enum FileCacheErrors: Error {
    case cannotFindDocumentDirectory
    case incorrectData
    case cannotSaveData
    case cannotLoadData
}

public enum Format {
    case json
    case csv
}


public final class FileCache<T: FileCachable>  {
    public private(set) var items: [String: T] = [:]
    //static let shared: FileCache = FileCache()
    
    public func add(_ item: T) {
        items[item.id] = item
    }
    
    public func remove(_ id: String) {
        guard items[id] != nil else { return }
        items.removeValue(forKey: id)
    }
    
    public init() { }
    
    public func save(to file: String, format: Format) throws {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            throw FileCacheErrors.cannotFindDocumentDirectory
        }
        
        let path = documentDirectory.appendingPathComponent(file)
        
        do {
            switch format {
            case .json:
                let serializedItems = items.map { _, item in item.json }
                let data = try JSONSerialization.data(withJSONObject: serializedItems, options: [])
                try data.write(to: path)
            case .csv:
                //var data = T.csvHeadLine
                var data = items.map { _, item in item.csv }.joined(separator: "\n")
                try data.write(to: path, atomically: true, encoding: .utf8)

            }
        } catch {
            throw FileCacheErrors.cannotSaveData
        }
    }
    
    public func load(from file: String, format: Format) throws {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            throw FileCacheErrors.cannotFindDocumentDirectory
        }
        
        let path = documentDirectory.appendingPathComponent(file)

        do {
            switch format {
            case .json:
                let data = try Data(contentsOf: path)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                
                guard let json = json as? [Any] else { throw FileCacheErrors.incorrectData }
                let newItems = json.compactMap { T.parse(json: $0) }
                self.items = newItems.reduce(into: [String: T]()) { newArray, item in
                    newArray[item.id] = item
                }
            case .csv:
                var data = try String(contentsOf: path).components(separatedBy: "\n")
                guard !data.isEmpty else { throw FileCacheErrors.incorrectData }
                data.removeFirst()
                let newItems = data.compactMap { T.parse(csv: $0) }
                self.items = newItems.reduce(into: [String: T]()) { newArray, item in
                    newArray[item.id] = item
                }
            }
        } catch {
            throw FileCacheErrors.cannotLoadData
        }
    }
}
