# Coin 发行量控制

前面两章我们使用 `TreasuryCap` 来铸造 Coin，持有 `TreasuryCap` 的地址就拥有铸造权限。但在实际项目中，我们往往需要对发行量进行更精细的控制，比如设定上限、自定义封装结构、收取手续费等。

Sui 提供了 `Supply` 类型，允许我们将 `TreasuryCap` 拆解，获得更灵活的控制能力。

## TreasuryCap 与 Supply 的关系

`TreasuryCap` 内部持有一个 `Supply` 对象。通过 `coin::treasury_into_supply` 函数，可以将 `TreasuryCap` 消耗掉，取出其中的 `Supply`：

```rust
let supply = coin::treasury_into_supply(treasury);
```

执行后，`TreasuryCap` 不复存在，取而代之的是一个 `Supply<T>` 类型的值。`Supply` 的核心能力：

- `increase_supply(amount)` -- 增加发行量，返回 `Balance<T>`
- `decrease_supply(balance)` -- 销毁发行量，减少总量
- `supply_value(&supply)` -- 查询当前已发行的总量

## 基本用法：自定义 Supply 封装

来看 `rmb` 模块的例子，展示如何将 `Supply` 封装到自定义结构中：

```move
module coin_supply::rmb ;
use std::option;
use sui::balance;
use sui::balance::Supply;
use sui::coin;
use sui::coin::{Coin};
use sui::object;
use sui::object::UID;
use sui::transfer;
use sui::transfer::{transfer};
use sui::tx_context::{Self, TxContext, sender};

public struct RMB has drop {}

public struct SupplyHold has key {
    id: UID,
    supply: Supply<RMB>
}

fun init(witness: RMB, ctx: &mut TxContext) {
    let (treasury, metadata) =
        coin::create_currency(witness, 6, b"RMB", b"", b"", option::none(), ctx);

    transfer::public_freeze_object(metadata);

    let supply = coin::treasury_into_supply(treasury);

    let supply_hold = SupplyHold {
        id: object::new(ctx),
        supply
    };
    transfer(supply_hold, sender(ctx));
}

public fun mint2(sup: &mut SupplyHold, amount: u64, ctx: &mut TxContext): Coin<RMB> {
    let rmbBalance = balance::increase_supply(&mut sup.supply, amount);
    coin::from_balance(rmbBalance, ctx)
}
```

### 代码说明

在 `init` 函数中，先用 `create_currency` 创建货币，然后将 `TreasuryCap` 通过 `treasury_into_supply` 转换为 `Supply<RMB>`，再封装到自定义的 `SupplyHold` 结构中，转移给发布者。

在 `mint2` 函数中，通过 `balance::increase_supply` 增加发行量并获得 `Balance`，再用 `coin::from_balance` 将其转为标准的 `Coin<RMB>`。

## 发行量上限控制

`hk` 模块展示了如何在铸造时检查发行上限：

```move
module coin_supply::hk;
use sui::balance;
use sui::balance::Supply;
use sui::coin;
use sui::coin::Coin;
use sui::transfer::{public_freeze_object, public_transfer, share_object};

public struct HK has drop {}

public struct HKTreasuryCap has key, store {
    id: UID,
    supply: Supply<HK>
}

fun init(hk: HK, ctx: &mut TxContext) {
    let (treasury, metadata) =
        coin::create_currency(hk, 6, b"HK", b"", b"", option::none(), ctx);

    public_freeze_object(metadata);

    let supply = coin::treasury_into_supply(treasury);

    let hk_treasury_cap = HKTreasuryCap {
        id: object::new(ctx),
        supply
    };

    public_transfer(hk_treasury_cap, ctx.sender());
}

public fun mint(hk_cap: &mut HKTreasuryCap, amt: u64, ctx: &mut TxContext): Coin<HK> {
    let supply_amt = balance::supply_value(&hk_cap.supply);
    let total = amt + supply_amt;
    // 最大发行 100 亿
    assert!(total <= 10000_000000000, 0x2);

    let balance = hk_cap.supply.increase_supply(amt);
    let hk_coin = coin::from_balance(balance, ctx);
    hk_coin
}
```

关键点在 `mint` 函数中：先通过 `balance::supply_value` 查询当前已发行量，加上本次要铸造的数量后判断是否超过上限，超过则断言失败，交易回滚。

## 自定义 Balance 封装与手续费

`my_coin` 模块展示了不使用标准 `Coin`，而是自定义 `Balance` 封装的方式，以及如何在转账时收取手续费：

```move
module coin_supply::my_coin ;
use std::option;
use sui::balance::{Balance, Supply};
use sui::coin;
use sui::transfer;
use sui::tx_context::{TxContext};

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
    let (treasury, metadata) =
        coin::create_currency(witness, 6, b"RMB", b"", b"", option::none(), ctx);
    transfer::public_freeze_object(metadata);

    let supply = coin::treasury_into_supply(treasury);
    public_transfer(supply, ctx.sender());
}

public fun mint(my_cap: HKTreasuryCap, ctx: &mut TxContext) : MyCoinB {
    let my_supply = my_cap.supply.increase_supply(100);
    MyCoinB {
        id: object::new(ctx),
        b: my_supply
    }
}

public fun my_t(fee: &mut Fees, my: MyCoinB, to: address, ctx: &mut TxContext) {
    let fee1 = my.b.split(10);
    fee.b.join(fee1);
    transfer(my, to);
}
```

### 代码说明

#### 自定义封装结构

这里定义了三个重要的自定义结构：

- `MyCoinB` -- 封装了 `Balance<MY_COIN>` 而不是 `Coin<MY_COIN>`。这意味着它不是标准的 Coin 对象，而是自定义的余额容器，可以在其中实现任意逻辑。
- `HKTreasuryCap` -- 封装了 `Supply<MY_COIN>`，持有此对象的地址拥有铸造权限。
- `Fees` -- 封装了 `Balance<MY_COIN>`，用于收集手续费。

#### mint 函数

`mint` 函数消耗 `HKTreasuryCap` 对象（注意参数没有 `&`，是值传递），调用 `increase_supply(100)` 增加发行量并获得 `Balance`，然后将其包装在 `MyCoinB` 中返回。每次铸造固定 100 个单位。

#### my_t 函数：带手续费的转账

```move
public fun my_t(fee: &mut Fees, my: MyCoinB, to: address, ctx: &mut TxContext) {
    let fee1 = my.b.split(10);
    fee.b.join(fee1);
    transfer(my, to);
}
```

- `my.b.split(10)` -- 从 `MyCoinB` 中拆分出 10 个单位作为手续费
- `fee.b.join(fee1)` -- 将手续费合并到 `Fees` 对象中
- `transfer(my, to)` -- 将扣除手续费后的 `MyCoinB` 转给目标地址

这种模式在 DeFi 项目中非常常见：转账时自动扣除一部分作为协议费用。

## 共享 Supply 与权限分离

`usd` 模块展示了将 `Supply` 作为共享对象，配合自定义 `AdminCap` 和 `MintCap` 实现权限分离：

```move
module coin_supply::usd ;
use std::option;
use sui::balance;
use sui::balance::Supply;
use sui::coin;
use sui::coin::Coin;
use sui::object;
use sui::object::UID;
use sui::transfer;
use sui::tx_context::{TxContext, sender};

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
    let (treasury, metadata) = coin::create_currency(
        witness, 6, b"USD", b"", b"", option::none(), ctx
    );
    transfer::public_freeze_object(metadata);

    let supply = coin::treasury_into_supply(treasury);
    transfer::share_object(USDSupply {
        id: object::new(ctx),
        supply
    });

    transfer::public_transfer(AdminCap { id: object::new(ctx) }, sender(ctx));
}

public fun give_cap(_: &AdminCap, to: address, ctx: &mut TxContext) {
    transfer::public_transfer(USDMintCap { id: object::new(ctx) }, to);
}

public fun mint(usd: &mut USDSupply, amount: u64, ctx: &mut TxContext): Coin<USD> {
    assert!(amount < 100, ErrNotLt100);
    let usdBalance = usd.supply.increase_supply(amount);
    coin::from_balance(usdBalance, ctx)
}

public fun mint_cap(_: &mut USDMintCap, usd: &mut USDSupply, amount: u64, ctx: &mut TxContext): Coin<USD> {
    let usdBalance = usd.supply.increase_supply(amount);
    coin::from_balance(usdBalance, ctx)
}
```

### 代码说明

- `USDSupply` 作为共享对象发布，任何人都可以调用 `mint` 函数，但限制了每次最多铸造 100 个单位
- `AdminCap` 转移给发布者，持有者可以通过 `give_cap` 给其他地址发放 `USDMintCap`
- `USDMintCap` 的持有者可以调用 `mint_cap` 函数，该函数没有金额上限限制
- 这实现了三层权限：普通用户（有上限铸造）、铸造权限持有者（无上限铸造）、管理员（发放铸造权限）

## 本章小结

| 方式 | 结构 | 特点 |
|------|------|------|
| TreasuryCap | 直接使用 | 简单，铸造权限与对象绑定 |
| Supply + 自定义封装 | SupplyHold / HKTreasuryCap | 可设定发行上限，灵活控制 |
| Supply 共享对象 | USDSupply (shared) | 任何人可铸造，配合 Cap 做权限分离 |
| 自定义 Balance 封装 | MyCoinB / Fees | 不使用标准 Coin，支持自定义转账逻辑和手续费 |

核心思路：`TreasuryCap` 可以拆解为 `Supply`，`Supply` 可以被封装到任意自定义结构中，从而实现发行量上限、权限分离、手续费收取等各种业务需求。
