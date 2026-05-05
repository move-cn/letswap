# 泛型交换合约：支持任意币对

在上一章中，我们实现了一个固定币对的 USD/RMB 兑换合约。那种方式有一个明显的局限：每种币对都需要编写独立的合约代码。如果想要支持 SUI/USDC、ETH/USDT 等新的币对，就必须复制并修改整个合约，这显然不可取。

本章将利用 Move 的泛型（Generics）特性，编写一个通用的交换合约，只需部署一次就能支持任意币对的兑换。

## 本章目标

- 理解 phantom 泛型参数的原理与作用
- 实现通用的 `Bank<CoinA, CoinB>` 泛型结构体
- 掌握泛型函数的定义与调用方式
- 实现任意币对的动态创建与 1:1 兑换

## 与固定币对合约的对比

先通过一个表格直观地了解两种实现的差异：

| 对比项 | 固定币对合约（上章） | 泛型合约（本章） |
|--------|---------------------|-------------------|
| 币对类型 | 硬编码为 USD/RMB | 通过泛型参数 CoinA/CoinB 指定 |
| Bank 结构体 | `Bank { rmb, usd }` | `Bank<CoinA, CoinB> { a, b }` |
| 存款函数 | `deposit_rmb` / `deposit_usd` | `deposit_a<CoinA, CoinB>` / `deposit_b<CoinA, CoinB>` |
| 兑换函数 | `swap_rmb_usd` / `swap_usd_rmb` | `swap_a_b<CoinA, CoinB>` |
| 新增币对 | 需要编写新合约 | 调用 `create` 函数即可 |
| 汇率 | 自定义固定汇率 | 本章使用 1:1（后续章节扩展） |

核心区别在于：固定币对合约将类型写死在代码中，而泛型合约将类型参数化，在调用时才确定具体的币种。

## phantom 泛型参数的原理

在 Move 语言中，泛型参数通常会影响结构体的存储能力（abilities）。但在某些场景下，泛型类型仅用作标记，不需要实际存储该类型的值。这时可以使用 `phantom` 关键字。

```move
public struct Bank<phantom CoinA, phantom CoinB> has key {
    id: UID,
    a: Balance<CoinA>,
    b: Balance<CoinB>
}
```

`phantom` 的含义是：`CoinA` 和 `CoinB` 这两个类型参数不包含在结构体的字段中（字段的类型虽然引用了它们，但 `phantom` 告诉编译器在推导 abilities 时忽略这些参数）。

更具体地说：

- 没有 `phantom` 时，`Bank<T1, T2>` 是否具有 `key` 能力取决于 `T1` 和 `T2` 是否具有相应的能力
- 加上 `phantom` 后，`Bank<T1, T2>` 的 abilities 只取决于结构体本身声明的 `has key`，不受 `T1` 和 `T2` 的影响

这意味着我们可以用任何 Coin 类型来实例化 `Bank`，而不需要这些 Coin 类型具有特定的 abilities。这正是我们需要的 -- USD、RMB、SUI、USDC 等各种 Coin 类型都可以自由组合。

## 完整代码展示

以下是 `sources/swap_generic.move` 的完整代码：

```move
module swap_generic::swap_generic {
    use sui::balance;
    use sui::balance::Balance;
    use sui::coin;
    use sui::coin::Coin;
    use sui::object;
    use sui::object::UID;
    use sui::transfer::{share_object, public_transfer};
    use sui::tx_context::{TxContext, sender};

    public struct AdminCap has key {
        id: UID,
    }

    public struct Bank<phantom CoinA, phantom CoinB> has key {
        id: UID,
        a: Balance<CoinA>,
        b: Balance<CoinB>
    }

    fun init(ctx: &mut TxContext) { }

    public entry fun create<CoinA, CoinB>(ctx: &mut TxContext) {
        let pool = Bank<CoinA, CoinB> {
            id: object::new(ctx),
            a: balance::zero(),
            b: balance::zero(),
        };
        share_object(pool);
    }

    public entry fun deposit_a<CoinA, CoinB>(bank: &mut Bank<CoinA, CoinB>, a: Coin<CoinA>, _: &mut TxContext) {
        let a_balance = coin::into_balance(a);
        bank.a.join(a_balance);
    }

    public entry fun deposit_b<CoinA, CoinB>(bank: &mut Bank<CoinA, CoinB>, b: Coin<CoinB>, _: &mut TxContext) {
        let b_balance = coin::into_balance(b);
        bank.b.join(b_balance);
    }

    public entry fun swap_a_b<CoinA, CoinB>(bank: &mut Bank<CoinA, CoinB>, a: Coin<CoinA>, ctx: &mut TxContext) {
        let amt = coin::value(&a);
        bank.a.join(coin::into_balance(a));
        let amt_b = amt;
        let b_balance = bank.b.split(amt_b);
        let b = coin::from_balance(b_balance, ctx);
        public_transfer(b, sender(ctx));
    }
}
```

## 逐段代码讲解

### Bank 泛型结构体

```move
public struct Bank<phantom CoinA, phantom CoinB> has key {
    id: UID,
    a: Balance<CoinA>,
    b: Balance<CoinB>
}
```

与上一章的 `Bank` 相比，关键变化在于引入了两个 `phantom` 泛型参数 `CoinA` 和 `CoinB`。

- `<phantom CoinA, phantom CoinB>` 声明了两个泛型类型参数，它们用 `phantom` 标记
- 字段 `a` 存储第一种代币的余额，类型为 `Balance<CoinA>`
- 字段 `b` 存储第二种代币的余额，类型为 `Balance<CoinB>`

当用具体类型实例化时，比如 `Bank<USD, RMB>`，`a` 就是 USD 的余额，`b` 就是 RMB 的余额。如果换成 `Bank<SUI, USDC>`，则 `a` 是 SUI 的余额，`b` 是 USDC 的余额。

不同类型参数实例化的 Bank 是完全不同的类型。`Bank<USD, RMB>` 和 `Bank<SUI, USDC>` 是两个独立的对象，互不干扰。

### init 函数

```move
fun init(ctx: &mut TxContext) { }
```

与上一章不同，这里的 `init` 函数是空的。因为 Bank 的创建需要指定具体的币对类型，而 `init` 在模块发布时自动执行，无法指定泛型参数。因此 Bank 的创建被移到了独立的 `create` 函数中，由用户在发布后手动调用。

### create 函数：动态创建币对池子

```move
public entry fun create<CoinA, CoinB>(ctx: &mut TxContext) {
    let pool = Bank<CoinA, CoinB> {
        id: object::new(ctx),
        a: balance::zero(),
        b: balance::zero(),
    };
    share_object(pool);
}
```

这是创建兑换池子的入口函数。调用时需要指定两个泛型类型参数，例如：

- `create<USD, RMB>` 创建 USD/RMB 兑换池
- `create<SUI, USDC>` 创建 SUI/USDC 兑换池

每次调用 `create` 都会在链上创建一个新的共享 `Bank` 对象，拥有独立的储备余额。这意味着同一个合约可以管理多个不同币对的兑换池。

### deposit_a 与 deposit_b：泛型存款

```move
public entry fun deposit_a<CoinA, CoinB>(bank: &mut Bank<CoinA, CoinB>, a: Coin<CoinA>, _: &mut TxContext) {
    let a_balance = coin::into_balance(a);
    bank.a.join(a_balance);
}

public entry fun deposit_b<CoinA, CoinB>(bank: &mut Bank<CoinA, CoinB>, b: Coin<CoinB>, _: &mut TxContext) {
    let b_balance = coin::into_balance(b);
    bank.b.join(b_balance);
}
```

逻辑与上一章的 `deposit_rmb` / `deposit_usd` 完全一致，只是将固定的币种类型替换为泛型参数。

注意函数签名中泛型参数的约束：`bank: &mut Bank<CoinA, CoinB>` 和 `a: Coin<CoinA>`。编译器会确保传入的 Coin 类型与 Bank 的泛型类型一致。如果你尝试向 `Bank<USD, RMB>` 存入 `Coin<SUI>`，编译会直接报错。

### swap_a_b：1:1 固定交换

```move
public entry fun swap_a_b<CoinA, CoinB>(bank: &mut Bank<CoinA, CoinB>, a: Coin<CoinA>, ctx: &mut TxContext) {
    let amt = coin::value(&a);
    bank.a.join(coin::into_balance(a));
    let amt_b = amt;
    let b_balance = bank.b.split(amt_b);
    let b = coin::from_balance(b_balance, ctx);
    public_transfer(b, sender(ctx));
}
```

交换逻辑与上一章类似，但简化了汇率计算 -- 本章使用 1:1 的固定汇率（`let amt_b = amt`）。

执行流程：

1. 读取用户存入的 CoinA 数量
2. 将 CoinA 合并到 Bank 的 A 储备中
3. 按相同数量从 Bank 的 B 储备中分离出余额
4. 将余额转为 CoinB 并转给用户

1:1 汇率简化了教学，但实际应用中可以根据需要修改计算逻辑，引入自定义的汇率公式。在后续章节中，我们将实现更复杂的恒定乘积做市商（AMM）汇率模型。

## 如何使用

以下以创建一个 SUI/USDC 兑换池为例，演示完整的操作流程。

### 编译与发布

```shell
cd src/03_swap/code/03_swap_generic
sui move build
sui client publish --gas-budget 100000000
```

记下发布后得到的 Package ID。

### 创建兑换池

假设我们已有 SUI 和 USDC 两种代币的类型信息：

```shell
# 创建 SUI/USDC 兑换池
sui client call --package <PACKAGE_ID> --module swap_generic \
  --function create --type-args 0x2::sui::SUI <USDC_TYPE> \
  --gas-budget 10000000
```

其中 `<USDC_TYPE>` 是 USDC 代币的完整类型路径，格式为 `<PACKAGE_ID>::usdc::USDC`。

执行成功后，会创建一个 `Bank<SUI, USDC>` 共享对象。记下这个 Bank 的对象 ID。

### 存入储备

```shell
# 存入 SUI
sui client call --package <PACKAGE_ID> --module swap_generic \
  --function deposit_a --type-args 0x2::sui::SUI <USDC_TYPE> \
  --args <BANK_ID> <SUI_COIN_ID> --gas-budget 10000000

# 存入 USDC
sui client call --package <PACKAGE_ID> --module swap_generic \
  --function deposit_b --type-args 0x2::sui::SUI <USDC_TYPE> \
  --args <BANK_ID> <USDC_COIN_ID> --gas-budget 10000000
```

注意 `--type-args` 必须与创建池子时指定的类型完全一致，否则会找不到对应的 Bank 对象。

### 执行兑换

```shell
# 用 SUI 换 USDC
sui client call --package <PACKAGE_ID> --module swap_generic \
  --function swap_a_b --type-args 0x2::sui::SUI <USDC_TYPE> \
  --args <BANK_ID> <SUI_COIN_ID> --gas-budget 10000000
```

## 本章小结

本章通过引入 Move 的泛型特性，将固定币对合约重构为通用合约。核心知识点包括：

- **phantom 泛型参数**：使用 `phantom` 关键字声明不参与 abilities 推导的类型参数，使结构体可以接受任意 Coin 类型
- **泛型函数**：`create<CoinA, CoinB>` 等函数在调用时通过 `--type-args` 指定具体类型，一次部署即可支持任意币对
- **类型安全**：编译器确保 Coin 类型和 Bank 的泛型参数一致，防止类型错误
- **动态创建池子**：每个币对对应一个独立的 Bank 对象，互不干扰

本合约使用 1:1 固定汇率，逻辑简化便于理解。但它仍然缺少管理员提取功能、自定义汇率、滑点保护等生产级特性。在后续章节中，我们将逐步引入这些功能，最终实现一个完整的恒定乘积做市商（AMM）模型。
