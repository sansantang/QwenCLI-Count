# Qwen Code 调用统计工具

## 📖 工具说明

统计 Qwen Code 在当日的调用次数，包括会话数、消息数、Token 数、时段分布和常用命令统计。

## 📍 日志来源

- **日志路径**: `C:\Users\Sinuxy\.qwen\projects\{项目名}\chats\*.jsonl`
- **统计范围**: 配置文件中指定的项目（默认：`D:\WorkSpace\pum`）
- **Token 统计**: 实际 API 调用数据（来自 Qwen Code 遥测）

## 🚀 使用方法

### 方式 1: 双击运行批处理文件
```
d:\项目\qwen-统计\qwen-stats.bat
```

### 方式 2: PowerShell 直接运行
```powershell
# 统计今日数据（含 Token 统计）
powershell -ExecutionPolicy Bypass -File "d:\项目\qwen-统计\qwen-stats.ps1" -Tokens

# 统计指定月份
powershell -ExecutionPolicy Bypass -File "d:\项目\qwen-统计\qwen-stats.ps1" -Month 2026-03 -Tokens

# 统计所有历史数据
powershell -ExecutionPolicy Bypass -File "d:\项目\qwen-统计\qwen-stats.ps1" -All -Tokens

# 显示详细调用记录
powershell -ExecutionPolicy Bypass -File "d:\项目\qwen-统计\qwen-stats.ps1" -Detailed

# 输出 JSON 格式
powershell -ExecutionPolicy Bypass -File "d:\项目\qwen-统计\qwen-stats.ps1" -Json
```

## ⚙️ 配置说明

编辑 `qwen-stats.ps1` 文件，修改第 35 行的项目路径：

```powershell
# 项目路径配置（可修改为实际项目路径）
$ProjectCwd = "D:\WorkSpace\pum"  # 修改为你的项目路径
```

将路径改为你实际使用的项目路径，例如：
- `D:\WorkSpace\pum`
- `C:\Projects\MyProject`
- 或其他 Qwen Code 项目目录

## 📊 输出内容

### 基础统计
- 总会话数
- 总消息数（用户消息 / 助手消息）
- 首次使用时间
- 最后使用时间

### Token 统计（-Tokens 参数）
- API 调用次数
- 当日输入总 Tokens
- 当日输出总 Tokens
- 当日缓存 Tokens
- 当日总计 Tokens
- ✓ 数据来源：实际 API 调用统计

### 时段分布图
显示 24 小时的调用分布，帮助了解使用习惯。

### 常用命令 Top 10
统计使用频率最高的 `/` 命令。

## 📋 参数说明

| 参数 | 说明 |
|------|------|
| (无参数) | 统计今日 (00:00-23:59) 的数据 |
| `-All` | 统计所有历史数据 |
| `-Month <yyyy-MM>` | 统计指定月份（例如：`-Month 2026-03`） |
| `-Detailed` | 显示详细的调用记录列表 |
| `-Json` | 以 JSON 格式输出统计数据 |
| `-Tokens` | 显示 Token 统计（实际 API 调用数据） |

## 📁 文件清单

```
d:\项目\qwen-统计\
├── qwen-stats.ps1      # PowerShell 统计脚本
├── qwen-stats.bat      # 批处理快捷方式
└── README.md           # 使用说明（本文件）
```

## 🔧 示例输出

### 今日统计
```
╔═══════════════════════════════════════════════════════════╗
║     🚀 Qwen Code 调用次数统计工具                          ║
╚═══════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════
  📊 Qwen Code 调用统计 - 今日 (2026-03-24)
═══════════════════════════════════════════════════════════

  总会话数                      : 5 个
  总消息数                      : 120 条
  ├─ 用户消息                   : 28 条
  └─ 助手消息                   : 92 条
  首次使用                      : 2026-03-24 16:51:07
  最后使用                      : 2026-03-24 22:39:40

═══════════════════════════════════════════════════════════
  📊 Token 统计
═══════════════════════════════════════════════════════════

  API 调用次数                  : 189 次
  当日输入总 Tokens              : 10796262
  当日输出总 Tokens              : 97500
  当日缓存 Tokens               : 2933222
  当日总计 Tokens               : 13826984
  ✓ 数据来源：实际 API 调用统计
  ...
```

### 月份统计
```
═══════════════════════════════════════════════════════════
  � Qwen Code 调用统计 - 2026-03
═══════════════════════════════════════════════════════════

  总会话数                      : 5 个
  总消息数                      : 120 条
  ├─ 用户消息                   : 28 条
  └─ 助手消息                   : 92 条
  首次使用                      : 2026-03-24 16:51:07
  最后使用                      : 2026-03-24 22:39:40

  📊 Token 统计
═══════════════════════════════════════════════════════════

  API 调用次数                  : 189 次
  当月输入总 Tokens              : 10796262
  当月输出总 Tokens              : 97500
  当月缓存 Tokens               : 2933222
  当月总计 Tokens               : 13826984
  ✓ 数据来源：实际 API 调用统计
```

## ⚠️ 注意事项

1. 脚本需要 PowerShell 执行权限（通过 `-ExecutionPolicy Bypass` 绕过）
2. 日志文件由 Qwen Code 自动生成，无需手动维护
3. 统计基于本地日志，不会影响 Qwen Code 正常运行
4. **统计范围说明**：
   - 脚本统计的是**配置文件中指定项目**的所有会话
   - 如果你打开了多个项目，只会统计 cwd 匹配的日志
   - 修改 `$ProjectCwd` 变量来切换统计的项目
5. **Token 统计说明**：
   - 数据来源：Qwen Code 实际 API 调用遥测数据
   - 包含输入 Tokens、输出 Tokens、缓存 Tokens
   - 实际消耗以 API 账单为准

## 📝 版本信息

- **版本**: 2.2
- **更新日期**: 2026-03-25
- **适用系统**: Windows 10/11
- **依赖**: PowerShell 5.1+
- **更新日志**:
  - v2.2: 项目迁移至 `d:\项目\qwen-统计\`
  - v2.2: 新增项目路径配置变量 `$ProjectCwd`
  - v2.1: 新增月份统计功能（`-Month <yyyy-MM>`）
  - v2.0: 改为读取项目 chats 目录的 .jsonl 日志
  - v2.0: 使用实际 API 调用 Token 数据而非估算
  - v2.0: 只统计当前项目 (cwd 匹配) 的日志
