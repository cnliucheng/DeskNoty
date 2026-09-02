# Noty 项目分析报告

## 项目概述
Noty 是一个原生 macOS 便签应用，使用 Swift、SwiftUI 和 AppKit 构建。便签贴靠在屏幕边缘，支持三种状态：静止（pill）、展开（fan）、编辑（expanded）。项目使用 MIT 许可证，可以自由修改和分发。

## 项目结构
```
noty/
├── Sources/                    # 源代码目录
│   ├── Main.swift             # 应用入口点
│   ├── AppDelegate.swift      # 应用委托，生命周期管理
│   ├── Core.swift             # 核心数据模型和工具
│   ├── Store.swift            # SQLite 数据库操作
│   ├── NoteStore.swift        # 可观察数据模型
│   ├── DeckController.swift   # Deck 状态机和控制器
│   ├── DeckPanel.swift        # NSPanel 子类
│   ├── DeckViews.swift        # SwiftUI 视图组件
│   ├── NoteEditor.swift       # 编辑器桥接
│   ├── Settings.swift         # 用户偏好设置
│   ├── HotKeys.swift          # 全局快捷键
│   ├── ExportImport.swift     # 导出导入功能
│   ├── LibraryWindow.swift    # 笔记库窗口
│   ├── UndoToast.swift        # 撤销提示
│   ├── QuickCapture.swift     # 快速捕获
│   ├── SettingsWindow.swift   # 设置窗口
│   ├── Updater.swift          # Sparkle 更新器
│   └── DeckLog.swift          # 调试日志
├── Tests/                      # 测试文件
├── scripts/                    # 构建脚本
├── Resources/                  # 资源文件
├── Info.plist                  # 应用配置
├── build.sh                    # 构建脚本
└── README.md                   # 项目说明
```

## 核心依赖关系

### 系统框架
1. **SQLite3** - 本地数据库存储
2. **CryptoKit** - AES-GCM 加密笔记内容
3. **AppKit** - macOS 原生 UI 框架
4. **SwiftUI** - 声明式 UI 框架
5. **Combine** - 响应式编程框架

### 可选依赖
- **Sparkle** - 自动更新框架（MIT 许可证）

## 核心模块分析

### 1. Core.swift - 核心数据模型
**主要功能：**
- **Paths** - 文件路径管理（数据库、加密密钥）
- **Crypto** - AES-GCM 加密/解密笔记内容
- **NoteColor** - 颜色调色板（8种预设颜色）
- **Ink** - 字体管理和缩放
- **Note** - 笔记数据模型（id, title, body, color, created, modified, archived, pinned, textDirection, order）
- **Tasks** - 复选框任务处理（☐/☑ 语法）
- **NoteTextDirection** - 文本方向支持（自动、从左到右、从右到左）

**关键实现细节：**
- 加密密钥存储在 `~/Library/Application Support/Noty/note.key`（0600 权限）
- 使用 AES-256-GCM 加密笔记内容，标题和元数据明文存储
- 支持双向文本（RTL/LTR），自动检测文本方向
- 任务语法：`☐` 表示未完成，`☑` 表示已完成

### 2. Store.swift - 数据库操作
**主要功能：**
- SQLite 数据库初始化和迁移
- 笔记的 CRUD 操作（创建、读取、更新、删除）
- WAL 模式和同步设置

**关键实现细节：**
- 数据库路径：`~/Library/Application Support/Noty/notes.db`
- 表结构：`notes` 表包含 id, title, body, color, created, modified, archived, sort_order, pinned, text_direction
- 使用 `INSERT ... ON CONFLICT DO UPDATE` 进行 upsert 操作
- 支持数据库迁移（添加新列如 pinned、text_direction）

### 3. DeckController.swift - Deck 状态机
**主要功能：**
- 管理每个显示器的 deck 实例
- 状态机：rest → fan → expanded
- 处理鼠标交互、拖拽、快捷键
- 上下文菜单和设置管理

**关键实现细节：**
- **DeckState** 枚举：rest（静止）、fan（展开）、expanded（编辑）
- **DeckModel** - 可观察对象，包含所有 UI 状态
- **DeckController** - 控制器，管理面板布局和状态转换
- **DeckManager** - 管理多个显示器的 deck 实例
- 支持多显示器，每个显示器一个 deck 实例
- 空闲检测：fan 状态 4 秒后折叠，expanded 状态 1 分钟后关闭
- 支持拖拽重新排列笔记
- 支持固定笔记（pinned）

### 4. NoteStore.swift - 数据管理
**主要功能：**
- 单一数据源模式
- 笔记的增删改查操作
- 撤销功能（10秒窗口）
- 笔记排序和重新排列

**关键实现细节：**
- 使用 Combine 框架进行响应式更新
- 支持笔记归档和恢复
- 支持批量导入
- 排序使用 `sort_order` 字段

## 修改建议

### 1. UI/UX 修改
- **DeckViews.swift** - 修改 deck 样式、动画、布局
- **NoteEditor.swift** - 自定义编辑器行为、快捷键
- **SettingsWindow.swift** - 添加新的设置选项

### 2. 功能扩展
- **添加新功能**：在 NoteStore.swift 中添加新的数据操作
- **修改加密方式**：在 Core.swift 中调整 Crypto 实现
- **扩展导出格式**：在 ExportImport.swift 中添加新格式

### 3. 数据库修改
- **添加新字段**：在 Store.swift 中修改表结构
- **数据迁移**：在 migrate() 方法中添加迁移逻辑
- **查询优化**：修改 load() 方法的查询

### 4. 快捷键和交互
- **HotKeys.swift** - 添加新的全局快捷键
- **DeckController.swift** - 修改交互逻辑

### 5. 构建和分发
- **build.sh** - 修改构建配置
- **Info.plist** - 更新应用信息
- **Sparkle 集成** - 更新自动更新机制

## 注意事项
1. 项目未沙盒化，数据存储在 `~/Library/Application Support/Noty/`
2. 使用自签名证书，首次运行需要右键→打开
3. 支持 macOS 15+，需要 Swift 工具链
4. 加密密钥与数据库存储在同一目录
5. 使用 Carbon API 实现全局快捷键（无需辅助功能权限）

## 开发建议
1. 先熟悉项目结构，特别是 Core.swift 和 Store.swift
2. 使用 `NOTY_DEBUG_DECK=1` 环境变量调试 deck 状态
3. 修改 UI 前先了解 DeckViews.swift 的布局系统
4. 数据库修改前先备份现有数据
5. 测试时注意多显示器场景