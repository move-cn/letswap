# 环境搭建

在开始编写智能合约之前，我们需要搭建 Sui Move 的开发环境。本章将引导你完成所有必要的工具安装和配置。

## 前置条件

- 一台 macOS、Linux 或 Windows（WSL）电脑
- 基本的命令行操作能力
- 稳定的网络连接

## 安装 Sui CLI

Sui CLI 是与 Sui 区块链交互的核心工具，用于编译、测试、发布合约以及管理账户。

### macOS / Linux

使用 Homebrew 安装（推荐）：

```shell
brew install sui
```

或者通过 Cargo 安装：

```shell
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch mainnet sui
```

### Windows（WSL）

在 WSL 终端中执行：

```shell
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch mainnet sui
```

### 验证安装

```shell
sui --version
```

看到版本号输出（如 `sui 1.x.x`）即表示安装成功。

## 创建钱包和账户

安装好 CLI 后，需要创建一个钱包来管理你的账户。

### 初始化客户端

```shell
sui client
```

首次运行会提示你创建钱包，选择以下选项：

```
Creating config folder [/home/user/.sui/sui_config]
? Select network: Testnet
? Select key scheme: ed25519
```

初始化完成后，会自动生成一个地址和助记词。**请务必将助记词妥善保存，切勿泄露给任何人。**

### 查看当前地址

```shell
sui client active-address
```

输出类似：

```
0x1fdcbc218b29c5d91eb445781016a24658c45825a8469b76f0efb289ccc89f86
```

### 查看所有地址

```shell
sui client addresses
```

### 切换网络

```shell
# 切换到测试网
sui client switch --env testnet

# 切换到主网
sui client switch --env mainnet
```

## 获取测试币

在测试网上发布合约和执行交易需要 SUI 作为 Gas 费。通过水龙头获取免费的测试 SUI：

```shell
sui client faucet
```

或者访问 Sui Discord 的 #testnet-faucet 频道获取。

查看余额：

```shell
sui client gas
```

输出类似：

```
╭─────────────────────────────────────────────────────────────────────╮
│  Coin         │  Balance                                │
├───────────────┼─────────────────────────────────────────┤
│  0x2::sui::SUI│  1000000000 MIST (1.00 SUI)            │
╰─────────────────────────────────────────────────────────────────────╯
```

> 注意：1 SUI = 10^9 MIST（即 1,000,000,000 MIST）。

## Move 项目结构

一个标准的 Move 项目包含以下文件和目录：

```
my_project/
├── Move.toml          # 项目配置文件（依赖、地址）
├── sources/           # 源代码目录
│   └── my_module.move
└── tests/             # 测试代码目录（可选）
    └── my_module_tests.move
```

### Move.toml 配置文件

`Move.toml` 是项目的核心配置文件，包含三个主要部分：

```toml
[package]
name = "my_project"        # 项目名称
edition = "2024.beta"      # Move 版本

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }

[addresses]
my_project = "0x0"         # 命名地址
```

- `[package]`：定义项目名称和 Move 语言版本
- `[dependencies]`：声明依赖项，`Sui` 是必须的框架依赖
- `[addresses]`：定义命名地址，`0x0` 表示发布时由 CLI 自动分配

## 编写第一个合约

创建一个简单的 Hello World 合约来验证环境。

### 创建项目

```shell
mkdir hello_sui && cd hello_sui
mkdir sources
```

### 创建 Move.toml

```shell
cat > Move.toml << 'EOF'
[package]
name = "hello_sui"
edition = "2024.beta"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }

[addresses]
hello_sui = "0x0"
EOF
```

### 编写合约代码

创建 `sources/hello.move`：

```move
module hello_sui::hello {
    use std::string;
    use sui::event;

    /// 一个简单的问候对象
    public struct Hello has key {
        id: UID,
        message: string::String,
    }

    /// 创建一个新的 Hello 对象并转移给调用者
    public entry fun say_hello(ctx: &mut TxContext) {
        let hello = Hello {
            id: object::new(ctx),
            message: string::utf8(b"Hello, Sui!"),
        };
        event::emit(SaidHello {
            message: string::utf8(b"Hello, Sui!"),
        });
        transfer::public_transfer(hello, tx_context::sender(ctx));
    }

    public struct SaidHello has copy, drop {
        message: string::String,
    }
}
```

### 编译合约

```shell
sui move build
```

编译成功后不会报错。如果出现错误，请检查代码和 Move.toml 配置。

### 运行测试

```shell
sui move test
```

### 发布合约

确保已切换到测试网并有足够的 Gas：

```shell
sui client publish
```

发布成功后，终端会输出交易结果，包含：

- **Published Objects**：新发布的 Package ID
- **Created Objects**：新创建的对象（如 Hello 对象）
- **Transaction Digest**：交易哈希

### 查看发布结果

你可以在 Sui Explorer 中查看发布结果：

```
https://suiscan.xyz/testnet/tx/<TRANSACTION_DIGEST>
```

将 `<TRANSACTION_DIGEST>` 替换为你实际得到的交易哈希。

## IDE 推荐

### VS Code

1. 安装 VS Code
2. 安装 "Move" 扩展（搜索 "move-analyzer"）
3. 打开项目目录，扩展会自动识别 Move.toml 并提供语法高亮和代码补全

### 功能特性

- 语法高亮
- 代码补全
- 跳转到定义
- 错误提示

## 常见问题

### 编译报错：找不到 Sui 框架

确保 Move.toml 中的 Sui 依赖地址正确，且网络可以访问 GitHub。如果网络不稳定，可以多次重试。

### 发布报错：Gas 不足

确保测试网账户有足够的 SUI：

```shell
sui client faucet
sui client gas
```

### 编译报错：版本不匹配

确保 sui CLI 版本较新：

```shell
sui --version
# 建议使用 1.x 以上版本
```

如果版本过旧，重新安装最新版：

```shell
brew upgrade sui
```

## 本章小结

本章完成了以下环境的搭建：

- 安装并验证了 Sui CLI
- 创建了钱包和测试网账户
- 获取了测试用的 SUI
- 了解了 Move 项目的标准结构
- 编译、测试并发布了第一个合约

接下来，我们将深入学习 Sui 上的 Coin 代币标准。
