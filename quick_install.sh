#!/bin/bash

# 快速安装脚本 - 从GitHub直接安装qhgp

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 qhgp 快速安装脚本${NC}"
echo -e "${BLUE}📦 正在从 GitHub 下载并安装 qhgp...${NC}"

# 检查依赖
echo -e "${BLUE}🔍 检查系统依赖...${NC}"

# 检查git
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ 错误: 未找到 git 命令${NC}"
    echo -e "${YELLOW}请先安装 git${NC}"
    exit 1
fi

# 检查curl
if ! command -v curl &> /dev/null; then
    echo -e "${RED}❌ 错误: 未找到 curl 命令${NC}"
    echo -e "${YELLOW}请先安装 curl${NC}"
    exit 1
fi

# 检查jq（可选）
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  建议安装 jq 以获得更好的 JSON 处理体验${NC}"
fi

echo -e "${GREEN}✅ 系统依赖检查通过${NC}"

# 下载配置
GIT_REPO="https://github.com/SoIomon/qhgp.git"
TEMP_DIR="/tmp/qhgp_install_$$"
REPO_DIR="$TEMP_DIR/qhgp"

# 确定安装目录
if [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
    LOCAL_BIN="/usr/local/bin"
else
    INSTALL_DIR="$HOME/.local/bin"
    LOCAL_BIN="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
fi

echo -e "${BLUE}📁 安装目录: $INSTALL_DIR${NC}"

# 创建临时目录
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo -e "${BLUE}📥 克隆仓库 (main 分支)...${NC}"
# 使用SSH克隆指定分支
if ! git clone --depth 1 --branch main "$GIT_REPO" "$REPO_DIR"; then
    echo -e "${RED}❌ 克隆仓库失败${NC}"
    echo -e "${YELLOW}请确保已配置SSH密钥并有仓库访问权限${NC}"
    echo -e "${YELLOW}请确认 main 分支存在${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${BLUE}📥 复制 qhgp.sh...${NC}"
# 复制主脚本
if [ -f "$REPO_DIR/qhgp.sh" ]; then
    # 确保目标文件不存在重复内容
    cp "$REPO_DIR/qhgp.sh" "qhgp.sh"
else
    echo -e "${RED}❌ 未找到 qhgp.sh 文件${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${BLUE}📥 复制配置文件...${NC}"
# 创建配置目录
mkdir -p qhgp_config

# 复制配置文件
if [ -f "$REPO_DIR/qhgp_config/config.json" ]; then
    cp "$REPO_DIR/qhgp_config/config.json" "qhgp_config/config.json"
elif [ -f "$REPO_DIR/qhgp_config/config.example.json" ]; then
    echo -e "${YELLOW}❌ 未找到配置文件${NC}"
    echo -e "${BLUE}📝 未找到配置文件时，从config.example.json创建一个新的配置文件${NC}"
    cp "$REPO_DIR/qhgp_config/config.example.json" "qhgp_config/config.json"
else
    echo -e "${RED}❌ 未找到配置文件和示例配置文件${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${BLUE}🚀 开始安装 qhgp 命令...${NC}"

# 复制主脚本
cp "qhgp.sh" "$INSTALL_DIR/qhgp"
chmod +x "$INSTALL_DIR/qhgp"

# 创建配置目录
CONFIG_DIR="$HOME/.config/qhgp"
mkdir -p "$CONFIG_DIR"

# 复制配置文件
if [ ! -f "$CONFIG_DIR/config.json" ]; then
    cp "qhgp_config/config.json" "$CONFIG_DIR/config.json"
    echo -e "${GREEN}📝 已创建默认配置文件: $CONFIG_DIR/config.json${NC}"
else
    echo -e "${YELLOW}⚠️  配置文件已存在，跳过创建${NC}"
fi

# 确保 ~/.local/bin 在 PATH 中
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo -e "${YELLOW}⚠️  $LOCAL_BIN 不在 PATH 中${NC}"
    echo -e "${BLUE}🔧 正在配置 PATH 环境变量...${NC}"
    
    # 检测当前使用的shell
    if [[ "$SHELL" == *"zsh"* ]] || [[ -n "$ZSH_VERSION" ]]; then
        SHELL_RC="$HOME/.zshrc"
        SHELL_NAME="zsh"
    else
        SHELL_RC="$HOME/.bashrc"
        SHELL_NAME="bash"
    fi
    
    # 添加PATH配置到shell配置文件
    if ! grep -q "export PATH=.*\.local/bin" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Added by qhgp installer" >> "$SHELL_RC"
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_RC"
        echo -e "${GREEN}✅ 已添加 PATH 配置到 $SHELL_RC${NC}"
    else
        echo -e "${GREEN}✅ PATH 配置已存在${NC}"
    fi
    
    # 临时设置PATH以便立即测试
    export PATH="$LOCAL_BIN:$PATH"
    echo -e "${GREEN}✅ 已临时设置 PATH 环境变量${NC}"
else
    echo -e "${GREEN}✅ PATH 环境变量已正确配置${NC}"
fi

echo -e "${GREEN}✅ qhgp 命令安装成功！${NC}"
echo -e "${BLUE}📖 使用方法:${NC}"
echo -e "  ${GREEN}qhgp${NC}              # 交互式确认commit消息后只提交（默认行为）"

echo -e "  ${GREEN}qhgp -p${NC}           # 交互式确认commit消息后提交并推送"
echo -e "  ${GREEN}qhgp -yp${NC}          # 自动确认commit消息并推送（简写组合）"
echo -e ""
echo -e "${BLUE}💡 交互选项:${NC}"
echo -e "  ${GREEN}y${NC}                 # 确认使用生成的commit消息"
echo -e "  ${GREEN}n${NC}                 # 取消操作"
echo -e "  ${GREEN}e${NC}                 # 编辑commit消息后再确认"
echo -e ""
echo -e "  ${GREEN}qhgp --help${NC}       # 查看帮助信息"

# 测试安装
echo -e "${BLUE}🧪 测试安装...${NC}"
if command -v qhgp &> /dev/null; then
    echo -e "${GREEN}✅ qhgp 命令可用！${NC}"
    echo -e "${BLUE}版本信息:${NC}"
    qhgp --version
else
    echo -e "${YELLOW}⚠️  qhgp 命令暂时不可用，可能需要重新加载 shell 或检查 PATH 设置${NC}"
    echo -e "${YELLOW}请尝试运行: source ~/.bashrc 或重新打开终端${NC}"
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

echo -e "${GREEN}🎉 安装完成！${NC}"
echo -e "${YELLOW}📝 重要提示：${NC}"
echo -e "${YELLOW}   为了使 qhgp 命令立即可用，请运行以下命令之一：${NC}"
if [[ "$SHELL" == *"zsh"* ]] || [[ -n "$ZSH_VERSION" ]]; then
    echo -e "${GREEN}   source ~/.zshrc${NC}    # 重新加载 zsh 配置"
else
    echo -e "${GREEN}   source ~/.bashrc${NC}   # 重新加载 bash 配置"
fi
echo -e "${YELLOW}   或者重新打开终端窗口${NC}"