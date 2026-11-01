import SwiftUI
import Testing
import MijiaCore
@testable import MijiaBarApp

@Suite @MainActor struct TypeDetailTests {
    @Test func dedicatedDemoDevicesAndArt() throws {
        let model = AppModel(mock: true)
        for (category, row) in [(DeviceCategory.humidifier, "humidifier"), (.vacuum, "vacuum"),
                                (.fridge, "fridge"), (.washer, "washer"), (.waterHeater, "water-heater"), (.curtain, "curtain")] {
            let device = try #require(model.devices.first { $0.category == category })
            #expect(device.homeId == "h2")
            #expect(model.states[device.did]?.spec != nil)
            #expect(ArtGallery.rows.filter { $0.0 == row }.count == 1)
        }
        #expect(ArtGallery.rows.count == 25)
        #expect(ArtGallery.size.height == CGFloat(ArtGallery.rows.count * 138))
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
