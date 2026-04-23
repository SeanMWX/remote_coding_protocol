# 基于 OpenClaw Skill + Codex CLI + 飞书 的远程自动 Coding 方案设计

## 1. 背景与目标

### 1.1 当前实际情况

你现在的环境和约束是：

- **本地电脑**
  - 可以写代码、跑测试、做最终验证
  - 但本地使用 Codex / VS Code 插件时，网络环境不理想，可能需要额外代理
  - 不希望把关键凭证、服务端口、安全风险放在本地

- **OpenClaw 服务器**
  - 网络环境更适合访问 Codex 所需服务
  - 更适合长期在线运行自动任务
  - 更适合作为统一的“远程开发执行端”

- **移动端 / 飞书**
  - 你希望在手机上发出任务
  - 不需要完整 IDE 交互
  - 更希望看到 Codex 的执行结果、摘要、分支名、提交信息、PR 链接等

### 1.2 目标

希望构建一个系统，使你可以做到：

1. **手机上通过飞书发任务**
2. **OpenClaw 上自动调用 Codex CLI 执行 coding 任务**
3. **任务结果自动回传到飞书**
4. **所有代码变更通过 GitHub 分支同步**
5. **本地电脑只负责 pull、测试、review、合并**
6. **尽可能结合 OpenClaw 的 skill 能力，而不是只做一个孤立脚本**

---

## 2. 核心思路总结

一句话概括：

> 把 OpenClaw 当作“远程执行与编排中心”，把 Codex CLI 当作“自动 coding 引擎”，把 GitHub 当作“唯一代码同步源”，把飞书当作“移动端任务入口和结果回传界面”，把本地电脑当作“最终测试与验收端”。

### 2.1 角色分工

#### A. OpenClaw
负责：
- 承载远程在线服务
- 运行 skill
- 调用 Codex CLI
- 访问 Git 仓库
- 管理任务队列 / 日志 / 会话
- 接飞书 webhook
- 把结果返回飞书

#### B. Codex CLI
负责：
- 理解 coding 任务
- 阅读当前分支代码
- 改代码 / 生成补丁
- 运行必要命令
- 输出修改说明与结果摘要

#### C. GitHub
负责：
- 作为代码同步中枢
- 保存 AI 修改的分支
- 承载 PR / CI / review 记录
- 连接本地开发与远程自动 coding

#### D. 本地电脑
负责：
- 拉取 AI 生成的分支
- 运行本地测试、实验、调试
- 代码 review
- 合并或继续修改

#### E. 飞书
负责：
- 作为手机端任务入口
- 作为结果通知出口
- 提供轻量级交互，而不是替代 IDE

---

## 3. 为什么这是最优方向

## 3.1 不把本地机器暴露到公网

这是一个很重要的安全原则：

- 不让飞书直接访问你的本地电脑
- 不在本地开 webhook 服务
- 不在本地保存用于服务器自动化的关键 token
- 不让本地 VS Code 承担远程常驻服务职责

这样可以显著降低：
- 本地机器被扫到或被打穿的风险
- token 泄露风险
- 因本地断网/关机导致系统不可用的问题

## 3.2 避开 VS Code 插件兼容性问题

你已经观察到：

- Codex CLI 可用
- 但 code-server / browser 场景中的 Codex 插件可能空白或不稳定

因此现阶段最佳实践不是依赖 IDE 插件，而是：

- **文件浏览 / 远程编辑：用 code-server**
- **自动 coding：用 Codex CLI**
- **移动交互：用飞书消息**

## 3.3 本地测试仍然保留

这点非常关键，因为很多 AI 自动 coding 系统失败的原因就是没有“最后的人类验证”。

你这个方案里：

- AI 在远程改代码
- GitHub 保存变更
- 你本地做最终验证

这样可以最大限度发挥 AI 的效率，同时保留可靠性。

---

## 4. 总体架构

```text
手机 / 飞书
    ↓
飞书 Bot / Webhook
    ↓
OpenClaw Skill Router
    ↓
任务编排器（Task Orchestrator）
    ├── Git 管理器
    ├── Codex Runner
    ├── 日志与结果格式化器
    └── 返回飞书消息
    ↓
GitHub 仓库（分支 / PR）
    ↓
本地电脑 pull / test / review / merge
```

---

## 5. 结合 OpenClaw Skill 的方式

这里是整个方案最关键的“产品化”部分。

### 5.1 不只是写一个独立脚本

不建议只写一个散乱的 `feishu_bot.py`，而应该把它设计成 **OpenClaw skill**。

这样做的好处：

- 统一接入 OpenClaw 现有的能力
- 统一日志、鉴权、任务管理
- 后续可以扩展更多 automation
- 可以把 Git、Codex、消息返回等封装成可组合能力

### 5.2 建议拆分的 skill 模块

建议把 skill 分成几个逻辑组件：

#### 1) `task_parser`
负责把飞书消息解析成结构化任务，例如：

输入：
- “帮我在 feature/login-v2 分支修复登录接口报错”
- “分析当前仓库的训练入口并给出结论”
- “基于 main 创建一个分支，重构 config 模块”

输出：
```json
{
  "repo": "your-repo",
  "base_branch": "main",
  "work_branch": "codex/fix-login-v2",
  "task_type": "code_modify",
  "prompt": "修复登录接口报错，并说明修改点",
  "need_pr": true,
  "need_test_hint": true
}
```

#### 2) `git_manager`
负责：
- clone / pull 仓库
- checkout 基础分支
- 创建工作分支
- commit / push
- 可选：创建 PR

#### 3) `codex_runner`
负责：
- 在指定工作目录运行 Codex CLI
- 传入 prompt
- 捕获 stdout / stderr
- 生成结构化执行结果

#### 4) `result_formatter`
负责把执行结果格式化为适合飞书返回的内容，例如：
- 任务状态
- 分支名
- 提交信息
- 修改文件列表
- 简要总结
- 如果太长则拆分消息

#### 5) `security_guard`
负责：
- 校验飞书请求签名 / token
- 校验允许访问的 repo / 分支 / 命令范围
- 限制危险任务
- 控制并发 / 限流

#### 6) `session_manager`（可选增强）
如果希望后面支持“带上下文的连续会话”，可以加这一层：
- 使用 tmux 保持一个持续的 Codex CLI session
- 同一个任务线程继续对话
- 对应飞书 thread 或 conversation id

---

## 6. 推荐的数据流

### 6.1 基础闭环

1. 用户在飞书发送任务
2. 飞书 webhook 把消息送到 OpenClaw skill endpoint
3. skill 解析任务
4. skill 在服务器上准备 Git 工作目录
5. skill 调用 Codex CLI 执行任务
6. skill 收集结果
7. skill 提交并 push 到 GitHub 分支
8. skill 把结果摘要返回飞书
9. 用户在本地 pull 该分支并测试

### 6.2 示例

用户发消息：

> 帮我从 main 创建分支 `codex/fix-login-timeout`，修复登录 timeout 问题，改完 push，并返回修改摘要。

系统内部执行：

1. `git checkout main`
2. `git pull origin main`
3. `git checkout -b codex/fix-login-timeout`
4. 运行：
   ```bash
   codex --full-auto "修复登录 timeout 问题；修改完成后总结变更点；如有测试命令请执行可行的最小验证"
   ```
5. `git add .`
6. `git commit -m "codex: fix login timeout"`
7. `git push origin codex/fix-login-timeout`
8. 返回飞书消息：

- 状态：成功
- 分支：`codex/fix-login-timeout`
- 修改文件：3 个
- 摘要：修复了超时重试逻辑；增加了默认 timeout 配置；补充了错误处理
- 下一步：请本地 `git fetch && git checkout codex/fix-login-timeout` 后测试

---

## 7. Git 工作流设计

这部分非常重要，决定了系统是否会“越用越乱”。

### 7.1 原则：所有 AI 改动都必须走分支

**禁止：**
- AI 直接改 `main`
- AI 直接改 `dev`
- AI 在未隔离的共享工作目录里写代码

**必须：**
- 每个任务一个工作分支
- 分支命名有统一规范
- 改动通过 commit 留痕

### 7.2 推荐分支命名

```text
codex/fix-login-timeout
codex/refactor-config-loader
codex/add-api-health-check
codex/analyze-training-entry
```

### 7.3 推荐规则

- 若任务是“分析类”而不改代码，可以不 push
- 若任务是“修改类”，必须用独立分支
- 每个分支只做一件事
- 不允许多个任务共用一个正在被 AI 改的分支，除非显式指定

### 7.4 本地使用方式

本地只需要：

```bash
git fetch origin
git checkout codex/fix-login-timeout
# 运行本地测试
pytest
# 或者你的实际测试命令
```

验证通过后：
- 提交你自己的修正
- 或创建 PR 合并

---

## 8. Codex CLI 的推荐使用方式

### 8.1 现阶段推荐 CLI，不推荐依赖插件

原因：
- 浏览器 / code-server 插件兼容性不稳定
- CLI 最直接、最可控
- 更适合自动脚本调用

### 8.2 推荐运行模式

建议基础模式为：

```bash
codex --full-auto
```

或者非交互调用：

```bash
codex --full-auto "你的任务描述"
```

### 8.3 Prompt 模板建议

建议不要把 prompt 写得太口语化，而应结构化。

推荐模板：

```text
你现在在一个 Git 工作分支中工作。
任务目标：
{TASK_GOAL}

约束：
1. 只修改与任务相关的文件
2. 不要做无关重构
3. 如果存在测试命令，执行最小可行验证
4. 输出最终总结，包含：
   - 修改了哪些文件
   - 为什么这么改
   - 还有哪些风险或待人工验证点
```

### 8.4 输出建议

Codex 输出最好被结构化解析，至少抽出：

- `status`
- `summary`
- `files_changed`
- `suggested_test_commands`
- `raw_output`

---

## 9. 飞书接入设计

## 9.1 飞书在这个系统中的作用

飞书不是 IDE，也不是 shell，而是：

- 移动端任务入口
- 结果回传入口
- 任务状态通知入口

## 9.2 推荐飞书消息交互形式

### 输入

支持这种自然语言格式：

- “帮我从 main 开一个分支修复登录 bug”
- “在 repoA 里分析训练入口，不改代码”
- “把 config 模块重构成 dataclass 风格”
- “继续上一个任务，补一版测试”

### 输出

推荐飞书返回的内容格式如下：

```text
任务：修复登录 timeout
状态：成功
仓库：repo-name
分支：codex/fix-login-timeout
提交：codex: fix login timeout
修改文件：
- app/auth.py
- app/config.py
- tests/test_auth.py

摘要：
1. 修复了请求 timeout 配置未生效的问题
2. 增加了默认重试间隔
3. 补充了异常路径处理

建议你本地执行：
git fetch origin
git checkout codex/fix-login-timeout
pytest tests/test_auth.py
```

### 长消息处理

如果 Codex 输出很长，需要拆分成多条消息：
- 第一条返回摘要
- 第二条返回修改文件列表
- 第三条返回关键 diff 摘要或 PR 链接

---

## 10. 安全设计

这是这个系统里绝对不能省略的部分。

### 10.1 原则一：本地电脑不暴露

不要：
- 让飞书直接访问本地电脑
- 在本地开公网 webhook
- 在本地保存机器人 token 用来执行远程 coding

### 10.2 原则二：只开放 OpenClaw 服务器入口

飞书 webhook 只打到服务器。

### 10.3 原则三：限制任务权限

飞书任务不应该能执行任意 shell。

禁止这种能力：
- “帮我执行 rm -rf”
- “帮我 curl 一个未知脚本并执行”
- “帮我读取系统上所有 token”

建议只允许这些安全动作：
- Git checkout / pull / push
- 在指定 repo 目录运行 Codex CLI
- 可选执行预定义测试命令
- 可选创建 PR

### 10.4 原则四：仓库白名单

只允许在白名单仓库中运行：
- `repo-a`
- `repo-b`
- `repo-c`

### 10.5 原则五：工作目录隔离

建议每个任务都有独立工作目录：

```text
/workspaces/repo-a/task-20260423-001/
/workspaces/repo-a/task-20260423-002/
```

这样避免：
- 任务之间互相污染
- Git 状态混乱
- 未提交改动被下一个任务覆盖

### 10.6 原则六：凭证隔离

需要的凭证可能包括：
- GitHub token
- 飞书 webhook secret / bot token
- Codex 认证信息

建议：
- 只保存在服务器
- 使用环境变量或 secret manager
- 不写进仓库
- 不下发到本地

### 10.7 原则七：审计日志

所有任务至少记录：
- 发起时间
- 发起人
- 仓库
- 分支
- prompt
- 运行结果
- 提交 hash
- 返回消息摘要

---

## 11. 会话设计：是否需要“Codex Session”

这是一个可选增强点。

### 11.1 基础版：无会话

每次任务独立执行：

- 优点：简单、稳定、好审计
- 缺点：没有连续上下文

适合第一阶段上线。

### 11.2 进阶版：tmux 会话复用

可以为每个仓库或每个任务维护一个 tmux session：

```bash
tmux new -s codex-repoA
```

然后把后续指令发送进去。

优点：
- 可以模拟“继续刚才的任务”
- 可以保留上下文

缺点：
- 实现更复杂
- 容易出现状态漂移
- 更难调试和审计

### 11.3 建议

**第一版不要做复杂 session 复用。**
先做“每次独立任务执行 + Git 分支隔离”。

等基础版稳定后，再考虑：

- 飞书 thread 对应 task session
- tmux 会话续跑
- 连续补充 prompt

---

## 12. 任务类型设计

建议系统一开始就定义清楚几类任务。

### 12.1 分析类
示例：
- “帮我分析这个 repo 的训练入口”
- “看一下 config 加载流程”
- “找出登录模块的调用链”

特点：
- 不改代码
- 不一定创建分支
- 直接把结论发回飞书

### 12.2 修改类
示例：
- “修复登录 timeout”
- “给 health 接口加一个返回字段”
- “把 config 模块重构一下”

特点：
- 创建分支
- 改代码
- commit + push
- 返回分支和摘要

### 12.3 补充类
示例：
- “继续上一个任务，再补测试”
- “在刚才那个分支里加日志”
- “把错误处理也补上”

特点：
- 需要引用已有 task id 或 branch
- 风险比第一轮稍高
- 要求更强的上下文管理

---

## 13. 推荐的最小可行版本（MVP）

### 13.1 第一阶段不要做太复杂

建议 MVP 只做以下功能：

1. 飞书接收任务
2. 白名单 repo 选择
3. 自动创建工作分支
4. 调用 Codex CLI 执行任务
5. 自动 commit + push
6. 飞书返回摘要与分支信息

### 13.2 暂时不要做的东西

第一阶段先不要做：
- 复杂 session 复用
- 多轮对话上下文
- 任意 shell 调用
- 自动合并 main
- 自动生产环境发布

---

## 14. 推荐配置清单

这里给出一份系统配置建议。

### 14.1 服务器侧

#### 必需组件
- OpenClaw 运行环境
- Python 3.10+ 或 Node.js（任选其一做 webhook 服务）
- Git
- Codex CLI
- 访问 GitHub 的 token
- 飞书 bot / webhook 配置
- 可选：tmux

#### 推荐目录结构

```text
/opt/openclaw-skills/
  ├── feishu_codex_skill/
  │   ├── app.py
  │   ├── task_parser.py
  │   ├── git_manager.py
  │   ├── codex_runner.py
  │   ├── formatter.py
  │   ├── security.py
  │   └── config.py

/workspaces/
  ├── repo-a/
  │   ├── task-001/
  │   └── task-002/
  └── repo-b/
```

### 14.2 GitHub 侧

建议准备：
- 一个 bot token 或 PAT
- 对目标 repo 的最小必要权限
- 可选：PR 创建权限
- 可选：GitHub Actions 测试工作流

### 14.3 本地侧

本地只需要：
- Git
- VS Code / 你习惯的 IDE
- 对 GitHub 的访问能力
- 本地测试环境（例如 Python / Node / CUDA 等）

本地不需要：
- 飞书机器人 token
- 服务器 webhook secret
- 远程服务端口暴露

---

## 15. 推荐的落地步骤

### 第一步：先把 CLI 跑通
在 OpenClaw 服务器上验证：
- 能进入 repo
- 能跑 `codex`
- 能返回输出

### 第二步：做一个最简单的 skill wrapper
只支持一个固定 repo，固定任务格式，例如：

> “修复 login bug”

### 第三步：接飞书 webhook
把收到的文本转给 skill。

### 第四步：加 Git 分支自动化
实现：
- pull base branch
- create work branch
- run codex
- commit
- push

### 第五步：返回飞书摘要
至少返回：
- 成功 / 失败
- 分支名
- 修改文件数
- 简短摘要

### 第六步：加本地验证工作流
规范本地操作：
- `git fetch`
- `git checkout branch`
- `run tests`
- `review`
- `merge`

---

## 16. 一套推荐的最终工作流

### 场景：你在手机上发现需要修一个问题

1. 你在飞书发消息：
   > 在 repo-a 里从 main 创建分支修复登录 timeout，并把结果发我

2. OpenClaw skill 收到任务并执行：
   - 校验用户权限
   - clone/pull repo-a
   - checkout main
   - 创建 `codex/fix-login-timeout`
   - 调用 Codex CLI
   - commit + push

3. 飞书收到返回：
   - 状态成功
   - 分支名
   - 修改文件列表
   - 任务摘要

4. 你回到本地执行：
   ```bash
   git fetch origin
   git checkout codex/fix-login-timeout
   pytest
   ```

5. 测试通过后：
   - 你本地补充修改，或
   - 提交 PR，或
   - 直接 merge

---

## 17. 这个方案的优点与限制

### 17.1 优点

- 不依赖本地常驻在线
- 不受本地代理问题影响
- 远程自动 coding 能力强
- 本地保留最终验证权
- 结合 Git 工作流，可审计、可回滚
- 飞书交互轻量，适合手机端

### 17.2 限制

- 不是完整远程 IDE 替代品
- 复杂调试仍然适合本地做
- 多轮上下文会话需要额外设计
- Codex CLI 的行为仍需通过 prompt、权限和分支策略加以约束

---

## 18. 最终建议

### 18.1 建议你当前就采用的方案

**最佳组合：**

- **OpenClaw**：做技能编排与服务托管
- **Codex CLI**：做自动 coding
- **GitHub 分支**：做同步层
- **飞书**：做手机任务入口和结果回传
- **本地电脑**：做测试与最终合并

### 18.2 第一版实现重点

第一版只做这四件事：

1. 飞书 -> OpenClaw skill
2. skill -> Git branch + Codex CLI
3. skill -> push GitHub
4. skill -> 返回飞书摘要

### 18.3 第一版不要做的事

- 不做复杂 session
- 不做任意 shell
- 不做自动合并
- 不做本地服务暴露
- 不做过大的权限开放

---

## 19. 给本地开发者的实现要求摘要

如果把这份文档交给本地开发者实现，可以直接按下面的目标拆任务：

### 模块 1：飞书接入
- 接飞书消息
- 校验签名 / token
- 转成内部任务对象

### 模块 2：任务编排
- 根据消息生成 repo、base branch、work branch、prompt
- 生成 task id

### 模块 3：Git 管理
- clone/pull repo
- checkout base branch
- create work branch
- commit/push

### 模块 4：Codex 执行
- 在指定目录运行 Codex CLI
- 捕获 stdout/stderr
- 返回结构化结果

### 模块 5：结果返回
- 格式化为飞书可读摘要
- 长文本拆分消息
- 返回 branch / commit / summary

### 模块 6：安全控制
- repo 白名单
- 任务类型白名单
- 限制危险动作
- 记录审计日志

---

## 20. 最后的判断

你的思路是成立的，而且不是“能不能做”的问题，而是“怎么把它设计成一个长期可用、可控、安全的系统”。

最优答案不是：

- 让本地 VS Code 永远在线
- 或者继续折腾 browser 插件兼容

而是：

> **把 OpenClaw 作为远程执行和编排中心，把 Codex CLI 作为 coding 引擎，把 GitHub 作为同步层，把飞书作为手机入口，把本地作为测试与验收端。**

这就是目前最稳、最实用、最适合你场景的方案。
