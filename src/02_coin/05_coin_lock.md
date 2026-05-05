# Coin 锁定（Time Lock）

在很多 DeFi 场景中，我们需要将代币锁定一段时间，到期后才能解锁使用。例如团队代币分期释放、质押奖励线性解锁等。本节介绍如何在 Sui Move 中实现一个基于时间的 Coin 锁定机制。

## 核心思路

Sui 的 `Coin` 是一个具有 `key` 和 `store` 能力的对象，可以在地址之间自由转移。要实现"锁定"，我们需要创建一个自定义的包装对象，将 `Balance` 存入其中，并记录一个释放时间。在释放时间到达之前，任何人都无法取出其中的代币。

## 完整代码

```move
module coin_lock::lock_coin ;

use std::option;
use sui::balance::Balance;
use sui::coin;
use sui::coin::{TreasuryCap, balance};
use sui::object;
use sui::object::{UID, id};
use sui::transfer;
use sui::tx_context::{Self, TxContext, sender};

const ErrNotRelease: u64 = 0x00001;

public struct LOCK_COIN has drop {}

public struct LockCoin has key {
    id: UID,
    balance: Balance<LOCK_COIN>,
    release_time: u64
}

fun init(witness: LOCK_COIN, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(witness, 6, b"USD", b"", b"", option::none(), ctx);
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, tx_context::sender(ctx));
}

public entry fun mint_and_lock(
    treasury: &mut TreasuryCap<LOCK_COIN>,
    amount: u64,
    lock_day: u64,
    to: address,
    ctx: &mut TxContext
) {
    let coin = coin::mint(treasury, amount, ctx);
    let current_ms = tx_context::epoch_timestamp_ms(ctx);
    let lock = LockCoin {
        id: object::new(ctx),
        balance: coin::into_balance(coin),
        release_time: current_ms + (lock_day * 24 * 3600 * 1000)
    };
    transfer::transfer(lock, to);
}

public entry fun unlock_coin(lock_coin: LockCoin, ctx: &mut TxContext) {
    let current_ms = tx_context::epoch_timestamp_ms(ctx);
    assert!(current_ms > lock_coin.release_time, ErrNotRelease);
    let LockCoin { id, balance, release_time: _ } = lock_coin;
    let unlock_coin = coin::from_balance(balance, ctx);
    transfer::public_transfer(unlock_coin, sender(ctx));
    object::delete(id);
}
```

## 代码解析

### LockCoin 结构体

```move
public struct LockCoin has key {
    id: UID,
    balance: Balance<LOCK_COIN>,
    release_time: u64
}
```

`LockCoin` 是锁定的核心结构体，它只具有 `key` 能力，没有 `store` 能力。这意味着 `LockCoin` 是一个不可转移的对象 -- 它不能作为字段嵌入其他对象，也不能通过常规的 `public_transfer` 传递。只有模块内部定义的函数才能操作它。

三个字段的作用：

- `id: UID` -- 对象唯一标识符，所有具有 `key` 能力的结构体都必须包含此字段
- `balance: Balance<LOCK_COIN>` -- 存储被锁定的代币余额。注意这里使用的是 `Balance` 而非 `Coin`。`Balance` 只有 `store` 能力，不是顶层对象，可以嵌在其他结构体中
- `release_time: u64` -- 释放时间，以毫秒为单位的 Unix 时间戳

### 为什么用 Balance 而不是 Coin

`Coin` 具有 `key + store` 能力，它本身就是一个对象（拥有 `id` 字段）。Sui 不允许在一个对象内部嵌套另一个具有 `key` 能力的对象作为值字段。而 `Balance` 只有 `store` 能力，不是对象，可以安全地作为字段嵌入。

所以在锁定过程中，我们需要用 `coin::into_balance` 将 `Coin` 转换为 `Balance`；解锁时，再用 `coin::from_balance` 将 `Balance` 转回 `Coin`。

### mint_and_lock -- 铸造并锁定

```move
public entry fun mint_and_lock(
    treasury: &mut TreasuryCap<LOCK_COIN>,
    amount: u64,
    lock_day: u64,
    to: address,
    ctx: &mut TxContext
) {
    let coin = coin::mint(treasury, amount, ctx);
    let current_ms = tx_context::epoch_timestamp_ms(ctx);
    let lock = LockCoin {
        id: object::new(ctx),
        balance: coin::into_balance(coin),
        release_time: current_ms + (lock_day * 24 * 3600 * 1000)
    };
    transfer::transfer(lock, to);
}
```

这个函数的执行流程：

1. **铸造 Coin**：通过 `coin::mint` 使用 `TreasuryCap` 铸造指定数量的代币
2. **获取当前时间**：`tx_context::epoch_timestamp_ms(ctx)` 返回当前 epoch 的毫秒级时间戳
3. **计算释放时间**：`current_ms + (lock_day * 24 * 3600 * 1000)`，将天数转换为毫秒并加到当前时间上
4. **构造 LockCoin**：将 Coin 转为 Balance，连同释放时间一起包装进 LockCoin
5. **转移给目标地址**：使用 `transfer::transfer` 将 LockCoin 对象发送给接收者

注意这里使用了 `transfer::transfer` 而非 `transfer::public_transfer`。因为 `LockCoin` 没有 `store` 能力，不能使用 `public_transfer`，只能使用模块内的 `transfer` 函数进行转移。这也意味着只有本模块可以控制 LockCoin 的转移。

### unlock_coin -- 解锁

```move
public entry fun unlock_coin(lock_coin: LockCoin, ctx: &mut TxContext) {
    let current_ms = tx_context::epoch_timestamp_ms(ctx);
    assert!(current_ms > lock_coin.release_time, ErrNotRelease);
    let LockCoin { id, balance, release_time: _ } = lock_coin;
    let unlock_coin = coin::from_balance(balance, ctx);
    transfer::public_transfer(unlock_coin, sender(ctx));
    object::delete(id);
}
```

这个函数的执行流程：

1. **时间检查**：获取当前时间，使用 `assert!` 断言当前时间已超过释放时间。如果未到期，交易会以 `ErrNotRelease` 错误中止

2. **解构 LockCoin**：`let LockCoin { id, balance, release_time: _ } = lock_coin;` 这是 Move 中的解构（destructuring）语法。由于 `LockCoin` 没有 `drop` 能力，编译器要求我们必须显式处理它的每一个字段。`release_time: _` 表示我们不需要这个字段的值，直接丢弃

3. **Balance 转 Coin**：`coin::from_balance(balance, ctx)` 将内部的 Balance 重新转换为可转移的 Coin 对象

4. **转移解锁的 Coin**：将 Coin 通过 `public_transfer` 转给调用者

5. **删除 UID**：`object::delete(id)` 删除解构出来的 UID。这是必须的 -- 每个 UID 都占用存储空间，如果不删除，对象虽然被解构了，但 UID 仍然存在于链上，会造成存储泄漏

### init 函数

```move
fun init(witness: LOCK_COIN, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(witness, 6, b"USD", b"", b"", option::none(), ctx);
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, tx_context::sender(ctx));
}
```

`init` 函数与前几节的逻辑一致：创建货币、冻结元数据、将铸造权限转移给发布者。

## 关键要点

**时间获取方式**：`tx_context::epoch_timestamp_ms(ctx)` 返回的是毫秒级 Unix 时间戳。在计算锁定期时要注意单位换算：1 天 = 24 * 3600 * 1000 毫秒。

**对象解构与资源管理**：Move 没有垃圾回收机制。当一个自定义对象不再需要时，必须手动解构它并删除其中的 UID。忘记调用 `object::delete(id)` 会导致编译错误，因为 `id` 没有被消费。

**不可转移对象的设计**：`LockCoin` 只有 `key` 能力没有 `store` 能力，使其成为一个"受限对象"。这种对象只能被其所有者在模块定义的入口函数中使用。这正是锁定机制的保证 -- 所有者无法绕过 `unlock_coin` 函数中的时间检查来提前取出代币。

## 调用示例

铸造并锁定 100 个 LOCK_COIN，锁定 30 天：

```shell
sui client call --package <PACKAGE_ID> \
    --module lock_coin \
    --function mint_and_lock \
    --args <TREASURY_CAP_ID> 100 30 <RECIPIENT_ADDRESS> \
    --gas-budget 100000000
```

到期后解锁：

```shell
sui client call --package <PACKAGE_ID> \
    --module lock_coin \
    --function unlock_coin \
    --args <LOCK_COIN_OBJECT_ID> \
    --gas-budget 100000000
```

## 本章小结

本章介绍了基于时间的 Coin 锁定机制：

- `LockCoin` 结构体封装 `Balance` + `release_time`，只有 `key` 能力，不可转移
- 使用 `Balance` 而非 `Coin` 嵌入结构体，因为 `Balance` 没有 `key` 能力
- `epoch_timestamp_ms` 返回毫秒级时间戳，计算锁定期时注意单位换算
- 解构对象时必须显式处理所有字段，并调用 `object::delete(id)` 删除 UID 防止存储泄漏
