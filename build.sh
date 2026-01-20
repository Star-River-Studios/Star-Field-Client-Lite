#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# ==================== 颜色定义 ====================
BLUE="\033[34m"
YELLOW="\033[33m"
RED="\033[31m"
GREEN="\033[32m"
CYAN="\033[36m"
RESET="\033[0m"

info() {
    echo -e "${BLUE}[INFO] $*${RESET}";
}
warn() {
    echo -e "${YELLOW}[WARN] $*${RESET}";
}
error() {
    echo -e "${RED}[ERROR] $*${RESET}";
}
done_msg() {
    echo -e "${GREEN}[DONE] $*${RESET}";
}
confirm() {
    local reply
    echo -en "${CYAN}[CONFIRM] $1：${RESET}" > /dev/tty
    read -r reply < /dev/tty || true
    echo "$reply"
}

# ==================== 基础路径 ====================
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$ROOT_DIR/tools"
BUILD_DIR="$ROOT_DIR/build"
PACK_DIR="$ROOT_DIR/modpack"

# ==================== OS 判断 ====================
case "$(uname -s)" in
  Linux*)  PACKWIZ="$TOOLS_DIR/packwiz-linux" ;;
  Darwin*) PACKWIZ="$TOOLS_DIR/packwiz-macos" ;;
  *) error "不支持的操作系统。"; exit 1 ;;
esac

[[ -x "$PACKWIZ" ]] || { error "Packwiz 不可执行: $PACKWIZ"; exit 1; }

# ==================== 工具函数 ====================
read_pack_name() {
    local pack_toml="$1"
    local name version
    name=$(grep '^name *= *"' "$pack_toml" | sed 's/.*"\(.*\)"/\1/')
    version=$(grep '^version *= *"' "$pack_toml" | sed 's/.*"\(.*\)"/\1/')
    printf "%s_%s" "$name" "$version"
}

prepare_build_dir() {
    local output_file="$1"
    if [[ ! -d "$BUILD_DIR" ]]; then
        info "检测到目标目录不存在，正在创建。"
        mkdir -p "$BUILD_DIR"
    else
        info "检测到目标目录已存在，开始构建。"
    fi

    if [[ -f "$BUILD_DIR/$output_file" ]]; then
        local choice
        choice=$(confirm "文件 $output_file 已存在，是否删除并继续？[y/N]")
        case "$choice" in
            [Yy]*) info "删除已存在文件"; rm -f "$BUILD_DIR/$output_file" ;;
            *) error "目录内有同名文件，构建已取消"; exit 1 ;;
        esac
    fi
}

build_modrinth_pack() {
    local pack_toml="$PACK_DIR/pack.toml"
    [[ -f "$pack_toml" ]] || { error "找不到 $pack_toml"; return 1; }
    local out=$(read_pack_name "$pack_toml")
    local output_file="$out.mrpack"
    prepare_build_dir "$output_file"
    info "开始构建 Modrinth 格式整合包..."
    "$PACKWIZ" --pack-file "$pack_toml" modrinth export --output "$BUILD_DIR/$output_file"
    done_msg "Modrinth 格式构建完成，文件名: $output_file"
}

build_curseforge_pack() {
    local pack_toml="$PACK_DIR/pack.toml"
    [[ -f "$pack_toml" ]] || { error "找不到 $pack_toml"; return 1; }
    local out=$(read_pack_name "$pack_toml")
    local output_file="$out.zip"
    prepare_build_dir "$output_file"
    info "开始构建 CurseForge 格式整合包..."
    "$PACKWIZ" --pack-file "$pack_toml" curseforge export --output "$BUILD_DIR/$output_file"
    done_msg "CurseForge 格式构建完成，文件名: $output_file"
}

refresh_pack() {
    info "开始刷新整合包元数据文件..."
    "$PACKWIZ" --pack-file "$PACK_DIR/pack.toml" refresh
    done_msg "整合包元数据文件已刷新"
}

clean_pack() {
    info "开始清理构建目录..."
    if [[ -d "$BUILD_DIR" && -n "$(ls -A "$BUILD_DIR" 2>/dev/null)" ]]; then
        rm -rf "$BUILD_DIR"/*
        done_msg "构建目录已清理完成"
    else
        info "构建目录不存在或已为空"
    fi
}

# ==================== 菜单 ====================
echo "====== Packwiz 构建脚本 ======"
echo "1. 刷新整合包元数据文件"
echo "2. 构建 Modrinth 格式 (.mrpack)"
echo "3. 构建 CurseForge 格式 (.zip)"
echo "4. 清理构建目录"
echo "5. 退出"

choice=$(confirm "请选择操作" || echo "")

# ==================== 行为映射 ====================
case "$choice" in
    1) refresh_pack ;;
    2) build_modrinth_pack ;;
    3) build_curseforge_pack ;;
    4) clean_pack ;;
    5) exit 0 ;;
    *) warn "无效选项。" ;;
esac