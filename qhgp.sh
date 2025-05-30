#!/bin/bash

# qhgp - Git自动提交工具 (Bash版本)
# 自动add、commit、push并生成commit消息
#
# Copyright (c) 2024 qhgp
# Licensed under the MIT License
# See LICENSE file for details

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

# 版本信息
VERSION="1.0.0"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/qhgp_config"
CONFIG_FILE="$CONFIG_DIR/config.json"
CONFIG_EXAMPLE="$CONFIG_DIR/config.example.json"

# 默认配置
DEFAULT_API_KEY="your-api-key-here"
DEFAULT_BASE_URL="https://api.example.com/v1"
DEFAULT_MODEL="your-model-name"
DEFAULT_TEMPERATURE="0.7"
DEFAULT_MAX_TOKENS="2000"

# 全局变量
AUTO_YES=false
PUSH=false
COMMAND=""
DEBUG=false

# 打印彩色文本
print_color() {
    local color=$1
    local text=$2
    echo -e "${color}${text}${NC}"
}

# 打印错误信息
print_error() {
    print_color "$RED" "❌ $1"
}

# 打印成功信息
print_success() {
    print_color "$GREEN" "✅ $1"
}

# 打印警告信息
print_warning() {
    print_color "$YELLOW" "⚠️  $1"
}

# 打印信息
print_info() {
    print_color "$BLUE" "ℹ️  $1"
}

# 初始化配置文件
init_config() {
    print_info "正在初始化配置..."
    
    # 确保配置目录存在
    mkdir -p "$CONFIG_DIR"
    
    # 如果存在示例配置文件，则复制它
    if [[ -f "$CONFIG_EXAMPLE" ]]; then
        print_info "从示例配置文件复制配置: $CONFIG_EXAMPLE"
        cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"
    else
        # 创建默认配置文件
        print_info "创建默认配置文件: $CONFIG_FILE"
        cat > "$CONFIG_FILE" << EOF
{
  "openai": {
    "api_key": "$DEFAULT_API_KEY",
    "base_url": "$DEFAULT_BASE_URL",
    "model": "$DEFAULT_MODEL",
    "temperature": $DEFAULT_TEMPERATURE,
    "max_tokens": $DEFAULT_MAX_TOKENS
  },
  "commit_message": {
    "language": "zh",
    "format": "conventional",
    "include_description": true,
    "max_title_length": 50
  },
  "git": {
    "auto_stage": true,
    "auto_push": true,
    "default_remote": "origin"
  }
}
EOF
    fi
    
    print_success "配置文件已初始化: $CONFIG_FILE"
    print_warning "请根据需要修改配置文件中的API密钥等信息"
}

# 加载配置
load_config() {
    # 检查配置文件是否存在
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warning "未找到配置文件: $CONFIG_FILE"
        init_config
    fi
    
    # 验证配置文件是否有效
    if [[ -f "$CONFIG_FILE" ]]; then
        if command -v jq >/dev/null 2>&1; then
            # 检查JSON格式是否有效
            if ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
                print_error "配置文件格式错误: $CONFIG_FILE"
                print_info "正在重新初始化配置文件..."
                init_config
            fi
        fi
    fi
    
    # 使用jq解析配置文件，如果没有jq则使用默认值
    if command -v jq >/dev/null 2>&1; then
        API_KEY=$(jq -r '.openai.api_key // "'$DEFAULT_API_KEY'"' "$CONFIG_FILE")
        BASE_URL=$(jq -r '.openai.base_url // "'$DEFAULT_BASE_URL'"' "$CONFIG_FILE")
        MODEL=$(jq -r '.openai.model // "'$DEFAULT_MODEL'"' "$CONFIG_FILE")
        TEMPERATURE=$(jq -r '.openai.temperature // '$DEFAULT_TEMPERATURE'' "$CONFIG_FILE")
        MAX_TOKENS=$(jq -r '.openai.max_tokens // '$DEFAULT_MAX_TOKENS'' "$CONFIG_FILE")
    else
        print_warning "未找到jq命令，使用默认配置"
        API_KEY="$DEFAULT_API_KEY"
        BASE_URL="$DEFAULT_BASE_URL"
        MODEL="$DEFAULT_MODEL"
        TEMPERATURE="$DEFAULT_TEMPERATURE"
        MAX_TOKENS="$DEFAULT_MAX_TOKENS"
    fi
}

# 调用AI API生成commit消息
chat_with_ai() {
    local message="$1"
    local url="${BASE_URL%/}/chat/completions"
    
    # 使用jq构建JSON payload以确保正确转义
    local json_payload
    if command -v jq >/dev/null 2>&1; then
        # 使用临时文件避免参数列表过长
        local temp_file=$(mktemp)
        echo "$message" > "$temp_file"
        json_payload=$(jq -n \
            --arg model "$MODEL" \
            --rawfile content "$temp_file" \
            --argjson temperature "$TEMPERATURE" \
            --argjson max_tokens "$MAX_TOKENS" \
            '{
                "model": $model,
                "messages": [{"role": "user", "content": $content}],
                "temperature": $temperature,
                "max_tokens": $max_tokens
            }')
        rm -f "$temp_file"
    else
        # 如果没有jq，使用简单的字符串替换（不够健壮）
        local escaped_message
        escaped_message=$(echo "$message" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')
        json_payload='{"model":"'$MODEL'","messages":[{"role":"user","content":"'$escaped_message'"}],"temperature":'$TEMPERATURE',"max_tokens":'$MAX_TOKENS'}'
    fi
    
    # Debug输出
    if [[ "$DEBUG" == "true" ]]; then
        print_color "$PURPLE" "🐛 [DEBUG] API调用信息:"
        echo "URL: $url"
        echo "Model: $MODEL"
        echo "Temperature: $TEMPERATURE"
        echo "Max Tokens: $MAX_TOKENS"
        echo "API Key: ${API_KEY:0:10}...(已隐藏)"
        echo "JSON Payload长度: ${#json_payload} 字符"
        print_color "$PURPLE" "🐛 [DEBUG] 执行的curl命令:"
        echo "curl -s -X POST '$url' \\"
        echo "  -H 'Content-Type: application/json' \\"
        echo "  -H 'Authorization: Bearer ${API_KEY:0:10}...' \\"
        echo "  -d '<JSON_PAYLOAD>'"
        echo
    fi
    
    local response
    response=$(curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "$json_payload" 2>/dev/null)
    
    local curl_exit_code=$?
    
    # Debug输出curl结果
    if [[ "$DEBUG" == "true" ]]; then
        print_color "$PURPLE" "🐛 [DEBUG] curl退出码: $curl_exit_code"
        print_color "$PURPLE" "🐛 [DEBUG] API响应长度: ${#response} 字符"
        if [[ ${#response} -gt 0 && ${#response} -lt 1000 ]]; then
            print_color "$PURPLE" "🐛 [DEBUG] API响应内容:"
            echo "$response"
        elif [[ ${#response} -ge 1000 ]]; then
            print_color "$PURPLE" "🐛 [DEBUG] API响应内容(前500字符):"
            echo "${response:0:500}..."
        fi
        echo
    fi
    
    if [[ $curl_exit_code -ne 0 ]]; then
        print_error "调用AI API失败 (curl退出码: $curl_exit_code)"
        return 1
    fi
    
    if [[ -z "$response" ]]; then
        print_error "AI API返回空响应"
        return 1
    fi
    
    # 检查API错误
    if echo "$response" | grep -q '"error"'; then
        local error_msg
        if command -v jq >/dev/null 2>&1; then
            error_msg=$(echo "$response" | jq -r '.error.message // "未知错误"' 2>/dev/null)
        else
            error_msg="API返回错误响应"
        fi
        print_error "AI API错误: $error_msg"
        return 1
    fi
    
    # 提取响应内容
    local content
    if command -v jq >/dev/null 2>&1; then
        content=$(echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    else
        # 简单的文本提取，不够健壮但可以工作
        content=$(echo "$response" | grep -o '"content":"[^"]*"' | sed 's/"content":"//' | sed 's/"$//' 2>/dev/null)
    fi
    
    if [[ -z "$content" || "$content" == "null" || "$content" == "empty" ]]; then
        print_error "AI API响应格式错误或内容为空"
        return 1
    fi
    
    echo "$content"
}

# 获取git diff
get_git_diff() {
    local staged=${1:-true}
    
    if [[ "$staged" == "true" ]]; then
        git diff --cached 2>/dev/null || return 1
    else
        git diff 2>/dev/null || return 1
    fi
}

# 获取git状态
get_git_status() {
    git status --porcelain 2>/dev/null || return 1
}

# 生成commit消息
generate_commit_message() {
    local auto_stage=${1:-false}
    
    # 如果需要自动暂存
    if [[ "$auto_stage" == "true" ]]; then
        git add . || {
            print_error "暂存文件失败"
            return 1
        }
    fi
    
    # 获取diff内容
    local diff_content
    diff_content=$(get_git_diff true)
    
    # 如果没有暂存的更改，尝试获取工作区更改
    if [[ -z "$diff_content" ]]; then
        diff_content=$(get_git_diff false)
    fi
    
    if [[ -z "$diff_content" ]]; then
        print_error "没有发现代码更改"
        return 1
    fi
    
    # 限制diff内容长度，避免参数列表过长
    local max_diff_length=10000
    if [[ ${#diff_content} -gt $max_diff_length ]]; then
        diff_content=$(echo "$diff_content" | head -c $max_diff_length)
        diff_content="$diff_content

[注意: diff内容过长，已截断显示前${max_diff_length}个字符]"
    fi
    
    # 构建提示词
    local prompt="请根据以下git diff内容，生成一个规范的中文commit消息。

要求：
1. 返回JSON格式，包含title、description、type三个字段
2. title: 简洁的中文提交标题（不超过50字符），如\"修复登录bug\"、\"新增用户管理功能\"
3. description: 详细的中文描述更改内容
4. type: 提交类型，严格按照以下规则选择：
   - feat: 新功能、新特性
   - fix: 修复bug、问题修复
   - docs: 文档相关
   - style: 代码格式、样式调整
   - refactor: 代码重构
   - test: 测试相关
   - chore: 构建工具、依赖管理等

Git Diff内容：
$diff_content

请仔细分析代码更改，如果是修复问题请使用fix类型，如果是新增功能请使用feat类型，并生成中文的commit消息："
    
    # 调用AI生成commit消息
    local ai_response
    ai_response=$(chat_with_ai "$prompt")
    
    if [[ -z "$ai_response" ]]; then
        print_error "AI生成commit消息失败"
        return 1
    fi
    
    echo "$ai_response"
}

# 解析commit消息JSON
parse_commit_message() {
    local json_response="$1"
    
    # Debug输出AI返回的原始内容
    if [[ "$DEBUG" == "true" ]]; then
        print_color "$PURPLE" "🐛 [DEBUG] AI返回的原始响应内容:"
        echo "$json_response"
        echo
    fi
    
    if command -v jq >/dev/null 2>&1; then
        COMMIT_TYPE=$(echo "$json_response" | jq -r '.type // "feat"' 2>/dev/null)
        COMMIT_TITLE=$(echo "$json_response" | jq -r '.title // "代码更新"' 2>/dev/null)
        COMMIT_DESCRIPTION=$(echo "$json_response" | jq -r '.description // ""' 2>/dev/null)
        
        # 检查jq解析是否成功
        if [[ $? -ne 0 ]]; then
            if [[ "$DEBUG" == "true" ]]; then
                print_color "$PURPLE" "🐛 [DEBUG] jq解析失败，尝试解析错误:"
                echo "$json_response" | jq . 2>&1 || true
                echo
            fi
            print_error "AI返回的JSON格式无效，无法解析commit消息"
            return 1
        fi
    else
        # 简单的文本解析
        COMMIT_TYPE=$(echo "$json_response" | grep -o '"type":"[^"]*"' | sed 's/"type":"//' | sed 's/"$//' || echo "feat")
        COMMIT_TITLE=$(echo "$json_response" | grep -o '"title":"[^"]*"' | sed 's/"title":"//' | sed 's/"$//' || echo "代码更新")
        COMMIT_DESCRIPTION=$(echo "$json_response" | grep -o '"description":"[^"]*"' | sed 's/"description":"//' | sed 's/"$//' || echo "")
    fi
}

# 编辑commit消息
edit_commit_message() {
    local temp_file
    temp_file=$(mktemp)
    
    # 创建临时文件内容
    cat > "$temp_file" << EOF
# 请编辑commit消息，以下是当前内容：
# 类型: $COMMIT_TYPE
# 标题: $COMMIT_TITLE
# 描述: $COMMIT_DESCRIPTION
#
# 格式说明：
# 第一行：类型(如feat, fix, docs等)
# 第二行：标题(简短描述)
# 第三行及以后：详细描述(可选)
# 以#开头的行将被忽略

$COMMIT_TYPE
$COMMIT_TITLE
$COMMIT_DESCRIPTION
EOF
    
    # 使用默认编辑器编辑文件
    local editor="${EDITOR:-vim}"
    if ! command -v "$editor" >/dev/null 2>&1; then
        # 尝试常见的编辑器
        for e in vim vi nano; do
            if command -v "$e" >/dev/null 2>&1; then
                editor="$e"
                break
            fi
        done
    fi
    
    print_info "使用 $editor 编辑commit消息..."
    if "$editor" "$temp_file"; then
        # 读取编辑后的内容
        local lines
        mapfile -t lines < <(grep -v '^#' "$temp_file" | grep -v '^$')
        
        if [[ ${#lines[@]} -ge 2 ]]; then
            COMMIT_TYPE="${lines[0]}"
            COMMIT_TITLE="${lines[1]}"
            # 合并剩余行作为描述
            if [[ ${#lines[@]} -gt 2 ]]; then
                COMMIT_DESCRIPTION=""
                for ((i=2; i<${#lines[@]}; i++)); do
                    if [[ -n "$COMMIT_DESCRIPTION" ]]; then
                        COMMIT_DESCRIPTION="$COMMIT_DESCRIPTION\n${lines[i]}"
                    else
                        COMMIT_DESCRIPTION="${lines[i]}"
                    fi
                done
            else
                COMMIT_DESCRIPTION=""
            fi
        else
            print_warning "编辑内容不完整，保持原有消息"
        fi
    else
        print_warning "编辑被取消，保持原有消息"
    fi
    
    # 清理临时文件
    rm -f "$temp_file"
}

# 执行commit
auto_commit() {
    local commit_type="$1"
    local commit_title="$2"
    local commit_description="$3"
    local push="$4"
    
    # 构建commit消息
    local commit_msg="$commit_type: $commit_title"
    if [[ -n "$commit_description" ]]; then
        commit_msg="$commit_msg

$commit_description"
    fi
    
    # 执行commit
    if git commit -m "$commit_msg" >/dev/null 2>&1; then
        print_success "提交成功: $commit_type: $commit_title"
    else
        print_error "提交失败"
        return 1
    fi
    
    # 如果需要推送
    if [[ "$push" == "true" ]]; then
        if git push >/dev/null 2>&1; then
            print_success "推送成功"
        else
            # 检查是否是没有上游分支的错误
            local current_branch
            current_branch=$(git branch --show-current 2>/dev/null)
            
            if [[ -n "$current_branch" ]]; then
                print_info "检测到分支 '$current_branch' 没有上游分支，正在自动设置..."
                
                if git push --set-upstream origin "$current_branch" >/dev/null 2>&1; then
                    print_success "推送成功并已设置上游分支"
                else
                    print_error "设置上游分支失败"
                    return 1
                fi
            else
                print_error "推送失败"
                return 1
            fi
        fi
    fi
    
    return 0
}

# 主要的qhgp命令逻辑
qhgp_command() {
    local auto_yes="$1"
    local push="$2"
    
    print_color "$CYAN" "🚀 开始执行 qhgp 命令..."
    
    # 检查是否在git仓库中
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "当前目录不是git仓库"
        return 1
    fi
    
    # 检查git状态
    local status
    status=$(get_git_status)
    
    if [[ -z "$status" ]]; then
        print_success "工作区干净，没有需要提交的更改"
        return 0
    fi
    
    print_color "$BLUE" "📋 发现以下更改:"
    echo "$status"
    
    # 自动暂存所有更改
    if git add . >/dev/null 2>&1; then
        print_success "已暂存所有更改"
    else
        print_error "暂存更改失败"
        return 1
    fi
    
    # 生成commit消息
    print_color "$YELLOW" "🤖 正在生成commit消息..."
    local ai_response
    ai_response=$(generate_commit_message false)
    
    if [[ -z "$ai_response" ]]; then
        print_error "生成commit消息失败"
        return 1
    fi
    
    # 解析commit消息
    parse_commit_message "$ai_response"
    
    # 显示生成的commit消息
    echo
    print_color "$GREEN" "📝 生成的commit消息:"
    echo "   类型: $COMMIT_TYPE"
    echo "   标题: $COMMIT_TITLE"
    echo "   描述: $COMMIT_DESCRIPTION"
    
    # 确认是否使用该消息
    if [[ "$auto_yes" != "true" ]]; then
        while true; do
            echo
            read -p "❓ 是否使用此commit消息？(y/n/e): " confirm
            case "$confirm" in
                [yY])
                    break
                    ;;
                [nN])
                    print_error "用户取消操作"
                    return 1
                    ;;
                [eE])
                    # 编辑commit消息
                    edit_commit_message
                    # 重新显示编辑后的消息
                    echo
                    print_color "$GREEN" "📝 编辑后的commit消息:"
                    echo "   类型: $COMMIT_TYPE"
                    echo "   标题: $COMMIT_TITLE"
                    echo "   描述: $COMMIT_DESCRIPTION"
                    ;;
                *)
                    print_warning "请输入 y(确认)、n(取消) 或 e(编辑)"
                    ;;
            esac
        done
    else
        echo
        print_success "自动确认使用生成的commit消息"
    fi
    
    # 执行commit和push
    if auto_commit "$COMMIT_TYPE" "$COMMIT_TITLE" "$COMMIT_DESCRIPTION" "$push"; then
        if [[ "$push" == "true" ]]; then
            print_color "$GREEN" "🎉 代码已成功提交并推送！"
        else
            print_color "$GREEN" "🎉 代码已成功提交！"
        fi
        return 0
    else
        print_error "提交失败"
        return 1
    fi
}

# 更新命令
update_command() {
    print_color "$CYAN" "🔄 正在检查qhgp工具更新..."
    
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # 清理函数
    cleanup() {
        rm -rf "$temp_dir"
    }
    trap cleanup EXIT
    
    print_color "$BLUE" "📥 正在下载最新版本..."
    
    # 克隆最新代码
    if git clone https://github.com/SoIomon/qhgp.git "$temp_dir/qhgp_latest" >/dev/null 2>&1; then
        cd "$temp_dir/qhgp_latest"
        
        # 切换到main分支
        if git checkout main >/dev/null 2>&1; then
            print_color "$BLUE" "🔧 正在安装更新..."
            
            # 运行安装脚本
            if ./install.sh >/dev/null 2>&1; then
                print_success "qhgp工具更新成功！"
                print_color "$GREEN" "🎉 请运行 'qhgp --version' 查看版本信息"
                return 0
            else
                print_error "更新失败：安装脚本执行失败"
                return 1
            fi
        else
            print_error "更新失败：切换分支失败"
            return 1
        fi
    else
        print_error "更新失败：下载失败"
        return 1
    fi
}

# 卸载命令
uninstall_command() {
    local auto_yes="$1"
    
    print_color "$YELLOW" "🗑️  正在准备卸载qhgp工具..."
    
    local home_dir="$HOME"
    local local_bin="$home_dir/.local/bin"
    local qhgp_path="$local_bin/qhgp"
    local config_dir="$local_bin/qhgp_config"
    
    local files_to_remove=()
    local dirs_to_remove=()
    
    # 检查要删除的文件和目录
    [[ -f "$qhgp_path" ]] && files_to_remove+=("$qhgp_path")
    [[ -d "$config_dir" ]] && dirs_to_remove+=("$config_dir")
    
    if [[ ${#files_to_remove[@]} -eq 0 && ${#dirs_to_remove[@]} -eq 0 ]]; then
        print_info "qhgp工具未安装或已被卸载"
        return 0
    fi
    
    # 显示将要删除的文件
    echo
    print_color "$BLUE" "📋 将要删除以下文件和目录:"
    for file_path in "${files_to_remove[@]}"; do
        echo "   📄 $file_path"
    done
    for dir_path in "${dirs_to_remove[@]}"; do
        echo "   📁 $dir_path/"
    done
    
    # 确认卸载
    if [[ "$auto_yes" != "true" ]]; then
        echo
        read -p "❓ 确认卸载qhgp工具？(y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            print_error "用户取消卸载"
            return 1
        fi
    else
        echo
        print_success "自动确认卸载"
    fi
    
    echo
    print_color "$YELLOW" "🗑️  正在卸载..."
    
    # 删除文件
    for file_path in "${files_to_remove[@]}"; do
        if rm -f "$file_path" 2>/dev/null; then
            print_success "已删除文件: $file_path"
        else
            print_warning "删除文件失败: $file_path"
        fi
    done
    
    # 删除目录
    for dir_path in "${dirs_to_remove[@]}"; do
        if rm -rf "$dir_path" 2>/dev/null; then
            print_success "已删除目录: $dir_path"
        else
            print_warning "删除目录失败: $dir_path"
        fi
    done
    
    # 检查PATH环境变量中的配置
    local shell_files=("$home_dir/.zshrc" "$home_dir/.bashrc" "$home_dir/.bash_profile")
    local path_cleaned=false
    
    for shell_file in "${shell_files[@]}"; do
        if [[ -f "$shell_file" ]] && grep -q ".local/bin" "$shell_file" && grep -q "PATH" "$shell_file"; then
            print_info "检测到 $shell_file 中包含 .local/bin 的PATH配置"
            print_info "由于可能影响其他工具，建议手动检查和清理"
            path_cleaned=true
        fi
    done
    
    # 验证卸载结果
    if ! command -v qhgp >/dev/null 2>&1; then
        echo
        print_color "$GREEN" "🎉 qhgp工具卸载成功！"
        if [[ "$path_cleaned" == "true" ]]; then
            print_color "$BLUE" "💡 提示: 请重新启动终端或运行 'source ~/.zshrc' (或相应的shell配置文件) 以更新环境变量"
        fi
        return 0
    else
        echo
        print_warning "qhgp命令仍然可用，可能存在其他安装位置"
        local qhgp_location
        qhgp_location=$(command -v qhgp)
        print_info "当前qhgp位置: $qhgp_location"
        return 1
    fi
}

# 显示帮助信息
show_help() {
    printf "${BLUE}qhgp${NC} - ${WHITE}Git自动提交工具，自动add、commit、push并生成commit消息${NC}\n\n"
    printf "${CYAN}用法:${NC}\n"
    printf "  qhgp [选项] [命令]\n\n"
    printf "${YELLOW}可选参数:${NC}\n"
    printf "  ${GREEN}-y, --yes${NC}      自动确认使用生成的commit消息，无需手动确认\n"
    printf "  ${GREEN}-p, --push${NC}     提交后推送到远程仓库\n"
    printf "  ${GREEN}--debug${NC}        启用调试模式，显示详细的API调用信息\n"
    printf "  ${GREEN}--version${NC}      显示版本信息\n"
    printf "  ${GREEN}-h, --help${NC}     显示此帮助信息\n\n"
    printf "${YELLOW}子命令:${NC}\n"
    printf "  ${GREEN}update${NC}         更新qhgp工具到最新版本\n"
    printf "  ${GREEN}uninstall${NC}      卸载qhgp工具\n\n"
    printf "${CYAN}示例:${NC}\n"
    printf "  ${GREEN}qhgp${NC}              # 交互式确认commit消息后只提交（默认行为）\n"
    printf "  ${GREEN}qhgp -y${NC}           # 自动确认commit消息并只提交\n"
    printf "  ${GREEN}qhgp -p${NC}           # 交互式确认commit消息后提交并推送\n"
    printf "  ${GREEN}qhgp -yp${NC}          # 自动确认commit消息并推送（简写组合）\n"
    printf "  ${GREEN}qhgp --debug${NC}      # 启用调试模式，查看详细的API调用信息\n\n"

    printf "  ${GREEN}qhgp update${NC}       # 更新qhgp工具到最新版本\n"
    printf "  ${GREEN}qhgp uninstall${NC}    # 卸载qhgp工具\n"
    printf "  ${GREEN}qhgp uninstall -y${NC} # 自动确认卸载\n\n"
    printf "${CYAN}配置文件:${NC}\n"
    printf "  qhgp 支持通过配置文件自定义模型和行为设置\n"
    printf "  ${YELLOW}配置文件位置:${NC} $CONFIG_FILE\n\n"
    printf "  ${YELLOW}主要配置项:${NC}\n"
    printf "  ${PURPLE}•${NC} ${WHITE}openai:${NC} API密钥、基础URL、模型名称等\n"
    printf "  ${PURPLE}•${NC} ${WHITE}commit_message:${NC} 语言、格式、描述等\n"
    printf "  ${PURPLE}•${NC} ${WHITE}git:${NC} 自动暂存、自动推送、默认远程仓库等\n\n"
    printf "  ${YELLOW}💡 提示:${NC} 首次运行时会自动创建默认配置文件\n"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                AUTO_YES=true
                shift
                ;;
            -p|--push)
                PUSH=true
                shift
                ;;
            --debug)
                DEBUG=true
                shift
                ;;
            -yp)
                AUTO_YES=true
                PUSH=true
                shift
                ;;
            --version)
                echo "qhgp $VERSION"
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            update|uninstall)
                COMMAND="$1"
                shift
                ;;
            -*)
                print_error "未知选项: $1"
                echo "使用 'qhgp --help' 查看帮助信息"
                exit 1
                ;;
            *)
                print_error "未知参数: $1"
                echo "使用 'qhgp --help' 查看帮助信息"
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    # 解析命令行参数
    parse_args "$@"
    
    # 加载配置
    load_config
    
    # 根据命令执行相应操作
    case "$COMMAND" in
        update)
            update_command
            ;;
        uninstall)
            uninstall_command "$AUTO_YES"
            ;;
        "")
            # 默认行为：执行qhgp命令（默认只commit不push）
            qhgp_command "$AUTO_YES" "$PUSH"
            ;;
        *)
            print_error "未知命令: $COMMAND"
            exit 1
            ;;
    esac
}

# 如果脚本被直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi