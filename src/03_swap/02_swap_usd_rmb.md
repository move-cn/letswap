# 固定汇率交换

本章实现一个固定币对的兑换合约：用户可以在 `RMB` 和 `USD` 之间按固定汇率交换。代码重点不是经济模型，而是让读者理解 Swap 合约的最小结构：共享资金池、存款、兑换、管理员提取。

## 本章目标

- 使用 `Balance<T>` 保存资金池储备
- 使用 shared object 让所有用户访问同一个 `Bank`
- 使用 `AdminCap` 控制管理员提取权限
- 理解固定汇率模型的局限

## 依赖配置

源码路径：`src/03_swap/code/02_swap_usd_rmb/Move.toml`

```toml
[package]
name = "swap"
version = "0.0.1"
edition = "2024.beta"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }
CoinOwner = { local= "../../../02_coin/code/02_coin_owner" }

[addresses]
swap = "0x0"
```

`CoinOwner` 提供前面章节创建的 `USD` 和 `RMB` 类型。

## 完整代码

源码路径：`src/03_swap/code/02_swap_usd_rmb/sources/swap.move`

```move
#[allow(lint(self_transfer))]
module swap::swap ;
use sui::balance;
use sui::balance::Balance;
use sui::coin;
use sui::coin::Coin;
use sui::transfer::{transfer, share_object, public_transfer};
use sui::tx_context::sender;
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
        rmb: balance::zero<RMB>(),
        usd: balance::zero<USD>()
    };

    share_object(bank);

    let admin_cap = AdminCap { id: object::new(ctx) };

    transfer(admin_cap, sender(ctx));
}

public fun deposit_rmb(bank: &mut Bank, rmb: Coin<RMB>, _: &mut TxContext) {
    let rmb_balance = coin::into_balance(rmb);
    bank.rmb.join(rmb_balance);
}

public fun deposit_usd(bank: &mut Bank, usd: Coin<USD>, _: &mut TxContext) {
    let usd_balance = coin::into_balance(usd);
    bank.usd.join(usd_balance);
}

public fun withdraw_rmb(_: &AdminCap, bank: &mut Bank, amt: u64, ctx: &mut TxContext) {
    let rmb_balance = bank.rmb.split(amt);
    let rmb = coin::from_balance(rmb_balance, ctx);
    public_transfer(rmb, sender(ctx));
}

public fun swap_rmb_usd(bank: &mut Bank, rmb: Coin<RMB>, ctx: &mut TxContext) {
    let amt = rmb.value();
    bank.rmb.join(coin::into_balance(rmb));

    let amt_usd = amt * 10000 / 73000;
    let usd_balance = bank.usd.split(amt_usd);
    let usd = coin::from_balance(usd_balance, ctx);

    public_transfer(usd, sender(ctx));
}

public fun swap_usd_rmb(bank: &mut Bank, usd: Coin<USD>, ctx: &mut TxContext) {
    let amt = usd.value();
    bank.usd.join(coin::into_balance(usd));

    let amt_rmb = amt * 73000 / 10000;
    let rmb_balance = bank.rmb.split(amt_rmb);
    let rmb = coin::from_balance(rmb_balance, ctx);

    public_transfer(rmb, sender(ctx));
}
```

## 资金池结构

```move
public struct Bank has key {
    id: UID,
    rmb: Balance<RMB>,
    usd: Balance<USD>
}
```

`Bank` 是 shared object，保存两种币的储备。用户兑换时，把一种币转入池子，再从另一种储备里取出对应数量。

## 汇率计算

本章使用固定汇率：

```text
1 USD = 7.3 RMB
```

为了避免浮点数，代码把 7.3 表示成 `73000 / 10000`：

```move
let amt_usd = amt * 10000 / 73000;
let amt_rmb = amt * 73000 / 10000;
```

Move 的整数除法会向下取整，因此小额兑换可能有精度损失。

## 调用流程

```shell
cd src/03_swap/code/02_swap_usd_rmb
sui move build
sui client publish
```

发布后记录：

- `Bank` 共享对象 ID
- `AdminCap` 对象 ID
- 前面 Coin 章节发布得到的 `TreasuryCap<RMB>` 和 `TreasuryCap<USD>`

典型流程：

```text
mint RMB/USD -> deposit_rmb/deposit_usd -> swap_rmb_usd/swap_usd_rmb -> withdraw_rmb
```

## 安全分析

固定汇率模型只适合教学，生产环境不能直接使用：

- 储备可能被耗尽：如果池子 USD 不够，`split` 会失败
- 没有滑点保护：用户不能指定最少收到多少
- 没有手续费：无法激励流动性提供者
- 固定价格容易被套利：真实市场价格变化后，池子会被低价买空

这些问题会在 Uniswap V2 章节用 AMM 模型进一步解决。

## 本章小结

本章完成了最小固定汇率 Swap。它展示了 Swap 合约的基本形态：共享资金池、两种储备、用户输入一种 Coin、合约输出另一种 Coin。这个模型简单清晰，但没有市场定价能力，只能作为理解 AMM 前的过渡。
