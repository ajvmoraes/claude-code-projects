// SwiftTerm normally gets these two types from a SwiftPM build plugin
// (SwiftTermBuildInfoPlugin) that runs at build time. This project compiles
// with swiftc directly, without SwiftPM, so they're supplied by hand here
// instead. Terminal.swift only reads `SwiftTermBuildInfo.{tag,branch,version}`
// (answers to the XTVERSION escape sequence) and
// `SwiftTermTerminfo.xtgettcapReplies` (answers to XTGETTCAP queries); an
// empty capability table just means those rarely-used queries go unanswered.
enum SwiftTermBuildInfo {
    static let tag = ""
    static let branch = "vendored"
    static let version = "1.0"
}

enum SwiftTermTerminfo {
    static let xtgettcapReplies: [String: String] = [:]
}
