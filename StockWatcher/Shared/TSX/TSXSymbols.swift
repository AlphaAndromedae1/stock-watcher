import Foundation

/// A curated, offline catalog of major Toronto Stock Exchange (TSX) listings so
/// search works instantly without a rate-limited remote lookup. Symbols use the
/// Yahoo Finance convention: TSX = ".TO", TSX Venture = ".V".
///
/// This is not exhaustive — users can also type any Yahoo symbol directly in
/// search (e.g. "BNS.TO", or a non-TSX ticker like "AAPL").
public enum TSXCatalog {
    public struct Entry: Identifiable, Equatable, Sendable {
        public let symbol: String
        public let name: String
        public let sector: String
        public var id: String { symbol }
    }

    public static let all: [Entry] = [
        // Financials — banks & insurers
        .init(symbol: "RY.TO",  name: "Royal Bank of Canada", sector: "Financials"),
        .init(symbol: "TD.TO",  name: "Toronto-Dominion Bank", sector: "Financials"),
        .init(symbol: "BNS.TO", name: "Bank of Nova Scotia", sector: "Financials"),
        .init(symbol: "BMO.TO", name: "Bank of Montreal", sector: "Financials"),
        .init(symbol: "CM.TO",  name: "Canadian Imperial Bank of Commerce", sector: "Financials"),
        .init(symbol: "NA.TO",  name: "National Bank of Canada", sector: "Financials"),
        .init(symbol: "MFC.TO", name: "Manulife Financial", sector: "Financials"),
        .init(symbol: "SLF.TO", name: "Sun Life Financial", sector: "Financials"),
        .init(symbol: "GWO.TO", name: "Great-West Lifeco", sector: "Financials"),
        .init(symbol: "IFC.TO", name: "Intact Financial", sector: "Financials"),
        .init(symbol: "BN.TO",  name: "Brookfield Corporation", sector: "Financials"),
        .init(symbol: "BAM.TO", name: "Brookfield Asset Management", sector: "Financials"),
        .init(symbol: "FFH.TO", name: "Fairfax Financial Holdings", sector: "Financials"),
        .init(symbol: "X.TO",   name: "TMX Group", sector: "Financials"),

        // Energy
        .init(symbol: "ENB.TO", name: "Enbridge Inc.", sector: "Energy"),
        .init(symbol: "TRP.TO", name: "TC Energy", sector: "Energy"),
        .init(symbol: "CNQ.TO", name: "Canadian Natural Resources", sector: "Energy"),
        .init(symbol: "SU.TO",  name: "Suncor Energy", sector: "Energy"),
        .init(symbol: "CVE.TO", name: "Cenovus Energy", sector: "Energy"),
        .init(symbol: "IMO.TO", name: "Imperial Oil", sector: "Energy"),
        .init(symbol: "PPL.TO", name: "Pembina Pipeline", sector: "Energy"),
        .init(symbol: "TOU.TO", name: "Tourmaline Oil", sector: "Energy"),
        .init(symbol: "ARX.TO", name: "ARC Resources", sector: "Energy"),
        .init(symbol: "WCP.TO", name: "Whitecap Resources", sector: "Energy"),
        .init(symbol: "KEY.TO", name: "Keyera Corp.", sector: "Energy"),

        // Materials — mining & gold
        .init(symbol: "ABX.TO", name: "Barrick Gold", sector: "Materials"),
        .init(symbol: "AEM.TO", name: "Agnico Eagle Mines", sector: "Materials"),
        .init(symbol: "FNV.TO", name: "Franco-Nevada", sector: "Materials"),
        .init(symbol: "WPM.TO", name: "Wheaton Precious Metals", sector: "Materials"),
        .init(symbol: "NTR.TO", name: "Nutrien Ltd.", sector: "Materials"),
        .init(symbol: "TECK-B.TO", name: "Teck Resources Class B", sector: "Materials"),
        .init(symbol: "FM.TO",  name: "First Quantum Minerals", sector: "Materials"),
        .init(symbol: "K.TO",   name: "Kinross Gold", sector: "Materials"),
        .init(symbol: "CCO.TO", name: "Cameco Corporation", sector: "Materials"),
        .init(symbol: "LUN.TO", name: "Lundin Mining", sector: "Materials"),

        // Technology
        .init(symbol: "SHOP.TO", name: "Shopify Inc.", sector: "Technology"),
        .init(symbol: "CSU.TO", name: "Constellation Software", sector: "Technology"),
        .init(symbol: "GIB-A.TO", name: "CGI Inc. Class A", sector: "Technology"),
        .init(symbol: "OTEX.TO", name: "Open Text Corporation", sector: "Technology"),
        .init(symbol: "DSG.TO", name: "Descartes Systems Group", sector: "Technology"),
        .init(symbol: "LSPD.TO", name: "Lightspeed Commerce", sector: "Technology"),
        .init(symbol: "NVEI.TO", name: "Nuvei Corporation", sector: "Technology"),
        .init(symbol: "KXS.TO", name: "Kinaxis Inc.", sector: "Technology"),

        // Industrials & rails
        .init(symbol: "CNR.TO", name: "Canadian National Railway", sector: "Industrials"),
        .init(symbol: "CP.TO",  name: "Canadian Pacific Kansas City", sector: "Industrials"),
        .init(symbol: "WCN.TO", name: "Waste Connections", sector: "Industrials"),
        .init(symbol: "TFII.TO", name: "TFI International", sector: "Industrials"),
        .init(symbol: "WSP.TO", name: "WSP Global", sector: "Industrials"),
        .init(symbol: "STN.TO", name: "Stantec Inc.", sector: "Industrials"),
        .init(symbol: "AC.TO",  name: "Air Canada", sector: "Industrials"),

        // Communication services
        .init(symbol: "BCE.TO", name: "BCE Inc.", sector: "Communication"),
        .init(symbol: "T.TO",   name: "TELUS Corporation", sector: "Communication"),
        .init(symbol: "RCI-B.TO", name: "Rogers Communications Class B", sector: "Communication"),
        .init(symbol: "QBR-B.TO", name: "Quebecor Class B", sector: "Communication"),

        // Consumer
        .init(symbol: "ATD.TO", name: "Alimentation Couche-Tard", sector: "Consumer"),
        .init(symbol: "L.TO",   name: "Loblaw Companies", sector: "Consumer"),
        .init(symbol: "MRU.TO", name: "Metro Inc.", sector: "Consumer"),
        .init(symbol: "DOL.TO", name: "Dollarama Inc.", sector: "Consumer"),
        .init(symbol: "QSR.TO", name: "Restaurant Brands International", sector: "Consumer"),
        .init(symbol: "WN.TO",  name: "George Weston Ltd.", sector: "Consumer"),
        .init(symbol: "GIL.TO", name: "Gildan Activewear", sector: "Consumer"),
        .init(symbol: "MG.TO",  name: "Magna International", sector: "Consumer"),

        // Utilities
        .init(symbol: "FTS.TO", name: "Fortis Inc.", sector: "Utilities"),
        .init(symbol: "EMA.TO", name: "Emera Inc.", sector: "Utilities"),
        .init(symbol: "H.TO",   name: "Hydro One", sector: "Utilities"),
        .init(symbol: "AQN.TO", name: "Algonquin Power & Utilities", sector: "Utilities"),
        .init(symbol: "BIP-UN.TO", name: "Brookfield Infrastructure Partners", sector: "Utilities"),
        .init(symbol: "BEP-UN.TO", name: "Brookfield Renewable Partners", sector: "Utilities"),

        // Real estate (REITs)
        .init(symbol: "REI-UN.TO", name: "RioCan REIT", sector: "Real Estate"),
        .init(symbol: "CAR-UN.TO", name: "Canadian Apartment Properties REIT", sector: "Real Estate"),
        .init(symbol: "GRT-UN.TO", name: "Granite REIT", sector: "Real Estate"),

        // Healthcare
        .init(symbol: "GUD.TO", name: "Knight Therapeutics", sector: "Healthcare"),
        .init(symbol: "BHC.TO", name: "Bausch Health Companies", sector: "Healthcare")
    ]

    /// Case-insensitive prefix/substring search over symbol and name.
    public static func search(_ query: String, limit: Int = 25) -> [Entry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !q.isEmpty else { return all }
        let scored: [(Entry, Int)] = all.compactMap { e in
            let sym = e.symbol.uppercased()
            let name = e.name.uppercased()
            if sym.hasPrefix(q) { return (e, 0) }
            if name.hasPrefix(q) { return (e, 1) }
            if sym.contains(q) { return (e, 2) }
            if name.contains(q) { return (e, 3) }
            return nil
        }
        return scored.sorted { $0.1 < $1.1 }.prefix(limit).map(\.0)
    }

    public static func name(for symbol: String) -> String? {
        all.first { $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame }?.name
    }
}
