# Coin 黑名单（Deny List）

在很多代币应用场景中，发行者需要能够禁止特定地址使用该代币。例如合规要求需要冻结某些地址的资产，或者发现异常交易时需要紧急封禁。Sui 提供了内置的 DenyList 机制来满足这一需求。

## 本章目标

- 理解 DenyList 机制的工作原理
- 掌握 `create_regulated_currency_v2` 的使用方法
- 实现完整的受监管代币模块，包括铸造、添加黑名单和移除黑名单
- 学会通过 CLI 调用黑名单相关操作

## DenyList 机制概述

DenyList 是 Sui 系统内置的一个共享对象，地址固定为 `0x403`，定义在 `sui::deny_list` 模块中。它的作用是维护一份全局的黑名单列表，按类型（type）分类存储被禁止的地址。

对于 Coin 类型，DenyList 的工作机制如下：

- 被添加到黑名单的地址，**立即**无法将该 Coin 作为交易输入使用（即无法发送）
- 从下一个 epoch 开始，被禁止的地址也将**无法接收**该 Coin
- 从黑名单中移除后，效果同样有即时和延迟两种：发送权限立即恢复，接收权限在下一个 epoch 恢复

这种设计的目的是在安全性和可用性之间取得平衡。即时阻止发送可以快速应对安全威胁，而延迟阻止接收则给系统留出了处理正在进行中的交易的时间。

### DenyCapV2

要操作 DenyList 中的 Coin 黑名单，需要持有 `DenyCapV2<T>` 对象。这个对象是通过 `create_regulated_currency_v2` 函数创建代币时自动生成的，它的定义如下：

```rust
public struct DenyCapV2<phantom T> has key, store {
    id: UID,
    allow_global_pause: bool,
}
```

其中 `allow_global_pause` 字段控制是否允许全局暂停。如果设为 `true`，持有者可以触发全局暂停，效果等同于将所有地址加入黑名单。

`DenyCapV2<T>` 是当前 Sui 主网使用的版本。早期版本使用 `DenyCap<T>`（v1），现已标记为弃用。新项目应始终使用 v2 版本。

## 完整示例模块

以下是一个完整的受监管代币模块，包含代币创建、铸造、添加黑名单和移除黑名单四个功能：

```move
module deny_coin::deny_coin {
    use std::option;
    use sui::coin::{Self, TreasuryCap, Coin, DenyCapV2};
    use sui::url::Url;
    use sui::deny_list::DenyList;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// 一次性见证类型
    public struct DENY_COIN has drop {}

    /// 创建受监管的代币
    /// create_regulated_currency_v2 返回三个对象：
    ///   - TreasuryCap：铸造权限
    ///   - DenyCapV2：黑名单管理权限
    ///   - CoinMetadata：代币元信息
    fun init(witness: DENY_COIN, ctx: &mut TxContext) {
        let (treasury, deny_cap, metadata) =
            coin::create_regulated_currency_v2<DENY_COIN>(
                witness,
                8,                          // 精度：8 位小数
                b"DENY",                    // 符号
                b"Deny Coin",               // 名称
                b"A regulated coin with deny list support", // 描述
                option::none<Url>(),        // 图标 URL（可选）
                true,                       // 允许全局暂停
                ctx
            );

        // 冻结元数据，使其变为不可变对象
        transfer::public_freeze_object(metadata);
        // 将黑名单管理权限转移给发布者
        transfer::public_transfer(deny_cap, tx_context::sender(ctx));
        // 将铸造权限转移给发布者
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    /// 铸造新的 DENY_COIN
    public entry fun mint(
        treasury: &mut TreasuryCap<DENY_COIN>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let coin = coin::mint(treasury, amount, ctx);
        transfer::public_transfer(coin, tx_context::sender(ctx));
    }

    /// 将指定地址添加到黑名单
    /// 被添加的地址将无法发送和接收 DENY_COIN
    public entry fun deny(
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV2<DENY_COIN>,
        addr: address,
        ctx: &mut TxContext
    ) {
        coin::deny_list_v2_add<DENY_COIN>(deny_list, deny_cap, addr, ctx);
    }

    /// 将指定地址从黑名单中移除
    /// 移除后该地址恢复使用 DENY_COIN 的权限
    public entry fun undeny(
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV2<DENY_COIN>,
        addr: address,
        ctx: &mut TxContext
    ) {
        coin::deny_list_v2_remove<DENY_COIN>(deny_list, deny_cap, addr, ctx);
    }
}
```

## 代码逐行讲解

### 模块声明与导入

```move
module deny_coin::deny_coin {
    use std::option;
    use sui::coin::{Self, TreasuryCap, Coin, DenyCapV2};
    use sui::url::Url;
    use sui::deny_list::DenyList;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
```

与前面章节相比，这里额外导入了两个关键类型：

- `DenyCapV2`：从 `sui::coin` 模块导入，是操作黑名单所需的权限凭证
- `DenyList`：从 `sui::deny_list` 模块导入，是系统级的黑名单共享对象

`Url` 类型用于 `create_regulated_currency_v2` 的图标 URL 参数，即使我们传入 `option::none()`，也需要导入这个类型以满足函数签名的要求。

### init 函数：创建受监管代币

```move
fun init(witness: DENY_COIN, ctx: &mut TxContext) {
    let (treasury, deny_cap, metadata) =
        coin::create_regulated_currency_v2<DENY_COIN>(
            witness,
            8,
            b"DENY",
            b"Deny Coin",
            b"A regulated coin with deny list support",
            option::none<Url>(),
            true,
            ctx
        );
```

这里使用 `create_regulated_currency_v2` 而非普通的 `create_currency`。两者的区别在于：

| 函数 | 返回值 | 黑名单支持 |
|------|--------|-----------|
| `create_currency` | `(TreasuryCap, CoinMetadata)` | 不支持 |
| `create_regulated_currency_v2` | `(TreasuryCap, DenyCapV2, CoinMetadata)` | 支持 |

`create_regulated_currency_v2` 多了一个参数 `allow_global_pause`（这里设为 `true`），并且多返回一个 `DenyCapV2<T>` 对象。这个对象是操作黑名单的凭证，必须妥善保管。

创建完成后，三个对象分别以不同方式处理：

- `metadata`：冻结为不可变对象，任何人可读但不可修改
- `deny_cap`：转移给发布者，只有发布者可以管理黑名单
- `treasury`：转移给发布者，只有发布者可以铸造代币

### mint 函数：铸造代币

```move
public entry fun mint(
    treasury: &mut TreasuryCap<DENY_COIN>,
    amount: u64,
    ctx: &mut TxContext
) {
    let coin = coin::mint(treasury, amount, ctx);
    transfer::public_transfer(coin, tx_context::sender(ctx));
}
```

铸造逻辑与前面章节完全相同。`coin::mint` 使用 TreasuryCap 创建指定数量的 Coin，然后通过 `public_transfer` 将其发送给调用者。

### deny 函数：添加黑名单

```move
public entry fun deny(
    deny_list: &mut DenyList,
    deny_cap: &mut DenyCapV2<DENY_COIN>,
    addr: address,
    ctx: &mut TxContext
) {
    coin::deny_list_v2_add<DENY_COIN>(deny_list, deny_cap, addr, ctx);
}
```

`deny` 函数需要两个关键参数：

1. `deny_list: &mut DenyList` -- 系统共享对象 `0x403` 的可变引用。由于 DenyList 是共享对象，这个调用需要经过共识机制处理
2. `deny_cap: &mut DenyCapV2<DENY_COIN>` -- 黑名单管理权限的可变引用。只有持有此对象的地址才能调用此函数

`coin::deny_list_v2_add` 是框架提供的方法，它在内部将被禁止地址的类型信息和地址写入 DenyList 对象。

### undeny 函数：移除黑名单

```move
public entry fun undeny(
    deny_list: &mut DenyList,
    deny_cap: &mut DenyCapV2<DENY_COIN>,
    addr: address,
    ctx: &mut TxContext
) {
    coin::deny_list_v2_remove<DENY_COIN>(deny_list, deny_cap, addr, ctx);
}
```

`undeny` 的参数与 `deny` 完全一致，只是调用了 `coin::deny_list_v2_remove` 来执行移除操作。

值得注意的是，`deny` 和 `undeny` 都不消耗 `DenyCapV2`（参数是可变引用 `&mut`，而非值传递），因此可以反复调用。这意味着代币发行者可以随时添加或移除黑名单中的地址。

## CLI 调用示例

### 发布模块

```shell
sui client publish --gas-budget 100000000
```

发布后，发布者地址将获得以下对象：

- `TreasuryCap<DENY_COIN>` -- 铸造权限
- `DenyCapV2<DENY_COIN>` -- 黑名单管理权限

### 铸造代币

```shell
sui client call \
    --package <PACKAGE_ID> \
    --module deny_coin \
    --function mint \
    --args <TREASURY_CAP_ID> 1000 \
    --gas-budget 100000000
```

这将铸造 1000 个 DENY_COIN（精度为 8 位，所以实际最小单位为 100000000000）并发送给调用者。

### 添加地址到黑名单

```shell
sui client call \
    --package <PACKAGE_ID> \
    --module deny_coin \
    --function deny \
    --args 0x403 <DENY_CAP_ID> <TARGET_ADDRESS> \
    --gas-budget 100000000
```

注意第一个参数是 `0x403`，即系统 DenyList 共享对象的地址。第二个参数是 `DenyCapV2` 对象的 ID。

执行后，`<TARGET_ADDRESS>` 将立即无法发送 DENY_COIN，从下一个 epoch 开始也无法接收。

### 从黑名单移除地址

```shell
sui client call \
    --package <PACKAGE_ID> \
    --module deny_coin \
    --function undeny \
    --args 0x403 <DENY_CAP_ID> <TARGET_ADDRESS> \
    --gas-budget 100000000
```

参数格式与添加黑名单完全相同，只是调用了 `undeny` 函数。

### 查询黑名单

除了 Move 模块中提供的函数，还可以通过 RPC 查询某个地址是否在黑名单中：

```shell
sui client object --id 0x403
```

也可以在 Move 代码中使用 `coin::deny_list_v2_contains_current_epoch` 和 `coin::deny_list_v2_contains_next_epoch` 进行检查：

```rust
// 检查当前 epoch 是否被禁止（影响接收）
let denied_now = coin::deny_list_v2_contains_current_epoch<DENY_COIN>(
    &deny_list, addr, ctx
);

// 检查下一个 epoch 是否被禁止（影响发送）
let denied_next = coin::deny_list_v2_contains_next_epoch<DENY_COIN>(
    &deny_list, addr
);
```

## 使用场景

### 合规与监管

许多司法管辖区要求代币发行者具备冻结资产的能力。例如，当法院命令要求冻结某个地址的资产时，发行者可以立即将该地址加入黑名单。使用 `create_regulated_currency_v2` 创建的代币天然支持这一需求。

### 安全应急响应

当检测到异常交易或安全漏洞时，发行者可以快速将可疑地址加入黑名单，防止资金进一步转移。`allow_global_pause` 设为 `true` 时，还可以通过 `coin::deny_list_v2_enable_global_pause` 触发全局暂停，阻止所有地址使用该代币，直到问题解决。

### 权限管理的最佳实践

- 将 `DenyCapV2` 转移给多签钱包地址，避免单点故障
- 在 `allow_global_pause` 参数的选择上谨慎评估：全局暂停是一把双刃剑，虽然可以快速应对紧急情况，但也可能被滥用
- 建立透明的黑名单管理流程，记录每次添加和移除的原因

## 本章小结

本章介绍了 Sui 的 DenyList 黑名单机制。通过 `create_regulated_currency_v2` 创建的代币会额外获得一个 `DenyCapV2` 对象，持有者可以使用它来管理黑名单。被禁止的地址将无法发送和接收该代币。

关键要点：

- 使用 `create_regulated_currency_v2` 替代 `create_currency` 来创建支持黑名单的代币
- `DenyCapV2` 是操作黑名单的权限凭证，必须妥善保管
- 黑名单的效果分为即时（阻止发送）和延迟到下一 epoch（阻止接收）两种
- `allow_global_pause` 参数控制是否允许全局暂停功能

至此，我们已介绍了 Coin 体系的核心功能。下一章将介绍 Sui 的 Token 标准，它在 Coin 的基础上提供了更高级的策略管控能力。
