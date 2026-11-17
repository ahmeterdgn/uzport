import Foundation

/// Basit iki dilli metin desteği (Türkçe / English).
/// Sıra: kullanıcı seçimi (UserDefaults "lang") → UZPORT_LANG ortam değişkeni → sistem dili.
public enum Lang {
    public static var isEnglish: Bool = {
        if let e = ProcessInfo.processInfo.environment["UZPORT_LANG"] { return e == "en" }
        if let v = UserDefaults.standard.string(forKey: "lang") { return v == "en" }
        return !(Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("tr")
    }()

    public static var code: String { isEnglish ? "en" : "tr" }
    public static var locale: Locale { Locale(identifier: isEnglish ? "en_US" : "tr_TR") }
}

/// Geçerli dile göre metin seçer.
@inline(__always) public func L(_ tr: String, _ en: String) -> String { Lang.isEnglish ? en : tr }
