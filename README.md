# Mobile Automation Framework with Ruby, RSpec, and Appium

这是一个使用Ruby、RSpec和Appium基于Page Object Model (POM)模式构建的移动自动化测试框架，支持Android和iOS平台的测试。

## 功能特点

- 页面对象模型(POM)架构
- 跨平台支持(Android和iOS)
- 智能元素定位，支持多种定位策略
- 自动截图和日志记录
- 丰富的重试和恢复机制
- 并行测试执行
- RSpec HTML报告集成
- 灵活的测试配置
- 健壮的错误处理

## 前提条件

- Ruby 2.7或更高版本
- Bundler
- Appium Server 2.0或更高版本
- Android SDK (用于Android测试)
- Xcode (用于iOS测试)
- Android模拟器或真机
- iOS模拟器或真机

## 项目结构

```
.
├── apps/                   # 移动应用文件 (.apk, .app)
├── config/                 # 能力配置文件
├── lib/
│   ├── pages/              # 页面对象
│   └── utils/              # 工具和辅助类
├── logs/                   # 测试执行日志
├── reports/
│   ├── html/               # HTML测试报告
│   └── screenshots/        # 测试截图
├── spec/
│   ├── login/              # 登录测试规范
│   └── spec_helper.rb      # RSpec配置
├── .env                    # 本地环境变量配置(不应提交到版本控制)
├── .env.example            # 环境变量示例模板
├── .gitignore              # Git忽略配置
├── Gemfile                 # Ruby依赖
├── Rakefile                # 任务定义
└── README.md               # 文档
```

## 安装设置

1. 克隆仓库:

```bash
git clone <repository-url>
cd <repository-name>
```

2. 安装依赖:

```bash
bundle install
# 或使用Rake任务
rake setup:install
```

3. 设置环境变量:

```bash
cp .env.example .env
```

4. 编辑`.env`文件，配置您的本地测试环境:
   - 设置Android和iOS设备信息
   - 配置应用路径
   - 修改Appium服务器URL(如需要)

5. 将SauceLabs Demo应用文件放入`apps`目录:
   - Android: `apps/SauceLabs-Demo-App.apk` (如已安装在设备上可选)
   - iOS: `apps/SauceLabs-Demo-App.app`

## 运行测试

### 启动Appium服务器

Android测试(端口4723):
```bash
appium -p 4723
```

iOS测试(端口4724):
```bash
appium -p 4724
```

### 运行测试

运行所有Android测试:
```bash
bundle exec rake test:android
```

运行所有iOS测试:
```bash
bundle exec rake test:ios
```

只运行Android登录测试:
```bash
bundle exec rake test:android_login
```

只运行iOS登录测试:
```bash
bundle exec rake test:ios_login
```

同时在Android和iOS上运行测试:
```bash
bundle exec rake test:parallel
```

## 清理测试资源

清理所有测试结果:
```bash
bundle exec rake clean:all
```

只清理测试报告:
```bash
bundle exec rake clean:results
```

只清理截图:
```bash
bundle exec rake clean:screenshots
```

只清理测试日志:
```bash
bundle exec rake clean:logs
```

## 查看测试报告

测试执行完成后，HTML报告会自动生成在`reports/html`目录中。你可以使用以下命令打开报告：

```bash
bundle exec rake report:open
```

## 完整测试流程

执行完整测试套件并生成报告:
```bash
bundle exec rake full_test
```

## SauceLabs样例应用说明

本框架使用的SauceLabs样例应用(Swag Labs)是一个用于测试的演示应用。默认登录凭据为:

- 用户名: `standard_user`
- 密码: `secret_sauce`

## 框架优化特性

1. **多策略元素定位**：
   - 支持多种定位策略，提高元素查找成功率
   - iOS使用class chain和predicate string作为备选策略

2. **智能等待和重试**：
   - 自动重试失败的元素查找
   - 智能等待页面加载
   - 平台特定的等待时间

3. **健壮的会话管理**：
   - 使用`terminate_app`和`activate_app`替代已废弃的`reset`
   - 会话创建失败时自动恢复

4. **详细日志和调试**：
   - 详细的测试执行日志
   - 失败时自动截图
   - 保存页面源码用于调试

5. **错误处理和恢复**：
   - 捕获和处理常见的测试错误
   - 崩溃恢复机制

## 添加新测试

1. 在`lib/pages/`中创建新的页面对象
2. 在`spec/`中创建新的测试规范
3. 如有需要，更新`spec_helper.rb`引入新的页面对象

## 许可证

本项目使用MIT许可证 