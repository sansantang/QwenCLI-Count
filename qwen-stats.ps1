#!/usr/bin/env powershell

<#
.SYNOPSIS
    Qwen Code 今日调用次数统计脚本
    
.DESCRIPTION
    统计 Qwen Code 在当日的调用次数，包括：
    - 总会话数
    - 总消息数
    - 各时段调用分布
    - 常用命令统计
    
.AUTHOR
    Generated for PUM Project
    
.LINK
    https://qwen.ai
#>

param(
    [switch]$All,  # 统计所有日期而非仅今日
    [switch]$Detailed,  # 显示详细信息
    [switch]$Json,  # 输出 JSON 格式
    [switch]$Tokens,  # 显示 Token 统计（估算）
    [string]$Month  # 统计指定月份（格式：yyyy-MM）
)

# 配置
$QwenTempPath = "$env:USERPROFILE\.qwen\tmp"
$QwenProjectChatsPath = "$env:USERPROFILE\.qwen\projects"

# 项目路径配置（可修改为实际项目路径）
# 设置为 $null 或空数组则统计所有项目，设置为具体路径数组则只统计指定项目
$ProjectCwd = @()  # 空数组 = 统计所有项目

$Today = Get-Date -Format "yyyy-MM-dd"
$TodayStart = Get-Date "$Today 00:00:00"
$TodayEnd = Get-Date "$Today 23:59:59"

# 月份统计配置
if ($Month) {
    if ($Month -match '^\d{4}-\d{2}$') {
        $MonthStart = Get-Date "$Month-01 00:00:00"
        $MonthEnd = $MonthStart.AddMonths(1).AddSeconds(-1)
        $PeriodName = "$Month"
    } else {
        Write-Error "月份格式错误，请使用 yyyy-MM 格式（例如：2026-03）"
        exit 1
    }
}

# 颜色定义
function Write-Header {
    param([string]$Text)
    Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
}

function Write-Stat {
    param(
        [string]$Label,
        [string]$Value,
        [string]$Color = "Green"
    )
    Write-Host "  $($Label.PadRight(25)) : " -NoNewline
    Write-Host $Value -ForegroundColor $Color
}

# 估算 Token 数（基于字符数的近似值）
# Qwen 模型：中文约 1.5 字符/token，英文约 4 字符/token
# 这里使用简化的估算：中文字符数 * 0.67 + 英文字符数 / 4
function Get-EstimatedTokens {
    param([string]$Text)
    
    if ([string]::IsNullOrEmpty($Text)) {
        return 0
    }
    
    # 中文字符（包括中文标点）
    $chineseChars = [System.Text.RegularExpressions.Regex]::Matches($Text, '[\u4e00-\u9fa5]').Count
    # 英文字符和数字
    $asciiChars = [System.Text.RegularExpressions.Regex]::Matches($Text, '[a-zA-Z0-9]').Count
    # 其他字符（空格、标点等）
    $otherChars = $Text.Length - $chineseChars - $asciiChars
    
    # 估算：中文约 1.5 字符/token，英文约 4 字符/token
    $chineseTokens = [int]($chineseChars / 1.5)
    $asciiTokens = [int]($asciiChars / 4)
    $otherTokens = [int]($otherChars / 8)
    
    return $chineseTokens + $asciiTokens + $otherTokens
}

# 统计 Token 使用情况
function Get-TokenStats {
    param([System.Collections.Generic.List[PSObject]]$Logs)
    
    if (-not $Logs -or $Logs.Count -eq 0) {
        return @{
            InputTokens = 0
            OutputTokens = 0
            CacheTokens = 0
            TotalTokens = 0
            ApiCalls = 0
        }
    }
    
    $inputTokens = 0
    $outputTokens = 0
    $cacheTokens = 0
    $apiCalls = 0

    foreach ($log in $Logs) {
        # 如果有实际 Token 数据，使用实际值
        if ($log.InputTokens -gt 0 -or $log.OutputTokens -gt 0) {
            $inputTokens += $log.InputTokens
            $outputTokens += $log.OutputTokens
            $cacheTokens += $log.CachedTokens
            # 每次 assistant 回复代表一次 API 调用
            if ($log.Type -eq "assistant") { $apiCalls++ }
        } else {
            # 否则使用估算
            $tokens = Get-EstimatedTokens -Text $log.Message
            if ($log.Type -eq "user") {
                $inputTokens += $tokens
            } else {
                $outputTokens += $tokens
            }
        }
    }
    
    return @{
        InputTokens = $inputTokens
        OutputTokens = $outputTokens
        CacheTokens = $cacheTokens
        TotalTokens = $inputTokens + $outputTokens + $cacheTokens
        ApiCalls = $apiCalls
    }
}

# 收集所有日志文件
function Get-AllLogs {
    $allLogs = New-Object System.Collections.Generic.List[PSObject]

    # 1. 读取项目 chats 目录的日志（.jsonl 格式）
    if (Test-Path $QwenProjectChatsPath) {
        $projectDirs = Get-ChildItem -Path $QwenProjectChatsPath -Directory -ErrorAction SilentlyContinue
        foreach ($projDir in $projectDirs) {
            $chatsPath = Join-Path $projDir.FullName "chats"
            if (Test-Path $chatsPath) {
                $jsonlFiles = Get-ChildItem -Path $chatsPath -Filter "*.jsonl" -ErrorAction SilentlyContinue
                foreach ($jsonlFile in $jsonlFiles) {
                    try {
                        $lines = Get-Content $jsonlFile.FullName -Encoding UTF8
                        foreach ($line in $lines) {
                            if ([string]::IsNullOrWhiteSpace($line)) { continue }
                            $log = $line | ConvertFrom-Json -ErrorAction Stop
                            
                            # 只统计配置的项目（cwd 匹配）
                            if ($ProjectCwd -and $ProjectCwd.Count -gt 0) {
                                if ($ProjectCwd -notcontains $log.cwd) { continue }
                            }
                            
                            # 提取 Token 数据：根据不同消息类型使用不同字段
                            $inputTokens = 0
                            $outputTokens = 0
                            $cachedTokens = 0

                            if ($log.type -eq "assistant" -and $log.usageMetadata) {
                                # assistant 消息使用 usageMetadata 字段（驼峰命名）
                                $inputTokens = if ($log.usageMetadata.promptTokenCount) { $log.usageMetadata.promptTokenCount } else { 0 }
                                $outputTokens = if ($log.usageMetadata.candidatesTokenCount) { $log.usageMetadata.candidatesTokenCount } else { 0 }
                                $cachedTokens = if ($log.usageMetadata.cachedContentTokenCount) { $log.usageMetadata.cachedContentTokenCount } else { 0 }
                            } elseif ($log.type -eq "system" -and $log.systemPayload -and $log.systemPayload.uiEvent) {
                                # system 消息使用 systemPayload.uiEvent 字段
                                $inputTokens = if ($log.systemPayload.uiEvent.input_token_count) { $log.systemPayload.uiEvent.input_token_count } else { 0 }
                                $outputTokens = if ($log.systemPayload.uiEvent.output_token_count) { $log.systemPayload.uiEvent.output_token_count } else { 0 }
                                $cachedTokens = if ($log.systemPayload.uiEvent.cached_content_token_count) { $log.systemPayload.uiEvent.cached_content_token_count } else { 0 }
                            }

                            $allLogs.Add([PSCustomObject]@{
                                SessionId = $log.sessionId
                                Timestamp = [DateTime]$log.timestamp
                                Type = $log.type
                                Message = if ($log.message) { $log.message.parts.text } else { "" }
                                SourceFile = $jsonlFile.Name
                                InputTokens = $inputTokens
                                OutputTokens = $outputTokens
                                CachedTokens = $cachedTokens
                            })
                        }
                    } catch {
                        Write-Warning "无法解析日志文件：$jsonlFile (错误：$($_.Exception.Message))"
                    }
                }
            }
        }
    }

    # 2. 读取 tmp 目录的日志（旧格式，备用）
    if (Test-Path $QwenTempPath) {
        $logDirs = Get-ChildItem -Path $QwenTempPath -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $logDirs) {
            $logFile = Join-Path $dir.FullName "logs.json"
            if (Test-Path $logFile) {
                try {
                    $content = $null
                    $encodings = @('UTF8', 'UTF8-BOM', 'Unicode', 'BigEndianUnicode', 'Default')
                    foreach ($encoding in $encodings) {
                        try {
                            $content = Get-Content $logFile -Raw -Encoding $encoding -ErrorAction Stop
                            break
                        } catch {
                            continue
                        }
                    }

                    if ($content) {
                        $logs = $content | ConvertFrom-Json -ErrorAction Stop
                        foreach ($log in $logs) {
                            $allLogs.Add([PSCustomObject]@{
                                SessionId = $log.sessionId
                                MessageId = $log.messageId
                                Type = $log.type
                                Message = $log.message
                                Timestamp = [DateTime]$log.timestamp
                                SourceFile = "tmp\$($dir.Name)"
                                InputTokens = 0
                                OutputTokens = 0
                                CachedTokens = 0
                            })
                        }
                    }
                } catch {
                    Write-Warning "无法解析日志文件：$logFile (错误：$($_.Exception.Message))"
                }
            }
        }
    }

    return $allLogs
}

# 过滤今日数据
function Filter-TodayLogs {
    param([System.Collections.Generic.List[PSObject]]$AllLogs)

    return $AllLogs | Where-Object {
        $_.Timestamp -ge $TodayStart -and $_.Timestamp -le $TodayEnd
    }
}

# 过滤月份数据
function Filter-MonthLogs {
    param([System.Collections.Generic.List[PSObject]]$AllLogs)

    return $AllLogs | Where-Object {
        $_.Timestamp -ge $MonthStart -and $_.Timestamp -le $MonthEnd
    }
}

# 统计调用次数
function Get-UsageStats {
    param(
        [System.Collections.Generic.List[PSObject]]$Logs,
        [string]$Period = "今日"
    )

    if (-not $Logs -or $Logs.Count -eq 0) {
        return @{
            Period = $Period
            TotalSessions = 0
            TotalMessages = 0
            UserMessages = 0
            AssistantMessages = 0
            SystemMessages = 0
            FirstUse = $null
            LastUse = $null
            HourlyDistribution = @{}
            TopCommands = @()
        }
    }

    $uniqueSessions = ($Logs | Select-Object -ExpandProperty SessionId -Unique).Count
    
    # 只统计 user 和 assistant 类型的消息
    $userMessages = ($Logs | Where-Object { $_.Type -eq "user" }).Count
    $assistantMessages = ($Logs | Where-Object { $_.Type -eq "assistant" }).Count
    $systemMessages = ($Logs | Where-Object { $_.Type -eq "system" -or $_.Type -eq "tool_result" }).Count
    $totalDisplayMessages = $userMessages + $assistantMessages

    # 时段分布（只统计用户消息）
    $hourlyDist = @{}
    for ($i = 0; $i -lt 24; $i++) {
        $hourlyDist[$i] = 0
    }
    $userLogs = $Logs | Where-Object { $_.Type -eq "user" }
    foreach ($log in $userLogs) {
        $hour = $log.Timestamp.Hour
        $hourlyDist[$hour]++
    }

    # 命令统计
    $commands = $userLogs | Where-Object { $_.Message -like "/*" } |
                Select-Object -ExpandProperty Message |
                Group-Object |
                Sort-Object Count -Descending |
                Select-Object -First 10

    return @{
        Period = $Period
        TotalSessions = $uniqueSessions
        TotalMessages = $totalDisplayMessages
        UserMessages = $userMessages
        AssistantMessages = $assistantMessages
        SystemMessages = $systemMessages
        FirstUse = ($Logs | Sort-Object Timestamp | Select-Object -First 1).Timestamp
        LastUse = ($Logs | Sort-Object Timestamp -Descending | Select-Object -First 1).Timestamp
        HourlyDistribution = $hourlyDist
        TopCommands = $commands
    }
}

# 输出统计报告
function Show-Report {
    param([hashtable]$Stats)

    Write-Header "📊 Qwen Code 调用统计 - $($Stats.Period)"

    Write-Stat "总会话数" "$($Stats.TotalSessions) 个" "Cyan"
    Write-Stat "总消息数" "$($Stats.TotalMessages) 条" "Cyan"
    Write-Stat "├─ 用户消息" "$($Stats.UserMessages) 条" "Green"
    Write-Stat "└─ 助手消息" "$($Stats.AssistantMessages) 条" "Green"

    if ($Stats.FirstUse) {
        Write-Stat "首次使用" "$($Stats.FirstUse.ToString("yyyy-MM-dd HH:mm:ss"))" "Yellow"
        Write-Stat "最后使用" "$($Stats.LastUse.ToString("yyyy-MM-dd HH:mm:ss"))" "Yellow"
    }

    # Token 统计
    if ($Tokens -or $Stats.TokenStats) {
        Write-Header "📊 Token 统计"
        Write-Stat "API 调用次数" "$($Stats.TokenStats.ApiCalls) 次" "Cyan"
        Write-Stat "当日输入总 Tokens" "$($Stats.TokenStats.InputTokens)" "Green"
        Write-Stat "当日输出总 Tokens" "$($Stats.TokenStats.OutputTokens)" "Green"
        Write-Stat "当日缓存 Tokens" "$($Stats.TokenStats.CacheTokens)" "Yellow"
        Write-Stat "当日总计 Tokens" "$($Stats.TokenStats.TotalTokens)" "Cyan"
        if ($Stats.TokenStats.ApiCalls -gt 0) {
            Write-Host "  ✓ 数据来源：实际 API 调用统计" -ForegroundColor Green
        } else {
            Write-Host "  ℹ️ 注：Token 数为估算值（基于字符数）`n" -ForegroundColor Gray
        }
    }

    # 时段分布图
    Write-Host "`n  📈 时段分布:" -ForegroundColor Cyan
    $maxCount = ($Stats.HourlyDistribution.Values | Measure-Object -Maximum).Maximum
    if ($maxCount -gt 0) {
        for ($i = 0; $i -lt 24; $i++) {
            $count = $Stats.HourlyDistribution[$i]
            $barLength = if ($maxCount -gt 50) { [int]($count / $maxCount * 40) } else { $count }
            $bar = "█" * $barLength
            $timeLabel = "$($i.ToString("00")):00"
            if ($count -gt 0) {
                Write-Host "    $timeLabel │ $bar ($count)" -ForegroundColor Gray
            }
        }
    }

    # 常用命令
    if ($Stats.TopCommands -and $Stats.TopCommands.Count -gt 0) {
        Write-Host "`n  🔧 常用命令 Top 10:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $Stats.TopCommands.Count; $i++) {
            $cmd = $Stats.TopCommands[$i]
            $rank = $i + 1
            $color = switch ($rank) {
                1 { "Yellow" }
                2 { "Gray" }
                3 { "Gray" }
                default { "Gray" }
            }
            Write-Host "    $rank. $($cmd.Name.PadRight(30)) - $($cmd.Count) 次" -ForegroundColor $color
        }
    }
}

# 主程序
Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     🚀 Qwen Code 调用次数统计工具                          ║" -ForegroundColor White
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$allLogs = Get-AllLogs

if ($All) {
    # 统计所有数据
    $stats = Get-UsageStats -Logs $allLogs -Period "全部"
    if ($Tokens) {
        $stats.TokenStats = Get-TokenStats -Logs $allLogs
    }
    Show-Report -Stats $stats
} elseif ($Month) {
    # 统计指定月份
    $monthLogs = Filter-MonthLogs -AllLogs $allLogs

    if ($monthLogs.Count -eq 0) {
        Write-Host "`n  ⚠️  $Month 暂无调用记录" -ForegroundColor Yellow
        Write-Host "  提示：使用 -All 参数查看所有历史统计`n" -ForegroundColor Gray
    } else {
        $stats = Get-UsageStats -Logs $monthLogs -Period "$Month"
        if ($Tokens) {
            $stats.TokenStats = Get-TokenStats -Logs $monthLogs
        }
        Show-Report -Stats $stats
    }
} else {
    # 仅统计今日
    $todayLogs = Filter-TodayLogs -AllLogs $allLogs

    if ($todayLogs.Count -eq 0) {
        Write-Host "`n  ⚠️  今日暂无调用记录" -ForegroundColor Yellow
        Write-Host "  提示：使用 -All 参数查看所有历史统计`n" -ForegroundColor Gray
        if ($Tokens) {
            Write-Host "  使用 -Tokens 参数查看 Token 统计`n" -ForegroundColor Gray
        }
    } else {
        $stats = Get-UsageStats -Logs $todayLogs -Period "今日 ($Today)"
        if ($Tokens) {
            $stats.TokenStats = Get-TokenStats -Logs $todayLogs
        }
        Show-Report -Stats $stats
    }
}

# 详细模式
if ($Detailed) {
    Write-Header "📋 详细调用记录"
    $filterLogs = if ($Month) { $monthLogs } elseif ($todayLogs) { $todayLogs } else { $allLogs }
    $filterLogs | Sort-Object Timestamp | ForEach-Object {
        $time = $_.Timestamp.ToString("HH:mm:ss")
        $type = if ($_.Type -eq "user") { "👤 用户" } else { "🤖 助手" }
        $msg = $_.Message
        if ($msg.Length -gt 60) {
            $msg = $msg.Substring(0, 60) + "..."
        }
        Write-Host "  [$time] $type : $msg" -ForegroundColor Gray
    }
}

# JSON 输出
if ($Json) {
    $filterLogs = if ($Month) { $monthLogs } elseif ($todayLogs) { $todayLogs } else { $allLogs }
    $period = if ($Month) { $Month } elseif ($todayLogs) { "今日" } else { "全部" }
    $output = @{
        Date = if ($Month) { $Month } else { $Today }
        Period = $period
        Stats = Get-UsageStats -Logs $filterLogs -Period $period
    }
    if ($Tokens) {
        $output.Stats.TokenStats = Get-TokenStats -Logs $filterLogs
    }
    $output | ConvertTo-Json -Depth 10
}

Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  脚本执行完成" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
