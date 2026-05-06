# 版本说明与迁移

Sui 和 Move 的工具链更新很快。一本教程如果只展示“当时能跑”的代码，很快就会过时。本章专门说明本书采用的版本口径，以及如何把旧教程里的 Coin 创建代码迁移到当前写法。

## 本章目标

- 明确本书使用的 Move 2024 语法
- 理解 `coin::create_currency` 为什么不再作为主线
- 掌握 `coin_registry::new_currency_with_otw` 的创建流程
- 理解受监管 Coin 的新旧 API 对照

## 本书版本口径

本书的 Move 示例统一使用：

```toml
edition = "2024.beta"
```

模块声明统一使用 Move 2024 风格：

```move
module my_package::my_module ;
```

而不是旧版的大括号包裹写法：

```move
module my_package::my_module {
    // old style
}
```

如果读者看到旧教程使用大括号模块语法，需要先迁移到 Move 2024 语法。

## Coin 创建 API 的变化

早期 Sui 教程通常这样创建 Coin：

```move
let (treasury, metadata) = coin::create_currency(
    witness,
    6,
    b"USD",
    b"",
    b"",
    option::none(),
    ctx
);
```

这个写法在当前工具链中会出现 deprecated warning。本书改用 Currency Registry：

```move
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
```

## 迁移对照表

| 旧写法 | 新写法 | 说明 |
|--------|--------|------|
| `coin::create_currency` | `coin_registry::new_currency_with_otw` | 创建货币类型和 `TreasuryCap<T>` |
| `vector<u8>` 元数据 | `string::utf8(b"...")` | 新 API 使用 `String` |
| `CoinMetadata<T>` | Currency Registry metadata | 元信息进入 registry |
| `public_freeze_object(metadata)` | `finalize_and_delete_metadata_cap(init, ctx)` | 完成元信息注册 |
| `create_regulated_currency_v2` | `new_currency_with_otw` + `make_regulated` | 创建受监管货币 |

## 普通 Coin 迁移模板

```move
module demo::usd ;
use sui::coin_registry;
use std::string;

public struct USD has drop {}

fun init(witness: USD, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"USD"),
        string::utf8(b"USD"),
        string::utf8(b"Demo USD"),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);
    transfer::public_transfer(treasury, ctx.sender());
}
```

## 受监管 Coin 迁移模板

```move
module demo::regulated ;
use sui::coin_registry;
use std::string;

public struct REGULATED has drop {}

fun init(witness: REGULATED, ctx: &mut TxContext) {
    let (mut init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"REG"),
        string::utf8(b"Regulated Coin"),
        string::utf8(b"Demo regulated coin"),
        string::utf8(b""),
        ctx
    );
    let deny_cap = coin_registry::make_regulated(&mut init, true, ctx);
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);
    transfer::public_transfer(treasury, ctx.sender());
    transfer::public_transfer(deny_cap, ctx.sender());
}
```

## 迁移检查清单

- 模块声明是否使用 `module package::module ;`
- 是否还在主代码里使用 `coin::create_currency`
- 是否还在主代码里使用 `create_regulated_currency_v2`
- metadata 字段是否已经从 `b"..."` 参数改成 `string::utf8(b"...")`
- 是否调用了 `coin_registry::finalize_and_delete_metadata_cap`
- `sui move build` 是否没有错误和可见警告

## 本章小结

本书以 Move 2024 和 Currency Registry 为主线。旧 API 只用于迁移说明，不再作为可复制的主代码。读者在参考其他旧教程时，最先要检查的就是模块声明语法和 Coin 创建 API。
