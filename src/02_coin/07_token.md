# Token 代币

在前面的章节中，我们学习了 Coin 的创建、共享所有权、发行量控制、锁定和黑名单等功能。本章介绍 Sui 上的另一个代币标准：Token。

## 本章目标

- 理解 Coin 与 Token 的区别和定位
- 掌握 TokenPolicy（代币策略）的生命周期
- 了解 Action 和 Rule 的工作机制
- 通过完整示例理解 Token 的使用方式

## Coin 与 Token 的区别

Coin 是 Sui 上最早也是最基础的同质化代币标准。我们在前面章节中使用的 `sui::coin` 模块提供了创建、铸造、转账等基本功能，通过 `TreasuryCap`（国库权限）来控制代币的铸造。Coin 是一种"开放式循环"（Open Loop）代币，一旦铸造出来，就可以在地址之间自由转移，没有额外的限制。

Token（`sui::token`）是 Sui 后来推出的新标准，它在 Coin 的基础上增加了更高级的管控能力，是一种"封闭式循环"（Closed Loop）代币：

| 特性 | Coin | Token |
|------|------|-------|
| 同质化代币 | 是 | 是 |
| 铸造权限控制 | TreasuryCap | TreasuryCap + TokenPolicy |
| 转账规则 | 无额外限制 | 可通过策略限制 |
| 花费审批 | 无 | Action 审批机制 |
| 灵活权限管理 | DenyList | 策略 + 规则组合 |
| 代币对象能力 | key + store | key（仅 key） |

简单来说，Coin 关注的是代币本身的存在形式，而 Token 关注的是代币的使用规则。Coin 一旦铸造就可以自由流通，而 Token 的每一次操作（转账、花费、兑换）都可以被策略约束。

## Token 的核心类型

Token 标准引入了以下几个核心类型：

**Token\<T\>**

```rust
public struct Token<phantom T> has key {
    id: UID,
    balance: Balance<T>,
}
```

Token 只有 `key` 能力，没有 `store` 能力。这意味着 Token 不能作为字段嵌入其他对象，也不能通过 `public_transfer` 转移。Token 的所有操作必须通过 `sui::token` 模块提供的函数来完成，从而确保每一次操作都会经过策略检查。

**TokenPolicy\<T\>**

```rust
public struct Token<phantom T> has key {
    id: UID,
    spent_balance: Balance<T>,
    rules: VecMap<String, VecSet<TypeName>>,
}
```

TokenPolicy 定义了代币的使用规则。它内部维护一个规则映射表（rules），记录每个 Action 需要满足哪些 Rule 才能执行。TokenPolicy 通常作为共享对象存在，任何人都可以读取它来验证规则。

**TokenPolicyCap\<T\>**

TokenPolicyCap 是管理 TokenPolicy 的权限凭证。持有者可以添加或移除规则，修改策略配置。

**ActionRequest\<T\>**

ActionRequest 是 Token 操作的中间产物。每次对 Token 执行操作（如转账、花费）时，都会生成一个 ActionRequest。这个请求必须经过所有相关 Rule 的验证后，才能被确认（confirm），整个操作才算完成。

## TokenPolicy 生命周期

TokenPolicy 的使用遵循一个明确的生命周期：

### 第一步：创建策略

在 `init` 函数中，使用 `token::new_policy` 从 TreasuryCap 创建 TokenPolicy 和对应的 TokenPolicyCap：

```move
let (policy, policy_cap) = token::new_policy(&treasury, ctx);
```

`new_policy` 接受 TreasuryCap 的不可变引用作为授权证明。由于 TreasuryCap 是唯一的，这保证了只有代币发行者才能创建策略。

### 第二步：配置规则

创建策略后，需要为各个 Action 添加规则。Token 标准定义了四个内置 Action：

| Action | 说明 | 触发时机 |
|--------|------|---------|
| `transfer` | 转账 | 将 Token 转移给其他地址时 |
| `spend` | 花费 | 销毁 Token 并取出其中的 Balance 时 |
| `to_coin` | 转为 Coin | 将 Token 转换为 Coin 时 |
| `from_coin` | 从 Coin 转入 | 将 Coin 转换为 Token 时 |

要允许某个 Action 自由执行（无需额外规则），可以使用 `token::allow`：

```move
// 允许转账操作自由执行，无需满足任何规则
token::allow(&mut policy, &policy_cap, token::transfer_action(), ctx);
```

要为某个 Action 添加规则，需要使用 `token::add_rule`：

```move
// 为 spending 操作添加一个自定义规则
//规则的具体验证逻辑由规则模块自己实现
token::add_rule(
    &mut policy,
    &policy_cap,
    token::spend_action(),
    type_name::get<MyRule>(),
    ctx
);
```

### 第三步：共享策略

配置完成后，将 TokenPolicy 作为共享对象发布：

```move
token::share_policy(policy);
```

TokenPolicyCap 需要妥善保管，后续修改策略时还需要使用它。

### 第四步：使用 Token

用户在使用 Token 时，操作流程如下：

```
用户操作 Token（如转账）
        |
        v
  生成 ActionRequest
        |
        v
  逐个验证 Rules
        |
        v
  确认请求（confirm_request）
        |
        v
     操作完成
```

每个 Rule 模块会提供自己的验证函数。验证通过后，在 ActionRequest 上"盖章"（stamp approval）。当所有规则都已满足时，调用 `token::confirm_request` 完成操作。

## 完整示例

以下是一个展示 Token 完整用法的伪代码示例。由于 Token 的规则模块需要单独开发，这里我们展示最常见的情况：将 Token 的转账设为自由操作（allow），对花费操作添加自定义规则：

```move
module token_coin::token_coin {
    use std::option;
    use sui::coin::{Self, TreasuryCap};
    use sui::token::{Self, Token, TokenPolicy, TokenPolicyCap, ActionRequest};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    public struct TOKEN_COIN has drop {}

    fun init(witness: TOKEN_COIN, ctx: &mut TxContext) {
        // 第一步：创建代币（与普通 Coin 创建方式相同）
        let (treasury, metadata) = coin::create_currency(
            witness,
            6,
            b"TKC",
            b"Token Coin",
            b"A token with policy",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);

        // 第二步：创建 TokenPolicy
        let (policy, policy_cap) = token::new_policy(&treasury, ctx);

        // 第三步：配置规则 -- 允许转账自由执行
        token::allow(&mut policy, &policy_cap, token::transfer_action(), ctx);

        // 第四步：共享策略
        token::share_policy(policy);

        // 将管理权限转移给发布者
        transfer::public_transfer(treasury, tx_context::sender(ctx));
        transfer::public_transfer(policy_cap, tx_context::sender(ctx));
    }

    /// 铸造 Token（注意返回的是 Token 类型，不是 Coin 类型）
    public entry fun mint_token(
        treasury: &mut TreasuryCap<TOKEN_COIN>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // 使用 token::mint 而非 coin::mint
        let token = token::mint(treasury, amount, ctx);
        transfer::public_transfer(token, tx_context::sender(ctx));
    }

    /// 转账 Token
    /// 由于我们在策略中将 transfer 设为 allow，所以只需
    /// 调用 token::transfer，然后立即确认即可
    public entry fun transfer_token(
        t: Token<TOKEN_COIN>,
        recipient: address,
        policy: &TokenPolicy<TOKEN_COIN>,
        ctx: &mut TxContext
    ) {
        // token::transfer 执行实际的转账，并返回一个 ActionRequest
        let request = token::transfer(t, recipient, ctx);

        // 由于 transfer 是 allow 的，无需额外验证，直接确认
        token::confirm_request(policy, request, ctx);
    }

    /// 花费 Token（销毁并取出 Balance）
    public entry fun spend_token(
        t: Token<TOKEN_COIN>,
        policy: &mut TokenPolicy<TOKEN_COIN>,
        ctx: &mut TxContext
    ) {
        // token::spend 销毁 Token，返回 ActionRequest
        let request = token::spend(t, ctx);

        // 如果 spending 有自定义规则，需要在此处添加规则验证逻辑
        // 例如：rule::verify(&mut request, ...)

        // 确认请求（使用 confirm_request_mut 因为 spend 操作涉及 Balance）
        token::confirm_request_mut(policy, request, ctx);
    }

    /// 将 Token 转换为 Coin
    public entry fun to_coin(
        t: Token<TOKEN_COIN>,
        policy: &TokenPolicy<TOKEN_COIN>,
        ctx: &mut TxContext
    ) {
        let (coin, request) = token::to_coin(t, ctx);
        token::confirm_request(policy, request, ctx);

        transfer::public_transfer(coin, tx_context::sender(ctx));
    }

    /// 将 Coin 转换为 Token
    public entry fun from_coin(
        coin: coin::Coin<TOKEN_COIN>,
        policy: &TokenPolicy<TOKEN_COIN>,
        ctx: &mut TxContext
    ) {
        let (t, request) = token::from_coin(coin, ctx);
        token::confirm_request(policy, request, ctx);

        transfer::public_transfer(t, tx_context::sender(ctx));
    }
}
```

### 代码说明

**init 函数**

init 函数完成了代币创建和策略配置的全部工作。先调用 `coin::create_currency` 创建代币（底层仍然使用 Coin 标准的类型系统），然后通过 `token::new_policy` 创建策略。`token::allow` 将 `transfer` Action 设为自由操作，这意味着转账不需要经过任何额外验证。最后通过 `token::share_policy` 将策略发布为共享对象。

**mint_token 函数**

使用 `token::mint` 铸造 Token 而非 `coin::mint` 铸造 Coin。`token::mint` 返回的是 `Token<T>` 类型而非 `Coin<T>` 类型。两者的区别在于 `Token` 只有 `key` 能力，其所有操作都受到 TokenPolicy 的约束。

**transfer_token 函数**

转账流程分两步：先调用 `token::transfer` 执行实际的对象转移并生成 `ActionRequest`，然后调用 `token::confirm_request` 确认请求。由于我们在策略中允许了自由转账，确认步骤会直接通过。如果策略中为 `transfer` 添加了规则，则需要在确认之前完成规则验证。

**spend_token 函数**

花费操作使用 `token::spend`，它会销毁 Token 对象并将 Balance 存入 ActionRequest。确认时需要使用 `confirm_request_mut`（可变引用版本），因为花费操作会将 Balance 转入 TokenPolicy 的 `spent_balance` 字段。这些余额最终可以通过 `token::flush` 取出并交由 TreasuryCap 持有者处理。

**to_coin / from_coin 函数**

Token 和 Coin 之间可以互相转换。这为代币在不同场景下的灵活使用提供了支持。例如，一个 Token 在受控环境中流通，但当需要接入只支持 Coin 标准的 DeFi 协议时，可以临时转换为 Coin。

## Coin 与 Token 的选择

**使用 Coin 就足够的场景：**

- 简单的代币发行与转账
- 只需要基本的铸造和销毁功能
- 通过 DenyList 黑名单即可满足合规需求
- 需要接入已有的 DeFi 协议（大多数协议直接使用 Coin 标准）

**需要使用 Token 的场景：**

- 需要对代币的每次花费或转账进行审批
- 需要实现复杂的权限管理规则，例如 KYC/AML 验证
- 需要在代币流通环节中加入自定义逻辑，例如收取手续费、限制交易频率
- 需要实现"封闭循环"代币，即代币只能在特定范围内使用

对于大多数 DeFi 应用，Coin 已经能够满足需求。Token 更适合需要精细化管控的场景，例如受监管的稳定币、企业内部的积分系统或需要链上权限审计的机构级代币。

## 本章小结

本章介绍了 Sui 的 Token 标准。Token 在 Coin 的基础上增加了一层策略管理，通过 TokenPolicy 和 Action 机制实现对代币操作的精细管控。

关键要点：

- Token 只有 `key` 能力，所有操作必须通过 `sui::token` 模块完成，确保策略检查不被绕过
- TokenPolicy 定义规则，ActionRequest 记录操作请求，两者配合实现"先验证后执行"的流程
- 四个内置 Action（transfer、spend、to_coin、from_coin）覆盖了代币的主要使用场景
- Token 和 Coin 可以互相转换，兼顾了管控能力和生态兼容性

至此，Coin 章节的内容全部结束。我们涵盖了从基础创建到高级管控的完整知识体系。在后续的 Swap 章节中，我们将使用这些知识来构建一个完整的去中心化交易协议。
