# 共享所有权 Coin

上一章把 `TreasuryCap<T>` 转给发布者，形成独享铸造权限。本章把 `TreasuryCap<T>` 作为共享对象发布到链上，让任何人都能访问它。这种模式适合测试币、水龙头和教学场景，不适合没有额外限制的真实价值代币。

## 本章目标

- 理解 shared object 与 address-owned object 的区别
- 掌握 `transfer::public_share_object` 的使用
- 理解共享 `TreasuryCap<T>` 的便利性和风险

## RMB 的代码

源码路径：`src/02_coin/code/03_coin_share/sources/rmb.move`

```move
module coin_share::rmb ;
use sui::coin_registry;
use std::string;

public struct RMB has drop {}

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
    // 所有人都能访问
    transfer::public_share_object(treasury);
}
```

## USD 的代码

源码路径：`src/02_coin/code/03_coin_share/sources/usd.move`

```move
module coin_share::usd ;
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
    transfer::public_share_object(treasury);
}
```

## 与独享所有权的区别

| 模式 | 关键调用 | `TreasuryCap<T>` 所有权 | 铸造权限 |
|------|----------|-------------------------|----------|
| 独享所有权 | `transfer::public_transfer` | 发布者地址拥有 | 只有持有人 |
| 共享所有权 | `transfer::public_share_object` | 链上共享对象 | 任何交易都可引用 |

共享对象没有单一 owner。任何用户都可以在交易中传入这个 `TreasuryCap<T>`，再调用对应的铸造函数。因此共享模式一定要和访问控制、额度限制或测试环境边界配合使用。

## 使用场景

- 测试网水龙头：任何开发者都可以拿测试币
- 教学示例：减少权限管理干扰，专注理解 Coin 结构
- 协议内部共享权限：由后续合约逻辑约束铸造流程

## 风险提醒

如果把共享 `TreasuryCap<T>` 用在生产价值代币中，任何人都能无限铸造，代币价值会立刻归零。生产项目通常使用以下方式替代：

- 把 `TreasuryCap<T>` 转给管理员多签
- 把 `TreasuryCap<T>` 包装进带权限检查的对象
- 使用 `Supply<T>` 自定义发行量和额度控制

## 本章小结

本章展示了共享所有权模式。核心变化只有一行：把 `public_transfer` 改成 `public_share_object`。这行代码会彻底改变权限模型：从“只有持有人能铸造”变为“任何人都能引用共享对象”。这种模式简单，但风险很高，适合测试与教学，不适合无约束的生产代币。
