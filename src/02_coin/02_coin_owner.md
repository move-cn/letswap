# 例子

我们先来看一下完整的产生 Coin 的例子。

## 独享所有权

独享所有权指的是 Coin 的铸造权限（TreasuryCap）只转移给发布者地址，只有发布者可以铸造新的 Coin。

### HK 的代码

```move
module coin_owner::hk {
    use sui::coin::create_currency;
    use sui::tx_context::{TxContext, sender};
    use std::option;
    use sui::transfer;

    public struct HK has drop {}

    fun init(hk: HK, ctx: &mut TxContext) {
        let (treasury_cap, coin_metadata) =
            create_currency(
                hk,
                8,
                b"HK",
                b"HK made in hongkong",
                b"HK made in hongkong",
                option::none(),
                ctx
            );

        transfer::public_freeze_object(coin_metadata);

        let my_address = sender(ctx);
        transfer::public_transfer(treasury_cap, my_address)
    }
}
```

### USD 的代码

```move
module coin_owner::usd {
    use std::option;
    use sui::coin;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    public struct USD has drop {}

    fun init(witness: USD, ctx: &mut TxContext) {
        let (treasury, metadata) =
            coin::create_currency(witness, 6, b"USD", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }
}
```

### 代码说明

#### `public struct HK has drop {}`

Witness 类型，必须具有 `drop` 能力。它在模块初始化时作为一次性见证（Witness）使用，用完即丢。

#### `create_currency`

- 创建 Coin 类型，返回两个对象：
  - `treasury_cap`：国库权限，持有者可以铸造新 Coin
  - `coin_metadata`：Coin 的元信息（名称、图标、描述等）

#### `public_freeze_object`

将 `coin_metadata` 冻结，变为不可变对象，任何人都可以读取但无法修改。

#### `public_transfer`

将 `treasury_cap` 转移给发布者地址，只有发布者拥有铸造权限，这就是"独享所有权"。

### 发布命令

```shell
sui client publish
```

发布后，`treasury_cap` 对象会出现在发布者的账户中，可以使用 `sui client call` 来铸造 Coin。

## 本章小结

本章介绍了 Coin 的独享所有权模式：

- 使用 `create_currency` 创建 Coin，返回 `TreasuryCap`（铸造权限）和 `CoinMetadata`（元信息）
- 使用 `public_transfer` 将 `TreasuryCap` 转移给发布者地址，实现独享铸造权限
- 使用 `public_freeze_object` 冻结 `CoinMetadata` 为不可变对象
- Witness 类型必须具有 `drop` 能力，在 `init` 函数中作为一次性见证使用
