# qhgp - 智能Git提交助手

一个基于豆包AI的智能Git提交工具，使用纯Bash实现，能够自动分析代码变更并生成高质量的commit消息。

## ✨ 特性

- 🤖 **AI驱动**: 使用豆包AI分析代码变更，生成语义化的commit消息
- 🚀 **一键操作**: 简单命令完成暂存、提交、推送全流程
- 🎯 **智能分析**: 自动识别代码变更类型和影响范围
- 🔧 **灵活配置**: 支持自定义AI模型、提示词等配置
- 📝 **交互确认**: 生成commit消息后可预览和编辑
- 🛡️ **安全默认**: 默认只提交不推送，避免意外操作
- 💻 **纯Bash实现**: 无需Python依赖，轻量级部署

## 🚀 快速开始

### 系统要求

- Git
- Curl
- Bash 4.0+
- jq

### 安装

#### 方法1: 一键安装（推荐）

```bash
curl -sSL https://raw.githubusercontent.com/SoIomon/qhgp/main/quick_install.sh | bash
```

#### 方法2: 手动安装

```bash
# 克隆仓库
git clone https://github.com/SoIomon/qhgp.git
cd qhgp

# 运行安装脚本
./install.sh
```

## 🚀 使用方法

### 基本用法

```bash
# 基本使用（默认只提交不推送）
qhgp

# 自动确认commit消息并只提交
qhgp -y

# 交互式确认commit消息后提交并推送
qhgp -p

# 自动确认commit消息并推送（简写组合）
qhgp -yp

# 自动确认commit消息并推送
qhgp -y --push



# 更新qhgp工具到最新版本
qhgp update

# 卸载qhgp工具
qhgp uninstall

# 查看帮助
qhgp --help

# 查看版本
qhgp --version
```

### 使用示例

```bash
# 场景1: 修复了一个bug
$ qhgp
🚀 开始执行 ggp 命令...
📋 发现以下更改:
 M  src/login.py
✅ 已暂存所有更改
🤖 正在生成commit消息...

📝 生成的commit消息:
   类型: fix
   标题: 修复登录页面验证码显示异常
   描述: 解决了验证码图片在某些浏览器下无法正常显示的问题

❓ 是否使用此commit消息？(y/n): y
✅ 自动确认使用生成的commit消息
提交成功: fix: 修复登录页面验证码显示异常
推送成功
🎉 代码已成功提交并推送！

# 场景2: 快速提交新功能
$ qhgp -y
🚀 开始执行 ggp 命令...
📋 发现以下更改:
 A  src/user_management.py
 M  src/routes.py
✅ 已暂存所有更改
🤖 正在生成commit消息...

📝 生成的commit消息:
   类型: feat
   标题: 新增用户管理功能
   描述: 添加了用户增删改查接口和相关路由配置

✅ 自动确认使用生成的commit消息
提交成功: feat: 新增用户管理功能
推送成功
🎉 代码已成功提交并推送！
```

## 🔧 配置说明

### 配置文件

`qhgp` 支持通过配置文件来自定义模型和行为设置。配置文件位于工具安装目录下的 `qhgp_config/config.json`。

#### 配置文件位置

- 默认位置：`<qhgp安装目录>/qhgp_config/config.json`
- 工具会在首次运行时自动创建默认配置文件
- 可以参考 `config.example.json` 了解配置格式

#### 配置选项说明

**OpenAI模型配置**：

```json
{
  "openai": {
    "api_key": "your-api-key-here",
    "base_url": "https://api.openai.com/v1",
    "model": "gpt-3.5-turbo",
    "temperature": 0.7,
    "max_tokens": 2000
  }
}
```

**Commit消息配置**：

```json
{
  "commit_message": {
    "language": "zh",
    "format": "conventional",
    "include_description": true,
    "max_title_length": 50
  }
}
```

**Git操作配置**：

```json
{
  "git": {
    "auto_stage": true,
    "auto_push": true,
    "default_remote": "origin"
  }
}
```

### 支持的模型

`qhgp` 支持任何兼容 OpenAI API 格式的模型：

- **OpenAI官方模型**: gpt-3.5-turbo, gpt-4, gpt-4-turbo 等
- **豆包模型**: 通过火山引擎API
- **其他兼容模型**: 如本地部署的模型、第三方API等不保真

### 配置示例

**使用OpenAI官方API**：

```json
{
  "openai": {
    "api_key": "sk-your-openai-api-key",
    "base_url": "https://api.openai.com/v1",
    "model": "gpt-3.5-turbo"
  }
}
```

**使用豆包API**：

```json
{
  "openai": {
    "api_key": "your-doubao-api-key",
    "base_url": "https://ark.cn-beijing.volces.com/api/v3/",
    "model": "ep-your-model-id"
  }
}
```

### Commit消息规范

生成的commit消息遵循以下规范：

- **type**: 提交类型
    - `feat`: 新功能、新特性
    - `fix`: 修复bug、问题修复
    - `docs`: 文档相关
    - `style`: 代码格式、样式调整
    - `refactor`: 代码重构
    - `test`: 测试相关
    - `chore`: 构建工具、依赖管理等

- **title**: 简洁的中文提交标题（不超过50字符）
- **description**: 详细的中文描述更改内容

## 🛠️ 开发说明

### 项目结构

```
qhgp-tool/
├── llms.py              # 主程序文件
├── qhgp_config/
│   ├── config.json          # 配置文件
│   └── config.example.json  # 配置文件示例
├── install.sh           # 本地安装脚本
├── quick_install.sh     # 一键下载安装脚本
├── requirements.txt     # Python依赖
└── README.md            # 项目文档
```

### 核心功能模块

- `chat_with_doubao()`: AI对话接口
- `get_git_diff()`: 获取Git差异
- `get_git_status()`: 获取Git状态
- `generate_commit_message()`: 生成commit消息
- `auto_commit()`: 自动提交代码
- `ggp_command()`: 主命令逻辑
- `main()`: 命令行入口

## 🐛 故障排除

### 常见问题

1. **命令找不到**:
   ```bash
   # 检查是否在PATH中
   which qhgp
   
   # 重新加载shell配置
   source ~/.bashrc  # 或 source ~/.zshrc
   ```

2. **权限问题**:
   ```bash
   # 确保文件有执行权限
   chmod +x /path/to/qhgp
   ```

3. **Python依赖问题**:
   ```bash
   # 重新安装依赖
   pip3 install -r requirements.txt
   ```

4. **API调用失败**:
    - 检查网络连接
    - 确认API密钥是否正确
    - 检查API额度是否充足

### 调试模式

如果遇到问题，可以直接运行Python文件进行调试：

```bash
python3 llms.py --help
```

## 📄 许可证

本项目采用MIT许可证，详见LICENSE文件。

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个工具！

---

**享受智能化的Git工作流程！** 🎉
