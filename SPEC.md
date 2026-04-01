# ScreenshotCleaner - iOS截图清理工具

## 1. Project Overview

- **Project Name**: ScreenshotCleaner
- **Bundle Identifier**: com.example.ScreenshotCleaner
- **Core Functionality**: 扫描iOS相册中的所有截图，按时间分组展示，允许用户选择并批量删除
- **Target Users**: 需要清理相册中大量截图的iOS用户
- **iOS Version Support**: iOS 15.0+

## 2. UI/UX Specification

### Screen Structure

1. **Main Screen (ScreenshotListViewController)**
   - 导航栏标题: "截图清理"
   - 右上角: 编辑按钮 (Edit)
   - 主内容: 按日期分组的截图列表
   - 底部: 删除按钮 (当有选中项时显示)

### Navigation Structure
- UINavigationController 包裹主页面

### Visual Design

**Color Palette**
- Primary: #007AFF (iOS系统蓝色)
- Background: #F2F2F7 (iOS系统浅灰背景)
- Card Background: #FFFFFF
- Text Primary: #000000
- Text Secondary: #8E8E93
- Destructive: #FF3B30 (iOS红色)
- Selection Tint: #007AFF with 10% opacity

**Typography**
- Navigation Title: SF Pro Bold, 17pt
- Section Header: SF Pro Semibold, 13pt
- Cell Title (日期): SF Pro Regular, 13pt
- Screenshot Count: SF Pro Regular, 13pt

**Spacing System (8pt grid)**
- Cell horizontal padding: 16pt
- Cell vertical padding: 12pt
- Grid item spacing: 2pt
- Section header padding: 16pt horizontal, 8pt vertical

### Views & Components

**1. Screenshot Collection View**
- 布局: 3列网格布局
- 每个item: 缩略图 + 可选checkbox
- Item size: (屏幕宽度 - 32 - 4) / 3 (正方形)
- Selection mode: 多选
- Corner radius: 0 (保持原图比例)

**2. Section Header**
- 显示格式: "2024年3月15日 周五"
- 显示该日期下的截图数量: "12张截图"

**3. Bottom Delete Bar**
- 高度: 60pt + safe area
- 背景: #FFFFFF with shadow
- 删除按钮: 红色背景, 白色文字, 圆角8pt
- 按钮文字: "删除所选 (X)"

**4. Empty State View**
- 图标: photo.on.rectangle (SF Symbol)
- 文字: "没有找到截图"
- 副文字: "您的相册中没有截图"

### Interactive Behaviors

- 点击checkbox: 切换选中状态
- 点击编辑按钮: 进入/退出编辑模式
- 编辑模式下点击item: 切换选中状态
- 非编辑模式下点击item: 可以预览 (可选, MVP暂不实现)
- 删除按钮点击: 弹出确认对话框

## 3. Functionality Specification

### Core Features

1. **读取相册截图** (Priority: High)
   - 使用 Photos 框架访问相册
   - 筛选条件: mediaSubtype == .screenshot
   - 按creationDate降序排列

2. **分组展示** (Priority: High)
   - 按日期分组 (年-月-日)
   - 每组显示日期标题和截图数量
   - 组内按时间降序排列

3. **选择功能** (Priority: High)
   - 编辑模式下显示checkbox
   - 支持多选
   - 显示已选择数量

4. **删除功能** (Priority: High)
   - 批量删除选中的截图
   - 删除前弹出确认对话框
   - 删除后刷新列表

### User Interactions and Flows

1. **启动流程**
   - 请求相册访问权限
   - 加载截图列表
   - 显示loading状态

2. **编辑流程**
   - 用户点击"编辑"
   - 显示所有checkbox
   - 显示底部删除栏

3. **删除流程**
   - 用户选择截图
   - 点击"删除所选"
   - 弹出确认对话框
   - 确认后执行删除
   - 刷新列表

### Architecture Pattern
- **MVC** (Model-View-Controller)
- Models: ScreenshotItem
- Views: UICollectionView with custom cells
- Controllers: ScreenshotListViewController

### Edge Cases and Error Handling

1. **无相册权限**: 显示权限请求界面
2. **无截图**: 显示空状态视图
3. **删除失败**: 显示错误提示
4. **加载中**: 显示loading indicator

## 4. Technical Specification

### Required Dependencies

**Swift Package Manager**
- SnapKit (5.7.0+): Auto Layout布局

### UI Framework
- UIKit

### Third-Party Libraries
- SnapKit: 声明式Auto Layout

### Asset Requirements

**SF Symbols**
- photo.on.rectangle: 空状态图标
- trash: 删除按钮图标
- checkmark.circle.fill: 选中状态
- circle: 未选中状态
- chevron.left: 返回图标
