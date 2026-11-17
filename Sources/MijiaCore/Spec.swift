import Foundation

public struct ValueOption: Codable, Hashable, Sendable { public let value: Int; public let description: String
    public init(value: Int, description: String) { self.value = value; self.description = description } }

public func urnName(_ t: String) -> String { let p = t.split(separator: ":"); return p.count > 3 ? String(p[3]) : t }

public struct SpecProperty: Codable, Hashable, Sendable {
    public let siid: Int, iid: Int
    public let type: String, description: String, format: String
    public let access: [String]
    public let unit: String?
    public let range: [Double]?
    public let options: [ValueOption]?
    public var name: String { urnName(type) }
    public var key: String { "\(siid).\(iid)" }
    public var readable: Bool { access.contains("read") }
    public var writable: Bool { access.contains("write") }
    public var isNumber: Bool { format != "bool" && format != "string" }
    public init(siid: Int, iid: Int, type: String, description: String, format: String, access: [String], unit: String?, range: [Double]?, options: [ValueOption]?) {
        self.siid = siid; self.iid = iid; self.type = type; self.description = description; self.format = format
        self.access = access; self.unit = unit; self.range = range; self.options = options
    }
}
public struct SpecAction: Codable, Hashable, Sendable {
    public let siid: Int, iid: Int
    public let type: String, description: String
    public let inputs: [Int]
    public var name: String { urnName(type) }
    public var key: String { "\(siid).\(iid)" }
}
public struct SpecService: Codable, Hashable, Sendable {
    public let iid: Int
    public let type: String, description: String
    public let properties: [SpecProperty]
    public let actions: [SpecAction]
    public var name: String { urnName(type) }
    public func prop(_ name: String) -> SpecProperty? { properties.first { $0.name == name } }
    public init(iid: Int, type: String, description: String, properties: [SpecProperty], actions: [SpecAction]) {
        self.iid = iid; self.type = type; self.description = description; self.properties = properties; self.actions = actions
    }
}
public struct DeviceSpec: Codable, Hashable, Sendable {
    public let type: String, description: String
    public let services: [SpecService]
    public var name: String { urnName(type) }
    public init(type: String, description: String, services: [SpecService]) { self.type = type; self.description = description; self.services = services }
    public var controlServices: [SpecService] { services.filter { $0.iid != 1 } }
    public func prop(named n: String) -> SpecProperty? { controlServices.lazy.compactMap { $0.prop(n) }.first }
    public func prop(key: String) -> SpecProperty? { services.flatMap(\.properties).first { $0.key == key } }
    public func action(key: String) -> SpecAction? { services.flatMap(\.actions).first { $0.key == key } }
    public func action(named n: String) -> SpecAction? { services.flatMap(\.actions).first { $0.name == n } }
    /// 主开关：第一个可写的 on 属性
    public var mainOnProperty: SpecProperty? { controlServices.lazy.compactMap { $0.prop("on") }.first { $0.writable && $0.format == "bool" } }

    public static func parse(_ obj: [String: Any]) -> DeviceSpec {
        let services = (obj["services"] as? [[String: Any]] ?? []).map { s -> SpecService in
            let siid = s["iid"] as? Int ?? 0
            let props = (s["properties"] as? [[String: Any]] ?? []).map { p in
                SpecProperty(siid: siid, iid: p["iid"] as? Int ?? 0, type: p["type"] as? String ?? "",
                             description: p["description"] as? String ?? "", format: p["format"] as? String ?? "",
                             access: p["access"] as? [String] ?? [], unit: p["unit"] as? String,
                             range: (p["value-range"] as? [NSNumber])?.map(\.doubleValue),
                             options: (p["value-list"] as? [[String: Any]])?.map {
                                ValueOption(value: ($0["value"] as? NSNumber)?.intValue ?? 0, description: $0["description"] as? String ?? "") })
            }
            let acts = (s["actions"] as? [[String: Any]] ?? []).map { a in
                SpecAction(siid: siid, iid: a["iid"] as? Int ?? 0, type: a["type"] as? String ?? "",
                           description: a["description"] as? String ?? "", inputs: a["in"] as? [Int] ?? [])
            }
            return SpecService(iid: siid, type: s["type"] as? String ?? "", description: s["description"] as? String ?? "", properties: props, actions: acts)
        }
        return DeviceSpec(type: obj["type"] as? String ?? "", description: obj["description"] as? String ?? "", services: services)
    }
}

/// 从 miot-spec.org 拉取并缓存设备规格（可变状态都由 lock 保护）
public final class SpecStore: @unchecked Sendable {
    public static let shared = SpecStore()
    private var mem: [String: DeviceSpec] = [:]
    /// 正在下载的规格：同型号的多台设备同时打开时只下载一次
    private var inflight: [String: Task<DeviceSpec?, Error>] = [:]
    /// 型号索引：新下载的用一天；网络不通时退回磁盘上过期的那份，10 分钟后再试
    private var indexTask: (task: Task<(index: [String: String], fresh: Bool), Error>, loaded: Date)?
    private let lock = NSLock()

    public func spec(for model: String) async throws -> DeviceSpec? {
        if let s = lock.withLock({ mem[model] }) { return s }
        // 型号来自云端或命令行参数，当文件名用之前去掉路径分隔符
        let file = Paths.specs.appendingPathComponent(model.replacingOccurrences(of: "/", with: "_") + ".json")
        if let d = try? Data(contentsOf: file), let s = try? JSONDecoder().decode(DeviceSpec.self, from: d), !s.services.isEmpty {
            lock.withLock { mem[model] = s }; return s
        }
        let task: Task<DeviceSpec?, Error> = lock.withLock {
            if let t = inflight[model] { return t }
            let t = Task { try await self.download(model, to: file) }
            inflight[model] = t; return t
        }
        defer { lock.withLock { inflight[model] = nil } }
        return try await task.value
    }

    private func download(_ model: String, to file: URL) async throws -> DeviceSpec? {
        guard let urn = try await index()[model] else { return nil }
        var c = URLComponents(string: "https://miot-spec.org/miot-spec-v2/instance")!
        c.queryItems = [URLQueryItem(name: "type", value: urn)]
        let (d, r) = try await URLSession.shared.data(from: c.url!)
        if let code = (r as? HTTPURLResponse)?.statusCode, code != 200 { throw CloudError.http(code) }
        guard let obj = try JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        let s = DeviceSpec.parse(obj)
        // 出错时服务器也可能返回 200 + 一段错误 JSON：没有任何服务的规格不缓存，下次再试
        guard !s.services.isEmpty else { return nil }
        try? JSONEncoder().encode(s).write(to: file)
        lock.withLock { mem[model] = s }
        return s
    }

    private func index() async throws -> [String: String] {
        let task = lock.withLock {
            if let t = indexTask { return t.task }
            let t = Task { try await Self.loadIndex(file: Paths.support.appendingPathComponent("spec-index.json")) { try await Self.fetchIndex() } }
            indexTask = (t, Date()); return t
        }
        do {
            let r = try await task.value
            // App 会连续运行很多天：索引到期后丢掉内存里的这份，下次重新走磁盘 / 网络
            lock.withLock { if let t = indexTask, t.task == task, Date().timeIntervalSince(t.loaded) > (r.fresh ? 86400 : 600) { indexTask = nil } }
            return r.index
        } catch { lock.withLock { if indexTask?.task == task { indexTask = nil } }; throw error }
    }

    private static func fetchIndex() async throws -> Data {
        let (d, r) = try await URLSession.shared.data(from: URL(string: "https://miot-spec.org/miot-spec-v2/instances?status=all")!)
        if let code = (r as? HTTPURLResponse)?.statusCode, code != 200 { throw CloudError.http(code) }
        return d
    }

    /// 磁盘上 7 天内的索引直接用；否则重新下载。下载失败（离线、服务器故障）时退回过期的那份（fresh = false），
    /// 不然索引一过期，没网的时候所有没缓存过规格的型号都打不开。
    static func loadIndex(file: URL, now: Date = Date(), fetch: () async throws -> Data) async throws -> (index: [String: String], fresh: Bool) {
        let cached = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }
        if let cached, let m = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date,
           now.timeIntervalSince(m) < 7 * 86400 { return (cached, true) }
        do {
            let idx = try await downloadIndex(to: file, fetch)
            // 服务器返回 200 但内容不对时索引是空的：有旧的就用旧的，都算「不新鲜」，过一会儿重试
            return idx.isEmpty ? (cached ?? idx, false) : (idx, true)
        } catch { if let cached, !cached.isEmpty { return (cached, false) }; throw error }
    }

    private static func downloadIndex(to file: URL, _ fetch: () async throws -> Data) async throws -> [String: String] {
        let obj = try JSONSerialization.jsonObject(with: try await fetch()) as? [String: Any] ?? [:]
        var best: [String: (String, Int, Bool)] = [:]
        for i in obj["instances"] as? [[String: Any]] ?? [] {
            guard let m = i["model"] as? String, let t = i["type"] as? String else { continue }
            let v = i["version"] as? Int ?? 0, rel = (i["status"] as? String) == "released"
            if let b = best[m], (b.2 && !rel) || (b.2 == rel && b.1 >= v) { continue }
            best[m] = (t, v, rel)
        }
        let idx = best.mapValues { $0.0 }
        // 空索引不写盘，否则 7 天内所有设备都找不到规格
        if !idx.isEmpty { try? JSONEncoder().encode(idx).write(to: file) }
        return idx
    }
}
