# 独享所有权 Coin

本章实现最基础的 Coin 发行方式：发布包时创建一种货币，并把 `TreasuryCap<T>` 转移给发布者地址。谁持有 `TreasuryCap<T>`，谁就拥有后续铸造该 Coin 的权限。

当前 Sui 推荐使用 `sui::coin_registry` 创建货币。旧教程常见的 `coin::create_currency` 仍能解释历史代码，但会触发 deprecated warning，本书正文统一使用 `coin_registry::new_currency_with_otw`。

## 本章目标

- 理解 One-Time Witness（OTW）在 Coin 创建中的作用
- 使用 `coin_registry::new_currency_with_otw` 创建新货币
- 理解 `CurrencyInitializer<T>`、`TreasuryCap<T>` 和 metadata finalize 流程
- 掌握独享铸造权限的转移方式

## HK 的代码

源码路径：`src/02_coin/code/02_coin_owner/sources/hk.move`

```move
module coin_owner::hk ;
use sui::coin_registry;
use std::string;

public struct HK has drop {}

fun init(hk: HK, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        hk,
        8,
        string::utf8(b"HK"),
        string::utf8(b"HK made in hongkong"),
        string::utf8(b"HK made in hongkong"),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);
    transfer::public_transfer(treasury, ctx.sender())
}
```

## USD 的代码

源码路径：`src/02_coin/code/02_coin_owner/sources/usd.move`

```move
module coin_owner::usd ;
use sui::coin_registry;
use std::string;

public struct USD has drop {}

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
    transfer::public_transfer(treasury, ctx.sender())
}
```

## 代码说明

### `public struct HK has drop {}`

`HK` 是 One-Time Witness 类型。Sui 在包发布时会把这个 witness 传入 `init`，合约可以用它证明“当前模块正在第一次初始化”，从而创建唯一的货币类型。

### `new_currency_with_otw`

```move
let (init, treasury) = coin_registry::new_currency_with_otw(...);
```

这个函数返回两个值：

| 返回值 | 作用 |
|--------|------|
| `CurrencyInitializer<T>` | 临时初始化器，用于设置 registry 中的货币元信息 |
| `TreasuryCap<T>` | 铸造权限，持有者可以调用 `coin::mint` |

与旧的 `coin::create_currency` 不同，新 API 使用 `String` 类型的元数据字段，所以代码里需要用 `string::utf8(b"...")` 把字节字面量转成字符串。

### `finalize_and_delete_metadata_cap`

```move
coin_registry::finalize_and_delete_metadata_cap(init, ctx);
```

`new_currency_with_otw` 只创建初始化状态。完成 metadata 设置后，必须 finalize。这里使用 `finalize_and_delete_metadata_cap`，表示注册完成后不保留后续修改 metadata 的权限，适合教程中的固定元数据示例。

### `public_transfer(treasury, ctx.sender())`

最后把 `TreasuryCap<T>` 转给发布者。这样只有发布者账户能继续铸造该 Coin，这就是“独享所有权”。

## 发布和验证

```shell
cd src/02_coin/code/02_coin_owner
sui move build
sui client publish
```

发布成功后，在输出的 Created Objects 中查找：

- `TreasuryCap<...::hk::HK>`
- `TreasuryCap<...::usd::USD>`
- `TreasuryCap<...::rmb::RMB>`

这些对象的 Owner 应该是发布者地址。

## 本章小结

本章使用当前 Sui 推荐的 `coin_registry` 流程创建 Coin：

- 用 OTW 类型证明货币只能在模块初始化时创建一次
- 用 `new_currency_with_otw` 创建 `CurrencyInitializer<T>` 和 `TreasuryCap<T>`
- 用 `finalize_and_delete_metadata_cap` 完成 registry 注册
- 用 `public_transfer` 把 `TreasuryCap<T>` 转给发布者，实现独享铸造权限
