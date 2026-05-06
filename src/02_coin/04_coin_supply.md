# Coin 发行量控制

前面两章直接使用 `TreasuryCap<T>` 控制铸造权限。本章进一步拆解 `TreasuryCap<T>`，把内部的 `Supply<T>` 取出来并封装进自定义对象，从而实现发行上限、共享发行、授权发行和自定义余额封装。

## 本章目标

- 理解 `TreasuryCap<T>` 与 `Supply<T>` 的关系
- 掌握 `coin::treasury_into_supply` 的使用
- 使用 `Supply<T>` 实现发行上限
- 理解为什么 `Balance<T>` 可以嵌入对象，而 `Coin<T>` 是顶层对象

## `TreasuryCap` 与 `Supply`

当前货币创建仍使用 `coin_registry::new_currency_with_otw`，它返回 `TreasuryCap<T>`。如果项目需要更细粒度的发行控制，可以把 `TreasuryCap<T>` 消耗掉，取出内部的 `Supply<T>`：

```move
let supply = coin::treasury_into_supply(treasury);
```

此后不再持有 `TreasuryCap<T>`，而是通过 `Supply<T>` 直接增加或减少发行量：

| 方法 | 作用 |
|------|------|
| `supply.increase_supply(amount)` | 增发，返回 `Balance<T>` |
| `balance::supply_value(&supply)` | 查询当前发行量 |
| `supply.decrease_supply(balance)` | 销毁对应余额 |

## 基本封装：`SupplyHold`

源码路径：`src/02_coin/code/04_coin_supply/sources/rmb.move`

```move
module coin_supply::rmb ;
use sui::balance;
use sui::balance::Supply;
use sui::coin::{Self, Coin};
use sui::coin_registry;
use std::string;

public struct RMB has drop {}

public struct SupplyHold has key {
    id: UID,
    supply: Supply<RMB>
}

fun init(witness: RMB, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"RMB"),
        string::utf8(b""),
        string::utf8(b""),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);

    let supply = coin::treasury_into_supply(treasury);

    let supply_hold = SupplyHold {
        id: object::new(ctx),
        supply
    };
    transfer::share_object(supply_hold);
}

public fun mint2(sup: &mut SupplyHold, amount: u64, ctx: &mut TxContext): Coin<RMB> {
    let rmb_balance = balance::increase_supply(&mut sup.supply, amount);
    coin::from_balance(rmb_balance, ctx)
}
```

这里把 `Supply<RMB>` 放进 `SupplyHold`，并把 `SupplyHold` 设为共享对象。任何人都能调用 `mint2`，因此这仍然是教学/测试模式。生产项目要在 `mint2` 中加入权限检查或额度限制。

## 发行上限：`HKTreasuryCap`

源码路径：`src/02_coin/code/04_coin_supply/sources/hk.move`

```move
module coin_supply::hk ;
use sui::balance;
use sui::balance::Supply;
use sui::coin::{Self, Coin};
use sui::coin_registry;
use std::string;

public struct HK has drop {}

public struct HKTreasuryCap has key, store {
    id: UID,
    supply: Supply<HK>
}

fun init(hk: HK, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        hk,
        6,
        string::utf8(b"HK"),
        string::utf8(b""),
        string::utf8(b""),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);

    let supply = coin::treasury_into_supply(treasury);

    let hk_treasury_cap = HKTreasuryCap {
        id: object::new(ctx),
        supply
    };

    transfer::public_transfer(hk_treasury_cap, ctx.sender());
}

public fun mint(hk_cap: &mut HKTreasuryCap, amt: u64, ctx: &mut TxContext): Coin<HK> {
    let supply_amt = balance::supply_value(&hk_cap.supply);
    let total = amt + supply_amt;
    // MAX 100 亿，单位按 decimals=6 计算
    assert!(total <= 10000_000000000, 0x2);

    let balance = hk_cap.supply.increase_supply(amt);
    coin::from_balance(balance, ctx)
}
```

这段代码通过 `balance::supply_value` 查询当前发行量，再和本次增发量相加，超过上限就回滚交易。注意：`Supply<T>` 是一个线性资源，不能复制。一个 `Supply<T>` 只能放进一个对象，不能同时放进两个结构体。

## 自定义 Balance 封装与手续费

源码路径：`src/02_coin/code/04_coin_supply/sources/my_coin.move`

```move
module coin_supply::my_coin ;
use sui::balance::{Balance, Supply};
use sui::coin;
use sui::coin_registry;
use std::string;

public struct MY_COIN has drop {}

public struct MyCoinB has key {
    id: UID,
    b: Balance<MY_COIN>
}

public struct HKTreasuryCap has key, store {
    id: UID,
    supply: Supply<MY_COIN>,
}

public struct Fees has key, store {
    id: UID,
    b: Balance<MY_COIN>,
}

fun init(witness: MY_COIN, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"RMB"),
        string::utf8(b""),
        string::utf8(b""),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);

    let supply = coin::treasury_into_supply(treasury);

    transfer::public_transfer(HKTreasuryCap {
        id: object::new(ctx),
        supply,
    }, ctx.sender());
}

public fun mint(my_cap: &mut HKTreasuryCap, ctx: &mut TxContext): MyCoinB {
    let my_supply = my_cap.supply.increase_supply(100);
    MyCoinB {
        id: object::new(ctx),
        b: my_supply
    }
}

public fun my_t(fee: &mut Fees, mut my: MyCoinB, to: address, _ctx: &mut TxContext) {
    let fee1 = my.b.split(10);
    fee.b.join(fee1);
    transfer::transfer(my, to);
}
```

这个例子没有返回标准 `Coin<MY_COIN>`，而是把 `Balance<MY_COIN>` 封装到自定义对象 `MyCoinB` 中。这样可以在模块内部定义自己的转账逻辑，比如 `my_t` 中先扣除 10 个单位作为手续费，再把剩余对象转出。

## 权限分离：公开额度与授权额度

源码路径：`src/02_coin/code/04_coin_supply/sources/usd.move`

```move
module coin_supply::usd ;
use sui::balance::Supply;
use sui::coin::{Self, Coin};
use sui::coin_registry;
use std::string;

const ErrNotLt100: u64 = 0x0001;

public struct USD has drop {}

public struct USDSupply has key {
    id: UID,
    supply: Supply<USD>
}

public struct AdminCap has key, store {
    id: UID
}

public struct USDMintCap has key, store {
    id: UID
}

fun init(witness: USD, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"USD"),
        string::utf8(b""),
        string::utf8(b""),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);
    let supply = coin::treasury_into_supply(treasury);
    transfer::share_object(USDSupply {
        id: object::new(ctx),
        supply
    });

    transfer::public_transfer(AdminCap { id: object::new(ctx) }, ctx.sender());
}

public fun give_cap(_: &AdminCap, to: address, ctx: &mut TxContext) {
    transfer::public_transfer(USDMintCap {
        id: object::new(ctx)
    }, to);
}

public fun mint(usd: &mut USDSupply, amount: u64, ctx: &mut TxContext): Coin<USD> {
    assert!(amount < 100, ErrNotLt100);
    let usd_balance = usd.supply.increase_supply(amount);
    coin::from_balance(usd_balance, ctx)
}

public fun mint_cap(_: &mut USDMintCap, usd: &mut USDSupply, amount: u64, ctx: &mut TxContext): Coin<USD> {
    let usd_balance = usd.supply.increase_supply(amount);
    coin::from_balance(usd_balance, ctx)
}
```

这里把 `USDSupply` 共享出去，但把大额铸造能力交给 `USDMintCap`。普通用户只能通过 `mint` 铸造小额，获得授权的用户可以用 `mint_cap` 铸造任意额度。这是权限分离的最小示例。

## 本章小结

本章的核心是：`TreasuryCap<T>` 可以转换为 `Supply<T>`，而 `Supply<T>` 可以被放入自定义对象中。通过这种方式可以实现：

- 发行量上限
- 共享发行对象
- 授权发行能力
- 自定义 `Balance<T>` 封装
- 手续费和业务规则

`Supply<T>` 是线性资源，不能复制，也不能重复移动。每一个示例都必须保持“一个 `Supply<T>` 只进入一个对象”的原则。
