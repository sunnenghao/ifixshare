# 哽哽密语记 · iOS 版（SwiftUI 源码工程）

与安卓版同 UI 风格、同功能，并通过 **坚果云 WebDAV** 与安卓版互相同步记录、语音和互动玩法。

## 没有 Mac 也能装：GitHub Actions 云编译（推荐）

利用 GitHub 免费提供的 macOS 云电脑自动编译出 IPA，全程只需 Windows：

1. 注册 GitHub 账号（github.com，免费），新建一个**私有**仓库（Private）。
2. 把本文件夹里的**全部内容**（含 `.github` 隐藏文件夹）上传到仓库
   （网页端 Add file → Upload files 拖进去，或用 Git 推送）。
3. 仓库页面 → 顶部 **Actions** 标签 → 左侧 **Build iOS IPA** →
   右侧 **Run workflow** → 点绿色 **Run workflow** 按钮。
4. 等 3~5 分钟，跑完后在该次运行页面底部 **Artifacts** 下载 `MiyuNote-ipa`
   （一个 zip，解压得到 `MiyuNote-unsigned.ipa`）。
5. Windows 上下载安装 **Sideloadly**（sideloadly.io，免费），
   iPhone 连电脑，把 ipa 拖进去，输入你自己的 Apple ID，点 Start——
   几分钟后 App 就装到手机上了（免费 Apple ID 签名 7 天有效，
   到期重拖一次即可；也可用 AltStore 自动续签）。

> 注意：GitHub Actions 的 macOS 云电脑对免费账户每月有免费额度
> （公共仓库无限，私有仓库每月 2000 分钟，够编译几百次）。

## 有 Mac 的话：手动编译

1. Mac 上安装 **Xcode**（App Store 免费），打开 Xcode →
   `File > New > Project…` → iOS / App，Product Name 填 `MiyuNote`，
   Interface 选 SwiftUI，创建。
2. 把 `Source/` 里所有 `.swift` 文件拖进项目，删除自动生成的
   `ContentView.swift` / `<项目名>App.swift`。
3. TARGETS → Info 添加 `Privacy - Microphone Usage Description` =
   `用于录制情侣语音日记`；用免费 Apple ID 选 Personal Team。
4. iPhone 连 Mac，点 ▶ 运行即可。
   （或者：`brew install xcodegen` 后在本文件夹执行 `xcodegen generate`
   生成现成工程，双击 `MiyuNote.xcodeproj` 直接跑。）

## 同步配置（两台手机）

1. 注册坚果云（jianguoyun.com），网页版右上角「账户信息 → 安全选项 →
   应用密码」生成一个应用密码。
2. 安卓和 iPhone 都在本 App「设置」里填同一个坚果云邮箱 + 同一个应用密码。
3. 记录、语音、互动画板、想你了震动，全部自动互通。

数据文件在坚果云的 `miyu/` 文件夹里：`notes.json`（索引）+ `audio/`（语音）
+ `signal/`（互动信号），可随时在网页版查看备份。

## 互动玩法协议（双端一致）

- 信号箱：`miyu/signal/sig_<时间戳>_<设备id>.json`
  - `{"type":"doodle","from":"...","img":"<base64 PNG>","created":...}`
  - `{"type":"miss","from":"...","created":...}`
- 接收端 App 处于前台时每 4 秒轮询一次，收到即弹窗/震动并删除信号文件；
  信号 6 小时过期自动清理。
- 限制：对方把 App 完全杀掉时收不到（无系统级推送），需打开 App 后补收。

## 文件结构

| 文件 | 作用 |
|---|---|
| `project.yml` | XcodeGen 工程定义（云编译用） |
| `.github/workflows/build.yml` | GitHub Actions 云编译工作流 |
| `Source/MiyuApp.swift` | 入口 + 全局配色 |
| `Source/Store.swift` | 数据模型与本地存储（JSON + 音频文件） |
| `Source/WebDav.swift` | WebDAV 客户端 + 双向同步引擎（与安卓版协议一致） |
| `Source/Signal.swift` | 实时互动信号（画板/想你了，与安卓版协议一致） |
| `Source/Llm.swift` | OpenAI 兼容接口（对话 / 语音转写） |
| `Source/MainView.swift` | 主页瀑布流 + 分类筛选 + 提问卡 + 互动按钮 |
| `Source/EditView.swift` | 写文字 / 录音 / 试听 |
| `Source/DoodleView.swift` | 互动画板（涂鸦发给对方） |
| `Source/SettingsView.swift` | AI 接口、昵称、坚果云同步配置 |
| `Source/SummaryView.swift` | AI 月度总结 + 历史 |

## 已知限制

- AI 接口与语音转写使用与安卓版相同的 OpenAI 兼容配置。
- 免费坚果云流量：上传 1GB/月、下载 3GB/月，纯文字+短语音足够用。
- iOS 语音转写走服务器接口，与安卓版一致；本地 Siri 听写不集成。
