import Foundation
import zlib

// Read the finalized workbook, including its ZIP directory and XML cell references.
// Assertions compare the public export files instead of private column-building helpers.
enum ExportWorkbookReader {
    enum ReadError: Error { case invalidArchive, invalidXML }

    static func rows(at url: URL) throws -> [[String]] {
        let files = try unzip(Data(contentsOf: url))
        guard let strings = files["xl/sharedStrings.xml"], let sheet = files["xl/worksheets/sheet1.xml"] else {
            throw ReadError.invalidArchive
        }
        let shared = WorkbookXMLReader()
        let stringsParser = XMLParser(data: strings)
        stringsParser.delegate = shared
        guard stringsParser.parse() else { throw ReadError.invalidXML }
        let worksheet = WorkbookXMLReader()
        worksheet.strings = shared.strings
        let sheetParser = XMLParser(data: sheet)
        sheetParser.delegate = worksheet
        guard sheetParser.parse(), !worksheet.invalid else { throw ReadError.invalidXML }
        return worksheet.rows
    }

    private static func unzip(_ data: Data) throws -> [String: Data] {
        let bytes = [UInt8](data)
        func value(_ offset: Int, _ count: Int) throws -> Int {
            guard offset >= 0, offset + count <= bytes.count else { throw ReadError.invalidArchive }
            return (0..<count).reduce(0) { $0 | Int(bytes[offset + $1]) << ($1 * 8) }
        }
        guard bytes.count >= 22 else { throw ReadError.invalidArchive }
        let end = bytes.count - 22
        guard try value(end, 4) == 0x06054b50 else { throw ReadError.invalidArchive }
        var cursor = try value(end + 16, 4)
        let entries = try value(end + 10, 2)
        var files = [String: Data]()
        for _ in 0..<entries {
            guard try value(cursor, 4) == 0x02014b50 else { throw ReadError.invalidArchive }
            let method = try value(cursor + 10, 2)
            let compressedCount = try value(cursor + 20, 4)
            let expandedCount = try value(cursor + 24, 4)
            let nameCount = try value(cursor + 28, 2)
            let extraCount = try value(cursor + 30, 2)
            let commentCount = try value(cursor + 32, 2)
            let local = try value(cursor + 42, 4)
            guard cursor + 46 + nameCount <= bytes.count,
                let name = String(bytes: bytes[(cursor + 46)..<(cursor + 46 + nameCount)], encoding: .utf8),
                try value(local, 4) == 0x04034b50
            else { throw ReadError.invalidArchive }
            let start = try local + 30 + value(local + 26, 2) + value(local + 28, 2)
            guard start + compressedCount <= bytes.count else { throw ReadError.invalidArchive }
            let compressed = Data(bytes[start..<(start + compressedCount)])
            if method == 0 {
                files[name] = compressed
            } else if method == 8 {
                files[name] = try inflate(compressed, count: expandedCount)
            } else {
                throw ReadError.invalidArchive
            }
            cursor += 46 + nameCount + extraCount + commentCount
        }
        return files
    }

    private static func inflate(_ compressed: Data, count: Int) throws -> Data {
        var stream = z_stream()
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw ReadError.invalidArchive
        }
        defer { inflateEnd(&stream) }
        var expanded = Data(count: count)
        let status = compressed.withUnsafeBytes { source in
            expanded.withUnsafeMutableBytes { destination in
                stream.next_in = UnsafeMutablePointer(mutating: source.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(compressed.count)
                stream.next_out = destination.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(count)
                return zlib.inflate(&stream, Z_FINISH)
            }
        }
        guard status == Z_STREAM_END, stream.total_out == count else { throw ReadError.invalidArchive }
        return expanded
    }
}

private final class WorkbookXMLReader: NSObject, XMLParserDelegate {
    var strings = [String]()
    var rows = [[String]]()
    var invalid = false
    private var row = [String]()
    private var content = ""
    private var element = ""

    func parser(
        _ parser: XMLParser, didStartElement name: String,
        namespaceURI: String?, qualifiedName: String?, attributes: [String: String]
    ) {
        element = name
        if name == "row" { row = [] }
        if name == "t" || name == "v" { content = "" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if element == "t" || element == "v" { content += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "t" { strings.append(content) }
        if name == "v" {
            if let index = Int(content), strings.indices.contains(index) {
                row.append(strings[index])
            } else {
                invalid = true
            }
        }
        if name == "row" { rows.append(row) }
        element = ""
    }
}
