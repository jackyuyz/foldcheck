# 首页左栏按需滚动验证

基于 main `6f31983`，在独立 worktree 中修改，没有创建功能分支。验证完成后将提交快进到 main。

## 行为

- 仅首页的双栏主面板启用按需滚动。把完整内容高度（包括内边距）与系统提供的可用视口高度比较（此高度已避开导航和底部安全区域，不重复扣减）。
- 放得下时禁用左栏滚动手势和无意义回弹；内容溢出时恢复滚动。
- 尺寸来自实际布局，不按设备型号或字号猜测，因此语言、字号、记录内容和可用空间变化都会重新判断。
- 双栏右侧、外屏/窄屏的整页滚动，以及检查流程和结果页保持原来的滚动方式。
- 右栏仍保留系统导航标题收起行为。回归测试区分了整个页面的导航区域高度变化与左栏自身的内容滚动。

## 验证环境

Xcode 27.1 RC build `27A9275`，安装路径为 `/Applications/Xcode.app`。每次构建与测试均指定 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`，项目由 XcodeGen 生成。

模拟器：iPhone Duo / iOS 27.1 展开内屏，以及 iPhone 17 / iOS 27.0 单栏。使用内存示例记录，不修改用户保存的检查数据。

普通字号并不保证所有语言、所有记录内容都放得下；例如英文完整示例的左栏含内边距为 598 pt、可用高度为 553 pt，此时应继续允许滚动。固定行为的回归使用确实放得下的空历史总览，避免仅以历史按钮可见作为判断依据。

## 结果

- XcodeGen 生成项目及最终 `build-for-testing` 成功。
- 最终 Duo iOS 27.1 回归：**5 项通过，1 项按布局不适用跳过，0 失败**。包含总览放得下时拖动不改变位置、右栏独立滚动、大字号左栏溢出后能够访问历史，以及原有仪表盘的有数据/空数据/辅助字号用例。
- iPhone 17 iOS 27.0 单栏回归此前完整运行：**4 项通过，2 项双栏专用用例跳过，0 失败**。此后修正仅涉及双栏高度判断和双栏用例的测试前提，单栏生产代码路径没有改变。
- 最终代码的单栏整组复测中，三个原有用例通过，之后卡在启动下一项 App 的阶段，已取消。独立模拟器重启后的单栏定向重试也停在测试启动阶段，未得到完成结果。**不把这两轮算作通过，也不声称最终整组或全量 App 回归已通过。**
- 普通 iPhone 单栏使用与外屏相同的 `layout.stacked` 分支；本轮没有完成实际 Duo 外屏的独立人工滚动走查。
- `git diff --check` 通过。未修改业务模型、检查数据、文案、图标或其他页面的滚动策略。

结果与日志（临时目录可能被系统清理）：

- 最终 Duo：`/tmp/foldcheck-home-scroll-duo-final.xcresult`、`/tmp/foldcheck-home-scroll-duo-final.log`。
- 完整通过的单栏回归：`/tmp/foldcheck-home-scroll-phone-2.xcresult`、`/tmp/foldcheck-home-scroll-phone-2.log`。
- 最终构建：`/tmp/foldcheck-home-scroll-final-build.log`。
- 取消的单栏复测：`/tmp/foldcheck-home-scroll-isolated-phone.log`、`/tmp/foldcheck-home-scroll-stacked-final.log`。

主目录存在其他并行开发的未提交文件。本次只提交布局、首页启用位置、仪表盘 UI 回归测试和本文；不暂存或推送这些其他工作。
