# Vim 中使用 vim-ai 解释代码与生成注释

该插件 `vim-ai` 是一个在 Vim 中通过 OpenAI API 调用 AI 的助手，可用于生成代码、编辑文本、头脑风暴、翻译等；它提供 `:AI`、`:AIEdit`、`:AIChat`、`:AIImage` 等命令，支持对当前行、可视选区或提示词进行操作，并支持聊天、文件包含、重试、角色配置、自定义命令和键位绑定。

- **文本/代码补全**：`:AI {prompt}` 补全提示词；对选区执行 `:AI` 补全选区；`:AI {instruction}` 按指令补全选区。
- **文本编辑**：`:AIEdit` 编辑当前行或选区，可附加指令，如 `:AIEdit fix grammar`。
- **AI 聊天**：`:AIChat` 开始或继续对话，可带选区/指令；`:AIStopChat` 取消当前聊天生成。
- **图像生成**：`:AIImage` 根据选区或指令生成图片，默认使用 DALL·E 3。
- **文件包含**：在聊天中使用 `>>> include` 角色包含文件，支持 glob 路径展开。
- **重试/替代**：`:AIRedo` 重复上一条 AI 命令，用于重试或获取不同结果。
- **配置与角色**：通过 `g:vim_ai_*` 配置模型、温度、端点、流式等；支持 `.ini` 角色文件，如 `/grammar`。
- **自定义与集成**：可设置键位，使用 `AIRun`、`AIEditRun`、`AIChatRun` 创建自定义命令；支持 Markdown 高亮和调试开关。


## 1. 目标

本文给出一套可直接复用的 `vim-ai` 配置，以及相应的自定义方法。目前主要需求如下：

1. 在 Visual Line 模式下选择代码，一键调用 AI 生成结构化、简洁的代码解释。
2. 在 Visual Line 模式下选择代码，一键调用 AI 为关键逻辑添加专业注释，同时保持原有代码逻辑不变。
3. 保存和恢复此次对话内容。
4. 为当前对话生成Q&A索引，支持快速跳转。  

`vim-ai` 支持 `:AI`、`:AIEdit`、`:AIChat`、`:AIStopChat`、`:AIRedo` 等命令，并可通过 OpenAI-compatible API 连接第三方模型。插件只发送用户明确选择或写入会话的内容，不会自动索引整个工程。参考：<https://github.com/madox2/vim-ai>

---

## 2. 安装并启用 vim-ai

### 2.1 使用 vim-plug 安装

由于我的`~/.vimrc`配置文件已经安装了插件管理插件`VundleVim`,

```vim
Plugin 'VundleVim/Vundle.vim'
```
可以在`~/.vimrc`中加入

```vim
Plugin 'madox2/vim-ai'
```

随后重新打开 Vim，执行：

```vim
:PlugInstall
```

### 2.2 使用原生 package 安装

不使用插件管理器时，可执行：

```bash
mkdir -p ~/.vim/pack/plugins/start
git clone https://github.com/madox2/vim-ai.git \
    ~/.vim/pack/plugins/start/vim-ai
```

### 2.3 验证插件

重新启动 Vim 后执行：

```vim
:echo exists(':AIChat')
:echo exists(':AIEdit')
:help vim-ai
```

前两条命令应返回 `2`。  
而最后一条命令将打开`vim-ai`文档  

---

## 3. 配置 Lenovo glm5.3 模型

以下配置假定 Lenovo 模型服务提供 OpenAI-compatible Chat Completions 接口。`endpoint_url`、API Key 和精确模型标识应以 Lenovo 内部服务文档为准。本文使用模型名 `glm5.3`。

### 3.1 保存 API Key

```bash
mkdir -p ~/.config/vim-ai
printf '%s\n' 'YOUR_LENOVO_API_KEY' > ~/.config/vim-ai/lenovo.token
chmod 600 ~/.config/vim-ai/lenovo.token
```

### 3.2 在 vimrc 中定义公共模型参数

```vim
let s:cfc_options = {
      \ 'model': 'glm-5.3',
      \ 'endpoint_url': 'https://cfc-llm-gateway.lenovo.com:4000/v1/chat/completions',
      \ 'auth_type': 'bearer',
      \ 'token_file_path': expand('~/.config/cfc-ai.token'),
      \ 'request_timeout': 120,
      \ 'stream': 1,
      \ 'selection_boundary': '#####',
      \ 'temperature': 0.1,
      \ 'max_tokens': 16384,
      \ }


```

- `model`：模型名称，需与网关注册的模型标识一致
- `endpoint_url`：API 地址，以 `/chat/completions` 结尾
- `auth_type`：认证方式，Bearer Token
- `token_file_path`：Token 文件路径，`expand()` 展开 `~` 为家目录
- `request_timeout`：请求超时时间（秒），此处 120
- `stream`：是否流式响应，`1` 启用（SSE 分块推送）
- `selection_boundary`：选中文本边界标记，界定插入/替换位置
- `temperature`：采样温度（0–2），越低越确定，代码任务建议低值
- `max_tokens`：单次响应最大 token 数，超限截断

### 3.3 配置 Chat、Edit 和 Complete

```vim
let g:vim_ai_chat = {
      \ 'provider': 'openai',
      \ 'options': copy(s:cfc_options),
      \ 'ui': {
      \   'open_chat_command': 'vertical botright 80new',
      \   'scratch_buffer_keep_open': 1,
      \   'populate_options': 0,
      \   'populate_all_options': 0,
      \   'force_new_chat': 0,
      \   'paste_mode': 1,
      \ },
      \ }

let g:vim_ai_edit = {
      \ 'provider': 'openai',
      \ 'options': copy(s:cfc_options),
      \ 'ui': {
      \   'paste_mode': 1,
      \ },
      \ }

let g:vim_ai_complete = {
      \ 'provider': 'openai',
      \ 'options': copy(s:cfc_options),
      \ 'ui': {
      \   'paste_mode': 1,
      \ },
      \ }
```
**g:vim_ai_chat**(聊天配置)

- `provider`: AI 服务提供方，如 `openai`、`gemini`、`ollama` 等
- `options`: 请求参数(模型、温度、api_key 等)，`copy(s:cfc_options)` 表示复制自定义变量中的选项
- `ui.open_chat_command`: 打开聊天窗口的 Vim 命令，即在右侧垂直打开一个 80 列宽的新窗口
- `ui.scratch_buffer_keep_open`: 为 1 时，聊天内容保留在 scratch 缓冲区，不自动关闭
- `ui.populate_options`: 为 1 时，在聊天界面头部显示当前生效的 options 配置
- `ui.populate_all_options`: 为 1 时显示全部选项(包括默认值)，而非仅自定义部分
- `ui.force_new_chat`: 为 1 时每次调用都强制开启新会话，不延续历史上下文
- `ui.paste_mode`: 为 1 时聊天缓冲区启用 paste 模式，避免自动缩进等干扰

**g:vim_ai_edit**(文本编辑/改写配置)

- `provider`: 同上，指定服务提供方
- `options`: 编辑请求所用的参数
- `ui.paste_mode`: 编辑输出时启用 paste 模式

**g:vim_ai_complete**(代码补全配置)

- `provider`: 同上，指定服务提供方
- `options`: 补全请求所用的参数
- `ui.paste_mode`: 补全输出时启用 paste 模式

---

## 4. 编写 Role 和固定 Prompt

### 4.1 创建 Role 文件

```bash
mkdir -p ~/.config/vim-ai
vim ~/.config/vim-ai/roles.ini
```

写入：

```ini
[kernel_explain.chat]
prompt = 你是一名专业的系统软件开发工程师。请仅依据选中的代码进行分析，并严格按以下格式输出：1. 功能：用一句话概括代码目的；2. 流程：按实际执行顺序分点说明；3. 关键机制：仅说明代码中确实涉及的数据结构、状态变化、锁、引用计数、RCU、内存屏障和错误处理；4. 注意事项：指出依赖外部定义或无法从当前代码确认的内容。要求表达专业、清晰、简洁，不重复代码，不扩展无关背景，不将推断表述为事实。
options.temperature = 0.1

[kernel_comment.edit]
prompt = Add concise English comments to the selected systems code. Comment only non-obvious control flow, state transitions, synchronization, reference counting, assumptions, and error paths. Follow the existing project comment style and prefer /* ... */ for C code. Do not restate obvious statements. Do not modify, reorder, remove, or reformat any original code, identifiers, macros, preprocessor directives, or executable logic. Return only the complete edited code without explanations or Markdown fences.
options.temperature = 0.1
```

说明：

- `[kernel_explain.chat]` 仅用于 `AIChat`。
- `[kernel_comment.edit]` 仅用于 `AIEdit`。
- `prompt` 固定任务、输出结构和边界。
- `options.temperature = 0.1` 用于降低输出随机性。

### 4.2 在 vimrc 中引用 Role 文件

```vim
let g:vim_ai_roles_config_file = expand('~/.config/vim-ai/roles.ini')
```

### 4.3 配置快捷键

```vim
let mapleader = ","

" Visual模式：解释选中代码
xnoremap <silent> <leader>ae :AIChat /kernel_explain<CR>

" Visual模式：为选中代码添加英文注释
xnoremap <silent> <leader>ac :AIEdit /kernel_comment<CR>

" Normal模式：打开或继续Chat
nnoremap <silent> <leader>aa :AIChat<CR>

" 停止异步Chat响应
nnoremap <silent> <leader>as :AIStopChat<CR>

" 重复最近一次AI操作
nnoremap <silent> <leader>ar :AIRedo<CR>
```

在 Visual Line 模式（按 `V` 进入）下用 `j`、`k` 调整选区后，可按 `,ae` 解释代码或按 `,ac` 添加注释，其等价命令分别为 `:'<,'>AIChat /kernel_explain` 和 `:'<,'>AIEdit /kernel_comment`。

`'<,'>` 是 Visual 选区范围，选中代码后按 `:` 会自动产生，无需手工输入。

---

## 5. UI 配置

### 5.1 推荐配置

```vim
let g:vim_ai_chat = {
      \ 'provider': 'openai',
      \ 'options': copy(s:cfc_options),
      \ 'ui': {
      \   'open_chat_command': 'vertical botright 80new',
      \   'scratch_buffer_keep_open': 1,
      \   'populate_options': 0,
      \   'populate_all_options': 0,
      \   'force_new_chat': 0,
      \   'paste_mode': 1,
      \ },
      \ }
```

该配置将 Chat 固定在最右侧，以宽度约 80 列的垂直窗口显示，适合左侧阅读源码、右侧查看解释。

### 5.2 UI 属性

- `open_chat_command`：指定 Chat 窗口打开方式。常用值为 `preset_below`、`preset_right`、`preset_tab`，也可使用自定义 Vim 命令，例如 `vertical botright 80new`。
- `scratch_buffer_keep_open`：关闭窗口后保留 Chat buffer，以便后续复用会话。
- `populate_options`：在 Chat 头部显示已修改的请求参数。
- `populate_all_options`：在 Chat 头部显示全部请求参数，主要用于调试。
- `force_new_chat`：是否强制创建新会话。连续分析代码时应设为 `0`。
- `paste_mode`：写入模型输出时使用 Vim paste 模式，避免自动缩进破坏代码块格式。

预定义 Chat Role 还包括 `/right`、`/below` 和 `/tab`。这些 Role 通常会设置 `ui.force_new_chat = 1`，因此适合临时创建新会话，不适合继续已有会话。参考：<https://github.com/madox2/vim-ai/blob/main/roles-default.ini>

---

## 6. 保存和恢复会话

### 6.1 保存当前会话

在 AIChat buffer 中执行：

```vim
:w ~/workspace/vimaichat/topic.aichat
```

建议使用 `.aichat` 扩展名，而不是 `.md`。插件通过 `filetype=aichat` 识别可继续的会话。

检查：

```vim
:set filetype?
```

预期结果：

```text
filetype=aichat
```

### 6.2 直接打开并继续会话

尚未打开其他文件时，可直接打开保存的会话：

```bash
vim ~/workspace/vimaichat/topic.aichat
```

在文件末尾追加：

```text
>>> user

请继续解释上述代码中的错误处理路径。
```

然后执行：

```vim
:AIChat
```

插件会读取当前 `.aichat` buffer 中已有的 `system`、`user` 和 `assistant` 内容，并在当前会话中继续回答。

### 6.3 在已打开代码文件时恢复会话

如果 Vim 中已经打开代码文件，建议保留当前代码窗口，并在右侧垂直分屏中打开已有 `.aichat` 文件：

```vim
:vertical rightbelow 80split ~/workspace/vimaichat/topic.aichat
```

该方式无需执行新的 `:AIChat` 来创建窗口。右侧打开的是已有会话文件，可以直接在其末尾追加问题并执行：

```vim
:AIChat
```

窗口切换：

```text
Ctrl-W h    切换到左侧代码窗口
Ctrl-W l    切换到右侧会话窗口
```

为简化操作，并支持在命令行中使用 `Tab` 补全任意 `.aichat` 文件路径，可在 `~/.vimrc` 中定义：

```vim
" 在右侧垂直分屏中打开已有会话；参数支持文件路径补全
command! -nargs=1 -complete=file AIChatOpen
      \ execute 'vertical rightbelow 80split ' . fnameescape(<q-args>)

" 进入命令行，等待输入会话文件路径
nnoremap <leader>ao :AIChatOpen 
```

重新加载配置：

```vim
:source ~/.vimrc
```

使用示例：

```vim
:AIChatOpen ~/workspace/vimaichat/topic.aichat
```

输入路径时可按 `Tab` 补全：

```text
:AIChatOpen ~/workspace/vimaichat/top<Tab>
```

该命令不固定目录前缀，既支持绝对路径，也支持相对于 Vim 当前工作目录的路径。当前工作目录可通过以下命令检查：

```vim
:pwd
```

必要时可仅为当前窗口设置工作目录：

```vim
:lcd ~/workspace/vimaichat
```

之后可直接执行：

```vim
:AIChatOpen topic.aichat
```

打开后检查：

```vim
:set filetype?
```

预期结果为：

```text
filetype=aichat
```

### 6.4 会话标记格式

```text
>>> system

系统提示词

>>> user

用户问题

<<< assistant

模型回答

>>> user

下一轮问题
```


## 7. 常用命令和功能

### 7.1 核心命令

- `:AI {prompt}`：生成或补全文本。
- `:AIEdit {instruction}`：编辑当前行或 Visual 选区，并用模型结果替换原内容。
- `:AIChat {instruction}`：新建或继续交互式会话。
- `:AIStopChat`：停止正在生成的 Chat 响应。
- `:AIRedo`：重复最近一次 AI 操作。
- `:AIUtilRolesOpen`：打开 Role 配置文件。
- `:AIUtilDebugOn`：启用调试日志。
- `:AIUtilDebugOff`：关闭调试日志。

### 7.2 范围调用

```vim
:%AIEdit /kernel_comment
:10,50AIChat /kernel_explain
```

第一条处理整个 buffer，第二条处理第 10 至 50 行。对于修改代码的操作，应优先使用精确选区，避免提交过多上下文。

### 7.3 Role 组合

Role 可在命令中通过 `/role_name` 引用，也可以组合多个 Role：

```vim
:AIChat /kernel_explain /right
```

### 7.4 Chat 中包含外部上下文

`.aichat` 支持显式加入其他文件：

```text
>>> include

include/linux/migrate.h
mm/migrate.c
```

也可以通过命令收集检索结果：

```text
>>> exec

git grep -n -E '\bmigrate_folio\s*\(' -- '*.c' '*.h'
```

然后执行：

```vim
:AIChat
```

该机制适合补充少量相关定义和调用点，但 `vim-ai` 不会自动构建项目级语义索引。不要直接包含整个 Linux 内核源码树。

### 7.5 调试

出现配置、鉴权或响应解析问题时：

```vim
:AIUtilDebugOn
```

默认或自定义日志路径可通过以下变量配置：

```vim
let g:vim_ai_debug = 1
let g:vim_ai_debug_log_file = '/tmp/vim-ai-debug.log'
```

检查日志：

```bash
tail -f /tmp/vim-ai-debug.log
```

调试结束后关闭：

```vim
:AIUtilDebugOff
```

---

加载配置：

```vim
:source ~/.vimrc
```

---

## 9. 推荐操作流程

### 9.1 解释代码

```text
V选择目标代码
    -> <leader>ae
    -> 在右侧Chat查看结构化解释
    -> 在Chat末尾追加问题
    -> :AIChat继续会话
    -> :w topic.aichat保存
```

### 9.2 添加注释

```text
V选择目标代码
    -> <leader>ac
    -> :!git diff -- % 检查修改
    -> 满意则:w
    -> 不满意则u撤销
```

`AIEdit` 会直接替换选区。即使 Prompt 明确禁止修改逻辑，也必须通过 `git diff` 审查结果。

---

## 参考资料

- vim-ai 项目：<https://github.com/madox2/vim-ai>
- vim-ai 默认 Role：<https://github.com/madox2/vim-ai/blob/main/roles-default.ini>

