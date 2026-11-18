import Foundation

public struct NewsItem: Identifiable, Equatable, Sendable {
    public let title: String
    public let link: URL?
    public let date: Date?
    public var id: String { (link?.absoluteString ?? "") + title }

    public init(title: String, link: URL?, date: Date?) {
        self.title = title
        self.link = link
        self.date = date
    }
}

/// Fetches recent headlines for a symbol from Yahoo Finance's RSS feed.
/// Best-effort: returns [] on any failure.
public final class NewsService: @unchecked Sendable {
    public static let shared = NewsService()

    private let session: URLSession
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    public func fetch(symbol: String, limit: Int = 8) async -> [NewsItem] {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? symbol
        guard let url = URL(string:
            "https://feeds.finance.yahoo.com/rss/2.0/headline?s=\(encoded)&region=US&lang=en-US")
        else { return [] }

        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: req),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode)
        else { return [] }

        let parser = RSSParser()
        return Array(parser.parse(data).prefix(limit))
    }
}

/// Minimal RSS <item> parser (title, link, pubDate).
private final class RSSParser: NSObject, XMLParserDelegate {
    private var items: [NewsItem] = []
    private var inItem = false
    private var current = ""
    private var title = ""
    private var link = ""
    private var pubDate = ""

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    func parse(_ data: Data) -> [NewsItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        current = ""
        if elementName == "item" {
            inItem = true
            title = ""; link = ""; pubDate = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        current += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let s = String(data: CDATABlock, encoding: .utf8) { current += s }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let value = current.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "title": if inItem { title = value }
        case "link": if inItem { link = value }
        case "pubDate": if inItem { pubDate = value }
        case "item":
            inItem = false
            if !title.isEmpty {
                items.append(NewsItem(title: title,
                                      link: URL(string: link),
                                      date: Self.dateFormatter.date(from: pubDate)))
            }
        default: break
        }
        current = ""
    }
}
