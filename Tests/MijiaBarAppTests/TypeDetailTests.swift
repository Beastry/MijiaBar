import SwiftUI
import Testing
import MijiaCore
@testable import MijiaBarApp

@Suite @MainActor struct TypeDetailTests {
    @Test func dedicatedDemoDevicesAndArt() throws {
        let model = AppModel(mock: true)
        for (category, row) in [(DeviceCategory.humidifier, "humidifier"), (.vacuum, "vacuum"),
                                (.fridge, "fridge"), (.washer, "washer"), (.waterHeater, "water-heater"), (.curtain, "curtain"), (.airPurifier, "air-purifier"),
                                (.heater, "heater"), (.dehumidifier, "dehumidifier"),
                                (.speaker, "speaker"), (.kitchen, "cooker"), (.kitchen, "kettle"), (.kitchen, "dishwasher"), (.kitchen, "juicer"), (.kitchen, "ihcooker"), (.purifier, "purifier")] {
            let device = try #require(model.devices.first { $0.category == category })
            #expect(device.homeId == (category == .dehumidifier ? "h1" : "h2"))
            #expect(model.states[device.did]?.spec != nil)
            #expect(ArtGallery.rows.filter { $0.0 == row }.count == 1)
        }
        #expect(ArtGallery.rows.count == 31)
        #expect(ArtGallery.size.height == CGFloat(ArtGallery.rows.count * 138))
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
