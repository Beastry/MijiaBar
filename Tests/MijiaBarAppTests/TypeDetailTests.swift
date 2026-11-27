import SwiftUI
import Testing
import MijiaCore
@testable import MijiaBarApp

@Suite @MainActor struct TypeDetailTests {
    @Test func dedicatedDemoDevicesAndArt() throws {
        let model = AppModel(mock: true)
        for (category, row) in [(DeviceCategory.humidifier, "humidifier"), (.vacuum, "vacuum"),
                                (.fridge, "fridge"), (.washer, "washer"), (.waterHeater, "water-heater"), (.curtain, "curtain"), (.airPurifier, "air-purifier"),
                                (.heater, "heater"), (.dehumidifier, "dehumidifier"), (.hood, "hood"), (.lock, "lock"), (.airer, "airer"), (.clock, "clock"), (.gateway, "gateway"), (.bathHeater, "bath-heater"),
                                (.speaker, "speaker"), (.kitchen, "cooker"), (.kitchen, "kettle"), (.kitchen, "dishwasher"), (.kitchen, "juicer"), (.kitchen, "ihcooker"), (.purifier, "purifier"), (.waterDispenser, "water-dispenser"), (.airMonitor, "air-monitor"), (.scale, "scale")] {
            let device = try #require(model.devices.first { $0.category == category })
            #expect(device.homeId == (category == .dehumidifier ? "h1" : "h2"))
            #expect(model.states[device.did]?.spec != nil)
            #expect(ArtGallery.rows.filter { $0.0 == row }.count == 1)
        }
        #expect(ArtGallery.rows.count == 42)
        #expect(ArtGallery.size.height == CGFloat(ArtGallery.rows.count * 138))
    }

    @Test func scaleDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        var device = try #require(model.devices.first { $0.did == "d44" })
        let state = try #require(model.states[device.did])
        #expect(device.category == .scale && device.category.rawValue == "scale")
        #expect(device.model == "yunmai.scales.demo" && device.form == nil)
        #expect(device.homeId == "h2" && device.roomName == L("浴室", "Bathroom"))
        #expect(device.icon == "scalemass" && zhCategory(device.category) == L("体重秤", "Scale"))
        #expect(device.category.color == Color(red: 0.42, green: 0.48, blue: 0.58))
        #expect(DeviceCategory.allCases.filter { $0 != .scale }.allSatisfy { $0.color != device.category.color })
        #expect(HouseCatalog.deviceClass(category: .scale) == .badge && HouseChipStyle.tint(.scale) == device.category.color)
        #expect(state.spec?.type == "urn:miot-spec-v2:device:scale:0" && model.powerInfo(device) == nil)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            if let art = value as? () -> ScaleArt { return contains(art(), type: type) }
            return value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        for online in [true, false] {
            device.isOnline = online
            let detail = ScaleDetail(dc: DC(device: device, state: state))
            #expect(detail.on == online && detail.title == L("最近读数", "Last reading"))
            #expect(detail.reading?.name == "weight" && detail.dc.num(detail.reading) == 62.4 && detail.readingUnit == "kg")
            #expect(detail.readout("bmi", "BMI", "") == "BMI 21.6")
            #expect(detail.readout("body-fat", "Fat", "%") == "Fat 19.8%")
            #expect(detail.dc.num(detail.dc.p("battery-level")) == 92 && detail.dc.text(detail.unit) == "kg")
            #expect(detail.settings.map(\.name) == ["unit"] && detail.heartRateDetection == nil)
            let routed = TypeDetailView(device: device, state: state).body
            #expect(contains(routed, type: ScaleDetail.self))
            #expect(!contains(routed, type: DeviceCardView.self) && !contains(routed, type: SensorDetail.self))
            #expect(contains(detail.body, type: ScaleArt.self))
            #expect(!contains(detail.body, type: GenericArt.self) && !contains(detail.body, type: ThermoArt.self))
            let fields = Mirror(reflecting: detail.body).children
            let art = try #require(fields.first { $0.label == "art" }?.value as? () -> ScaleArt)
            #expect(art().on == online && art().reading == "62.4" && art().tint == device.category.color)
            #expect(fields.first { $0.label == "powerOn" }?.value as? Bool == nil)
            #expect(!(fields.first { $0.label == "onPower" }?.value is () -> Void))
        }
        #expect(contains(offArt(device, tint: device.category.color), type: ScaleArt.self))
    }

    @Test func scaleFallbacksAndOptionalProperties() {
        var device = Device(did: "demo", name: "Demo", model: "xiaomi.scale.v1", isOnline: true)
        let spec = DeviceSpec.parse(["services": [["iid": 2, "type": "scale", "properties": [
            ["iid": 1, "type": "weight", "format": "float", "access": ["read"]],
            ["iid": 2, "type": "bmi", "format": "float", "access": ["read"]],
            ["iid": 3, "type": "muscle", "format": "float", "access": ["read"], "unit": "percentage"],
            ["iid": 4, "type": "heart-rate", "format": "uint8", "access": ["read"]],
            ["iid": 5, "type": "impedance", "format": "float", "access": ["read"]]
        ]]]])
        let state = DeviceState(values: ["2.2": .double(22.1), "2.3": .int(40), "2.4": .int(72), "2.5": .int(510)], spec: spec, legacy: false, source: "cloud")
        let detail = ScaleDetail(dc: DC(device: device, state: state))
        #expect(detail.reading?.name == "bmi" && detail.readingUnit == "")
        #expect(detail.readout("muscle", "Muscle", "%") == "Muscle 40%")
        #expect(detail.readout("heart-rate", "Heart", " bpm") == "Heart 72 bpm")
        #expect(detail.readout("impedance", "Impedance", " Ω") == "Impedance 510 Ω")
        #expect(detail.settings.isEmpty && detail.unit == nil)
        for online in [true, false] {
            device.isOnline = online
            let empty = ScaleDetail(dc: DC(device: device, state: DeviceState(values: [:], spec: nil, legacy: false, source: "cloud")))
            #expect(empty.reading == nil && empty.settings.isEmpty && empty.on == online)
            #expect(empty.title == (online ? L("在线", "Online") : L("离线", "Offline")))
            #expect(empty.readout("battery-level", "Battery", "%") == nil)
        }
        for access in [["read"], ["read", "write"]] {
            let settingsSpec = DeviceSpec.parse(["services": [["iid": 2, "type": "scale", "properties": [
                ["iid": 1, "type": "heart-rate-detection", "format": "bool", "access": access],
                ["iid": 2, "type": "unit", "format": "uint8", "access": access]
            ]]]])
            let settings = ScaleDetail(dc: DC(device: device, state: DeviceState(values: [:], spec: settingsSpec, legacy: false, source: "cloud")))
            #expect(settings.heartRateDetection?.key == "2.1" && settings.unit?.key == "2.2")
            #expect(settings.settings.map(\.name) == (access.contains("write") ? ["heart-rate-detection"] : []))
        }
    }

    @Test func airMonitorDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        var device = try #require(model.devices.first { $0.did == "d43" })
        let state = try #require(model.states[device.did])
        #expect(device.category == .airMonitor && device.category.rawValue == "air-monitor")
        #expect(device.model == "cgllc.airmonitor.demo" && device.form == nil)
        #expect(device.homeId == "h2" && device.roomName == L("客厅", "Living room"))
        #expect(device.icon == "aqi.medium" && zhCategory(device.category) == L("空气检测仪", "Air monitor"))
        #expect(device.category.color == Color(red: 0.32, green: 0.64, blue: 0.48))
        #expect(HouseCatalog.deviceClass(category: device.category) == .badge)
        #expect(HouseChipStyle.tint(device.category) == device.category.color)
        #expect(state.spec?.type == "urn:miot-spec-v2:device:air-monitor:0")
        #expect(model.powerInfo(device) == nil)
        let context = DC(device: device, state: state)
        #expect(context.num(context.p("temperature")) == 24.6 && context.num(context.p("relative-humidity")) == 48)
        #expect(context.num(context.p("co2-density")) == 620 && context.num(context.p("tvoc-density")) == 0.12)
        #expect(context.num(context.p("battery-level")) == 86)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            if let art = value as? () -> AirMonitorArt { return contains(art(), type: type) }
            return value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        for online in [true, false] {
            device.isOnline = online
            let detail = AirMonitorDetail(dc: DC(device: device, state: state))
            #expect(detail.on == online && detail.title == (online ? L("监测中", "Monitoring") : L("离线", "Offline")))
            #expect(detail.reading?.name == "pm2.5-density" && detail.readingUnit == "µg/m³")
            #expect(detail.dc.num(detail.reading) == 12 && detail.screen == nil)
            let routed = TypeDetailView(device: device, state: state).body
            #expect(contains(routed, type: AirMonitorDetail.self))
            #expect(!contains(routed, type: DeviceCardView.self) && !contains(routed, type: AirPurifierDetail.self) && !contains(routed, type: SensorDetail.self))
            #expect(contains(detail.body, type: AirMonitorArt.self))
            #expect(!contains(detail.body, type: GenericArt.self) && !contains(detail.body, type: AirPurifierArt.self) && !contains(detail.body, type: ThermoArt.self))
            let fields = Mirror(reflecting: detail.body).children
            let art = try #require(fields.first { $0.label == "art" }?.value as? () -> AirMonitorArt)
            #expect(art().on == online && art().reading == "12" && art().tint == device.category.color)
            #expect(fields.first { $0.label == "powerOn" }?.value as? Bool == nil)
            #expect(!(fields.first { $0.label == "onPower" }?.value is () -> Void))
        }
        #expect(contains(offArt(device, tint: device.category.color), type: AirMonitorArt.self))
        let purifier = try #require(model.devices.first { $0.did == "d21" })
        let sensor = try #require(model.devices.first { $0.did == "d6" })
        #expect(purifier.category == .airPurifier && sensor.category == .sensor)
        #expect(contains(TypeDetailView(device: purifier, state: try #require(model.states["d21"])).body, type: AirPurifierDetail.self))
        #expect(contains(TypeDetailView(device: sensor, state: try #require(model.states["d6"])).body, type: SensorDetail.self))
    }

    @Test func airMonitorPrimaryReadingFallbacks() {
        let device = Device(did: "demo", name: "Demo", model: "cgllc.airmonitor.demo", isOnline: true)
        let names = ["pm2.5-density", "co2-density", "air-quality-index", "air-quality", "temperature"]
        for index in names.indices {
            let properties: [[String: Any]] = names[index...].enumerated().map { offset, name in
                ["iid": offset + 1, "type": name, "format": "float", "access": ["read"]]
            }
            let spec = DeviceSpec.parse(["services": [["iid": 2, "type": "air-monitor", "properties": properties]]])
            let detail = AirMonitorDetail(dc: DC(device: device, state: DeviceState(values: [:], spec: spec, legacy: false, source: "cloud")))
            #expect(detail.reading?.name == names[index])
            #expect(detail.readingUnit == ["µg/m³", "ppm", "", "", "°C"][index])
            #expect(primarySliderProp(detail.dc) == nil)
        }
    }

    @Test func airMonitorOptionalScreenAndMissingSpec() {
        let device = Device(did: "demo", name: "Demo", model: "cgllc.airmonitor.demo", isOnline: true)
        let empty = AirMonitorDetail(dc: DC(device: device, state: DeviceState(values: [:], spec: nil, legacy: false, source: "cloud")))
        #expect(empty.reading == nil && empty.screen == nil && empty.on)
        #expect(empty.readout("temperature", L("温度", "Temperature"), "°C") == nil)
        for access in [["read"], ["read", "write"]] {
            let spec = DeviceSpec.parse(["services": [["iid": 2, "type": "screen", "properties": [
                ["iid": 1, "type": "on", "format": "bool", "access": access]
            ]], ["iid": 3, "type": "air-monitor", "properties": [
                ["iid": 1, "type": "pm10-density", "format": "float", "access": ["read"]]
            ]]]])
            for screenOn in [true, false] {
                let state = DeviceState(values: ["2.1": .bool(screenOn), "3.1": .int(18)], spec: spec, legacy: false, source: "cloud")
                let detail = AirMonitorDetail(dc: DC(device: device, state: state))
                #expect(detail.screen?.key == "2.1" && detail.on == screenOn)
                #expect(detail.title == L("监测中", "Monitoring"))
                #expect(detail.readout("pm10-density", "PM10", " µg/m³") == "PM10 18 µg/m³")
                let fields = Mirror(reflecting: detail.body).children
                #expect(fields.first { $0.label == "powerOn" }?.value as? Bool == nil)
                #expect(!(fields.first { $0.label == "onPower" }?.value is () -> Void))
            }
        }
    }

    @Test func waterDispenserDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d42" })
        #expect(device.category == .waterDispenser && device.category.rawValue == "water-dispenser")
        #expect(device.model == "yunmi.ysj.demo" && device.form == nil)
        #expect(device.name == L("饮水机", "Water dispenser"))
        #expect(device.homeId == "h2" && device.roomName == L("厨房", "Kitchen"))
        #expect(device.icon == "waterbottle" && zhCategory(device.category) == L("饮水机", "Water dispenser"))
        #expect(device.category.color == Color(red: 0.20, green: 0.58, blue: 0.72))
        #expect(HouseCatalog.deviceClass(category: device.category, model: device.model) == .badge)
        #expect(HouseChipStyle.tint(device.category) == device.category.color)
        var state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        #expect(context.spec?.type == "urn:miot-spec-v2:device:water-dispenser:0")
        let power = try #require(context.p("on", in: "water-dispenser"))
        let target = try #require(context.p("target-temperature"))
        #expect(model.powerInfo(device)?.key == power.key && context.bool(power) == true)
        #expect(target.writable && target.range == [25, 95, 5] && context.num(target) == 45)
        #expect(context.num(context.p("outlet-temperature")) == 45)
        #expect(context.num(context.p("water-level")) == 75)
        #expect(context.p("mode")?.writable == true && context.p("mode")?.options?.count == 2)
        #expect(context.p("physical-controls-locked")?.writable == true && context.bool(context.p("physical-controls-locked")) == true)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            if let art = value as? () -> WaterDispenserArt { return contains(art(), type: type) }
            return value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        for on in [true, false] {
            state.values[power.key] = .bool(on)
            let detail = WaterDispenserDetail(dc: DC(device: device, state: state))
            #expect(detail.on == on && detail.title == (on ? L("已开启", "On") : L("已关闭", "Off")))
            #expect(detail.power == power && detail.writablePower == power && detail.target == target)
            let routed = TypeDetailView(device: device, state: state).body
            #expect(contains(routed, type: WaterDispenserDetail.self))
            #expect(!contains(routed, type: PurifierDetail.self) && !contains(routed, type: KettleDetail.self) && !contains(routed, type: WaterHeaterDetail.self) && !contains(routed, type: DeviceCardView.self))
            #expect(contains(detail.body, type: WaterDispenserArt.self))
            #expect(!contains(detail.body, type: PurifierArt.self) && !contains(detail.body, type: KettleArt.self) && !contains(detail.body, type: WaterHeaterArt.self) && !contains(detail.body, type: GenericArt.self))
            let fields = Mirror(reflecting: detail.body).children
            let art = try #require(fields.first { $0.label == "art" }?.value as? () -> WaterDispenserArt)
            #expect(art().on == on && art().tint == device.category.color)
            #expect(fields.first { $0.label == "isOn" }?.value as? Bool == on)
            #expect(fields.first { $0.label == "powerOn" }?.value as? Bool == on)
            #expect(fields.first { $0.label == "onPower" }?.value is () -> Void)
            #expect(fields.first { $0.label == "subtitle" }?.value as? String == L("饮水机", "Water dispenser"))
        }
        let idle = offArt(device, tint: device.category.color)
        #expect(contains(idle, type: WaterDispenserArt.self) && !contains(idle, type: PurifierArt.self) && !contains(idle, type: GenericArt.self))
        let gallery = try #require(ArtGallery.rows.first { $0.0 == "water-dispenser" })
        #expect(contains(gallery.1, type: WaterDispenserArt.self) && contains(gallery.2, type: WaterDispenserArt.self))
        for suffix in ["on", "off"] {
            #expect(AppResources.url("badge-water-dispenser-" + suffix, "png", subdirectory: "House")
                ?? AppResources.url("badge-water-dispenser-" + suffix, "png") != nil)
        }
        state.spec = nil
        let absent = WaterDispenserDetail(dc: DC(device: device, state: state))
        #expect(absent.power == nil && absent.writablePower == nil && !absent.on)
        #expect(absent.temperature == nil && absent.target == nil && absent.mode == nil && absent.childLock == nil)
        #expect(absent.title == L("已关闭", "Off"))
    }

    @Test func waterDispenserOptionalAndReadOnlyProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d42" })
        var state = try #require(model.states[device.did])
        state.spec = DeviceSpec.parse(["services": [["iid": 2, "type": "water-dispenser", "properties": [
            ["iid": 1, "type": "on", "format": "bool", "access": ["read"]],
            ["iid": 2, "type": "outlet-temperature", "format": "uint8", "access": ["read", "write"], "value-range": [25, 95, 5]],
            ["iid": 5, "type": "child-lock", "format": "bool", "access": ["read", "write"]]
        ]]]])
        let detail = WaterDispenserDetail(dc: DC(device: device, state: state))
        #expect(detail.on && detail.writablePower == nil)
        #expect(detail.temperature?.writable == true && detail.temperature?.range == [25, 95, 5])
        #expect(detail.target == nil && detail.mode == nil && detail.childLock?.name == "child-lock")
        let fields = Mirror(reflecting: detail.body).children
        #expect((fields.first { $0.label == "onPower" }?.value as? (() -> Void)) == nil)
    }

    @Test func bathHeaterDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d41" })
        #expect(device.category == .bathHeater && device.category.rawValue == "bath-heater")
        #expect(device.model == "yeelink.bhf_light.demo" && device.form == nil)
        #expect(device.homeId == "h2" && device.roomName == L("浴室", "Bathroom"))
        #expect(device.name == L("浴霸", "Bath heater") && device.icon == "fan.and.light.ceiling")
        #expect(device.category.color == Color(red: 0.86, green: 0.42, blue: 0.35))
        #expect(zhCategory(device.category) == L("浴霸", "Bath heater"))
        #expect(HouseCatalog.deviceClass(category: .bathHeater) == .badge)
        var state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        #expect(context.spec?.type == "urn:miot-spec-v2:device:bath-heater:0")
        let light = try #require(context.p("on", in: "light"))
        let brightness = try #require(context.p("brightness", in: "light"))
        let heating = try #require(context.p("heating", in: "ptc-bath-heater"))
        let ventilation = try #require(context.p("ventilation", in: "ptc-bath-heater"))
        for prop in [light, heating, ventilation] { #expect(prop.writable && prop.format == "bool") }
        #expect(context.bool(light) == true && context.bool(heating) == true && context.bool(ventilation) == false)
        #expect(model.powerInfo(device)?.key == light.key)
        #expect(brightness.writable && brightness.format == "uint8" && brightness.range == [1, 100, 1])
        #expect(context.num(brightness) == 80 && primarySliderProp(context)?.key == brightness.key)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            if let art = value as? () -> BathHeaterArt { return contains(art(), type: type) }
            if let content = value as? () -> TupleView<(PropSlider?, HStack<TupleView<(PropTile?, PropTile?, PropTile?)>>)> { return contains(content(), type: type) }
            return value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        for (lightOn, heatingOn, ventilationOn, title) in [
            (true, true, true, L("加热中", "Heating")), (true, false, true, L("换气中", "Ventilating")),
            (true, false, false, L("照明已开", "Light on")), (false, false, false, L("已关闭", "Off")),
            (false, true, false, L("加热中", "Heating")), (false, false, true, L("换气中", "Ventilating"))] {
            state.values[light.key] = .bool(lightOn); state.values[heating.key] = .bool(heatingOn); state.values[ventilation.key] = .bool(ventilationOn)
            let detail = BathHeaterDetail(dc: DC(device: device, state: state))
            #expect(detail.light == light && detail.power == light && detail.heating == heating && detail.ventilation == ventilation && detail.blow == nil)
            #expect(detail.lightOn == lightOn && detail.on == (lightOn || heatingOn || ventilationOn) && detail.title == title)
            let routed = TypeDetailView(device: device, state: state).body
            #expect(contains(routed, type: BathHeaterDetail.self))
            #expect(!contains(routed, type: LightDetail.self) && !contains(routed, type: HeaterDetail.self) && !contains(routed, type: DeviceCardView.self))
            #expect(contains(detail.body, type: BathHeaterArt.self) && contains(detail.body, type: PropSlider.self) && contains(detail.body, type: PropTile.self))
            #expect(!contains(detail.body, type: BulbArt.self) && !contains(detail.body, type: HeaterArt.self) && !contains(detail.body, type: GenericArt.self))
            let fields = Mirror(reflecting: detail.body).children
            let art = try #require(fields.first { $0.label == "art" }?.value as? () -> BathHeaterArt)
            #expect(art().on == detail.on)
            #expect(fields.first { $0.label == "isOn" }?.value as? Bool == detail.on)
            #expect(fields.first { $0.label == "powerOn" }?.value as? Bool == lightOn)
            #expect(fields.first { $0.label == "title" }?.value as? String == title)
            #expect(fields.first { $0.label == "subtitle" }?.value as? String == L("浴霸", "Bath heater"))
        }
        #expect(contains(offArt(device, tint: device.category.color), type: BathHeaterArt.self))
        let gallery = try #require(ArtGallery.rows.first { $0.0 == "bath-heater" })
        #expect(contains(gallery.1, type: BathHeaterArt.self) && contains(gallery.2, type: BathHeaterArt.self))
        for suffix in ["on", "off"] {
            #expect(AppResources.url("badge-bath-heater-" + suffix, "png", subdirectory: "House")
                ?? AppResources.url("badge-bath-heater-" + suffix, "png") != nil)
        }
        state.spec = nil
        let absent = BathHeaterDetail(dc: DC(device: device, state: state))
        #expect(absent.light == nil && absent.power == nil && !absent.on && absent.title == L("已关闭", "Off"))
        #expect(!contains(absent.body, type: PropSlider.self) && !contains(absent.body, type: PropTile.self))
        for access in [["read"], ["read", "write"]] {
            state.spec = DeviceSpec.parse(["services": [["iid": 2, "type": "ptc-bath-heater", "properties": [
                ["iid": 1, "type": "on", "format": "bool", "access": access],
                ["iid": 2, "type": "blow", "format": "bool", "access": access]]]]])
            state.values = ["2.1": .bool(false), "2.2": .bool(true)]
            let detail = BathHeaterDetail(dc: DC(device: device, state: state))
            #expect(detail.on && detail.title == L("吹风中", "Blowing") && detail.blow != nil)
            #expect((detail.power != nil) == access.contains("write"))
            #expect(!contains(detail.body, type: PropSlider.self))
            state.values["2.1"] = .bool(true)
            #expect(BathHeaterDetail(dc: DC(device: device, state: state)).title == L("加热中", "Heating"))
        }
    }

    @Test func gatewayDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d40" })
        #expect(device.category == .gateway && device.category.rawValue == "gateway")
        #expect(device.model == "lumi.gateway.demo" && device.form == nil)
        #expect(device.homeId == "h2" && device.roomName == L("客厅", "Living room"))
        #expect(device.name == L("网关", "Gateway") && device.icon == "antenna.radiowaves.left.and.right")
        #expect(device.category.color == Color(red: 0.35, green: 0.48, blue: 0.86))
        #expect(zhCategory(device.category) == L("网关", "Gateway"))
        #expect(HouseCatalog.deviceClass(category: .gateway) == .badge)
        var state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        #expect(context.spec?.type == "urn:miot-spec-v2:device:gateway:0")
        let light = try #require(context.p("on", in: "light"))
        let brightness = try #require(context.p("brightness", in: "light"))
        #expect(light.writable && light.format == "bool" && context.bool(light) == true)
        #expect(model.powerInfo(device)?.key == light.key)
        #expect(brightness.writable && brightness.format == "uint8" && brightness.range == [1, 100, 1])
        #expect(context.num(brightness) == 80 && primarySliderProp(context)?.key == brightness.key)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            if let art = value as? () -> GatewayArt { return contains(art(), type: type) }
            if let content = value as? () -> TupleView<(PropSlider?, HStack<PropTile?>)> { return contains(content(), type: type) }
            return value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        func checkShell(_ shell: some View, on: Bool, hasPower: Bool) throws {
            let fields = Mirror(reflecting: shell).children
            let art = try #require(fields.first { $0.label == "art" }?.value as? () -> GatewayArt)
            let handler = try #require(fields.first { $0.label == "onPower" }?.value)
            #expect(fields.first { $0.label == "isOn" }?.value as? Bool == on)
            #expect(art().on == on)
            #expect(!Mirror(reflecting: handler).children.isEmpty == hasPower)
            #expect(fields.first { $0.label == "subtitle" }?.value as? String == L("网关", "Gateway"))
            #expect(fields.first { $0.label == "title" }?.value as? String == (on ? L("已开启", "On") : L("已关闭", "Off")))
        }
        for on in [true, false] {
            state.values[light.key] = .bool(on)
            let detail = GatewayDetail(dc: DC(device: device, state: state))
            #expect(detail.light?.key == light.key && detail.power?.key == light.key && detail.on == on)
            let routed = TypeDetailView(device: device, state: state).body
            #expect(contains(routed, type: GatewayDetail.self))
            #expect(contains(detail.body, type: GatewayArt.self))
            #expect(!contains(routed, type: DeviceCardView.self) && !contains(detail.body, type: GenericArt.self))
            try checkShell(detail.body, on: on, hasPower: true)
        }
        let idle = offArt(device, tint: device.category.color)
        #expect(contains(idle, type: GatewayArt.self) && !contains(idle, type: GenericArt.self))
        let gallery = try #require(ArtGallery.rows.first { $0.0 == "gateway" })
        #expect(contains(gallery.1, type: GatewayArt.self) && contains(gallery.2, type: GatewayArt.self))
        for suffix in ["on", "off"] {
            #expect(AppResources.url("badge-gateway-" + suffix, "png", subdirectory: "House")
                ?? AppResources.url("badge-gateway-" + suffix, "png") != nil)
        }
        state.spec = nil
        let absent = GatewayDetail(dc: DC(device: device, state: state))
        #expect(absent.light == nil && absent.power == nil && primarySliderProp(absent.dc) == nil)
        #expect(!contains(absent.body, type: PropSlider.self) && !contains(absent.body, type: PropTile.self))
        try checkShell(absent.body, on: false, hasPower: false)
        for access in [["read"], ["read", "write"]] {
            let spec = DeviceSpec.parse(["services": [["iid": 2, "type": "light", "properties": [
                ["iid": 1, "type": "on", "format": "bool", "access": access],
                ["iid": 2, "type": "brightness", "format": "uint8", "access": access, "value-range": [1, 100, 1]]
            ]]]])
            let detail = GatewayDetail(dc: DC(device: device, state: DeviceState(values: ["2.1": .bool(true)], spec: spec, legacy: false, source: "cloud")))
            #expect((primarySliderProp(detail.dc) != nil) == access.contains("write"))
            #expect(contains(detail.body, type: PropSlider.self) == access.contains("write"))
            try checkShell(detail.body, on: true, hasPower: access.contains("write"))
        }
        let powerOnly = DeviceSpec.parse(["services": [["iid": 2, "type": "gateway", "properties": [
            ["iid": 1, "type": "on", "format": "bool", "access": ["read", "write"]]
        ]]]])
        let detail = GatewayDetail(dc: DC(device: device, state: DeviceState(values: ["2.1": .bool(true)], spec: powerOnly, legacy: false, source: "cloud")))
        #expect(detail.light?.key == "2.1" && primarySliderProp(detail.dc) == nil)
        #expect(!contains(detail.body, type: PropSlider.self) && !contains(detail.body, type: PropTile.self))
        try checkShell(detail.body, on: true, hasPower: true)
    }

    @Test func clockDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d37" })
        #expect(device.category == .clock && device.category.rawValue == "clock")
        #expect(device.model == "yeelink.clock.demo" && device.form == nil)
        #expect(device.homeId == "h2" && device.roomName == L("主卧", "Bedroom"))
        #expect(device.name == L("闹钟", "Clock") && device.icon == "deskclock")
        #expect(device.category.color == Color(red: 0.95, green: 0.70, blue: 0.25))
        #expect(zhCategory(device.category) == L("闹钟", "Clock"))
        #expect(HouseCatalog.deviceClass(category: .clock) == .badge)
        var state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        #expect(context.spec?.type == "urn:miot-spec-v2:device:clock:0")
        let light = try #require(context.p("on", in: "light"))
        let brightness = try #require(context.p("brightness", in: "light"))
        let alarm = try #require(context.p("on", in: "alarm"))
        let battery = try #require(context.p("battery-level", in: "battery"))
        #expect(light.writable && light.format == "bool" && context.bool(light) == true)
        #expect(model.powerInfo(device)?.key == light.key)
        #expect(brightness.writable && brightness.format == "uint8" && brightness.range == [1, 100, 1])
        #expect(context.num(brightness) == 80 && primarySliderProp(context)?.key == brightness.key)
        #expect(alarm.writable && alarm.format == "bool" && context.bool(alarm) == true)
        #expect(battery.readable && !battery.writable && battery.range == [0, 100, 1] && battery.unit == "percentage")
        #expect(context.num(battery) == 90)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            if let art = value as? () -> ClockArt { return contains(art(), type: type) }
            return value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        func checkShell(_ shell: some View, on: Bool, hasPower: Bool) throws {
            let fields = Mirror(reflecting: shell).children
            let art = try #require(fields.first { $0.label == "art" }?.value as? () -> ClockArt)
            let handler = try #require(fields.first { $0.label == "onPower" }?.value)
            #expect(fields.first { $0.label == "isOn" }?.value as? Bool == on)
            #expect(art().on == on)
            #expect(!Mirror(reflecting: handler).children.isEmpty == hasPower)
            #expect(fields.first { $0.label == "subtitle" }?.value as? String == L("闹钟", "Clock"))
            #expect(fields.first { $0.label == "title" }?.value as? String == (on ? L("已开启", "On") : L("已关闭", "Off")))
        }
        for on in [true, false] {
            state.values[light.key] = .bool(on)
            let detail = ClockDetail(dc: DC(device: device, state: state))
            #expect(detail.light?.key == light.key && detail.power?.key == light.key && detail.on == on)
            let routed = TypeDetailView(device: device, state: state).body
            #expect(contains(routed, type: ClockDetail.self))
            #expect(contains(detail.body, type: ClockArt.self))
            #expect(!contains(routed, type: DeviceCardView.self) && !contains(detail.body, type: GenericArt.self))
            try checkShell(detail.body, on: on, hasPower: true)
        }
        let idle = offArt(device, tint: device.category.color)
        #expect(contains(idle, type: ClockArt.self) && !contains(idle, type: GenericArt.self))
        let gallery = try #require(ArtGallery.rows.first { $0.0 == "clock" })
        #expect(contains(gallery.1, type: ClockArt.self) && contains(gallery.2, type: ClockArt.self))
        for suffix in ["on", "off"] {
            #expect(AppResources.url("badge-clock-" + suffix, "png", subdirectory: "House")
                ?? AppResources.url("badge-clock-" + suffix, "png") != nil)
        }
        state.spec = nil
        let absent = ClockDetail(dc: DC(device: device, state: state))
        #expect(absent.light == nil && absent.power == nil && primarySliderProp(absent.dc) == nil)
        try checkShell(absent.body, on: false, hasPower: false)
        for access in [["read"], ["read", "write"]] {
            let spec = DeviceSpec.parse(["services": [["iid": 2, "type": "light", "properties": [
                ["iid": 1, "type": "on", "format": "bool", "access": access],
                ["iid": 2, "type": "brightness", "format": "uint8", "access": access, "value-range": [1, 100, 1]]
            ]]]])
            let detail = ClockDetail(dc: DC(device: device, state: DeviceState(values: ["2.1": .bool(true)], spec: spec, legacy: false, source: "cloud")))
            #expect((primarySliderProp(detail.dc) != nil) == access.contains("write"))
            try checkShell(detail.body, on: true, hasPower: access.contains("write"))
        }
    }

    @Test func airerDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d36" })
        #expect(device.category == .airer && device.category.rawValue == "airer")
        #expect(device.model == "hyd.airer.demo" && device.form == nil)
        #expect(device.homeId == "h2" && device.roomName == L("阳台", "Balcony"))
        #expect(device.name == L("晾衣架", "Clothes airer") && device.icon == "hanger")
        #expect(device.category.color == Color.mint)
        #expect(zhCategory(device.category) == L("晾衣架", "Clothes airer"))
        #expect(HouseCatalog.deviceClass(category: .airer) == .badge)
        var state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let light = try #require(context.p("on", in: "light"))
        let position = try #require(context.p("current-position"))
        let target = try #require(primarySliderProp(context))
        let drying = try #require(context.p("drying"))
        #expect(light.writable && light.format == "bool" && context.bool(light) == true)
        #expect(model.powerInfo(device)?.key == light.key)
        #expect(!position.writable && position.range == [0, 100, 1] && context.num(position) == 100)
        #expect(target.name == "target-position" && target.writable && target.range == [0, 100, 1])
        #expect(context.num(target) == 100 && context.bool(drying) == false)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            if let art = value as? () -> AirerArt { return contains(art(), type: type) }
            return value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        func checkShell(_ shell: some View, on: Bool, lowered: Bool, hasPower: Bool) throws {
            let fields = Mirror(reflecting: shell).children
            let art = try #require(fields.first { $0.label == "art" }?.value as? () -> AirerArt)
            let handler = try #require(fields.first { $0.label == "onPower" }?.value)
            #expect(fields.first { $0.label == "isOn" }?.value as? Bool == on)
            #expect(art().lowered == lowered && art().lightOn == (hasPower && on))
            #expect(!Mirror(reflecting: handler).children.isEmpty == hasPower)
            #expect(fields.first { $0.label == "subtitle" }?.value as? String == L("晾衣架", "Clothes airer"))
            #expect(fields.first { $0.label == "title" }?.value as? String == (hasPower ? (on ? L("已开启", "On") : L("已关闭", "Off")) : (lowered ? L("已降下", "Lowered") : L("已升起", "Raised"))))
        }
        for active in [true, false] {
            state.values[light.key] = .bool(active)
            state.values[position.key] = .int(active ? 100 : 0)
            state.values[target.key] = .int(active ? 100 : 0)
            let detail = AirerDetail(dc: DC(device: device, state: state))
            #expect(detail.on == active && detail.lowered == active && detail.power == light)
            let routed = TypeDetailView(device: device, state: state).body
            #expect(contains(routed, type: AirerDetail.self))
            #expect(contains(detail.body, type: AirerArt.self))
            #expect(!contains(routed, type: DeviceCardView.self))
            #expect(!contains(detail.body, type: GenericArt.self))
            #expect(!contains(detail.body, type: WasherArt.self))
            #expect(!contains(detail.body, type: WaterHeaterArt.self))
            try checkShell(detail.body, on: active, lowered: active, hasPower: true)
        }
        state.values[position.key] = .int(100)
        let unlit = AirerDetail(dc: DC(device: device, state: state))
        try checkShell(unlit.body, on: false, lowered: true, hasPower: true)
        for access in [["read"], ["read", "write"]] {
            let targetProperty = SpecProperty(siid: target.siid, iid: target.iid, type: target.type, description: target.description,
                                              format: target.format, access: access, unit: target.unit, range: target.range, options: target.options)
            state.spec = DeviceSpec(type: "", description: "", services: [
                SpecService(iid: 2, type: "urn:miot-spec-v2:service:airer:0", description: "", properties: [position, targetProperty], actions: [])])
            let noLight = DC(device: device, state: state)
            #expect((primarySliderProp(noLight) != nil) == access.contains("write"))
            try checkShell(AirerDetail(dc: noLight).body, on: true, lowered: true, hasPower: false)
        }
        state.spec = nil
        let absent = AirerDetail(dc: DC(device: device, state: state))
        #expect(absent.light == nil && absent.position == nil && primarySliderProp(absent.dc) == nil)
        try checkShell(absent.body, on: false, lowered: false, hasPower: false)
        let idle = offArt(device, tint: device.category.color)
        #expect(contains(idle, type: AirerArt.self) && !contains(idle, type: GenericArt.self))
        let gallery = try #require(ArtGallery.rows.first { $0.0 == "airer" })
        #expect(contains(gallery.1, type: AirerArt.self) && contains(gallery.2, type: AirerArt.self))
        for suffix in ["on", "off"] {
            #expect(AppResources.url("badge-airer-" + suffix, "png", subdirectory: "House")
                ?? AppResources.url("badge-airer-" + suffix, "png") != nil)
        }
        #expect(model.devices.first { $0.did == "d18" }?.category == .washer)
    }

    @Test func lockDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d35" })
        #expect(device.category == .lock && device.category.rawValue == "lock")
        #expect(device.model == "lumi.lock.demo" && device.form == nil)
        #expect(device.homeId == "h2" && device.roomName == L("门口", "Entrance"))
        #expect(device.name == L("门锁", "Door lock"))
        #expect(device.icon == DeviceCategory.lock.icon && device.icon == "lock.fill")
        #expect(device.category.color == Color.brown)
        #expect(zhCategory(device.category) == L("门锁", "Door lock"))
        #expect(HouseCatalog.deviceClass(category: .lock) == .badge)
        var state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let locked = try #require(context.p("locked"))
        let door = try #require(context.p("door-state"))
        let battery = try #require(context.p("battery-level"))
        #expect(locked.key == "2.1" && locked.writable && locked.format == "bool")
        #expect(context.bool(locked) == true && context.spec?.mainOnProperty == nil)
        #expect(door.key == "2.2" && !door.writable && door.options?.count == 2)
        #expect(context.num(door) == 0)
        #expect(battery.key == "3.1" && !battery.writable && context.num(battery) == 80)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            if let art = value as? () -> LockArt { return contains(art(), type: type) }
            return value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        func tiles(_ value: Any) -> [PropTile] {
            if let tile = value as? PropTile { return [tile] }
            return Mirror(reflecting: value).children.flatMap { tiles($0.value) }
        }
        for isLocked in [true, false] {
            state.values[locked.key] = .bool(isLocked)
            let detail = LockDetail(dc: DC(device: device, state: state))
            #expect(detail.locked == isLocked)
            let shell = try #require(detail.body as? TypeShell<LockArt, HStack<TupleView<(PropTile, PropTile, PropTile)>>>)
            #expect(shell.isOn == isLocked && shell.art().locked == isLocked)
            #expect(shell.title == (isLocked ? L("已上锁", "Locked") : L("已解锁", "Unlocked")))
            #expect(shell.subtitle == L("门锁", "Door lock") && shell.onPower == nil)
            #expect(tiles(shell.content()).compactMap(\.prop) == [door, battery, locked])
            let routed = TypeDetailView(device: device, state: state).body
            #expect(contains(routed, type: LockDetail.self))
            #expect(contains(detail.body, type: LockArt.self))
            #expect(!contains(routed, type: DeviceCardView.self))
            #expect(!contains(detail.body, type: GenericArt.self))
            #expect(!contains(detail.body, type: CameraArt.self))
            #expect(!contains(detail.body, type: DoorbellArt.self))
        }
        let alias = SpecProperty(siid: 2, iid: 1, type: "urn:miot-spec-v2:property:lock:0", description: "", format: "bool",
                                 access: ["read", "write"], unit: nil, range: nil, options: nil)
        let power = SpecProperty(siid: 2, iid: 3, type: "urn:miot-spec-v2:property:on:0", description: "", format: "bool",
                                 access: ["read", "write"], unit: nil, range: nil, options: nil)
        state.spec = DeviceSpec(type: "", description: "", services: [
            SpecService(iid: 2, type: "urn:miot-spec-v2:service:lock:0", description: "", properties: [alias, power], actions: [])])
        state.values[alias.key] = .bool(true)
        state.values[power.key] = .bool(false)
        let powered = LockDetail(dc: DC(device: device, state: state))
        let poweredShell = try #require(powered.body as? TypeShell<LockArt, HStack<TupleView<(PropTile, PropTile, PropTile)>>>)
        #expect(powered.lockProperty == alias && poweredShell.isOn)
        #expect(poweredShell.onPower != nil && poweredShell.powerOn == false)
        state.spec = DeviceSpec(type: "", description: "", services: [])
        let empty = LockDetail(dc: DC(device: device, state: state))
        let emptyShell = try #require(empty.body as? TypeShell<LockArt, HStack<TupleView<(PropTile, PropTile, PropTile)>>>)
        #expect(emptyShell.onPower == nil && !emptyShell.isOn)
        let emptyTiles = tiles(emptyShell.content())
        #expect(emptyTiles.count == 3 && emptyTiles.allSatisfy { $0.prop == nil })
        let idle = offArt(device, tint: device.category.color)
        #expect(contains(idle, type: LockArt.self) && !contains(idle, type: GenericArt.self))
        let gallery = try #require(ArtGallery.rows.first { $0.0 == "lock" })
        #expect(contains(gallery.1, type: LockArt.self) && contains(gallery.2, type: LockArt.self))
        for suffix in ["on", "off"] {
            #expect(AppResources.url("badge-lock-" + suffix, "png", subdirectory: "House")
                ?? AppResources.url("badge-lock-" + suffix, "png") != nil)
        }
    }

    @Test func hoodDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d34" })
        #expect(device.category == .hood && device.category.rawValue == "hood")
        #expect(device.model == "yunmi.hood.demo" && device.form == nil)
        #expect(device.homeId == "h2" && device.roomName == L("厨房", "Kitchen"))
        #expect(device.name == L("油烟机", "Range hood") && device.icon == "fan.ceiling")
        #expect(zhCategory(device.category) == L("油烟机", "Range hood"))
        #expect(HouseCatalog.deviceClass(category: .hood) == .badge)
        var state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let power = try #require(context.spec?.mainOnProperty)
        let level = try #require(context.p("fan-level"))
        let light = try #require(context.p("on", in: "light"))
        #expect(power.key == "2.1" && power.writable && power.format == "bool")
        #expect(context.bool(power) == true && model.powerInfo(device)?.key == power.key)
        #expect(level.writable && level.format == "uint8" && level.options?.count == 3)
        #expect(context.num(level) == 2 && context.bool(light) == true)
        #expect(light.writable && light.format == "bool" && light.key != power.key)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            if let art = value as? () -> HoodArt { return contains(art(), type: type) }
            return value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        func tiles(_ value: Any) -> [PropTile] {
            if let tile = value as? PropTile { return [tile] }
            if let content = value as? () -> HStack<TupleView<(PropTile, PropTile)>> { return tiles(content()) }
            return Mirror(reflecting: value).children.flatMap { tiles($0.value) }
        }
        #expect(tiles(HoodDetail(dc: context).body).compactMap(\.prop) == [level, light])
        for on in [true, false] {
            state.values[power.key] = .bool(on)
            let detail = HoodDetail(dc: DC(device: device, state: state))
            #expect(detail.on == on)
            let routed = TypeDetailView(device: device, state: state).body
            #expect(contains(routed, type: HoodDetail.self))
            #expect(!contains(routed, type: DeviceCardView.self))
            #expect(contains(detail.body, type: HoodArt.self))
            #expect(!contains(detail.body, type: GenericArt.self))
            #expect(!contains(detail.body, type: CookerArt.self))
            #expect(!contains(detail.body, type: FanArt.self))
        }
        state.spec = DeviceSpec(type: "", description: "", services: [
            SpecService(iid: 2, type: "urn:miot-spec-v2:service:hood:0", description: "", properties: [power], actions: [])])
        let absent = tiles(HoodDetail(dc: DC(device: device, state: state)).body)
        #expect(absent.count == 2 && absent.allSatisfy { $0.prop == nil })
        let idle = offArt(device, tint: device.category.color)
        #expect(contains(idle, type: HoodArt.self) && !contains(idle, type: GenericArt.self))
        #expect(ArtGallery.rows.filter { $0.0 == "hood" }.count == 1)
        let gallery = try #require(ArtGallery.rows.first { $0.0 == "hood" })
        #expect(contains(gallery.1, type: HoodArt.self) && contains(gallery.2, type: HoodArt.self))
        for suffix in ["on", "off"] {
            #expect(AppResources.url("badge-hood-" + suffix, "png", subdirectory: "House")
                ?? AppResources.url("badge-hood-" + suffix, "png") != nil)
        }
    }

    @Test func wallSwitchDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d33" })
        #expect(device.model == "lumi.switch.demo")
        #expect(device.category == .plug && device.form == .wallSwitch)
        #expect(device.homeId == "h2" && device.roomName == L("客厅", "Living room"))
        #expect(device.isOnline && device.icon == "lightswitch.on")
        var state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let power = try #require(context.spec?.mainOnProperty)
        #expect(power.key == "2.1" && power.writable && power.format == "bool")
        #expect(context.bool(power) == true)
        #expect(model.powerInfo(device)?.key == power.key)
        let indicator = try #require(context.p("on", in: "indicator-light"))
        let lock = try #require(context.p("physical-controls-locked"))
        #expect(indicator.writable && indicator.format == "bool" && context.bool(indicator) == true)
        #expect(lock.writable && lock.format == "bool" && context.bool(lock) == false)
        #expect(context.p("electric-power") == nil && context.p("power-consumption") == nil)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            if let art = value as? () -> WallSwitchArt { return contains(art(), type: type) }
            if let content = value as? () -> HStack<TupleView<(PropTile, PropTile)>> { return contains(content(), type: type) }
            return value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        func tiles(_ value: Any) -> [PropTile] {
            if let tile = value as? PropTile { return [tile] }
            if let content = value as? () -> HStack<TupleView<(PropTile, PropTile)>> { return tiles(content()) }
            return Mirror(reflecting: value).children.flatMap { tiles($0.value) }
        }
        #expect(tiles(WallSwitchDetail(dc: context).body).compactMap(\.prop) == [indicator, lock])
        state.spec = DeviceSpec(type: "", description: "", services: [
            SpecService(iid: 2, type: "urn:miot-spec-v2:service:switch:0", description: "", properties: [power], actions: [])])
        let minimal = WallSwitchDetail(dc: DC(device: device, state: state))
        #expect(minimal.on)
        let absent = tiles(minimal.body)
        #expect(absent.count == 2 && absent.allSatisfy { $0.prop == nil })
        #expect(absent.allSatisfy { !contains($0.body, type: ToggleTile.self) })
        state = try #require(model.states[device.did])
        for on in [true, false] {
            state.values[power.key] = .bool(on)
            let detail = WallSwitchDetail(dc: DC(device: device, state: state))
            #expect(detail.on == on)
            let routed = TypeDetailView(device: device, state: state).body
            #expect(contains(routed, type: WallSwitchDetail.self))
            #expect(!contains(routed, type: PlugDetail.self))
            #expect(!contains(routed, type: DeviceCardView.self))
            #expect(contains(detail.body, type: WallSwitchArt.self))
            #expect(!contains(detail.body, type: PlugArt.self))
            #expect(!contains(detail.body, type: GenericArt.self))
            #expect(!contains(detail.body, type: PowerHistoryCard.self))
            #expect(!contains(detail.body, type: BigValue.self))
        }
        let idle = offArt(device, tint: device.category.color)
        #expect(contains(idle, type: WallSwitchArt.self))
        #expect(!contains(idle, type: PlugArt.self) && !contains(idle, type: GenericArt.self))
        let gallery = try #require(ArtGallery.rows.first { $0.0 == "wall-switch" })
        #expect(ArtGallery.rows.filter { $0.0 == "wall-switch" }.count == 1)
        #expect(contains(gallery.1, type: WallSwitchArt.self) && contains(gallery.2, type: WallSwitchArt.self))
        state.values.removeValue(forKey: power.key)
        #expect(!WallSwitchDetail(dc: DC(device: device, state: state)).on)
        state.spec = nil
        let missing = WallSwitchDetail(dc: DC(device: device, state: state))
        #expect(!missing.on)
        #expect(contains(missing.body, type: WallSwitchArt.self))
    }

    @Test func wallSwitchFormDoesNotStealPlugsOrOtherCategories() throws {
        let model = AppModel(mock: true)
        var device = try #require(model.devices.first { $0.did == "d33" })
        for name in ["lumi.switch.acn11", "lumi.ctrl_neutral1", "lumi.ctrl_ln1.aq1", "LUMI.SWITCH.ACN11", "LUMI.CTRL_NEUTRAL2", "LUMI.CTRL_LN2.AQ1"] {
            device.model = name
            #expect(device.category == .plug && device.form == .wallSwitch, "\(name)")
        }
        for name in ["chuangmi.plug.m1", "cuco.plug.v3", "cuco.plug.switch.demo", "lumi.outlet.ctrl_neutral1", "lumi.plug.ctrl_ln1", "lumi.outlet.switch.demo", "lumi.switchless.demo"] {
            device.model = name
            #expect(device.category == .plug && device.form == nil, "\(name)")
        }
        for name in ["xiaomi.printer.switch.demo", "lumi.curtain.ctrl_neutral1", "xiaomi.fridge.ctrl_ln1"] {
            device.model = name
            #expect(device.category != .plug && device.form != .wallSwitch, "\(name)")
        }
        let plug = try #require(model.devices.first { $0.did == "d5" })
        #expect(plug.category == .plug && plug.form == nil)
        #expect(plug.icon == plug.category.icon)
        let state = try #require(model.states[plug.did])
        let context = DC(device: plug, state: state)
        #expect(context.num(context.p("electric-power")) == 36.5)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: plug, state: state).body, type: PlugDetail.self))
        #expect(!contains(TypeDetailView(device: plug, state: state).body, type: WallSwitchDetail.self))
        #expect(contains(offArt(plug, tint: plug.category.color), type: PlugArt.self))
        #expect(!contains(offArt(plug, tint: plug.category.color), type: WallSwitchArt.self))
    }

    @Test func thermoDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d6" })
        #expect(device.category == .sensor)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        #expect(context.num(context.p("temperature")) == 25.6)
        #expect(context.num(context.p("relative-humidity")) == 58)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: SensorDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(!contains(SensorDetail(dc: context).body, type: MotionSensorDetail.self))
    }

    @Test func contactDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d12" })
        #expect(device.category == .sensor)
        #expect(device.form == .contact)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        #expect(context.bool(context.p("contact-state")) == false)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: SensorDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(SensorDetail(dc: context).body, type: ContactSensorDetail.self))
    }

    @Test func leakDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d13" })
        #expect(device.category == .sensor)
        #expect(device.form == .leak)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        #expect(context.bool(context.p("submersion-state")) == true)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: SensorDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(SensorDetail(dc: context).body, type: LeakSensorDetail.self))
    }

    @Test func smokeDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d38" })
        #expect(device.category == .sensor && device.form == .smoke)
        #expect(device.model == "lumi.sensor_smoke.demo" && device.icon == "smoke")
        #expect(device.homeId == "h2" && device.roomName == L("厨房", "Kitchen"))
        #expect(device.name == L("烟雾传感器", "Smoke sensor") && device.isOnline)
        #expect(device.category.color == Color.mint)
        #expect(zhCategory(device.category) == L("传感器", "Sensor"))
        #expect(HouseCatalog.deviceClass(category: .sensor) == .badge)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        #expect(context.spec?.type == "urn:miot-spec-v2:device:smoke-sensor:0")
        let smoke = try #require(context.p("smoke-detection", in: "smoke-sensor"))
        let battery = try #require(context.p("battery-level", in: "battery"))
        #expect(smoke.readable && !smoke.writable && smoke.format == "bool" && smoke.access.contains("notify"))
        #expect(context.bool(smoke) == false)
        #expect(battery.readable && !battery.writable && battery.range == [0, 100, 1] && battery.unit == "percentage")
        #expect(context.num(battery) == 94)
        #expect(CardModel.primaryNames[.sensor]?.contains("smoke-detection") == true)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            if let art = value as? () -> SmokeArt { return contains(art(), type: type) }
            return value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        let routed = TypeDetailView(device: device, state: state).body
        #expect(contains(routed, type: SensorDetail.self) && !contains(routed, type: DeviceCardView.self))
        for online in [true, false] {
            for alarm: Bool? in [false, true, nil] {
                var changedDevice = device, changedState = state
                changedDevice.isOnline = online
                changedState.values[smoke.key] = alarm.map { .bool($0) }
                let changedContext = DC(device: changedDevice, state: changedState)
                let sensor = SensorDetail(dc: changedContext).body
                #expect(contains(sensor, type: SmokeSensorDetail.self))
                #expect(!contains(sensor, type: MotionSensorDetail.self))
                let shell = SmokeSensorDetail(dc: changedContext).body
                let fields = Mirror(reflecting: shell).children
                let art = try #require(fields.first { $0.label == "art" }?.value as? () -> SmokeArt)
                #expect(art().on == online && art().alarm == alarm)
                #expect(art().tint == (alarm == true ? Color.orange : Color.mint))
                #expect(fields.first { $0.label == "title" }?.value as? String == (!online ? L("离线", "Offline") : alarm.map { $0 ? L("检测到烟雾", "Smoke detected") : L("无烟雾", "No smoke") } ?? L("在线", "Online")))
                #expect(fields.first { $0.label == "subtitle" }?.value as? String == L("烟雾传感器", "Smoke sensor"))
                #expect(contains(shell, type: SmokeArt.self))
                #expect(!contains(shell, type: MotionSensorArt.self) && !contains(shell, type: ThermoArt.self) && !contains(shell, type: GenericArt.self))
            }
        }
        let idle = offArt(device, tint: .mint)
        #expect(contains(idle, type: SmokeArt.self) && !contains(idle, type: ThermoArt.self))
        let gallery = try #require(ArtGallery.rows.first { $0.0 == "smoke" })
        #expect(contains(gallery.1, type: SmokeArt.self) && contains(gallery.2, type: SmokeArt.self))
        for suffix in ["on", "off"] {
            #expect(AppResources.url("badge-sensor-" + suffix, "png", subdirectory: "House")
                ?? AppResources.url("badge-sensor-" + suffix, "png") != nil)
        }
        for name in ["lumi.sensor_smoke.v1", "jiaoyan.smoke.t1", "LUMI.SENSOR_SMOKE.DEMO", "lumi.sensor_smoke_magnet_flood_motion.demo"] {
            var variant = device
            variant.model = name
            #expect(variant.category == .sensor && variant.form == .smoke && variant.icon == "smoke")
            let missing = DeviceState(values: [:], spec: nil, legacy: false, source: "cloud")
            #expect(contains(SensorDetail(dc: DC(device: variant, state: missing)).body, type: SmokeSensorDetail.self))
        }
        var generic = device
        generic.model = "vendor.sensor.demo"
        #expect(generic.form == nil)
        #expect(contains(SensorDetail(dc: DC(device: generic, state: state)).body, type: SmokeSensorDetail.self))
    }

    @Test func gasDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d39" })
        #expect(device.category == .sensor && device.form == .gas)
        #expect(device.model == "lumi.sensor_natgas.demo" && device.icon == "flame")
        #expect(device.homeId == "h2" && device.roomName == L("厨房", "Kitchen"))
        #expect(device.name == L("燃气传感器", "Gas sensor") && device.isOnline)
        #expect(device.category.color == Color.mint)
        #expect(zhCategory(device.category) == L("传感器", "Sensor"))
        #expect(HouseCatalog.deviceClass(category: device.category) == .badge)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        #expect(context.spec?.type == "urn:miot-spec-v2:device:gas-sensor:0")
        let leakage = try #require(context.p("gas-leakage", in: "gas-sensor"))
        let concentration = try #require(context.p("gas-concentration", in: "gas-sensor"))
        let battery = try #require(context.p("battery-level", in: "battery"))
        #expect(leakage.readable && !leakage.writable && leakage.format == "bool" && leakage.access.contains("notify"))
        #expect(concentration.readable && !concentration.writable && concentration.format == "float" && concentration.access.contains("notify"))
        #expect(concentration.range == [0, 100, 1] && concentration.unit == "percentage")
        #expect(battery.readable && !battery.writable && battery.range == [0, 100, 1] && battery.unit == "percentage")
        #expect(context.bool(leakage) == false && context.num(concentration) == 1 && context.num(battery) == 96)
        #expect(!Recorder.shared.series(device.did, "gas").samples.isEmpty)
        #expect(CardModel.primaryNames[.sensor]?.contains("gas-leakage") == true)
        #expect(CardModel.primaryNames[.sensor]?.contains("gas-concentration") == true)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            if let art = value as? () -> GasArt { return contains(art(), type: type) }
            if let content = value as? () -> TupleView<(BigValue?, ReadoutRow, SensorHistoryCard)> { return contains(content(), type: type) }
            return value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        let detail = GasSensorDetail(dc: context).body
        let shell = try #require(detail as? TypeShell<GasArt, TupleView<(BigValue?, ReadoutRow, SensorHistoryCard)>>)
        #expect(shell.content().value.0?.unit == "%")
        #expect(contains(detail, type: BigValue.self))
        let lel = SpecProperty(siid: 2, iid: 2, type: concentration.type, description: concentration.description, format: "float", access: ["read", "notify"], unit: nil, range: [0, 100, 1], options: nil)
        var lelState = state
        lelState.spec = DeviceSpec(type: "gas-sensor", description: "", services: [SpecService(iid: 2, type: "gas-sensor", description: "", properties: [lel], actions: [])])
        let lelShell = try #require(GasSensorDetail(dc: DC(device: device, state: lelState)).body as? TypeShell<GasArt, TupleView<(BigValue?, ReadoutRow, SensorHistoryCard)>>)
        #expect(lelShell.content().value.0?.unit == "%LEL")
        let routed = TypeDetailView(device: device, state: state).body
        #expect(contains(routed, type: SensorDetail.self) && !contains(routed, type: DeviceCardView.self))
        for online in [true, false] {
            for alarm: Bool? in [false, true, nil] {
                var changed = device, changedState = state
                changed.isOnline = online
                changedState.values[leakage.key] = alarm.map { .bool($0) } ?? .null
                let changedContext = DC(device: changed, state: changedState)
                let sensor = SensorDetail(dc: changedContext).body
                #expect(contains(sensor, type: GasSensorDetail.self))
                #expect(!contains(sensor, type: SmokeSensorDetail.self) && !contains(sensor, type: MotionSensorDetail.self))
                let shell = GasSensorDetail(dc: changedContext).body
                let fields = Mirror(reflecting: shell).children
                let art = try #require(fields.first { $0.label == "art" }?.value as? () -> GasArt)
                #expect(art().on == online && art().alarm == alarm)
                #expect(art().tint == (alarm == true ? Color.orange : Color.mint))
                #expect(fields.first { $0.label == "title" }?.value as? String == (!online ? L("离线", "Offline") : alarm.map { $0 ? L("检测到燃气", "Gas detected") : L("无燃气泄漏", "No gas leak") } ?? L("在线", "Online")))
                #expect(fields.first { $0.label == "subtitle" }?.value as? String == L("燃气传感器", "Gas sensor"))
                #expect(contains(shell, type: GasArt.self))
                #expect(!contains(shell, type: SmokeArt.self) && !contains(shell, type: MotionSensorArt.self))
                #expect(!contains(shell, type: GenericArt.self) && !contains(shell, type: ThermoArt.self))
                let gasMetric = Recorder.metrics(changed, changedState).first { $0.name == "gas" }
                #expect(gasMetric?.value == alarm.map { $0 ? 1.0 : 0.0 })
            }
        }
        let idle = offArt(device, tint: .mint)
        #expect(contains(idle, type: GasArt.self) && !contains(idle, type: ThermoArt.self))
        let gallery = try #require(ArtGallery.rows.first { $0.0 == "gas" })
        #expect(contains(gallery.1, type: GasArt.self) && contains(gallery.2, type: GasArt.self))
        for suffix in ["on", "off"] {
            #expect(AppResources.url("badge-sensor-" + suffix, "png", subdirectory: "House")
                ?? AppResources.url("badge-sensor-" + suffix, "png") != nil)
        }
        for name in ["lumi.sensor_natgas.v1", "lumi.sensor_gas.mcn02", "jiaoyan.gas.t1", "LUMI.SENSOR_NATGAS.DEMO"] {
            var variant = device
            variant.model = name
            #expect(variant.category == .sensor && variant.form == .gas && variant.icon == "flame")
            let missing = DeviceState(values: [:], spec: nil, legacy: false, source: "cloud")
            #expect(contains(SensorDetail(dc: DC(device: variant, state: missing)).body, type: GasSensorDetail.self))
        }
        for name in ["xiaomi.gasheater.gas.demo", "xiaomi.waterheater.gas.demo", "xiaomi.water_heater.gas.demo"] {
            var heater = device
            heater.model = name
            #expect(heater.category == .waterHeater && heater.form != .gas)
        }
        for (name, form) in [("lumi.sensor_motion.demo", DeviceForm.motion), ("lumi.sensor_magnet.aq2", .contact), ("lumi.flood.agl02", .leak)] {
            var variant = device
            variant.model = name
            #expect(variant.category == .sensor && variant.form == form)
        }
        var thermometer = device
        thermometer.model = "miaomiaoce.sensor_ht.t2"
        #expect(thermometer.category == .sensor && thermometer.form == nil)
        var generic = device
        generic.model = "vendor.sensor.demo"
        #expect(generic.form == nil)
        #expect(contains(SensorDetail(dc: DC(device: generic, state: state)).body, type: GasSensorDetail.self))
        var concentrationOnly = state
        concentrationOnly.spec = DeviceSpec(type: "", description: "", services: [SpecService(iid: 2, type: "gas-sensor", description: "", properties: [concentration], actions: [])])
        concentrationOnly.values[concentration.key] = .double(100)
        #expect(DC(device: generic, state: concentrationOnly).gasAlarm == nil)
        #expect(contains(SensorDetail(dc: DC(device: generic, state: concentrationOnly)).body, type: GasSensorDetail.self))
        var smoke = device
        smoke.model = "lumi.sensor_smoke_gas.demo"
        #expect(smoke.form == .smoke)
        #expect(contains(SensorDetail(dc: DC(device: smoke, state: state)).body, type: SmokeSensorDetail.self))
    }

    @Test func gasStatusAlarmMapping() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d39" })
        let options = ["预热", "监测正常", "自检", "传感器寿命到期", "设备故障", "天然气泄漏报警"].enumerated().map { ValueOption(value: $0.offset, description: $0.element) }
        let status = SpecProperty(siid: 2, iid: 3, type: "status", description: "", format: "uint8", access: ["read", "notify"], unit: nil, range: nil, options: options)
        func spec(service: String, properties: [SpecProperty]) -> DeviceSpec {
            DeviceSpec(type: "gas-sensor", description: "", services: [SpecService(iid: 2, type: service, description: "", properties: properties, actions: [])])
        }
        var state = DeviceState(values: [:], spec: spec(service: "gas-sensor", properties: [status]), legacy: false, source: "cloud")
        #expect(DC(device: device, state: state).gasAlarm == nil)
        for value in 0...5 {
            state.values[status.key] = .int(value)
            #expect(DC(device: device, state: state).gasAlarm == (value == 5))
            #expect(Recorder.metrics(device, state).first { $0.name == "gas" }?.value == (value == 5 ? 1 : 0))
            let fields = Mirror(reflecting: GasSensorDetail(dc: DC(device: device, state: state)).body).children
            let art = try #require(fields.first { $0.label == "art" }?.value as? () -> GasArt)
            #expect(art().alarm == (value == 5))
        }
        state.spec = spec(service: "unrelated-service", properties: [status])
        #expect(DC(device: device, state: state).gasAlarm == nil)
        let unknownStatus = SpecProperty(siid: 2, iid: 3, type: "status", description: "", format: "uint8", access: ["read"], unit: nil, range: nil, options: nil)
        state.spec = spec(service: "gas-sensor", properties: [unknownStatus])
        #expect(DC(device: device, state: state).gasAlarm == nil)
        let demoState = try #require(model.states[device.did])
        let leakage = try #require(DC(device: device, state: demoState).p("gas-leakage"))
        state.spec = spec(service: "gas-sensor", properties: [status, leakage])
        state.values[leakage.key] = .bool(false)
        #expect(DC(device: device, state: state).gasAlarm == false)
        state.values[leakage.key] = .null
        #expect(DC(device: device, state: state).gasAlarm == nil)
    }

    @Test func motionDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d26" })
        #expect(device.category == .sensor)
        #expect(device.form == .motion)
        #expect(device.homeId == "h2")
        #expect(device.roomName == L("客厅", "Living room"))
        #expect(device.isOnline)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let illumination = try #require(context.p("illumination"))
        #expect(!illumination.writable)
        #expect(illumination.format == "uint16")
        #expect(illumination.unit == "lux")
        #expect(context.num(illumination) == 320)
        let battery = try #require(context.p("battery-level"))
        #expect(!battery.writable)
        #expect(battery.unit == "percentage")
        #expect(context.num(battery) == 86)
        #expect(!Recorder.shared.series(device.did, "illumination").samples.isEmpty)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: SensorDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(SensorDetail(dc: context).body, type: MotionSensorDetail.self))
        #expect(contains(offArt(device, tint: device.category.color), type: MotionSensorArt.self))
    }

    @Test func cameraDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d10" })
        #expect(device.category == .camera)
        #expect(device.form == nil)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        #expect(context.bool(context.p("on", in: "camera-control")) == true)
        #expect(context.p("night-shot") != nil)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: CameraDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
    }

    @Test func doorbellDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d11" })
        #expect(device.category == .camera)
        #expect(device.form == .doorbell)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        #expect(context.num(context.p("battery-level")) == 64)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: CameraDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(offArt(device, tint: device.category.color), type: DoorbellArt.self))
    }

    @Test func printerDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d27" })
        #expect(device.category == .printer)
        #expect(device.homeId == "h2")
        #expect(device.roomName == L("书房", "Study"))
        #expect(device.isOnline)
        #expect(model.devices.first { $0.did == "d9" }?.isOnline == false)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let status = try #require(context.p("status", in: "printer"))
        #expect(!status.writable)
        #expect(status.options?.map(\.description) == ["Processing", "Idle", "Error"])
        let processing = try #require(status.options?.first { $0.description == "Processing" })
        #expect(context.num(status) == Double(processing.value))
        let pages = try #require(context.p("printed-page"))
        #expect(!pages.writable)
        #expect(context.num(pages) == 128)
        let sleep = try #require(context.p("auto-sleep-mode"))
        #expect(sleep.writable)
        #expect(sleep.format == "bool")
        #expect(context.bool(sleep) == true)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: PrinterDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(offArt(device, tint: device.category.color), type: PrinterArt.self))
    }

    @Test func speakerDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d23" })
        #expect(device.category == .speaker)
        #expect(device.homeId == "h2")
        #expect(device.roomName == L("客厅", "Living room"))
        #expect(device.isOnline)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let volume = try #require(context.p("volume", in: "speaker"))
        #expect(volume.writable)
        #expect(volume.format == "uint8")
        #expect(volume.range == [0, 100, 1])
        #expect(volume.unit == "percentage")
        #expect(context.num(volume) == 60)
        let mute = try #require(context.p("mute", in: "speaker"))
        #expect(mute.writable)
        #expect(mute.format == "bool")
        #expect(context.bool(mute) == false)
        let playing = try #require(context.p("playing-state"))
        #expect(!playing.writable)
        #expect(playing.options?.map(\.description) == ["Playing", "Idle"])
        let playingOption = try #require(playing.options?.first { $0.description == "Playing" })
        #expect(context.num(playing) == Double(playingOption.value))
        for name in ["previous", "play", "pause", "next"] {
            let action = try #require(context.a(name, in: "play-control"))
            #expect(action.siid == 2)
            #expect(action.inputs.isEmpty)
        }
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: SpeakerDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(offArt(device, tint: device.category.color), type: SpeakerArt.self))
    }

    @Test func cookerDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d24" })
        #expect(device.category == .kitchen)
        #expect(device.form == nil)
        #expect(device.icon == device.category.icon)
        #expect(device.homeId == "h2")
        #expect(device.roomName == L("厨房", "Kitchen"))
        #expect(device.isOnline)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let status = try #require(context.p("status"))
        #expect(!status.writable)
        #expect(status.options?.map(\.description) == ["Cooking", "Idle"])
        let cookingOption = try #require(status.options?.first { $0.description == "Cooking" })
        #expect(context.num(status) == Double(cookingOption.value))
        let mode = try #require(context.p("mode"))
        #expect(mode.writable)
        #expect(mode.options?.map(\.value) == [0, 1])
        #expect(context.num(mode) == 0)
        let left = try #require(context.p("left-time"))
        #expect(!left.writable)
        #expect(left.unit == "minutes")
        #expect(context.num(left) == 25)
        #expect(context.p("temperature")?.writable == false)
        for name in ["target-temperature", "heat-level", "alarm"] {
            #expect(context.p(name)?.writable == true)
        }
        #expect(context.num(context.p("temperature")) == 96)
        #expect(context.num(context.p("target-temperature")) == 100)
        #expect(context.num(context.p("heat-level")) == 2)
        #expect(context.bool(context.p("alarm")) == true)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: CookerDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(offArt(device, tint: device.category.color), type: CookerArt.self))
        #expect(!contains(offArt(device, tint: device.category.color), type: KettleArt.self))
    }

    @Test func kettleDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d28" })
        #expect(device.category == .kitchen)
        #expect(device.form == .kettle)
        #expect(device.icon == "mug")
        #expect(device.homeId == "h2")
        #expect(device.roomName == L("厨房", "Kitchen"))
        #expect(device.isOnline)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let status = try #require(context.p("status"))
        #expect(!status.writable)
        #expect(status.options?.map(\.description) == ["Boiling", "Idle"])
        let boilingOption = try #require(status.options?.first { $0.description == "Boiling" })
        #expect(context.num(status) == Double(boilingOption.value))
        let temperature = try #require(context.p("temperature"))
        #expect(!temperature.writable)
        #expect(temperature.unit == "celsius")
        #expect(context.num(temperature) == 96)
        let target = try #require(context.p("target-temperature"))
        #expect(target.writable)
        #expect(target.unit == "celsius")
        #expect(context.num(target) == 100)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: KettleDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: CookerDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(offArt(device, tint: device.category.color), type: KettleArt.self))
        #expect(!contains(offArt(device, tint: device.category.color), type: CookerArt.self))
    }

    @Test func dishwasherDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d29" })
        #expect(device.category == .kitchen)
        #expect(device.form == .dishwasher)
        #expect(device.icon == "dishwasher")
        #expect(device.homeId == "h2")
        #expect(device.roomName == L("厨房", "Kitchen"))
        #expect(device.isOnline)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let status = try #require(context.p("status"))
        #expect(!status.writable)
        #expect(status.options?.map(\.description) == ["Washing", "Idle"])
        let washingOption = try #require(status.options?.first { $0.description == "Washing" })
        #expect(context.num(status) == Double(washingOption.value))
        let left = try #require(context.p("left-time"))
        #expect(!left.writable)
        #expect(left.unit == "minutes")
        #expect(context.num(left) == 42)
        let mode = try #require(context.p("mode"))
        #expect(mode.writable)
        #expect(mode.options?.map(\.description) == ["Auto", "Intense", "Eco"])
        #expect(context.num(mode) == 0)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: DishwasherDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: CookerDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(offArt(device, tint: device.category.color), type: DishwasherArt.self))
        #expect(!contains(offArt(device, tint: device.category.color), type: CookerArt.self))
        #expect(!contains(offArt(device, tint: device.category.color), type: WasherArt.self))
    }

    @Test func juicerDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d30" })
        #expect(device.category == .kitchen)
        #expect(device.form == .juicer)
        #expect(device.icon == "cup.and.saucer")
        #expect(device.homeId == "h2")
        #expect(device.roomName == L("厨房", "Kitchen"))
        #expect(device.isOnline)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let status = try #require(context.p("status"))
        #expect(!status.writable)
        #expect(status.options?.map(\.description) == ["Blending", "Idle"])
        let blendingOption = try #require(status.options?.first { $0.description == "Blending" })
        #expect(context.num(status) == Double(blendingOption.value))
        let mode = try #require(context.p("mode"))
        #expect(mode.writable)
        #expect(mode.options?.map(\.description) == ["Juice", "Smoothie", "Pulse"])
        #expect(context.num(mode) == 0)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: JuicerDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: CookerDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(offArt(device, tint: device.category.color), type: JuicerArt.self))
        #expect(!contains(offArt(device, tint: device.category.color), type: CookerArt.self))
        #expect(!contains(offArt(device, tint: device.category.color), type: DishwasherArt.self))
    }

    @Test func ihcookerDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d31" })
        #expect(device.category == .kitchen)
        #expect(device.form == .ihcooker)
        #expect(device.icon == "cooktop")
        #expect(NSImage(systemSymbolName: device.icon, accessibilityDescription: nil) != nil)
        #expect(device.homeId == "h2")
        #expect(device.roomName == L("厨房", "Kitchen"))
        #expect(device.isOnline)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let status = try #require(context.p("status"))
        #expect(status.format == "uint8")
        #expect(!status.writable)
        #expect(status.options?.map(\.description) == ["Heating", "Idle"])
        let heatingOption = try #require(status.options?.first { $0.description == "Heating" })
        #expect(context.num(status) == Double(heatingOption.value))
        let heat = try #require(context.p("heat-level"))
        #expect(heat.readable)
        #expect(heat.writable)
        #expect(heat.range == [1, 9, 1])
        #expect(context.num(heat) == 5)
        let mode = try #require(context.p("mode"))
        #expect(mode.writable)
        #expect(mode.options?.map(\.description) == ["Manual", "Soup"])
        #expect(context.num(mode) == 0)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: IHCookerDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: CookerDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(offArt(device, tint: device.category.color), type: IHCookerArt.self))
        #expect(!contains(offArt(device, tint: device.category.color), type: CookerArt.self))
        let gallery = try #require(ArtGallery.rows.first { $0.0 == "ihcooker" })
        #expect(contains(gallery.1, type: IHCookerArt.self))
        #expect(contains(gallery.2, type: IHCookerArt.self))
    }

    @Test func ihcookerFormDoesNotMatchGenericCooker() throws {
        let model = AppModel(mock: true)
        var device = try #require(model.devices.first { $0.did == "d31" })
        for name in ["chunmi.ihcooker.v1", "CHUNMI.IHCOOKER.V2"] {
            device.model = name
            #expect(device.form == .ihcooker)
        }
        device.model = "chunmi.cooker.demo"
        #expect(device.form == nil)
        for (name, form) in [("dishwasher", DeviceForm.dishwasher), ("kettle", .kettle), ("juicer", .juicer)] {
            device.model = "xiaomi.\(name).ihcooker"
            #expect(device.form == form)
        }
    }

    @Test func mfcpDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d32" })
        #expect(device.category == .kitchen)
        #expect(device.form == .mfcp)
        #expect(device.icon == "frying.pan")
        #expect(device.homeId == "h2")
        #expect(device.roomName == L("厨房", "Kitchen"))
        #expect(device.isOnline)
        var state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let status = try #require(context.p("status"))
        #expect(!status.writable)
        #expect(status.options?.map(\.description) == ["Cooking", "Idle"])
        #expect(context.num(status) == 1)
        let mode = try #require(context.p("mode"))
        #expect(mode.writable)
        #expect(mode.options?.map(\.description) == ["Manual", "Soup"])
        #expect(context.num(mode) == 1)
        let left = try #require(context.p("left-time"))
        #expect(!left.writable && left.unit == "minutes")
        #expect(context.num(left) == 18)
        let heat = try #require(context.p("heat-level"))
        #expect(heat.writable && heat.range == [1, 5, 1])
        #expect(context.num(heat) == 3)
        #expect(context.num(context.p("temperature")) == 96)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            if let art = value as? () -> MfcpArt { return contains(art(), type: type) }
            return value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        for cooking in [true, false] {
            state.values["2.1"] = .int(cooking ? 1 : 2)
            state.values["2.3"] = .int(cooking ? 18 : 0)
            let detail = MfcpDetail(dc: DC(device: device, state: state))
            #expect(detail.cooking == cooking)
            let routed = TypeDetailView(device: device, state: state).body
            #expect(contains(routed, type: MfcpDetail.self))
            #expect(!contains(routed, type: CookerDetail.self))
            #expect(!contains(routed, type: DeviceCardView.self))
            #expect(contains(detail.body, type: MfcpArt.self))
            #expect(!contains(detail.body, type: CookerArt.self))
        }
        #expect(contains(offArt(device, tint: device.category.color), type: MfcpArt.self))
        #expect(!contains(offArt(device, tint: device.category.color), type: CookerArt.self))
        let gallery = try #require(ArtGallery.rows.first { $0.0 == "mfcp" })
        #expect(ArtGallery.rows.filter { $0.0 == "mfcp" }.count == 1)
        #expect(contains(gallery.1, type: MfcpArt.self))
        #expect(contains(gallery.2, type: MfcpArt.self))
        state.values.removeValue(forKey: "2.1")
        #expect(!MfcpDetail(dc: DC(device: device, state: state)).cooking)
        state.spec = nil
        #expect(!MfcpDetail(dc: DC(device: device, state: state)).cooking)
    }

    @Test func mfcpFormDoesNotStealOtherKitchenForms() throws {
        let model = AppModel(mock: true)
        var device = try #require(model.devices.first { $0.did == "d32" })
        for name in ["chunmi.mfcp.v1", "CHUNMI.MFCP.V2"] {
            device.model = name
            #expect(device.form == .mfcp)
        }
        device.model = "chunmi.cooker.demo"
        #expect(device.form == nil)
        let cooker = try #require(model.devices.first { $0.did == "d24" })
        let state = try #require(model.states[cooker.did])
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: cooker, state: state).body, type: CookerDetail.self))
        #expect(contains(offArt(cooker, tint: cooker.category.color), type: CookerArt.self))
        for (name, form) in [("dishwasher", DeviceForm.dishwasher), ("kettle", .kettle), ("juicer", .juicer), ("ihcooker", .ihcooker)] {
            for suffix in ["demo", "mfcp"] {
                device.model = "xiaomi.\(name).\(suffix)"
                #expect(device.form == form)
                #expect(device.form != .mfcp)
            }
        }
        device.model = "xiaomi.light.mfcp"
        #expect(device.category != .kitchen)
        #expect(device.form == nil)
    }

    @Test func purifierDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d25" })
        #expect(device.category == .purifier)
        #expect(device.homeId == "h2")
        #expect(device.roomName == L("厨房", "Kitchen"))
        #expect(device.isOnline)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let spec = try #require(state.spec)
        let properties = spec.controlServices.flatMap(\.properties)
        let tds = properties.filter { $0.name.contains("tds") }
        let filters = properties.filter { $0.name.contains("filter-life") }
        #expect(tds.count == 2)
        #expect(filters.count == 1)
        #expect(context.num(tds.first { $0.name.contains("out") }) == 8)
        #expect(context.num(tds.first { $0.name.contains("in") }) == 180)
        #expect(filters.compactMap { context.num($0) }.min() == 72)
        for property in properties {
            #expect(!property.writable)
            #expect(context.num(property) != nil)
        }
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: PurifierDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(offArt(device, tint: device.category.color), type: PurifierArt.self))
    }

    @Test func heaterDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d22" })
        #expect(device.category == .heater)
        #expect(device.homeId == "h2")
        #expect(device.roomName == L("客厅", "Living room"))
        #expect(model.powerInfo(device)?.isOn == true)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        for name in ["on", "target-temperature", "mode", "heat-level", "physical-controls-locked"] {
            #expect(context.p(name)?.writable == true)
        }
        let target = try #require(context.p("target-temperature"))
        #expect(target.range == [16, 30, 1])
        #expect(context.num(target) == 24)
        #expect(context.p("mode")?.options?.map(\.value) == [0, 1])
        #expect(context.p("heat-level")?.options?.map(\.value) == [1, 2, 3])
        #expect(context.num(context.p("heat-level")) == 2)
        #expect(context.bool(context.p("physical-controls-locked")) == false)
        for name in ["temperature", "relative-humidity"] {
            #expect(context.p(name)?.writable == false)
            #expect(context.num(context.p(name)) != nil)
        }
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: HeaterDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(offArt(device, tint: device.category.color), type: HeaterArt.self))
    }

    @Test func dehumidifierDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d7" })
        #expect(device.category == .dehumidifier)
        #expect(device.homeId == "h1")
        #expect(device.roomName == L("书房", "Study"))
        #expect(model.powerInfo(device)?.isOn == false)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        for name in ["on", "target-humidity", "mode", "fan-level", "physical-controls-locked"] {
            #expect(context.p(name)?.writable == true)
        }
        #expect(context.num(context.p("target-humidity")) == 50)
        #expect(context.p("mode")?.options?.map(\.value) == [0, 1])
        #expect(context.num(context.p("mode")) == 0)
        #expect(context.p("fan-level")?.options?.map(\.value) == [1, 2, 3])
        #expect(context.num(context.p("fan-level")) == 2)
        #expect(context.bool(context.p("physical-controls-locked")) == false)
        for name in ["temperature", "relative-humidity", "tank-full"] {
            #expect(context.p(name)?.writable == false)
        }
        #expect(context.num(context.p("temperature")) != nil)
        #expect(context.num(context.p("relative-humidity")) == 62)
        #expect(context.bool(context.p("tank-full")) == false)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: DehumidifierDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(offArt(device, tint: device.category.color), type: DehumidifierArt.self))
    }

    @Test func airPurifierDemoRoutingAndProps() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d21" })
        #expect(device.category == .airPurifier)
        #expect(device.homeId == "h2")
        #expect(device.roomName == L("客厅", "Living room"))
        #expect(model.powerInfo(device)?.isOn == true)
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        for name in ["on", "fan-level", "mode", "pm2.5-density", "filter-life-level", "relative-humidity"] {
            #expect(context.p(name) != nil)
        }
        let level = try #require(context.p("fan-level"))
        #expect(level.writable && level.options?.map(\.value) == [1, 2, 3])
        #expect(propFraction(level, context.num(level)) == 0.5)
        #expect(context.num(context.p("mode")) == 0)
        #expect(context.num(context.p("pm2.5-density")) == 12)
        #expect(context.p("pm2.5-density")?.writable == false)
        #expect(context.num(context.p("filter-life-level")) == 78)
        #expect(context.p("filter-life-level")?.writable == false)
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: AirPurifierDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(offArt(device, tint: device.category.color), type: AirPurifierArt.self))
    }

    @Test func curtainDemoPositionControlsAndRouting() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.did == "d20" })
        #expect(device.category == .curtain)
        #expect(device.roomName == L("客厅", "Living room"))
        #expect(model.powerInfo(device) == nil)
        var state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let target = try #require(primarySliderProp(context))
        #expect(target.name == "target-position" && target.writable)
        #expect(context.label(target) == L("目标位置", "Target position"))
        #expect(context.p("current-position")?.writable == false)
        for (command, value) in [(CurtainCommand.open, 0), (.pause, 1), (.close, 2)] {
            #expect(command.option(in: context.p("motor-control"))?.value == value)
        }
        for (percent, title) in [(100, L("全开", "Open")), (50, "50%"), (0, L("全关", "Closed"))] {
            state.values["2.1"] = .int(percent)
            let detail = CurtainDetail(dc: DC(device: device, state: state))
            #expect(detail.position == Double(percent) / 100)
            #expect(detail.title == title)
        }
        state.values.removeValue(forKey: "2.1")
        let unknown = CurtainDetail(dc: DC(device: device, state: state))
        #expect(unknown.position == nil)
        #expect(unknown.title == L("暂无读数", "No reading"))
        func contains<Value>(_ value: Any, type: Value.Type) -> Bool {
            value is Value || Mirror(reflecting: value).children.contains { contains($0.value, type: type) }
        }
        #expect(contains(TypeDetailView(device: device, state: state).body, type: CurtainDetail.self))
        #expect(!contains(TypeDetailView(device: device, state: state).body, type: DeviceCardView.self))
        #expect(contains(offArt(device, tint: device.category.color), type: CurtainArt.self))
        #expect(ArtGallery.rows.filter { $0.0 == "curtain-half" }.count == 1)
    }

    @Test func curtainMissingReadOnlyAndNonstandardMotorValues() {
        let device = Device(did: "demo", name: "Demo", model: "lumi.curtain.demo", isOnline: true)
        let empty = DC(device: device, state: DeviceState(values: [:], spec: nil, legacy: false, source: "cloud"))
        #expect(primarySliderProp(empty) == nil)
        #expect(CurtainDetail(dc: empty).position == nil)
        for access in [["read"], ["read", "write"]] {
            let spec = DeviceSpec.parse(["services": [["iid": 2, "type": "curtain", "properties": [
                ["iid": 1, "type": "target-position", "format": "uint8", "access": access, "value-range": [0, 10, 1]],
                ["iid": 2, "type": "motor-control", "format": "uint8", "access": access, "value-list": [
                    ["value": 7, "description": "Up"], ["value": 9, "description": "Stop"], ["value": 4, "description": "Down"]]]
            ]]]])
            let context = DC(device: device, state: DeviceState(values: ["2.1": .int(5)], spec: spec, legacy: false, source: "cloud"))
            #expect(CurtainDetail(dc: context).position == 0.5)
            #expect((primarySliderProp(context) != nil) == access.contains("write"))
            for (command, value) in [(CurtainCommand.open, 7), (.pause, 9), (.close, 4)] {
                #expect(command.option(in: context.p("motor-control"))?.value == (access.contains("write") ? value : nil))
                #expect(command.option(in: nil) == nil)
                #expect(command.option(in: context.p("target-position")) == nil)
            }
        }
    }

    @Test func curtainArtOpeningGeometry() {
        let closed = CurtainArt(position: 0, tint: .blue)
        let half = CurtainArt(position: 0.5, tint: .blue)
        let open = CurtainArt(position: 1, tint: .blue)
        #expect(closed.panelWidth == 80)
        #expect(half.panelWidth == (closed.panelWidth + open.panelWidth) / 2)
        #expect(open.panelWidth == 14)
        #expect(CurtainArt(position: -1, tint: .blue).opening == 0)
        #expect(CurtainArt(position: 2, tint: .blue).opening == 1)
    }

    @Test func applianceDemoPropertiesAndPower() throws {
        let model = AppModel(mock: true)
        for (category, names) in [(DeviceCategory.fridge, ["target-temperature", "mode", "temperature"]),
                                   (.washer, ["status", "remaining-time", "progress"]),
                                   (.waterHeater, ["target-temperature", "heating", "temperature"])] {
            let device = try #require(model.devices.first { $0.category == category })
            let state = try #require(model.states[device.did])
            let context = DC(device: device, state: state)
            for name in names { #expect(context.v(context.p(name)) != nil) }
            if category != .washer {
                let target = try #require(primarySliderProp(context))
                #expect(target.name == "target-temperature" && target.writable)
            }
            let power = try #require(model.powerInfo(device))
            #expect(power.isOn)
            model.states[device.did]?.values[power.key] = power.off
            #expect(model.powerInfo(device)?.isOn == false)
        }
    }

    @Test func applianceMissingAndReadOnlyProperties() {
        for model in ["viomi.fridge.demo", "xiaomi.washer.demo", "viomi.waterheater.demo"] {
            let device = Device(did: "demo", name: "Demo", model: model, isOnline: true)
            let empty = DC(device: device, state: DeviceState(values: [:], spec: nil, legacy: false, source: "cloud"))
            #expect(primarySliderProp(empty) == nil)
            #expect(empty.p("status") == nil)
            let spec = DeviceSpec.parse(["services": [["iid": 2, "type": "appliance", "properties": [
                ["iid": 1, "type": "target-temperature", "format": "uint8", "access": ["read"], "value-range": [2, 75, 1]]
            ]]]])
            let context = DC(device: device, state: DeviceState(values: ["2.1": .int(4)], spec: spec, legacy: false, source: "cloud"))
            #expect(context.num(context.p("target-temperature")) == 4)
            #expect(primarySliderProp(context) == nil)
        }
    }

    @Test func washerBusyAndWaterHeaterHeating() throws {
        let model = AppModel(mock: true)
        var washer = try #require(model.states["d18"])
        #expect(HouseDeviceState.busy(washer, otherwise: false))
        washer.values["2.2"] = .int(2)
        #expect(!HouseDeviceState.busy(washer, otherwise: false))
        washer.values.removeValue(forKey: "2.2")
        #expect(!HouseDeviceState.busy(washer, otherwise: false))
        let device = try #require(model.devices.first { $0.category == .waterHeater })
        var heater = try #require(model.states[device.did])
        #expect(WaterHeaterDetail(dc: DC(device: device, state: heater)).heating)
        heater.values["2.3"] = .bool(false)
        #expect(!WaterHeaterDetail(dc: DC(device: device, state: heater)).heating)
        heater.values.removeValue(forKey: "2.3")
        #expect(!WaterHeaterDetail(dc: DC(device: device, state: heater)).heating)
        heater.spec = nil
        #expect(!WaterHeaterDetail(dc: DC(device: device, state: heater)).heating)
    }

    @Test func humidifierUsesHumidityKeyboardSlider() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.category == .humidifier })
        let state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        let target = try #require(primarySliderProp(context))
        #expect(target.name == "target-humidity" && target.writable)
        #expect(context.num(target) == 55)
        #expect(context.num(context.p("relative-humidity")) == 42)
        for name in ["mode", "fan-level", "physical-controls-locked"] { #expect(context.p(name) != nil) }
    }

    @Test func readOnlyHumidityHasNoKeyboardSlider() {
        let spec = DeviceSpec.parse(["services": [["iid": 2, "type": "humidifier", "properties": [
            ["iid": 1, "type": "target-humidity", "format": "uint8", "access": ["read"], "value-range": [30, 80, 5]]
        ]]]])
        let context = DC(device: Device(did: "demo", name: "Demo", model: "deerma.humidifier.demo", isOnline: true),
                         state: DeviceState(values: ["2.1": .int(50)], spec: spec, legacy: false, source: "cloud"))
        #expect(primarySliderProp(context) == nil)
    }

    @Test func actionOnlyVacuumRetainsBatteryAndBusyState() throws {
        let model = AppModel(mock: true)
        let device = try #require(model.devices.first { $0.category == .vacuum })
        var state = try #require(model.states[device.did])
        let context = DC(device: device, state: state)
        #expect(model.powerInfo(device) == nil)
        #expect(context.num(context.p("battery-level")) == 76)
        #expect(HouseDeviceState.busy(state, otherwise: false))
        for command in VacuumCommand.allCases { #expect(command.action(in: context) != nil) }
        state.values["2.1"] = .int(2)
        #expect(!HouseDeviceState.busy(state, otherwise: false))
        state.values.removeValue(forKey: "2.1")
        #expect(!HouseDeviceState.busy(state, otherwise: false))
    }

    @Test func vacuumActionsRequireExposedZeroInputSpecActions() {
        let device = Device(did: "demo", name: "Demo", model: "roborock.vacuum.demo", isOnline: true)
        func context(_ actions: [[String: Any]]) -> DC {
            let spec = DeviceSpec.parse(["services": [["iid": 2, "type": "vacuum", "actions": actions]]])
            return DC(device: device, state: DeviceState(values: [:], spec: spec, legacy: false, source: "cloud"))
        }
        for command in VacuumCommand.allCases {
            #expect(command.action(in: context([])) == nil)
            for name in command.names {
                #expect(command.action(in: context([["iid": 4, "type": name, "in": [1]]])) == nil)
                #expect(command.action(in: context([["iid": 4, "type": name, "in": []]]))?.key == "2.4")
            }
        }
        let fallback = context([["iid": 1, "type": "start-charge", "in": [1]], ["iid": 2, "type": "dock", "in": []]])
        #expect(VacuumCommand.charge.action(in: fallback)?.key == "2.2")
    }
}
