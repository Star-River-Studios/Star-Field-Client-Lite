Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ==================== 颜色函数 ====================
function InfoMsg($msg) {
    Write-Host "[INFO] $msg" -ForegroundColor Blue
}
function WarnMsg($msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}
function ErrorMsg($msg) {
    Write-Host "[ERROR] $msg" -ForegroundColor Red
}
function DoneMsg($msg) {
    Write-Host "[DONE] $msg" -ForegroundColor Green
}
function ConfirmMsg($msg) {
    # 输出提示，不换行
    Write-Host -NoNewline "[CONFIRM] $msg" -ForegroundColor Cyan
    try {
        $input = [Console]::ReadLine()
    } catch [System.Management.Automation.PipelineStoppedException] {
        exit
    }
    return $input.Trim()  # 去掉前后空格
}


# ==================== 基础路径 ====================
$RootDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolsDir = Join-Path $RootDir 'tools'
$BuildDir = Join-Path $RootDir 'build'
$PackDir  = Join-Path $RootDir 'modpack'

# ==================== OS 判断 ====================
if ($IsWindows) { $Packwiz = Join-Path $ToolsDir 'packwiz-windows.exe' }
elseif ($IsLinux) { $Packwiz = Join-Path $ToolsDir 'packwiz-linux' }
elseif ($IsMacOS) { $Packwiz = Join-Path $ToolsDir 'packwiz-macos' }
else { throw (ErrorMsg '不支持的操作系统。') }

if (-not (Test-Path $Packwiz)) { throw (ErrorMsg "Packwiz 不存在。") }

# ==================== 工具函数 ====================
function Get-PackName {
    param([string]$PackToml)
    $Name    = (Select-String '^name\s*=' $PackToml).Line.Split('"')[1]
    $Version = (Select-String '^version\s*=' $PackToml).Line.Split('"')[1]
    "$Name`_$Version"
}

function Initialize-Build {
    param([string]$OutputFile)

    if (-not (Test-Path $BuildDir)) {
        InfoMsg "检测到目标目录不存在，正在创建。"
        New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
    }
    else {
        InfoMsg "检测到目标目录已存在，开始构建。"
    }

    $TargetFile = Join-Path $BuildDir $OutputFile
    if (Test-Path $TargetFile) {
        $choice = ConfirmMsg "文件 $OutputFile 已存在，是否删除并继续？[y/N]："
        if ($choice -match '^[Yy]$') {
            InfoMsg "删除已存在文件"
            Remove-Item $TargetFile -Force
        }
        else {
            ErrorMsg "目录内有同名文件，构建已取消。"
            exit 1
        }
    }
}

function Build-ModrinthPack {
    $PackToml = Join-Path $PackDir 'pack.toml'
    if (-not (Test-Path $PackToml)) { throw (ErrorMsg "找不到 $PackToml") }

    $OutName = Get-PackName $PackToml
    $OutputFile = "$OutName.mrpack"
    Initialize-Build $OutputFile

    InfoMsg "开始构建 Modrinth 格式整合包..."
    & $Packwiz --pack-file $PackToml modrinth export --output (Join-Path $BuildDir $OutputFile)
    DoneMsg "Modrinth 格式构建完成，文件名: $OutputFile"
}

function Build-CurseForgePack {
    $PackToml = Join-Path $PackDir 'pack.toml'
    if (-not (Test-Path $PackToml)) { throw (ErrorMsg "找不到 $PackToml") }

    $OutName = Get-PackName $PackToml
    $OutputFile = "$OutName.zip"
    Initialize-Build $OutputFile

    InfoMsg "开始构建 CurseForge 格式整合包..."
    & $Packwiz --pack-file $PackToml curseforge export --output (Join-Path $BuildDir $OutputFile)
    DoneMsg "CurseForge 格式构建完成，文件名: $OutputFile"
}

function Refresh-Pack {
    InfoMsg '开始刷新整合包元数据文件...'
    & $Packwiz --pack-file (Join-Path $PackDir 'pack.toml') refresh
    DoneMsg "整合包元数据文件已刷新"
}

function Clear-Pack {
    InfoMsg '开始清理构建目录...'
    if (Test-Path $BuildDir) {
        $items = Get-ChildItem $BuildDir -Recurse
        if ($items) {
            Remove-Item "$BuildDir\*" -Recurse -Force -ErrorAction SilentlyContinue
            DoneMsg "构建目录已清理完成"
        }
        else {
            InfoMsg "构建目录已为空"
        }
    }
    else {
        InfoMsg "构建目录不存在"
    }
}

# ==================== 菜单 ====================
Write-Host "====== Packwiz 构建脚本 ======"
Write-Host '1. 刷新整合包元数据文件'
Write-Host '2. 构建 Modrinth 格式 (.mrpack)'
Write-Host '3. 构建 CurseForge 格式 (.zip)'
Write-Host '4. 清理构建目录'
Write-Host '5. 退出'

# 先读取用户输入
$Choice = ConfirmMsg '请选择操作：'

# ==================== 行为映射 ====================
switch ($Choice) {
    '1' { Refresh-Pack }
    '2' { Build-ModrinthPack }
    '3' { Build-CurseForgePack }
    '4' { Clear-Pack }
    '5' { exit }
    default { WarnMsg '无效选项。' }
}