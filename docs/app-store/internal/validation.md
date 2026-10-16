# 内部校验记录 / Validation

核对日期：2026-10-16。校验只覆盖文案字段，不代表正式上架条件全部完成。

## 字段长度

从目标字段的 `text` 代码块提取正文，计入内部段落换行，不计代码围栏及围栏外说明。字符字段按 Unicode 码点计数；关键词及审核备注按 UTF-8 字节计数。最终仍需在 App Store Connect 中确认输入框校验。

| 文件 | 字段 | 实际长度 | 上限及单位 | 结果 |
|---|---|---:|---|---|
| public/en-US.md | `app-name` | 29 | 30 字符 | 通过 |
| public/en-US.md | `subtitle` | 28 | 30 字符 | 通过 |
| public/en-US.md | `promotional-text` | 150 | 170 字符 | 通过 |
| public/en-US.md | `description` | 2812 | 4000 字符 | 通过 |
| public/en-US.md | `keywords` | 92 | 100 UTF-8 字节 | 通过 |
| public/en-US.md | `whats-new-initial` | 277 | 4000 字符 | 通过 |
| public/en-US.md | `whats-new-update` | 518 | 4000 字符 | 通过 |
| public/zh-Hans.md | `app-name` | 15 | 30 字符 | 通过 |
| public/zh-Hans.md | `subtitle` | 13 | 30 字符 | 通过 |
| public/zh-Hans.md | `promotional-text` | 66 | 170 字符 | 通过 |
| public/zh-Hans.md | `description` | 1007 | 4000 字符 | 通过 |
| public/zh-Hans.md | `keywords` | 90 | 100 UTF-8 字节 | 通过 |
| public/zh-Hans.md | `whats-new-initial` | 102 | 4000 字符 | 通过 |
| public/zh-Hans.md | `whats-new-update` | 179 | 4000 字符 | 通过 |
| review/en-US.md | `review-notes` | 3543 | 4000 UTF-8 字节 | 通过 |
| review/zh-Hans.md | `review-notes` | 3187 | 4000 UTF-8 字节 | 通过 |

## 其他检查

- 两种公开文案均包含名称、副标题、简介、完整描述、关键词，以及条件互斥的首发/更新说明。
- 两种审核备注独立可用，不需要拼接；均低于 4000 UTF-8 字节。
- 关键词使用英文逗号分隔，没有重复项或空格项，各词条长度超过两个字符。
- 可复制正文中没有待确认标记、虚构固定金额或 example.com 占位链接；未知信息集中在内部 TODO，并在入口 README 标明文案仍为草案。
- 功能、付费边界、签名范围、语言与设备限制已逐项回查实现；依据见 feature-evidence.md。
- 本地 Markdown 链接目标已检查存在。
- App、图标、Packages、测试、工程及 StoreKit 配置未改动；本轮未运行构建或应用测试，因为新增内容仅为文档。
- `docs/app-store/` 未 stage、commit、push；未上传构建、编辑商店记录或提交审核。
- 原有设计记录推送提交为 `f240279`，保留当前 App 图标。该提交不包含本目录。
