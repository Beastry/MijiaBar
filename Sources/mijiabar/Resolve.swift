import Foundation
import MijiaCore

/// 依次按 did、显示名称（别名）、米家里的原名、名称片段找设备，用第一种有结果的方式。
/// 同一种方式匹配到多台（重名、片段不唯一）时报错并列出 did，不再悄悄选第一台——写操作选错设备的代价比多问一句大得多。
/// 显示名称排在原名前面：两台同名设备里给一台起了别名后，原名就只指另一台。
func matchDevice(_ q: String, in ds: [Device], name: (Device) -> String) throws -> Device {
    if let d = ds.first(where: { $0.did == q }) { return d }
    var m = ds.filter { name($0) == q }
    if m.isEmpty { m = ds.filter { $0.name == q } }
    if m.isEmpty { m = ds.filter { name($0).localizedCaseInsensitiveContains(q) } }
    if m.count == 1 { return m[0] }
    throw MijiaError.deviceNotFound(q + (m.count > 1 ? L("（匹配到多个：", " (ambiguous: ") + m.map { "\(name($0)) [\($0.did)]" }.joined(separator: ", ") + L("）", ")") : ""))
}

/// 动作参数必须是 JSON 数组。解析失败要报错：当成「没有参数」会让动作带着错误的输入执行
func parseActionInputs(_ raw: Any?) throws -> [PropValue] {
    guard let raw, !(raw is NSNull) else { return [] }
    if let a = raw as? [Any] { return a.map { PropValue($0) } }
    guard let s = raw as? String, let a = (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [Any] else {
        throw MijiaError.badValue(L("动作参数要写成 JSON 数组，例如 [1, \"a\"]", "action inputs must be a JSON array, e.g. [1, \"a\"]"))
    }
    return a.map { PropValue($0) }
}
