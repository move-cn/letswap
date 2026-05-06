# 通用多币对交换

上一章把币种写死为 `RMB` 和 `USD`。本章把资金池改成泛型结构 `Bank<phantom CoinA, phantom CoinB>`，让同一套代码可以创建任意两个 Coin 的固定汇率池。

## 本章目标

- 理解 `phantom` 类型参数
- 使用泛型定义通用资金池
- 对比固定币对版本与泛型版本
- 理解泛型 Swap 的扩展边界

## 完整代码

源码路径：`src/03_swap/code/03_swap_generic/sources/swap_generic.move`

```move
#[allow(lint(self_transfer))]
module swap_generic::swap_generic ;

use sui::balance;
use sui::balance::Balance;
use sui::coin;
use sui::coin::Coin;
use sui::transfer::{share_object, public_transfer};
use sui::tx_context::sender;

public struct AdminCap has key {
    id: UID,
}

public struct Bank<phantom CoinA, phantom CoinB> has key {
    id: UID,
    a: Balance<CoinA>,
    b: Balance<CoinB>
}

fun init(_ctx: &TxContext) {
    // let admin_cap = AdminCap { id: object::new(ctx) };
    // transfer(admin_cap, sender(ctx));
}

public fun create<CoinA, CoinB>(ctx: &mut TxContext) {
    let pool = Bank<CoinA, CoinB> {
        id: object::new(ctx),
        a: balance::zero<CoinA>(),
        b: balance::zero<CoinB>(),
    };
    share_object(pool);
}

public fun deposit_a<CoinA, CoinB>(bank: &mut Bank<CoinA, CoinB>, a: Coin<CoinA>, _: &mut TxContext) {
    let a_balance = coin::into_balance(a);
    bank.a.join(a_balance);
}

public fun deposit_b<CoinA, CoinB>(bank: &mut Bank<CoinA, CoinB>, b: Coin<CoinB>, _: &mut TxContext) {
    let b_balance = coin::into_balance(b);
    bank.b.join(b_balance);
}

public fun swap_a_b<CoinA, CoinB>(bank: &mut Bank<CoinA, CoinB>, a: Coin<CoinA>, ctx: &mut TxContext) {
    let amt = coin::value(&a);

    bank.a.join(coin::into_balance(a));

    let amt_b = amt;
    let b_balance = bank.b.split(amt_b);
    let b = coin::from_balance(b_balance, ctx);

    public_transfer(b, sender(ctx));
}
```

## 为什么使用 `phantom`

`Bank` 的字段是 `Balance<CoinA>` 和 `Balance<CoinB>`，类型参数只用于标记余额类型，不直接作为普通字段值参与能力推导，因此可以写成：

```move
public struct Bank<phantom CoinA, phantom CoinB> has key
```

这样不同币对会得到不同类型的池子：

- `Bank<SUI, USDC>`
- `Bank<USDC, USDT>`
- `Bank<RMB, USD>`

它们在类型系统里互不混淆。

## 创建池子

```move
public fun create<CoinA, CoinB>(ctx: &mut TxContext)
```

调用时需要提供两个类型参数。函数会创建一个共享的 `Bank<CoinA, CoinB>`，内部两边余额都初始化为 0。

## 与固定币对版本对比

| 维度 | 固定币对版本 | 泛型版本 |
|------|--------------|----------|
| 支持币种 | 只支持 `RMB/USD` | 任意 `CoinA/CoinB` |
| 代码复杂度 | 简单 | 稍高 |
| 类型安全 | 具体类型写死 | 类型参数区分池子 |
| 汇率 | 固定 7.3 | 当前示例为 1:1 |
| 适合用途 | 入门理解 | 多币对扩展 |

## 局限

本章仍是固定数量兑换，`swap_a_b` 中直接使用：

```move
let amt_b = amt;
```

这意味着 `1 CoinA = 1 CoinB`。真实 DEX 不能这样定价，需要使用 AMM 公式、订单簿或预言机价格。后续 Uniswap V2 章节会进入真正的自动定价模型。

## 本章小结

泛型让同一套合约支持多个币对，`phantom` 让类型参数只作为类型标记存在。这个版本解决了“只能写死 USD/RMB”的扩展问题，但仍没有解决“价格如何由市场决定”的核心问题。
