# Coin 锁定（Time Lock）

本章实现一个时间锁 Coin：管理员铸造代币后，把 `Coin<T>` 转成 `Balance<T>` 并封装进 `LockCoin` 对象。只有当前时间超过释放时间时，持有人才能把 `Balance<T>` 转回 `Coin<T>`。

## 本章目标

- 理解为什么锁仓对象内部使用 `Balance<T>` 而不是 `Coin<T>`
- 掌握 `tx_context::epoch_timestamp_ms` 的时间判断
- 理解 `transfer::transfer` 与 `transfer::public_transfer` 的区别
- 使用当前 `coin_registry` API 创建锁仓代币

## 完整代码

源码路径：`src/02_coin/code/05_coin_lock/sources/lock_coin.move`

```move
#[allow(lint(self_transfer))]
module coin_lock::lock_coin ;
use sui::balance::Balance;
use sui::coin::{Self, TreasuryCap};
use sui::coin_registry;
use std::string;

const ErrNotRelease: u64 = 0x00001;

public struct LOCK_COIN has drop {}

public struct LockCoin has key {
    id: UID,
    balance: Balance<LOCK_COIN>,
    release_time: u64
}

fun init(witness: LOCK_COIN, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"LOCK"),
        string::utf8(b"Locked Coin"),
        string::utf8(b""),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);
    transfer::public_transfer(treasury, ctx.sender());
}

public fun mint_and_lock(
    treasury: &mut TreasuryCap<LOCK_COIN>,
    amount: u64,
    lock_day: u64,
    to: address,
    ctx: &mut TxContext
) {
    let minted = coin::mint(treasury, amount, ctx);
    let current_ms = tx_context::epoch_timestamp_ms(ctx);

    let lock = LockCoin {
        id: object::new(ctx),
        balance: coin::into_balance(minted),
        release_time: current_ms + (lock_day * 24 * 3600 * 1000)
    };

    transfer::transfer(lock, to);
}

public fun unlock_coin(lock_coin: LockCoin, ctx: &mut TxContext) {
    let current_ms = tx_context::epoch_timestamp_ms(ctx);
    assert!(current_ms > lock_coin.release_time, ErrNotRelease);

    let LockCoin { id, balance, release_time: _ } = lock_coin;

    let unlocked = coin::from_balance(balance, ctx);

    transfer::public_transfer(unlocked, ctx.sender());

    object::delete(id);
}
```

## 核心结构

```move
public struct LockCoin has key {
    id: UID,
    balance: Balance<LOCK_COIN>,
    release_time: u64
}
```

`LockCoin` 是一个对象，内部包含两部分：

- `balance`：被锁定的余额
- `release_time`：解锁时间，单位是毫秒

这里不能直接存 `Coin<LOCK_COIN>`。`Coin<T>` 自身也是对象，不能作为普通字段嵌入另一个对象；`Balance<T>` 只有 `store` 能力，适合作为字段保存。

## 铸造并锁定

```move
let minted = coin::mint(treasury, amount, ctx);
let current_ms = tx_context::epoch_timestamp_ms(ctx);
```

`mint_and_lock` 使用 `TreasuryCap<LOCK_COIN>` 先铸造 Coin，然后计算释放时间：

```move
release_time: current_ms + (lock_day * 24 * 3600 * 1000)
```

最后用 `coin::into_balance` 把 Coin 转成 Balance，装进 `LockCoin`。

## 解锁

```move
assert!(current_ms > lock_coin.release_time, ErrNotRelease);
```

如果当前时间没有超过释放时间，交易直接回滚。通过检查后，函数解构 `LockCoin`，把 `Balance` 转回 `Coin`：

```move
let unlocked = coin::from_balance(balance, ctx);
transfer::public_transfer(unlocked, ctx.sender());
object::delete(id);
```

最后必须删除 `id`，否则会留下没有用的对象 UID。

## 调用示例

发布：

```shell
cd src/02_coin/code/05_coin_lock
sui move build
sui client publish
```

铸造并锁定：

```shell
sui client call \
    --package <PACKAGE_ID> \
    --module lock_coin \
    --function mint_and_lock \
    --args <TREASURY_CAP_ID> 1000000 7 <RECIPIENT_ADDRESS>
```

到期后解锁：

```shell
sui client call \
    --package <PACKAGE_ID> \
    --module lock_coin \
    --function unlock_coin \
    --args <LOCK_COIN_OBJECT_ID>
```

## 本章小结

本章实现了最小可运行的时间锁。核心技巧是：锁定时使用 `Coin -> Balance`，解锁时使用 `Balance -> Coin`。时间判断来自 `tx_context::epoch_timestamp_ms`，对象销毁时必须调用 `object::delete(id)`。
