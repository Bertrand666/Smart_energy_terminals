# Git 分支管理与版本发布策略

本文档定义了本项目的 Git 分支管理模型、工作流规范以及版本发布流程。

## 1. 分支模型 (Branching Model)

本项目采用简化的 **Feature Branch Workflow**，适合嵌入式个人项目或小型团队。

| 分支类型 | 命名规范 | 说明 |不仅限于|
|:---|:---|:---|:---|
| **主分支** | `main` | **受保护分支**。永远保持“可编译、可运行”状态。所有功能的最终归宿。 |
| **功能分支** | `feat/<功能名>` | 用于开发新功能（如 `feat/spi-flash`）。从 `main` 检出，完成后合并回 `main`。 |
| **修复分支** | `fix/<bug名>` | 用于修复 Bug（如 `fix/uart-dma-hang`）。从 `main` 检出，完成后合并回 `main`。 |
| **重构分支** | `refactor/<模块名>` | 用于代码重构（如 `refactor/project-structure`）。 |

> 💡 **提示**：不再维护 `develop` 分支，减少维护成本，专注于功能的快速迭代。

---

## 2. 工作流 (Workflow)

### 2.1 开发新功能

1.  **同步主分支**：
    ```bash
    git checkout main
    git pull origin main
    ```

2.  **创建功能分支**：
    命名建议：`feat/` + `模块名` + `简短描述` (中划线分隔)
    ```bash
    # 例如开发 SPI Flash 驱动
    git checkout -b feat/spi-w25q-driver
    ```

3.  **开发与提交**：
    遵循 [提交信息规范](#3-提交信息规范-commit-message)。
    ```bash
    git add .
    git commit -m "feat(spi): add w25q128 basic read/write driver"
    ```

4.  **合并回主分支**：
    完成功能并自测通过后，合并回 `main`。推荐使用 **Squash Merge** (压缩合并)，将该功能的所有琐碎提交合并为一个干净的提交。

    **方式 A：使用命令行**
    ```bash
    git checkout main
    git merge --squash feat/spi-w25q-driver
    git commit -m "feat(spi): integrate W25Q128 driver"
    git push origin main
    ```

    **方式 B：使用 Pull Request (推荐)**
    在 GitHub 上发起 PR，Code Review 后选择 "Squash and merge"。

5.  **删除功能分支**：
    ```bash
    git branch -D feat/spi-w25q-driver
    ```

---

## 3. 提交信息规范 (Commit Message)

采用 **Conventional Commits** 规范，格式如下：

```text
<type>(<scope>): <subject>
```

### Type (类型)
*   `feat`: 新功能
*   `fix`: 修复 Bug
*   `docs`: 文档变更
*   `style`: 代码格式调整 (不影响逻辑)
*   `refactor`: 代码重构 (既不是新增功能也不是修改 bug)
*   `perf`: 性能优化
*   `test`: 增加测试
*   `chore`: 构建过程或辅助工具的变动

### Scope (范围)
可选，指明影响的模块，如 `uart`, `spi`, `rtos`, `cmake`, `doc`。

### Subject (主题)
简短描述变更内容，使用祈使句，不以句号结尾。

**示例**：
*   `feat(uart): add DMA receive support with ring buffer`
*   `fix(os): fix stack overflow in sensor_task`
*   `docs(readme): update architecture diagram`
*   `chore(cmake): enable verbose makefile`

---

## 4. 产物管理 (Artifacts)

嵌入式项目的编译产物（二进制文件）不应提交到 Git 仓库中（避免仓库膨胀），而应通过 **Releases** 托管。

### `.gitignore` 配置检查
确保以下文件被忽略：
```text
build/
*.bin
*.hex
*.elf
*.map
*.o
.vscode/
```

### 发布清单
每次 Release 应包含：
1.  **`app.bin`**: 原始二进制，用于 IAP/OTA。
2.  **`app.hex`**: 十六进制文件，用于 ST-Link Utility / J-Flash 烧录。
3.  **`app.elf`**: 包含调试信息，用于 GDB 调试（可选，文件较大）。
4.  **`app.map`**: 链接映射文件，用于分析内存布局和栈使用情况（**强烈建议保留**，排查 HardFault 神器）。

---

## 5. 常用命令速查

| 场景 | 命令 |
|:---|:---|
| **查看分支** | `git branch -a` |
| **同步远程** | `git fetch --all --prune` |
| **暂存当前修改** | `git stash` |
| **恢复暂存修改** | `git stash pop` |
| **放弃本地修改** | `git checkout .` |
| **查看提交历史** | `git log --oneline --graph --decorate --all` |
