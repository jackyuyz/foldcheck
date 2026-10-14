# FoldCheck UI mockups

这些图按 iPhone Duo 的三种姿态画，不是普通竖屏 iPhone。

| 文件 | 姿态 | 画面 |
|---|---|---|
| `png/01-home-unfolded.png` | 完全展开，内屏 | 首页：左半开始体检，右半上次结果和快捷测试，中间是折痕 |
| `png/02-test-intro-unfolded.png` | 完全展开，内屏 | 测试介绍：左半说明，右半示意，按钮不压折痕 |
| `png/03-hinge-sweep-unfolded.png` | 完全展开，内屏 | 铰链扫掠全屏：左半角度，右半曲线 |
| `png/04-touch-grid-unfolded.png` | 完全展开，内屏 | 触控网格横跨两半内屏，折痕处是半尺寸加密格 |
| `png/05-summary-unfolded.png` | 完全展开，内屏 | 小结：左半总分，右半各项结果 |
| `png/06-report-unfolded.png` | 完全展开，内屏 | 报告：左半 PDF，右半二维码和签名 |
| `png/07-verify-unfolded.png` | 完全展开，内屏 | 核验：左半扫描/导入，右半签名结果 |
| `png/08-paywall-unfolded.png` | 完全展开，内屏 | 报告解锁：左半功能，右半价格 |
| `png/09-crease-partial.png` | 半折 | 两块屏被铰链分开；左半评分，右半折痕图案 |
| `png/10-cover-folded.png` | 合盖 | 外屏。右侧画出折叠铰链的厚度 |

源文件在 `render/`，用无头 Chrome 导出到 `png/`。完全展开时折痕宽度为零，图上只留一条浅折痕；半折才把两块屏分开。
