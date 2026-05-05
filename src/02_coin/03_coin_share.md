# 共享所有权 Coin

共享所有权指的是 Coin 的铸造权限（TreasuryCap）不归属任何单一地址，而是作为共享对象存在于链上，任何人都可以访问并调用铸造方法。

## 与独享所有权的区别

在上一章中，我们使用 `transfer::public_transfer(treasury, address)` 将 `TreasuryCap` 转移给发布者地址，只有发布者拥有铸造权限。

本章的关键区别在于使用 `transfer::public_share_object(treasury)` 替代 `public_transfer`，将 `TreasuryCap` 变为共享对象。

| 方法 | 所有权类型 | 铸造权限 |
|------|-----------|---------|
| `public_transfer` | 独享，仅拥有者可操作 | 只有发布者 |
| `public_share_object` | 共享，任何人可操作 | 所有人 |

## RMB 的代码

```move
module coin_share::rmb ;

use std::option;
use sui::coin;
use sui::transfer;
use sui::tx_context::{TxContext};

public struct RMB has drop {}

fun init(witness: RMB, ctx: &mut TxContext) {
    let (treasury, metadata) =
        coin::create_currency(witness, 6, b"RMB", b"", b"", option::none(), ctx);
    transfer::public_freeze_object(metadata);

    transfer::public_share_object(treasury);
}
```

## USD 的代码

```move
module coin_share::usd ;

use std::option;
use sui::coin;
use sui::transfer;

public struct USD has drop {}

fun init(witness: USD, ctx: &mut TxContext) {
    let (treasury, metadata) =
        coin::create_currency(witness, 6, b"USD", b"", b"", option::none(), ctx);
    transfer::public_freeze_object(metadata);
    transfer::public_share_object(treasury);
}
```

## 代码说明

### `public_share_object(treasury)`

这是本章的核心。调用 `public_share_object` 后，`TreasuryCap` 对象变为共享对象（Shared Object）。在 Sui 的对象模型中，共享对象不属于任何单一地址，任何人都可以读取和引用它。

这意味着任何用户都可以通过 `coin::mint` 方法使用这个 `TreasuryCap` 来铸造新的 Coin，不需要得到发布者的授权。

### 其他部分

其余代码与独享所有权完全相同：

- `RMB` / `USD`：Witness 类型，具有 `drop` 能力，在模块初始化时作为一次性见证使用。
- `create_currency`：创建 Coin 类型，返回 `treasury`（国库权限）和 `metadata`（元信息）。
- `public_freeze_object`：将 `metadata` 冻结为不可变对象。

## 使用场景

共享所有权的 Coin 适用于以下场景：

- **测试环境**：在开发和测试阶段，希望所有参与者都能自由获取代币。
- **无许可铸造**：某些应用需要任何人都能铸造代币，例如水龙头（Faucet）合约。
- **DeFi 协议**：由合约逻辑控制铸造流程，而非依赖单一管理员的权限。

需要注意的风险是，由于任何人都能铸造代币，在没有额外限制的情况下，这种模式不适合生产环境中的价值代币。在实际项目中，通常会配合额外的访问控制逻辑来约束铸造行为。

## 发布命令

```shell
sui client publish
```

发布后，`TreasuryCap` 对象会作为共享对象存在于链上，不会归属任何地址。任何人都可以通过 `sui client call` 调用 `coin::mint` 方法来铸造 Coin。

## 本章小结

本章介绍了 Coin 的共享所有权模式：

- 使用 `public_share_object` 替代 `public_transfer`，将 `TreasuryCap` 变为共享对象
- 共享对象任何人都可以访问，适用于测试环境和无许可铸造场景
- 在生产环境中使用共享所有权需要配合额外的访问控制逻辑
