import os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import subprocess
import sys
import re
files={'en':'README.md','zh-Hans':'README.zh-CN.md','zh-Hant':'README.zh-TW.md'}
names={'en':'English','zh-Hans':'简体中文','zh-Hant':'繁體中文'}
R='neardws/MijiaBar'
badges=f'''<p align="center">
  <a href="https://github.com/{R}/releases/latest"><img src="https://img.shields.io/github/v/release/{R}?label=release&color=blue" alt="Release"></a>
  <a href="https://github.com/{R}/releases"><img src="https://img.shields.io/github/downloads/{R}/total?color=brightgreen" alt="Downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0--only-blue" alt="GPL-3.0-only"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-000000?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/Apple-notarized-success?logo=apple" alt="Notarized">
  <a href="https://github.com/{R}/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/{R}/build.yml?branch=main&label=build" alt="Build"></a>
  <a href="https://github.com/{R}/stargazers"><img src="https://img.shields.io/github/stars/{R}?style=social" alt="Stars"></a>
</p>'''
T={}
T['en']=dict(tag="Control your Xiaomi Mi Home devices from the macOS menu bar — and let AI agents do it too.",
note="Unofficial project, not affiliated with Xiaomi. It uses the same cloud API as the Mi Home app plus the LAN miIO protocol.",
toc=["Features","Screenshots","Install","Sign in","Agent / MCP","Build from source","Credits"],
dark="Dark mode",
feat=["**QR sign-in** — scan with the Mi Home app, no password. Mainland China server by default; Europe, US, Russia, Singapore and India are one click away. Credentials stay in the macOS Keychain.",
"**Automatic device list** — all homes, rooms and shared devices with online state. Offline and long-unused devices are hidden by default.",
"**House cutaway** — pixel-art isometric home at the top of the list: composed layouts draw room fixtures and appliances; tap them to toggle matched devices. Lighting stays local to each fixture, day/night art follows local time, and **Enlarge** opens a dedicated House window.",
"**House pets** — up to three customizable pixel cats and dogs; choose a palette or generate one from a photo analyzed only on your Mac.",
"**A page designed for each device type** — air conditioner, fan, light, plug, TV, speaker, camera, printer, kitchen appliances, water purifier, humidifier, vacuum, fridge, washer, water heater, curtain, air purifier, heater, dehumidifier and sensors, each with its own skeuomorphic illustration.",
"**Restrained motion** — fast, non-bouncy springs (< 300 ms); fan blades spin with speed, the TV screen glows, heaters radiate; the power button ripples; sliders track 1:1, snap and tick the trackpad. Reduce Motion is respected.",
"**Keyboard first** — `↑/↓` select, `↩` open, `Space` power, `←/→` adjust the main slider, `/` search, `Esc` back, `⌘Q` quit.",
"**Light & dark** — follows the system appearance using semantic colors.",
"**3 UI languages** — English, 简体中文, 繁體中文 (Taiwan wording); region-aware defaults.",
"**Agent interface** — `mijiabar` CLI and a stdio MCP server, read-only by default, with allowlist / full access and optional confirmation dialogs.",
"**Two control paths** — Xiaomi cloud MIoT RPC with LAN miIO fallback; AC partners (`lumi.acpartner.*`) use legacy LAN commands."],
inst=["Download `MijiaBar-x.y.z.dmg` from [Releases](https://github.com/neardws/MijiaBar/releases/latest), drag MijiaBar into Applications and open it. Release DMGs are Developer ID signed and notarized by Apple.",
"The first time you control a device, allow the **Local Network** permission (needed for LAN control)."],
inst_note="CI `*-unsigned.dmg` builds and your own local builds are ad-hoc signed; run `xattr -dr com.apple.quarantine /Applications/MijiaBar.app` before first launch.",
req="Requires macOS 14 or later, Apple silicon or Intel.",
login=["Click the 🏠 icon in the menu bar; a QR code appears.","Pick your server region (Mainland China by default).","In the **Mi Home** app tap **+ → Scan**, scan the code and confirm on the phone. Devices load automatically."],
agent_intro="Open **Settings → Agent interface**, click **Copy setup instructions** and paste the text into Claude Code, Codex, Cursor or any other agent. The agent finds the bundled CLI, registers the MCP server in its own config and verifies by listing your devices. The same text (with the path filled in) is printed by `mijiabar setup-prompt`:",
perm_h="Permissions", perm=[("Off","Agents can do nothing"),("Read (default)","List devices and read state only"),("Allowlist","Control only the devices you tick"),("Full","Control every device")],
confirm="With **Confirm every write** on, every change an agent makes shows a macOS dialog that you must approve.",
cli_h="CLI", perm_head=("Mode","What agents can do"),
tools="MCP tools: `list_devices`, `get_device_state`, `set_property`, `run_action`, plus `get_house*` / `set_house*` tools that only rearrange the house and never control a device ([docs/HOUSE.md](docs/HOUSE.md)).",
links=[("Website","https://www.neardws.com/MijiaBar/"),("Download","https://github.com/neardws/MijiaBar/releases/latest"),("Agent setup guide","docs/AGENT_SETUP.md"),("House config","docs/HOUSE.md")],
alt=dict(demo="Animated demo of the air conditioner card",list="Device list",ac_cool="Air conditioner card, cooling",fan="Fan card",list_dark="Device list in dark mode",ac_heat="Air conditioner card, heating, in dark mode",light_dark="Light card in dark mode",plug="Smart plug card",agent="Agent interface settings",login="QR sign-in screen",camera="Camera live view",doorbell="Doorbell live view in dark mode"),
build_note="Project layout: `Sources/MijiaCore` (cloud API, QR login, miIO, MIoT spec), `Sources/MijiaBarApp` (SwiftUI app), `Sources/mijiabar` (CLI + MCP). Translations live in `i18n/*.tsv`; run `scripts/gen-i18n.py` after editing. Contributor notes are in [AGENTS.md](AGENTS.md), the design guide in [docs/DESIGN.md](docs/DESIGN.md).",
credits="Motion design contributed by [@skyswordw](https://github.com/skyswordw) ([#1](https://github.com/neardws/MijiaBar/pull/1)). Protocol details from [python-miio](https://github.com/rytilahti/python-miio), [Xiaomi-cloud-tokens-extractor](https://github.com/PiotrMachowski/Xiaomi-cloud-tokens-extractor) and [ha_xiaomi_home](https://github.com/XiaoMi/ha_xiaomi_home). UI inspired by [@the_mcnaveen](https://x.com/the_mcnaveen)'s AC menu bar app.",
lic_h="License",
lic="""First-party MijiaBar source, scripts, tests, and documentation in this repository are licensed under the GNU General Public License, version 3 only ([GPL-3.0-only](LICENSE)). The grant names version 3 and stops there. `LICENSE` is the unmodified GNU GPL version 3. The same scope is written out in [LICENSES/GPL-3.0-only.txt](LICENSES/GPL-3.0-only.txt).

Copyright (c) 2026 neardws. Contributors keep the copyright in their own contributions. This repository does not assign those copyrights. Third-party material keeps its own license.

From this change forward, first-party material is offered under GPL-3.0-only. Copies already received under the MIT License keep the MIT rights granted with those copies, including copies from earlier commits, tags, and releases. Those earlier permissions remain in force. The original MIT copyright line and permission notice are preserved unmodified in [LICENSES/MIT-legacy.txt](LICENSES/MIT-legacy.txt).

The appendix in `LICENSE`, “How to Apply These Terms to Your New Programs,” contains a sample notice with the words “or any later version.” That sample is part of the unmodified GPL text. It is not the grant for this repository. The first-party grant is version 3 only.

Third-party components keep their own licenses. Bundled [go2rtc](https://github.com/AlexxIT/go2rtc) remains MIT: it is an official release, SHA-256 checked at build time, and it is not committed in this repository. [Sparkle](https://sparkle-project.org/) remains MIT and is downloaded at build time. Motion design by [@skyswordw](https://github.com/skyswordw) stays credited above.

MijiaBar is an unofficial project and is not affiliated with Xiaomi.""")
T['zh-Hans']=dict(tag="在 macOS 菜单栏控制米家设备，也可以交给 AI Agent 来控制。",
note="非小米官方项目。使用与米家 App 相同的云端接口和局域网 miIO 协议。",
toc=["功能","截图","安装","登录","Agent / MCP","从源码构建","致谢"],dark="深色模式",
feat=["**扫码登录**：用米家 App 扫一扫，无需密码。默认中国大陆服务器，也可切换欧洲、美国、俄罗斯、新加坡、印度。凭据只存在 macOS 钥匙串。",
"**自动获取设备**：拉取所有家庭、房间和共享设备及在线状态；离线和久未使用的设备默认隐藏。",
"**小屋剖面图**：设备列表顶部的像素风等距小屋，组合布局呈现房间里的灯具与家电，点击即可开关已匹配的设备。灯光逐点呈现，昼夜随本地时间切换；点 **放大** 可打开独立小屋窗口。",
"**小屋宠物**：最多三只可定制的像素猫狗，可手选配色，或从仅在本机分析的照片生成。",
"**每类设备单独设计**：空调、风扇、灯、插座、电视、音箱、摄像机、打印机、厨房电器、净水器、加湿器、扫地机、冰箱、洗衣机、热水器、窗帘、空气净化器、取暖器、除湿机、传感器，各有拟物插画。",
"**克制的动效**：无回弹的快速弹簧（< 300ms）；风扇按风速转动、电视屏幕发光、取暖器热浪；电源键涟漪；滑条 1:1 跟手、松手吸附、跨档触控板轻触。遵循「减弱动态效果」。",
"**键盘优先**：`↑/↓` 选择、`↩` 打开、`空格` 开关、`←/→` 调节主滑条、`/` 搜索、`Esc` 返回、`⌘Q` 退出。",
"**浅色 / 深色**：使用系统语义色，自动跟随外观。",
"**支持三种界面语言**：简体中文、繁體中文（台湾用语）、English，按地区推荐默认语言。",
"**Agent 接口**：`mijiabar` 命令行和 stdio MCP 服务器，默认只读，可选白名单 / 全部权限，写操作可弹窗确认。",
"**双通道控制**：小米云 MIoT RPC，失败时回落局域网 miIO；空调伴侣（`lumi.acpartner.*`）使用旧版局域网命令。"],
inst=["从 [Releases](https://github.com/neardws/MijiaBar/releases/latest) 下载 `MijiaBar-x.y.z.dmg`，把 MijiaBar 拖进「应用程序」后打开。正式版已用 Developer ID 签名并通过 Apple 公证。","第一次控制设备时，请允许「本地网络」权限（局域网直连需要）。"],
inst_note="CI 构建的 `*-unsigned.dmg` 和自己本地打包的版本为 ad-hoc 签名，首次打开前执行 `xattr -dr com.apple.quarantine /Applications/MijiaBar.app`。",
req="系统要求：macOS 14 及以上，支持 Apple 芯片和 Intel。",
login=["点菜单栏的 🏠 图标，会显示二维码。","选择服务器地区（默认中国大陆）。","打开手机 **米家 App** →「+」→「扫一扫」，扫码并在手机上确认，设备会自动加载。"],
agent_intro="打开 **设置 → Agent 接口**，点 **复制安装说明**，粘贴给 Claude Code、Codex、Cursor 等 Agent。Agent 会自己找到内置 CLI、在自己的配置里注册 MCP 服务器，并列出设备完成验证。`mijiabar setup-prompt` 会输出同样的内容（路径已填好）：",
perm_h="权限", perm=[("关闭","Agent 什么都不能做"),("只读（默认）","只能列设备、读状态"),("白名单","只能控制你勾选的设备"),("全部","可以控制所有设备")],
confirm="开启 **每次写操作弹窗确认** 后，Agent 的每次控制都会弹出系统对话框，需要你点「允许」。",
cli_h="命令行", perm_head=("模式","Agent 能做什么"),
tools="MCP 工具：`list_devices`、`get_device_state`、`set_property`、`run_action`，以及只调整小屋、不控制设备的 `get_house*` / `set_house*`（见 [docs/HOUSE.md](docs/HOUSE.md)）。",
links=[("官网","https://www.neardws.com/MijiaBar/zh-CN.html"),("下载","https://github.com/neardws/MijiaBar/releases/latest"),("Agent 安装指南","docs/AGENT_SETUP.zh-CN.md"),("小屋配置","docs/HOUSE.md")],
alt=dict(demo="演示动画：空调卡片",list="设备列表",ac_cool="空调卡片（制冷）",fan="风扇卡片",list_dark="深色模式下的设备列表",ac_heat="深色模式下的空调卡片（制热）",light_dark="深色模式下的灯卡片",plug="智能插座卡片",agent="Agent 接口设置",login="扫码登录界面",camera="摄像机直播",doorbell="深色模式下的门铃直播"),
build_note="项目结构：`Sources/MijiaCore`（云端 API、扫码登录、miIO、MIoT 规格）、`Sources/MijiaBarApp`（SwiftUI 应用）、`Sources/mijiabar`（CLI + MCP）。翻译在 `i18n/*.tsv`，修改后运行 `scripts/gen-i18n.py`。贡献须知见 [AGENTS.md](AGENTS.md)，设计规范见 [docs/DESIGN.md](docs/DESIGN.md)。",
credits="动效设计由 [@skyswordw](https://github.com/skyswordw) 贡献（[#1](https://github.com/neardws/MijiaBar/pull/1)）。协议细节参考 [python-miio](https://github.com/rytilahti/python-miio)、[Xiaomi-cloud-tokens-extractor](https://github.com/PiotrMachowski/Xiaomi-cloud-tokens-extractor) 和 [ha_xiaomi_home](https://github.com/XiaoMi/ha_xiaomi_home)。界面灵感来自 [@the_mcnaveen](https://x.com/the_mcnaveen) 的空调菜单栏应用。",
lic_h="许可证",
lic="""本仓库中的第一方源代码、脚本、测试和文档，以 GNU 通用公共许可证第 3 版且仅此版本授权（[GPL-3.0-only](LICENSE)）。授权写明第 3 版，到此为止。`LICENSE` 是未经修改的 GNU GPL 第 3 版全文。同一范围说明见 [LICENSES/GPL-3.0-only.txt](LICENSES/GPL-3.0-only.txt)。

Copyright (c) 2026 neardws。贡献者保留其各自贡献的著作权。本仓库不转移这些著作权。第三方材料仍使用其自身的许可证。

自本次变更起，第一方材料以 GPL-3.0-only 提供。此前已经按 MIT 许可证获得的副本，仍保留随该副本授予的 MIT 权利，包括更早的提交、标签和发布版本中的副本。这些既有许可继续有效。原来的 MIT 著作权声明和许可声明按原文保存在 [LICENSES/MIT-legacy.txt](LICENSES/MIT-legacy.txt)。

`LICENSE` 中的附录 “How to Apply These Terms to Your New Programs” 含有一份示例声明，其中写有 “or any later version”。该示例属于未经修改的 GPL 正文，不是本仓库的授权。第一方授权仅为第 3 版。

第三方组件仍使用各自的许可证。内置的 [go2rtc](https://github.com/AlexxIT/go2rtc) 仍为 MIT：它是官方发布包，构建时校验 SHA-256，且不进入本仓库。[Sparkle](https://sparkle-project.org/) 仍为 MIT，在构建时下载。动效设计仍致谢 [@skyswordw](https://github.com/skyswordw)，见上一节。

本项目非小米官方项目，与小米无关。""")
T['zh-Hant']=dict(tag="在 macOS 選單列控制米家裝置，也可以交給 AI Agent 來控制。",
note="非小米官方專案。使用與米家 App 相同的雲端介面和區域網路 miIO 協定。",
toc=["功能","截圖","安裝","登入","Agent / MCP","從原始碼建置","致謝"],dark="深色模式",
feat=["**掃碼登入**：用米家 App 掃一掃，免密碼。預設中國大陸伺服器，也可切換歐洲、美國、俄羅斯、新加坡、印度。憑證只存在 macOS 鑰匙圈。",
"**自動取得裝置**：載入所有家庭、房間和共享裝置及上線狀態；離線和久未使用的裝置預設隱藏。",
"**小屋剖面圖**：裝置清單頂部的像素風等距小屋，組合配置呈現房間裡的燈具與家電，點選即可開關已配對的裝置。燈光逐點呈現，日夜依本機時間切換；點 **放大** 可開啟獨立小屋視窗。",
"**小屋寵物**：最多三隻可自訂的像素貓狗，可手選配色，或從僅在本機分析的照片產生。",
"**每類裝置單獨設計**：冷氣、電風扇、燈、插座、電視、音箱、攝影機、印表機、廚房電器、淨水器、加濕器、掃地機、冰箱、洗衣機、熱水器、窗簾、空氣清淨機、電暖器、除濕機、感測器，各有擬物插圖。",
"**克制的動態效果**：無回彈的快速彈簧（< 300ms）；風扇依風速轉動、電視螢幕發光、電暖器熱浪；電源鍵漣漪；滑桿 1:1 跟手、放開吸附、跨檔觸控板輕觸。遵循「減少動態效果」。",
"**鍵盤優先**：`↑/↓` 選擇、`↩` 開啟、`空白鍵` 開關、`←/→` 調整主滑桿、`/` 搜尋、`Esc` 返回、`⌘Q` 結束。",
"**淺色 / 深色**：使用系統語意色彩，自動跟隨外觀。",
"**支援三種介面語言**：繁體中文（台灣用語）、简体中文、English，依地區建議預設語言。",
"**Agent 介面**：`mijiabar` 命令列和 stdio MCP 伺服器，預設唯讀，可選白名單 / 全部權限，寫入操作可跳出視窗確認。",
"**雙通道控制**：小米雲端 MIoT RPC，失敗時退回區域網路 miIO；空調夥伴（`lumi.acpartner.*`）使用舊版區域網路指令。"],
inst=["從 [Releases](https://github.com/neardws/MijiaBar/releases/latest) 下載 `MijiaBar-x.y.z.dmg`，把 MijiaBar 拖進「應用程式」後開啟。正式版已用 Developer ID 簽署並通過 Apple 公證。","第一次控制裝置時，請允許「本機網路」權限（區域網路直連需要）。"],
inst_note="CI 建置的 `*-unsigned.dmg` 和自行本機打包的版本為 ad-hoc 簽署，首次開啟前執行 `xattr -dr com.apple.quarantine /Applications/MijiaBar.app`。",
req="系統需求：macOS 14 以上，支援 Apple 晶片和 Intel。",
login=["點選單列的 🏠 圖示，會顯示 QR 碼。","選擇伺服器地區（預設為中國大陸）。","開啟手機 **米家 App** →「+」→「掃一掃」，掃描 QR 碼並在手機上確認，裝置會自動載入。"],
agent_intro="開啟 **設定 → Agent 介面**，點 **複製安裝說明**，貼給 Claude Code、Codex、Cursor 等 Agent。Agent 會自己找到內建 CLI、在自己的設定裡註冊 MCP 伺服器，並列出裝置完成驗證。`mijiabar setup-prompt` 會輸出同樣的內容（路徑已填好）：",
perm_h="權限", perm=[("關閉","Agent 什麼都不能做"),("唯讀（預設）","只能列出裝置、讀取狀態"),("白名單","只能控制你勾選的裝置"),("全部","可以控制所有裝置")],
confirm="開啟 **每次寫入操作跳出視窗確認** 後，Agent 的每次控制都會跳出系統對話框，需要你點「允許」。",
cli_h="命令列", perm_head=("模式","Agent 能做什麼"),
tools="MCP 工具：`list_devices`、`get_device_state`、`set_property`、`run_action`，以及只調整小屋、不控制裝置的 `get_house*` / `set_house*`（見 [docs/HOUSE.md](docs/HOUSE.md)）。",
links=[("官網","https://www.neardws.com/MijiaBar/"),("下載","https://github.com/neardws/MijiaBar/releases/latest"),("Agent 安裝指南","docs/AGENT_SETUP.zh-TW.md"),("小屋設定檔","docs/HOUSE.md")],
alt=dict(demo="示範動畫：冷氣卡片",list="裝置清單",ac_cool="冷氣卡片（冷房）",fan="電風扇卡片",list_dark="深色模式下的裝置清單",ac_heat="深色模式下的冷氣卡片（暖房）",light_dark="深色模式下的燈卡片",plug="智慧插座卡片",agent="Agent 介面設定",login="掃碼登入畫面",camera="攝影機直播",doorbell="深色模式下的門鈴直播"),
build_note="專案結構：`Sources/MijiaCore`（雲端 API、掃碼登入、miIO、MIoT 規格）、`Sources/MijiaBarApp`（SwiftUI 應用程式）、`Sources/mijiabar`（CLI + MCP）。翻譯在 `i18n/*.tsv`，修改後執行 `scripts/gen-i18n.py`。貢獻須知見 [AGENTS.md](AGENTS.md)，設計規範見 [docs/DESIGN.md](docs/DESIGN.md)。",
credits="動態效果設計由 [@skyswordw](https://github.com/skyswordw) 貢獻（[#1](https://github.com/neardws/MijiaBar/pull/1)）。協定細節參考 [python-miio](https://github.com/rytilahti/python-miio)、[Xiaomi-cloud-tokens-extractor](https://github.com/PiotrMachowski/Xiaomi-cloud-tokens-extractor) 和 [ha_xiaomi_home](https://github.com/XiaoMi/ha_xiaomi_home)。介面靈感來自 [@the_mcnaveen](https://x.com/the_mcnaveen) 的冷氣選單列 App。",
lic_h="授權條款",
lic="""本儲存庫中的第一方原始碼、指令碼、測試和文件，以 GNU 通用公眾授權條款第 3 版且僅此版本授權（[GPL-3.0-only](LICENSE)）。授權寫明第 3 版，到此為止。`LICENSE` 是未經修改的 GNU GPL 第 3 版全文。同一範圍說明見 [LICENSES/GPL-3.0-only.txt](LICENSES/GPL-3.0-only.txt)。

Copyright (c) 2026 neardws。貢獻者保留其各自貢獻的著作權。本儲存庫不移轉這些著作權。第三方材料仍使用其自身的授權條款。

自本次變更起，第一方材料以 GPL-3.0-only 提供。此前已依 MIT 授權取得的副本，仍保留隨該副本授予的 MIT 權利，包括較早的提交、標籤和發行版本中的副本。這些既有許可繼續有效。原來的 MIT 著作權聲明和許可聲明按原文保存在 [LICENSES/MIT-legacy.txt](LICENSES/MIT-legacy.txt)。

`LICENSE` 中的附錄 “How to Apply These Terms to Your New Programs” 含有一份範例聲明，其中寫有 “or any later version”。該範例屬於未經修改的 GPL 正文，不是本儲存庫的授權。第一方授權僅限第 3 版。

第三方元件仍使用各自的授權條款。內建的 [go2rtc](https://github.com/AlexxIT/go2rtc) 仍為 MIT：它是官方發佈套件，建置時驗證 SHA-256，且不進入本儲存庫。[Sparkle](https://sparkle-project.org/) 仍為 MIT，於建置時下載。動態效果設計仍致謝 [@skyswordw](https://github.com/skyswordw)，見上一節。

本專案非小米官方專案，與小米無關。""")
S="~/Library/Application Support/MijiaBar/"
X={
'en':("Auto-hidden devices",["A device is collapsed to the bottom of the list by default when either is true:","the cloud reports it offline (`isOnline = false`);","the cloud returns a last-online time (`last_online` / `lastOnline` / `last_online_time`) older than 30 days.","Click the eye button or **Show** to reveal them, or turn on **Settings → Devices → Show hidden devices**. Right-click a device to hide / unhide it manually — a manual choice always overrides the automatic rule."],
 "Where data is stored",["Sign-in session: macOS Keychain, service `com.neardws.MijiaBar` (account `session`). Signing out deletes it.",f"Device cache `devices.json`, preferences `prefs.json` (favorites, aliases, hidden flags, region), agent policy `agent.json`, and MIoT spec cache `spec-index.json` + `specs/<model>.json` — all in `{S}`, written with file mode 600.","House layout, pets and decor `house.json`: in iCloud Drive (`MijiaBar/house.json`) when iCloud Drive is on, so your Macs share it; otherwise in the same folder. `mijiabar house sync icloud|local|<folder>` moves it ([docs/HOUSE.md](docs/HOUSE.md)). It holds device and room ids, no credentials.",f"Sensor and power history: `history/<device>/<metric>.json` in `{S}` (raw samples for 31 days, daily summaries for 400), file mode 600, never uploaded.","UI language: `MijiaBarLang` in UserDefaults (shared by the app and CLI; `MIJIABAR_LANG` overrides it).","Network: MijiaBar only talks to Xiaomi's servers, your devices on the LAN, miot-spec.org (public spec downloads), and this project's site and GitHub Releases for update checks and downloads. No analytics."]),
'zh-Hans':("默认隐藏规则",["满足任一条件的设备默认收起到列表底部：","云端报告离线（`isOnline = false`）；","云端返回了最后在线时间（`last_online` / `lastOnline` / `last_online_time`），且超过 30 天。","点眼睛按钮或「显示」可以展开，也可以在 **设置 → 设备管理 → 显示已隐藏的设备** 中打开。右键设备可以手动「隐藏 / 取消隐藏」，手动设置始终优先于自动规则。"],
 "数据存放",["登录凭据：macOS 钥匙串，服务名 `com.neardws.MijiaBar`（账户 `session`），退出登录即删除。",f"设备缓存 `devices.json`、偏好 `prefs.json`（收藏、别名、隐藏、地区）、Agent 权限 `agent.json`、MIoT 规格缓存 `spec-index.json` 和 `specs/<型号>.json`，都在 `{S}`，文件权限 600。","小屋布局、宠物和装饰 `house.json`：开着 iCloud 云盘时放在 iCloud 云盘的 `MijiaBar/house.json`，多台 Mac 共用；否则放在同一目录。可用 `mijiabar house sync icloud|local|<文件夹>` 换位置（见 [docs/HOUSE.md](docs/HOUSE.md)）。里面只有设备和房间 id，没有任何凭据。",f"传感器和用电历史：`{S}` 下的 `history/<设备>/<指标>.json`（原始采样保留 31 天，按天汇总保留 400 天），文件权限 600，不上传。","界面语言：UserDefaults 的 `MijiaBarLang`（App 和 CLI 共用，环境变量 `MIJIABAR_LANG` 可覆盖）。","联网范围：只访问小米服务器、局域网内的设备、miot-spec.org（下载公开规格），以及用于检查和下载更新的本项目网站与 GitHub Releases。没有任何统计或埋点。"]),
'zh-Hant':("預設隱藏規則",["符合任一條件的裝置預設收合到清單底部：","雲端回報離線（`isOnline = false`）；","雲端回傳了最後上線時間（`last_online` / `lastOnline` / `last_online_time`），且超過 30 天。","按眼睛按鈕或「顯示」可以展開，也可以在 **設定 → 裝置管理 → 顯示已隱藏的裝置** 中開啟。在裝置上按右鍵可以手動「隱藏 / 取消隱藏」，手動設定一律優先於自動規則。"],
 "資料存放位置",["登入憑證：macOS 鑰匙圈，服務名稱 `com.neardws.MijiaBar`（帳號 `session`），登出即刪除。",f"裝置快取 `devices.json`、偏好設定 `prefs.json`（收藏、別名、隱藏、地區）、Agent 權限 `agent.json`、MIoT 規格快取 `spec-index.json` 和 `specs/<型號>.json`，都在 `{S}`，檔案權限 600。","小屋配置、寵物和裝飾 `house.json`：開啟 iCloud 雲碟時放在 iCloud 雲碟的 `MijiaBar/house.json`，多台 Mac 共用；否則放在同一個目錄。可用 `mijiabar house sync icloud|local|<檔案夾>` 更換位置（見 [docs/HOUSE.md](docs/HOUSE.md)）。裡面只有裝置和房間 id，沒有任何憑證。",f"感測器和用電歷史：`{S}` 下的 `history/<裝置>/<指標>.json`（原始取樣保留 31 天，每日彙總保留 400 天），檔案權限 600，不會上傳。","介面語言：UserDefaults 的 `MijiaBarLang`（App 與 CLI 共用，環境變數 `MIJIABAR_LANG` 可覆寫）。","連線範圍：只連線小米伺服器、區域網路內的裝置、miot-spec.org（下載公開規格），以及用來檢查和下載更新的本專案網站與 GitHub Releases。沒有任何統計或追蹤。"]),
}
LV={
'en':("Live video (cameras)",["Camera and doorbell detail cards have a **Watch live** button: the video plays inline in the card, and the enlarge button pops it out into a resizable window.","It uses the bundled [go2rtc](https://github.com/AlexxIT/go2rtc) (MIT, official release, SHA-256 verified at build time) as a helper that only runs while you watch: it listens on `127.0.0.1` on a random port, has RTSP / WebRTC / HomeKit (mDNS) disabled, exposes only the player and `/api/ws`, stops 20 s after the player closes and is killed when MijiaBar quits.","Sign-in reuses the QR session: MijiaBar keeps the `passToken` returned by the QR login in the Keychain and hands it to go2rtc via a temporary `go2rtc.yaml` (mode 600, deleted as soon as go2rtc has read it). Sessions from before v0.1.8 need one more QR scan (**Settings → Camera live view**).","Stream keys come from the Xiaomi cloud on every connect; video comes from the camera over Xiaomi's P2P. Nothing is recorded. Battery doorbells are woken up and drain faster, so keep it short. Agents / MCP have no camera access.","Each device's detail header (and, subtly, its list row) shows which path the last read/control used: **LAN** (direct miIO), **Cloud** (fallback) or **BLE gateway**.","Away-from-home detection: MijiaBar compares the Mac's network subnets with the devices' local IPs (re-checked on every network change, nothing stored). When you're away it skips LAN attempts and goes straight to the cloud, and camera cards say live view is only available at home."]),
'zh-Hans':("摄像头直播",["摄像机和门铃的详情卡片里有 **看直播** 按钮：画面直接在卡片里播放，点放大按钮可以弹出可调整大小的独立窗口。","播放由内置的 [go2rtc](https://github.com/AlexxIT/go2rtc)（MIT，官方发布包，构建时校验 SHA-256）完成，只在观看时运行：只监听 `127.0.0.1` 的随机端口，关闭 RTSP / WebRTC / HomeKit（mDNS），只开放播放器和 `/api/ws`；关闭画面 20 秒后停止，完全退出 MijiaBar 时结束。","登录复用扫码会话：MijiaBar 把扫码登录返回的 `passToken` 存在钥匙串，通过临时的 `go2rtc.yaml`（权限 600，go2rtc 读入后立即删除）交给 go2rtc。v0.1.8 之前的登录需要再扫一次码（**设置 → 摄像头直播**）。","每次连接都会向小米云获取密钥，视频经小米 P2P 从摄像头传来，不做任何录制。电池门铃会被唤醒、耗电更快，请尽量短时间观看。Agent / MCP 无法访问摄像头。","设备详情页标题（以及列表行上的小图标）显示最近一次读取/控制走的通道：**局域网**（miIO 直连）、**云端**（回退）或 **蓝牙网关**。","离家检测：比较 Mac 当前网卡子网和设备的局域网 IP（网络变化时重新判断，不保存任何网络信息）。不在家时跳过局域网直接走云端，摄像头卡片提示只能在家里看直播。"]),
'zh-Hant':("攝影機直播",["攝影機和門鈴的詳細卡片裡有 **看直播** 按鈕：畫面直接在卡片裡播放，按放大按鈕可以彈出可調整大小的獨立視窗。","播放由內建的 [go2rtc](https://github.com/AlexxIT/go2rtc)（MIT，官方發佈套件，建置時驗證 SHA-256）完成，只在觀看時執行：只監聽 `127.0.0.1` 的隨機埠，關閉 RTSP / WebRTC / HomeKit（mDNS），只開放播放器和 `/api/ws`；關閉畫面 20 秒後停止，完全結束 MijiaBar 時終止。","登入沿用掃碼工作階段：MijiaBar 把掃碼登入回傳的 `passToken` 存在鑰匙圈，透過暫時的 `go2rtc.yaml`（權限 600，go2rtc 讀入後立即刪除）交給 go2rtc。v0.1.8 之前的登入需要再掃一次碼（**設定 → 攝影機直播**）。","每次連線都會向小米雲端取得金鑰，影像經小米 P2P 從攝影機傳來，不做任何錄影。電池門鈴會被喚醒、耗電更快，請盡量短時間觀看。Agent / MCP 無法存取攝影機。","裝置詳細頁標題（以及清單列上的小圖示）顯示最近一次讀取/控制走的通道：**區域網路**（miIO 直連）、**雲端**（備援）或 **藍牙閘道**。","離家偵測：比較 Mac 目前網卡子網路和裝置的區域網路 IP（網路變化時重新判斷，不保存任何網路資訊）。不在家時略過區域網路直接走雲端，攝影機卡片提示只能在家裡看直播。"]),
}

# 「直播」一节里原来混着两条和摄像头无关的内容（通道标记、离家检测），单独成节
NETH={'en':'Cloud and LAN','zh-Hans':'云端与局域网','zh-Hant':'雲端與區域網路'}
DOCL={'en':('Full step-by-step instructions for agents:',''),'zh-Hans':('写给 Agent 的完整步骤：','.zh-CN'),'zh-Hant':('寫給 Agent 的完整步驟：','.zh-TW')}
IMG='https://files.neardws.com/mijiabar/readme'
def anchor(h): return re.sub(r'[^\w\- ]','',h.lower()).strip().replace(' ','-')
def shots(alt,*names,head=''):
    return f'<p align="center">{head}\n'+''.join(f'  <img src="{IMG}/{n}.webp" width="260" alt="{alt[k]}">\n' for n,k in names)+'</p>'
cli='''```bash
mijiabar list                     # list devices (--all, --refresh, --json)
mijiabar get <device>             # read state as JSON
mijiabar set <device> <prop> <value>
mijiabar action <device> <action> [JSON array]
mijiabar house <subcommand>       # house layout, pets and decor (see: mijiabar house help)
mijiabar mcp                      # stdio MCP server
mijiabar setup-prompt             # print the agent setup instructions
```'''
build='''```bash
git clone https://github.com/neardws/MijiaBar && cd MijiaBar
swift build
scripts/test.sh                                  # unit tests
.build/debug/MijiaBarApp --snapshot /tmp/shots   # every screen with demo data, light and dark
scripts/package.sh   # dist/MijiaBar.app + DMG (signs & notarizes when a Developer ID is available)
# env: VERSION, SIGN_IDENTITY ("-" = ad-hoc), NOTARY_PROFILE (default MijiaBar-notary)
```'''
for lang,fn in files.items():
    t=T[lang]; alt=t['alt']
    sw=' · '.join(f'<b>{names[l]}</b>' if l==lang else f'<a href="{f}">{names[l]}</a>' for l,f in files.items())
    links=' · '.join(f'<a href="{u}">{n}</a>' for n,u in t['links'])
    hh,hl,dh,dl=X[lang]
    lvh,lvl=LV[lang]
    neth=NETH[lang]
    toc=t['toc'][:4]+[hh,neth,lvh]+t['toc'][4:6]+[dh]+t['toc'][6:]+[t['lic_h']]
    if '--reuse-prompts' in sys.argv:
        prompt=re.search(r'```text\n(.*?)\n```',open(fn).read(),re.S).group(1)
    else:
        prompt=subprocess.run(['.build/debug/mijiabar','setup-prompt'],env={**os.environ,'MIJIABAR_LANG':lang},capture_output=True,text=True,check=True).stdout.rstrip()
    o=['<p align="center"><img src="docs/assets/icon.png" width="96" alt="MijiaBar"></p>',
       '<h1 align="center">MijiaBar</h1>',f'<p align="center">{t["tag"]}</p>','',f'<p align="center">{links}</p>','',badges,'',f'<p align="center">{sw}</p>','',
       f'> {t["note"]}','',
       f'<p align="center"><img src="{IMG}/demo.gif" width="300" alt="{alt["demo"]}"></p>','',
       ' · '.join(f'[{h}](#{anchor(h)})' for h in toc),'',
       f'## {toc[0]}','']+[f'- {x}' for x in t['feat']]+['',
       f'## {toc[1]}','',
       shots(alt,('list-light','list'),('ac-cool-light','ac_cool'),('fan-light','fan')),
       shots(alt,('list-dark','list_dark'),('ac-heat-dark','ac_heat'),('light-dark','light_dark'),head=f'<b>{t["dark"]}</b><br>'),
       shots(alt,('plug-light','plug'),('agent-light','agent'),('login-light','login')),'',
       f'## {toc[2]}','']+[f'{i+1}. {x}' for i,x in enumerate(t['inst'])]+['',f'> {t["inst_note"]}','',t['req'],'',
       f'## {toc[3]}','']+[f'{i+1}. {x}' for i,x in enumerate(t['login'])]+['',
       f'## {hh}','',hl[0],'']+[f'- {x}' for x in hl[1:3]]+['',hl[3],'',
       f'## {neth}','']+[f'- {x}' for x in lvl[4:]]+['',
       f'## {lvh}','']+[f'- {x}' for x in lvl[:4]]+['',shots(alt,('camera-live-light','camera'),('doorbell-live-dark','doorbell')),'',
       f'## {toc[7]}','',t['agent_intro'],'','```text',prompt,'```','',f'{DOCL[lang][0]} [docs/AGENT_SETUP{DOCL[lang][1]}.md](docs/AGENT_SETUP{DOCL[lang][1]}.md)','',
       f'### {t["perm_h"]}','',f'| {t["perm_head"][0]} | {t["perm_head"][1]} |','| --- | --- |']+[f'| {a} | {b} |' for a,b in t['perm']]+['',t['confirm'],'',
       f'### {t["cli_h"]}','',cli,'',t['tools'],'',
       f'## {toc[8]}','',build,'',t['build_note'],'',
       f'## {dh}','']+[f'- {x}' for x in dl]+['',
       f'## {toc[10]}','',t['credits'],'',
       f'## {toc[11]}','',t['lic'],'']
    open(fn,'w',encoding='utf-8').write('\n'.join(o))
print('ok')
