#!/bin/bash
# ============================================================================
# Hermes Agent 一键启动脚本
# ============================================================================

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo -e "${CYAN}⚕ Hermes Agent 启动器${NC}"
echo ""

# ============================================================================
# 1. 检测 Python 3.11
# ============================================================================

check_python() {
    # 检查系统 Python 3.11
    if command -v python3.11 &> /dev/null; then
        PYTHON_CMD="python3.11"
        PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
        echo -e "${GREEN}✓${NC} 找到 $PYTHON_VERSION"
        return 0
    fi
    
    # 检查 uv 是否可用
    if command -v uv &> /dev/null; then
        echo -e "${CYAN}→${NC} 使用 uv 检查 Python 3.11..."
        if uv python find 3.11 &> /dev/null; then
            UV_PYTHON=$(uv python find 3.11)
            PYTHON_VERSION=$($UV_PYTHON --version 2>&1)
            echo -e "${GREEN}✓${NC} 找到 $PYTHON_VERSION (via uv)"
            PYTHON_CMD="$UV_PYTHON"
            return 0
        fi
    fi
    
    return 1
}

# ============================================================================
# 2. 检测/创建虚拟环境
# ============================================================================

check_venv() {
    if [ -d "venv" ]; then
        if [ -f "venv/bin/hermes" ]; then
            echo -e "${GREEN}✓${NC} 虚拟环境已就绪"
            return 0
        else
            echo -e "${YELLOW}⚠${NC} 虚拟环境存在但可能损坏，重新创建..."
            rm -rf venv
        fi
    fi
    return 1
}

# ============================================================================
# 3. 自动安装依赖
# ============================================================================

install_dependencies() {
    echo -e "${CYAN}→${NC} 安装依赖..."
    
    # 安装 Python 3.11 (如需要)
    if ! check_python; then
        echo -e "${CYAN}→${NC} 安装 Python 3.11..."
        if command -v uv &> /dev/null; then
            uv python install 3.11
        else
            echo -e "${RED}✗${NC} 请先安装 uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
            exit 1
        fi
    fi
    
    # 创建虚拟环境
    echo -e "${CYAN}→${NC} 创建虚拟环境..."
    if command -v uv &> /dev/null; then
        uv venv venv --python 3.11
    else
        python3.11 -m venv venv
    fi
    
    # 安装依赖
    echo -e "${CYAN}→${NC} 安装 hermes-agent 及其依赖..."
    source venv/bin/activate
    
    if [ -f "uv.lock" ]; then
        UV_PROJECT_ENVIRONMENT="$SCRIPT_DIR/venv" uv sync --all-extras --locked 2>/dev/null || \
            uv pip install -e ".[all]"
    else
        uv pip install -e ".[all]" || pip install -e ".[all]"
    fi
    
    # 创建 .env (如果不存在)
    if [ ! -f ".env" ] && [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓${NC} 创建 .env 配置文件"
        echo -e "${YELLOW}⚠${NC} 请编辑 .env 配置你的 API keys"
    fi
    
    echo -e "${GREEN}✓${NC} 依赖安装完成"
}

# ============================================================================
# 主流程
# ============================================================================

# 检查虚拟环境
if ! check_venv; then
    echo -e "${CYAN}→${NC} 初始化环境..."
    install_dependencies
fi

# 激活虚拟环境
source venv/bin/activate

# 检查 API Key (通过 hermes status)
if ! hermes status 2>/dev/null | grep -q "Anthropic.*✓"; then
    echo -e "${YELLOW}⚠${NC} 未检测到有效的 API Key"
    echo -e "${CYAN}→${NC} 运行 hermes setup 配置..."
    hermes setup
fi

# 启动 hermes
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  启动 Hermes Agent！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 传递所有参数给 hermes
hermes "$@"
