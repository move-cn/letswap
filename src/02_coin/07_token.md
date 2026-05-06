# Token 代币

Sui 上有 Coin 标准，也有更强调策略控制的 Token 模型。本章先保持代码可编译，展示如何使用当前 `coin_registry` API 创建基础代币，并说明 Token Policy 应该放在什么位置继续扩展。

## 本章目标

- 区分 Coin 与 Token 的职责
- 使用当前 Currency Registry 创建代币
- 理解为什么 Token Policy 适合受控流通场景
- 为后续扩展策略留出接口

## 当前示例代码

源码路径：`src/02_coin/code/07_token_coin/sources/token_coin.move`

```move
module token_coin::token_coin ;
use sui::coin_registry;
use std::string;

public struct TOKEN_COIN has drop {}

fun init(witness: TOKEN_COIN, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"TOKEN_COIN"),
        string::utf8(b""),
        string::utf8(b""),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);

    // token::new_policy()

    transfer::public_transfer(treasury, ctx.sender())
}
```

这段代码目前创建的是一个可继续扩展的基础货币。注释中的 `token::new_policy()` 表示后续可以在此处加入 Token Policy，但本章源码没有强行加入未讲清楚的策略逻辑，避免读者复制后编译失败。

## Coin 与 Token 的区别

| 维度 | Coin | Token / Token Policy |
|------|------|----------------------|
| 主要目标 | 同质化资产发行与转账 | 在资产流通过程中加入策略控制 |
| 铸造权限 | `TreasuryCap<T>` 或自定义 `Supply<T>` | 通常仍依赖底层资产权限 |
| 转账规则 | 默认自由转账，可配合 DenyList | 可按 action 和 rule 组合限制 |
| 适合场景 | DeFi、AMM、普通代币 | 合规资产、受控支付、机构工作流 |

对于大多数 Swap 和 AMM 场景，`Coin<T>` 已经足够。只有当代币流通过程需要审批、规则或合规策略时，才需要引入 Token Policy。

## Token Policy 应放在哪里

货币创建流程中，`new_currency_with_otw` 负责注册类型和生成 `TreasuryCap<T>`。策略相关逻辑应在初始化阶段完成：

```move
let (init, treasury) = coin_registry::new_currency_with_otw(...);

// 在这里创建和配置 token policy
// let policy = token::new_policy(...);
// token::allow(...);
// token::share_policy(policy);

coin_registry::finalize_and_delete_metadata_cap(init, ctx);
```

本书主线是 Swap，因此不会把 Token Policy 展开成完整合规系统。实际项目如果要使用 Token Policy，需要单独设计：

- 哪些 action 需要审批
- 哪些地址或对象可以批准 action
- 规则失败时如何提示用户
- 策略对象如何升级或治理

## 本章小结

本章把旧的 `coin::create_currency` 写法更新为当前 `coin_registry` 写法，并明确 Token Policy 是后续扩展点。对于 Swap 教程，核心仍是 `Coin<T>`；Token 更适合受控流通、合规和机构资产场景。
