# Coin 黑名单（Deny List）

某些代币需要具备合规控制能力，例如禁止特定地址接收或发送代币。Sui 为受监管代币提供了 DenyList 机制。旧代码常见 `coin::create_regulated_currency_v2`，当前推荐流程是 `coin_registry::new_currency_with_otw` 加 `coin_registry::make_regulated`。

## 本章目标

- 理解 `DenyCapV2<T>` 的作用
- 使用 `coin_registry::make_regulated` 创建受监管货币
- 区分普通 Coin 与受监管 Coin
- 理解 DenyList 的应用边界

## 完整代码

源码路径：`src/02_coin/code/06_deny_coin/sources/deny_coin.move`

```move
module deny_coin::deny_coin ;
use sui::coin_registry;
use std::string;

public struct DENY_COIN has drop {}

fun init(witness: DENY_COIN, ctx: &mut TxContext) {
    let (mut init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        8,
        string::utf8(b"DENY"),
        string::utf8(b"Deny Coin"),
        string::utf8(b"Deny list demo coin"),
        string::utf8(b""),
        ctx
    );
    let deny_cap = coin_registry::make_regulated(&mut init, true, ctx);
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);
    transfer::public_transfer(deny_cap, ctx.sender());
    transfer::public_transfer(treasury, ctx.sender());
}
```

## `make_regulated`

```move
let deny_cap = coin_registry::make_regulated(&mut init, true, ctx);
```

`make_regulated` 会把初始化中的货币标记为受监管货币，并返回 `DenyCapV2<T>`。第二个参数表示是否允许全局暂停：

| 参数 | 含义 |
|------|------|
| `true` | 允许发行者全局暂停该币种 |
| `false` | 只允许按地址加入/移除黑名单 |

`DenyCapV2<T>` 是管理黑名单的权限对象，必须妥善保管。示例中把它转给发布者：

```move
transfer::public_transfer(deny_cap, ctx.sender());
```

## 新旧 API 对比

| 旧 API | 新 API |
|--------|--------|
| `coin::create_regulated_currency_v2` | `coin_registry::new_currency_with_otw` |
| 函数直接返回 `DenyCapV2<T>` | 通过 `coin_registry::make_regulated` 生成 `DenyCapV2<T>` |
| 返回 `CoinMetadata<T>` | 使用 registry initializer 并 finalize |

本书不再把旧 API 作为主线，因为它会触发 deprecated warning。

## DenyList 的操作方式

框架中仍提供 DenyList 操作函数。新代码应使用 V2 版本：

```move
coin::deny_list_v2_add<T>(
    deny_list,
    deny_cap,
    addr,
    ctx
);

coin::deny_list_v2_remove<T>(
    deny_list,
    deny_cap,
    addr,
    ctx
);
```

真实项目通常会再封装一层业务函数，例如：

```move
public fun deny(
    deny_list: &mut DenyList,
    deny_cap: &mut DenyCapV2<DENY_COIN>,
    addr: address,
    ctx: &mut TxContext
) {
    coin::deny_list_v2_add<DENY_COIN>(deny_list, deny_cap, addr, ctx);
}
```

## 使用场景

- 合规稳定币：按监管要求冻结地址
- 风险控制：阻止已知攻击地址继续流通代币
- 机构资产：链上资产需要满足 KYC/AML 规则

## 风险边界

DenyList 是强权限工具。它提升了合规能力，但也带来中心化控制风险。生产项目需要明确：

- 谁持有 `DenyCapV2<T>`
- 是否由多签或治理控制
- 是否允许全局暂停
- 黑名单操作是否需要事件记录
- 用户是否能查询某地址是否被限制

## 本章小结

当前推荐的受监管 Coin 创建流程是：

1. 使用 `coin_registry::new_currency_with_otw` 创建货币初始化器和 `TreasuryCap<T>`
2. 使用 `coin_registry::make_regulated` 生成 `DenyCapV2<T>`
3. finalize metadata
4. 把 `TreasuryCap<T>` 和 `DenyCapV2<T>` 转给管理员

不要在新教程中继续以 `create_regulated_currency_v2` 作为主方案。
