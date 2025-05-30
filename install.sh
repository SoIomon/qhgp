#!/bin/bash

# qhgp 安装脚本
# 自动安装 qhgp 工具到用户的本地环境

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 获取用户主目录
HOME_DIR="$HOME"
LOCAL_BIN="$HOME_DIR/.local/bin"
CONFIG_DIR="$LOCAL_BIN/qhgp_config"

# 创建必要的目录
echo -e "${BLUE}📁 创建安装目录...${NC}"
mkdir -p "$LOCAL_BIN"
mkdir -p "$CONFIG_DIR"

# 复制主程序文件
echo -e "${BLUE}📋 复制程序文件...${NC}"
cp qhgp.sh "$LOCAL_BIN/qhgp"
chmod +x "$LOCAL_BIN/qhgp"

# 复制配置文件
if [ -f "qhgp_config/config.json" ]; then
    cp qhgp_config/config.json "$CONFIG_DIR/"
    echo -e "${GREEN}✅ 已复制现有配置文件${NC}"
else
    cp qhgp_config/config.example.json "$CONFIG_DIR/config.json"
    echo -e "${YELLOW}📝 已创建默认配置文件${NC}"
fi

# 检查必要的依赖
echo -e "${BLUE}🔍 检查系统依赖...${NC}"

# 检查git
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ 未找到 git，请先安装 Git${NC}"
    exit 1
fi

# 检查curl
if ! command -v curl &> /dev/null; then
    echo -e "${RED}❌ 未找到 curl，请先安装 curl${NC}"
    exit 1
fi

# 检查jq（可选）
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  未找到 jq，建议安装以获得更好的JSON解析体验${NC}"
    echo -e "${YELLOW}   macOS: brew install jq${NC}"
    echo -e "${YELLOW}   Ubuntu/Debian: sudo apt-get install jq${NC}"
    echo -e "${YELLOW}   CentOS/RHEL: sudo yum install jq${NC}"
else
    echo -e "${GREEN}✅ jq 已安装${NC}"
fi

echo -e "${GREEN}✅ 系统依赖检查完成${NC}"

echo -e "${BLUE}🚀 开始安装 qhgp 命令...${NC}"

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

echo -e "${GREEN}🎉 安装完成！${NC}"