# 固定币对交换：USD/RMB 合约实现

在上一章中，我们理解了固定汇率交换的核心原理。本章将动手实现一个完整的 USD/RMB 兑换合约，包含储备存入、管理员提取、双向兑换等全部功能。

## 本章目标

- 实现一个 Bank 共享对象，用于托管 USD 和 RMB 的储备
- 实现管理员存入和提取储备的接口
- 实现 RMB 与 USD 之间的固定汇率双向兑换
- 理解 AdminCap 权限控制模式
- 掌握 Balance 与 Coin 类型的转换操作

## 项目配置

本章的项目位于 `src/03_swap/code/02_swap_usd_rmb` 目录下。在编写合约之前，需要先配置好项目的依赖关系。

### Move.toml

```toml
[package]
name = "swap"
version = "0.0.1"
edition = "2024.beta"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }
CoinOwner = { local = "../../../02_coin/code/02_coin_owner" }

[addresses]
swap = "0x0"
```

### 依赖说明

这里有两个依赖：

- **Sui**：Sui 框架，提供了 `coin`、`balance`、`transfer` 等标准库模块。
- **CoinOwner**：我们在第二章中创建的 Coin 项目，其中包含了 `coin_owner::usd::USD` 和 `coin_owner::rmb::RMB` 两个 Coin 类型。这里通过 `local` 路径引用它，使我们的 Swap 合约可以直接使用已发布的 USD 和 RMB 类型。

> 注意：`local` 路径是相对于 `Move.toml` 文件所在目录计算的。本项目的 `Move.toml` 位于 `code/02_swap_usd_rmb/` 下，因此需要用 `../../../02_coin/code/02_coin_owner` 回溯到 Coin 项目目录。

## 完整代码展示

以下是 `sources/swap.move` 的完整代码：

```move
module swap::swap {
    use sui::balance;
    use sui::balance::Balance;
    use sui::coin;
    use sui::coin::Coin;
    use sui::object;
    use sui::object::UID;
    use sui::transfer::{transfer, share_object, public_transfer};
    use sui::tx_context::{TxContext, sender};
    use coin_owner::usd::USD;
    use coin_owner::rmb::RMB;

    public struct AdminCap has key {
        id: UID,
    }

    public struct Bank has key {
        id: UID,
        rmb: Balance<RMB>,
        usd: Balance<USD>
    }

    fun init(ctx: &mut TxContext) {
        let bank = Bank {
            id: object::new(ctx),
            rmb: balance::zero(),
            usd: balance::zero()
        };
        share_object(bank);
        let admin_cap = AdminCap { id: object::new(ctx) };
        transfer(admin_cap, sender(ctx));
    }

    public entry fun deposit_rmb(bank: &mut Bank, rmb: Coin<RMB>, _: &mut TxContext) {
        let rmb_balance = coin::into_balance(rmb);
        bank.rmb.join(rmb_balance);
    }

    public entry fun deposit_usd(bank: &mut Bank, usd: Coin<USD>, _: &mut TxContext) {
        let usd_balance = coin::into_balance(usd);
        bank.usd.join(usd_balance);
    }

    public entry fun withdraw_rmb(_: &AdminCap, bank: &mut Bank, amt: u64, ctx: &mut TxContext) {
        let rmb_balance = bank.rmb.split(amt);
        let rmb = coin::from_balance(rmb_balance, ctx);
        public_transfer(rmb, sender(ctx));
    }

    /// 1 usd = 1 rmb
    public entry fun swap_rmb_usd(bank: &mut Bank, rmb: Coin<RMB>, ctx: &mut TxContext) {
        let amt = rmb.value();
        bank.rmb.join(coin::into_balance(rmb));
        let amt_usd = amt * 10000 / 73000;
        let usd_balance = bank.usd.split(amt_usd);
        let usd = coin::from_balance(usd_balance, ctx);
        public_transfer(usd, sender(ctx));
    }

    public entry fun swap_usd_rmb(bank: &mut Bank, usd: Coin<USD>, ctx: &mut TxContext) {
        let amt = usd.value();
        bank.usd.join(coin::into_balance(usd));
        let amt_rmb = amt * 73000 / 10000;
        let rmb_balance = bank.rmb.split(amt_rmb);
        let rmb = coin::from_balance(rmb_balance, ctx);
        public_transfer(rmb, sender(ctx));
    }
}
```

## 逐段代码讲解

### AdminCap 与 Bank 结构体

```move
public struct AdminCap has key {
    id: UID,
}
```

`AdminCap` 是一个仅具有 `key` 能力的结构体，它不携带任何业务数据，唯一的作用是作为**权限凭证**。在 Sui 的对象模型中，只有持有某个对象的人才能在交易中传递该对象的引用。因此，只有拥有 `AdminCap` 的地址才能调用需要 `AdminCap` 参数的函数。

这种模式在 Sui Move 中被称为 **Capability 模式**，是一种常见的权限控制手段。

```move
public struct Bank has key {
    id: UID,
    rmb: Balance<RMB>,
    usd: Balance<USD>
}
```

`Bank` 是合约的核心对象，存储了 USD 和 RMB 两种货币的储备余额。

- 具有 `key` 能力，说明它是一个全局对象，可以通过对象 ID 在链上引用
- `rmb` 和 `usd` 字段使用 `Balance<T>` 类型而非 `Coin<T>`。`Balance` 类型不可转移，适合用于在对象内部存储余额；而 `Coin` 类型可以转移，适合在用户之间传递

### init 函数

```move
fun init(ctx: &mut TxContext) {
    let bank = Bank {
        id: object::new(ctx),
        rmb: balance::zero(),
        usd: balance::zero()
    };
    share_object(bank);
    let admin_cap = AdminCap { id: object::new(ctx) };
    transfer(admin_cap, sender(ctx));
}
```

`init` 是模块的初始化函数，在合约发布时自动执行一次。它完成两件事：

**第一步：创建 Bank 共享对象。**

- `balance::zero()` 创建一个余额为零的空储备
- `share_object(bank)` 将 Bank 设置为共享对象。共享对象不属于任何单一地址，所有用户都可以读取和修改它（通过引用传递）。这正是 Bank 需要的特性 -- 任何用户都应该能向它存入代币或执行兑换

**第二步：创建并转移 AdminCap。**

- 创建 `AdminCap` 对象
- `transfer(admin_cap, sender(ctx))` 将它转移给合约发布者地址。只有发布者持有 AdminCap，因此只有发布者能执行管理员操作（如提取储备）

### deposit_rmb 与 deposit_usd

```move
public entry fun deposit_rmb(bank: &mut Bank, rmb: Coin<RMB>, _: &mut TxContext) {
    let rmb_balance = coin::into_balance(rmb);
    bank.rmb.join(rmb_balance);
}

public entry fun deposit_usd(bank: &mut Bank, usd: Coin<USD>, _: &mut TxContext) {
    let usd_balance = coin::into_balance(usd);
    bank.usd.join(usd_balance);
}
```

这两个函数负责向 Bank 中存入储备。以 `deposit_rmb` 为例，流程如下：

1. **`coin::into_balance(rmb)`**：将 `Coin<RMB>` 转换为 `Balance<RMB>`。这个操作会消耗掉 Coin 对象（它不再存在），取出其内部的余额数据
2. **`bank.rmb.join(rmb_balance)`**：将这笔余额合并到 Bank 的 RMB 储备中。`join` 会将传入的余额加到已有的余额上

这两个函数没有权限控制 -- 任何人都可以向 Bank 存入代币，这是合理的，因为存入操作只会增加储备，不会造成资金损失。

### withdraw_rmb

```move
public entry fun withdraw_rmb(_: &AdminCap, bank: &mut Bank, amt: u64, ctx: &mut TxContext) {
    let rmb_balance = bank.rmb.split(amt);
    let rmb = coin::from_balance(rmb_balance, ctx);
    public_transfer(rmb, sender(ctx));
}
```

`withdraw_rmb` 允许管理员从 Bank 中提取 RMB 储备。注意第一个参数 `_: &AdminCap`，它实现了权限控制：

- 调用时必须传入 `AdminCap` 对象的引用
- 由于 `AdminCap` 只转移给了合约发布者，只有发布者能提供这个引用
- 参数名使用 `_`，表示函数内部不使用这个值，它纯粹用于权限验证

提取流程：

1. **`bank.rmb.split(amt)`**：从 Bank 的 RMB 储备中分离出指定数量的余额，返回一个新的 `Balance<RMB>`
2. **`coin::from_balance(rmb_balance, ctx)`**：将 `Balance` 转换回 `Coin`，这样才能通过 `public_transfer` 转移给用户
3. **`public_transfer(rmb, sender(ctx))`**：将提取的 RMB 代币转给调用者

### swap_rmb_usd 与 swap_usd_rmb

这两个函数是合约的核心，实现了两种货币之间的双向兑换。

#### RMB 换 USD

```move
public entry fun swap_rmb_usd(bank: &mut Bank, rmb: Coin<RMB>, ctx: &mut TxContext) {
    let amt = rmb.value();
    bank.rmb.join(coin::into_balance(rmb));
    let amt_usd = amt * 10000 / 73000;
    let usd_balance = bank.usd.split(amt_usd);
    let usd = coin::from_balance(usd_balance, ctx);
    public_transfer(usd, sender(ctx));
}
```

逐行分析：

1. **`rmb.value()`**：获取用户存入的 RMB 数量。注意这里使用的是 `rmb.value()` 而不是 `coin::value(&rmb)`，两种写法等价，Move 支持通过点号语法调用模块函数
2. **`bank.rmb.join(coin::into_balance(rmb))`**：将用户传入的 RMB 合并到 Bank 的储备中。此时用户的 Coin 对象被消耗
3. **`amt * 10000 / 73000`**：按照固定汇率计算应返还的 USD 数量。回顾上一章的汇率公式：1 USD = 7.3 RMB，所以 RMB 转 USD 的计算是 `amt * 10000 / 73000`
4. **`bank.usd.split(amt_usd)`**：从 Bank 的 USD 储备中分离出计算出的数量
5. **`coin::from_balance` + `public_transfer`**：将余额转为 Coin 并转给用户

#### USD 换 RMB

```move
public entry fun swap_usd_rmb(bank: &mut Bank, usd: Coin<USD>, ctx: &mut TxContext) {
    let amt = usd.value();
    bank.usd.join(coin::into_balance(usd));
    let amt_rmb = amt * 73000 / 10000;
    let rmb_balance = bank.rmb.split(amt_rmb);
    let rmb = coin::from_balance(rmb_balance, ctx);
    public_transfer(rmb, sender(ctx));
}
```

逻辑与 `swap_rmb_usd` 完全对称，只是汇率方向相反：USD 转 RMB 使用 `amt * 73000 / 10000`。

## 发布与交互

### 编译合约

进入项目目录并编译：

```shell
cd src/03_swap/code/02_swap_usd_rmb
sui move build
```

如果没有报错，说明编译通过。

### 发布合约

```shell
sui client publish --gas-budget 100000000
```

发布成功后，终端会输出交易结果，其中包含以下关键对象：

- **Bank 对象**：作为共享对象创建，所有用户都可以引用
- **AdminCap 对象**：转移给发布者地址，用于管理员操作

记下 Bank 的对象 ID 和 AdminCap 的对象 ID，后续交互会用到。

### 准备代币

在测试 Swap 之前，需要先确保你的地址拥有 USD 和 RMB 代币。如果之前发布的 Coin 项目使用了共享所有权模式（`public_share_object`），你可以直接铸造：

```shell
# 铸造 1000000000 RMB（考虑精度）
sui client call --package <COIN_PACKAGE_ID> --module rmb --function mint \
  --args <RMB_TREASURY_CAP_ID> 1000000000 --gas-budget 10000000

# 铸造 100000000 USD
sui client call --package <COIN_PACKAGE_ID> --module usd --function mint \
  --args <USD_TREASURY_CAP_ID> 100000000 --gas-budget 10000000
```

### 存入储备

```shell
# 向 Bank 存入 RMB
sui client call --package <SWAP_PACKAGE_ID> --module swap --function deposit_rmb \
  --args <BANK_ID> <RMB_COIN_ID> --gas-budget 10000000

# 向 Bank 存入 USD
sui client call --package <SWAP_PACKAGE_ID> --module swap --function deposit_usd \
  --args <BANK_ID> <USD_COIN_ID> --gas-budget 10000000
```

### 执行兑换

```shell
# 用 RMB 换 USD
sui client call --package <SWAP_PACKAGE_ID> --module swap --function swap_rmb_usd \
  --args <BANK_ID> <RMB_COIN_ID> --gas-budget 10000000

# 用 USD 换 RMB
sui client call --package <SWAP_PACKAGE_ID> --module swap --function swap_usd_rmb \
  --args <BANK_ID> <USD_COIN_ID> --gas-budget 10000000
```

### 管理员提取

```shell
# 从 Bank 中提取 1000 RMB
sui client call --package <SWAP_PACKAGE_ID> --module swap --function withdraw_rmb \
  --args <ADMIN_CAP_ID> <BANK_ID> 1000 --gas-budget 10000000
```

## 安全性分析

### 储备耗尽风险

这是本合约最大的风险。当用户执行兑换时，合约会从 Bank 的储备中分离出对应数量的代币转给用户。如果某种代币的储备不足，`split` 操作会触发运行时中止（abort），导致整个交易失败。

这意味着：

- 用户不会丢失资金（交易回滚，存入的代币会退还）
- 但交易会失败，用户体验不好
- 合约管理者需要确保 Bank 中有足够的储备

在实际的 DeFi 项目中，通常会在兑换前添加储备充足的检查，并在储备不足时提供更友好的错误提示。

### 精度损失

由于 Move 使用整数除法（向下取整），汇率计算中会存在精度损失。以 RMB 换 USD 为例：

```
amt_usd = amt * 10000 / 73000
```

如果用户存入 1 个最小单位的 RMB，则 `1 * 10000 / 73000 = 0`，用户得到 0 个 USD。这不是一个合理的兑换结果。

在实际项目中，通常会设置最小兑换数量，或使用更大的精度因子来减少误差。这些细节在当前的教学合约中暂不处理，但在生产环境中必须考虑。

### 无滑点保护

本合约使用固定汇率，不涉及滑点问题。但在后续章节实现恒定乘积做市商（AMM）模型时，滑点保护将是一个重要的安全议题。

## 本章小结

本章实现了一个完整的固定汇率 USD/RMB 兑换合约。核心知识点包括：

- **Bank 共享对象**：通过 `share_object` 创建，允许所有用户访问，用于托管代币储备
- **AdminCap 权限控制**：使用 Capability 模式限制管理员操作（提取储备）的访问权限
- **Balance 与 Coin 的转换**：`coin::into_balance` 将 Coin 转为 Balance 用于存储，`coin::from_balance` 将 Balance 转回 Coin 用于转移
- **固定汇率计算**：通过整数乘除法实现，避免浮点数精度问题
- **储备管理**：`split` 从储备中分离，`join` 向储备中合并

这个合约的局限性在于：币对（USD/RMB）是硬编码的，如果需要支持新的币对，就必须编写新的合约。在下一章中，我们将引入泛型（Generics）来解决这个问题，实现一个可以支持任意币对的通用 Swap 合约。
