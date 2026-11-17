import Foundation
import Testing
import MijiaCore
@testable import mijiabar

@Suite struct ResolveTests {
    let devices = [
        Device(did: "1", name: "台灯", model: "yeelink.light.lamp1"),
        Device(did: "2", name: "台灯", model: "yeelink.light.lamp1"),
        Device(did: "3", name: "客厅空调", model: "lumi.acpartner.mcn02"),
        Device(did: "4", name: "卧室空调", model: "lumi.acpartner.mcn02"),
    ]
    func find(_ q: String, alias: [String: String] = [:]) throws -> String {
        try matchDevice(q, in: devices) { alias[$0.did] ?? $0.name }.did
    }

    @Test func findsByIdNameAliasAndFragment() throws {
        #expect(try find("2") == "2")                                 // did 优先于名称
        #expect(try find("客厅空调") == "3")
        #expect(try find("客厅") == "3")                               // 唯一的片段
        #expect(try find("书房灯", alias: ["2": "书房灯"]) == "2")      // 别名
        #expect(try find("台灯", alias: ["2": "书房灯"]) == "1")        // 起了别名后原名不再重复…
        #expect(try find("卧室空调", alias: ["4": "主卧"]) == "4")      // …但原名仍然能找到自己
    }

    @Test func refusesToGuessBetweenDuplicates() {
        // 两台同名设备：以前悄悄选第一台，写操作可能控制错设备
        for q in ["台灯", "空调", "灯"] {
            #expect(throws: MijiaError.self) { _ = try find(q) }
        }
        #expect(throws: MijiaError.self) { _ = try find("不存在") }
        // 报错里带 did，Agent 可以直接改用 did 重试
        do { _ = try find("台灯"); Issue.record("should be ambiguous") }
        catch { #expect(error.localizedDescription.contains("[1]") && error.localizedDescription.contains("[2]")) }
    }

    @Test func actionInputsMustBeAJSONArray() throws {
        #expect(try parseActionInputs(nil).isEmpty)
        #expect(try parseActionInputs(NSNull()).isEmpty)
        #expect(try parseActionInputs("[1, \"a\", true]") == [.int(1), .string("a"), .bool(true)])
        #expect(try parseActionInputs([2, "b"] as [Any]) == [.int(2), .string("b")])       // MCP 传来的已经是数组
        // 以前解析失败会当成「没有参数」照样执行
        for bad: Any in ["1, 2", "{\"a\": 1}", "not json", 5, ["a": 1]] {
            #expect(throws: MijiaError.self) { _ = try parseActionInputs(bad) }
        }
    }
}
