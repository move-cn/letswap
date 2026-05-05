# Uniswap V2 恒定乘积做市商

在前面的章节中，我们学习了固定汇率交换和经济模型的基本概念。固定汇率虽然简单，但它有一个致命的缺陷：价格不会随市场供需变化。当市场上美元紧缺时，固定汇率仍然按照 1:7.3 兑换，这就给了套利者可乘之机，同时也无法反映真实的供需关系。

Uniswap V2 提出了一种优雅的解决方案：恒定乘积做市商（Constant Product Market Maker）。它用一个简洁的数学公式，让价格自动随供需调整，无需任何中心化的定价机构。本章我们将从数学原理出发，逐步推导核心公式，并完整解析 LetSwap 项目的实现。

## 1. 本章目标

本章结束后，你将理解以下内容：

- 恒定乘积公式 x * y = k 的推导过程
- Swap 中输出量的计算方法
- 滑点的成因与影响
- LP Token 的铸造与赎回逻辑
- 手续费的分账机制
- LetSwap 项目的六模块架构
- 完整的部署与操作流程
- 智能合约中的安全防护措施

---

## 2. 恒定乘积公式推导

### 2.1 从 x * y = k 出发

设想一个资金池，里面同时存放着两种代币：代币 X 和代币 Y。我们用 x 表示池中 X 的数量，用 y 表示池中 Y 的数量。恒定乘积公式的核心思想非常简单：

```
x * y = k
```

其中 k 是一个常数。这意味着，无论用户往池子里放入多少代币或从中取出多少代币，池中两种代币数量的乘积始终保持不变。

为什么这个乘积应该恒定？可以这样理解：当用户用 X 换 Y 时，用户把 X 放入池子，池子的 X 数量增加了；同时从池子中取出 Y，池子的 Y 数量减少了。为了维持乘积不变，X 增加越多，Y 就必须减少越多。这就自然地形成了一个价格曲线：换得越多，单位代币的兑换价格越差。

### 2.2 推导 get_amount_out 公式

现在我们推导最关键的公式：已知输入量、当前储备量，求输出量。

设当前池子状态为：

- X 的储备量：reserve_x
- Y 的储备量：reserve_y
- 恒定乘积：k = reserve_x * reserve_y

用户希望用 x_in 个代币 X 换取代币 Y。交换完成后：

- 池中 X 的新数量：reserve_x + x_in
- 池中 Y 的新数量：reserve_y - y_out

根据恒定乘积约束：

```
(reserve_x + x_in) * (reserve_y - y_out) = k = reserve_x * reserve_y
```

展开等式左边：

```
reserve_x * reserve_y - reserve_x * y_out + x_in * reserve_y - x_in * y_out = reserve_x * reserve_y
```

两边消去 reserve_x * reserve_y：

```
-reserve_x * y_out + x_in * reserve_y - x_in * y_out = 0
```

移项整理：

```
x_in * reserve_y = y_out * (reserve_x + x_in)
```

最终得到：

```
y_out = (x_in * reserve_y) / (reserve_x + x_in)
```

这就是 Uniswap V2 的核心公式。它告诉我们：在已知输入量和两种代币当前储备量的情况下，输出量可以通过上述公式精确计算。

### 2.3 LetSwap 中的代码实现

在 LetSwap 的 `core_amm.move` 中，这个公式的实现如下：

```move
public fun get_amount_out(amount_in_without_fee: u64, reserve_in: u64, reserve_out: u64): u64 {
    assert!(amount_in_without_fee > 0, ERR_INSUFFICIENT_INPUT_AMOUNT);
    assert!(reserve_in > 0 && reserve_out > 0, ERR_INSUFFICIENT_LIQUIDITY);

    let numerator = (amount_in_without_fee as u128) * (reserve_out as u128);
    let denominator = (reserve_in as u128) + (amount_in_without_fee as u128);
    ((numerator / denominator) as u64)
}
```

代码逻辑与数学公式完全对应：`numerator` 是分子（x_in * reserve_out），`denominator` 是分母（reserve_in + x_in），两者相除得到输出量。注意中间计算使用了 u128 类型，这是为了防止两个 u64 值相乘时溢出，后面安全性分析一节会详细讨论。

### 2.4 数值示例

为了更直观地理解公式，我们用一个具体的例子来计算。

假设有一个 USD/RMB 的资金池，当前储备为：

- reserve_x（USD）= 100 亿 = 10,000,000,000
- reserve_y（RMB）= 100 亿 = 10,000,000,000
- 恒定乘积 k = 100 亿 * 100 亿 = 10^20

**示例 1：用 1 亿 USD 换 RMB**

代入公式：

```
y_out = (1 亿 * 100 亿) / (100 亿 + 1 亿)
      = 10^18 / 1.01 * 10^10
      = 0.9900990099 亿
      = 99,009,900.99 RMB
```

注意，表面汇率是 100 亿 / 100 亿 = 1:1，但实际换了不到 1 亿 RMB（约 0.99 亿）。这个差额就是滑点，下一节会详细解释。

交换后池子状态：

- USD 储备：101 亿
- RMB 储备：100 亿 - 0.990099 亿 = 99.009901 亿
- 验证：101 亿 * 99.009901 亿 = 9999.9999... 亿（约等于 10000 亿，微小差异源于整数截断）

**示例 2：用 10 亿 USD 换 RMB**

```
y_out = (10 亿 * 100 亿) / (100 亿 + 10 亿)
      = 10^19 / 1.1 * 10^10
      = 9.0909 亿 RMB
```

对比示例 1：1 亿 USD 换到约 0.99 亿 RMB，10 亿 USD 只换到约 9.09 亿 RMB。兑换量增加了 10 倍，但得到的人民币只有大约 9.18 倍（9.09 / 0.99）。这就是滑点在起作用：换得越多，平均汇率越差。

交换后池子状态：

- USD 储备：110 亿
- RMB 储备：100 亿 - 9.0909 亿 = 90.9091 亿

如果有人继续用 100 亿 USD 来兑换，此时的储备已经从 100/100 变成了 110/90.9091，汇率会进一步恶化。这个自动调整机制确保了池子永远不会被某一种代币掏空。

---

## 3. 滑点概念

### 3.1 什么是滑点

滑点（Slippage）是指交易的实际成交价格与预期价格之间的差异。在恒定乘积做市商中，滑点是不可避免的。

用上一节的例子来说明：

- 初始汇率（池子中 USD 和 RMB 各 100 亿）：1 USD = 1 RMB（边际价格）
- 用 1 亿 USD 兑换时，实际得到 0.99 亿 RMB，实际汇率约 1 USD = 0.99 RMB
- 用 10 亿 USD 兑换时，实际得到 9.09 亿 RMB，实际汇率约 1 USD = 0.909 RMB

兑换量越大，实际汇率偏离边际价格越远，滑点就越大。

### 3.2 为什么换得越多汇率越差

从数学角度分析。将输出公式 y_out = (x_in * reserve_y) / (reserve_x + x_in) 变形为平均汇率：

```
平均汇率 = y_out / x_in = reserve_y / (reserve_x + x_in)
```

当 x_in = 0 时，平均汇率 = reserve_y / reserve_x，这就是边际价格。随着 x_in 增大，分母 (reserve_x + x_in) 越来越大，平均汇率越来越小。这就是恒定乘积模型"换得越多越亏"的数学本质。

从经济角度理解：池子中的代币是有限的。当大量买入某种代币时，该代币的储备急剧减少，变得稀缺，自然就要付出更高的代价才能换到。这和现实中供求关系决定价格的逻辑完全一致。

### 3.3 滑点保护

在实际的 Swap 合约中，用户通常会设置一个最小输出量（min_out），如果实际输出低于这个值，交易就会回滚。这就是滑点保护机制。在 LetSwap 的 `swap.move` 中：

```move
let (out, out_amount) = pool::swap_x_to_y(pool, real, min_out, ctx);
assert!(out_amount >= min_out, EHaveSlippage);
```

用户传入 `min_out` 参数，合约在计算完实际输出量后检查是否满足条件。如果因为价格波动导致实际输出低于 `min_out`，交易直接失败，资金退回用户。这有效防止了在剧烈波动行情中被"三明治攻击"等问题。

---

## 4. LP Token 计算

流动性提供者（LP）向池子中存入代币时，合约会铸造 LP Token 作为凭证。LP Token 的计算分为两种情况：首次添加流动性和后续添加流动性。

### 4.1 首次添加流动性

当池子为空（total_supply = 0）时，LP Token 的数量取存入两种代币数量的几何平均值：

```
lp_amount = sqrt(coin_x_value * coin_y_value)
```

为什么用几何平均而不是算术平均？因为恒定乘积模型的核心是 x * y = k，几何平均直接与恒定乘积关联。使用几何平均可以确保 LP Token 的价值与池子的恒定乘积 k 成正比。

在 LetSwap 中，对应的代码实现为：

```move
if (total_supply == 0) {
    let lp = (sqrt_u128((coin_x_value as u128) * (coin_y_value as u128)) as u64);
    assert!(lp > get_min_lp_value(), ERR_MIN_LP);
    lp
}
```

举例：首次向池子存入 100 亿 USD 和 100 亿 RMB，铸造的 LP Token 数量为：

```
lp = sqrt(100 亿 * 100 亿) = sqrt(10^20) = 100 亿
```

注意首次铸造时会锁定一部分 LP Token 到池子中（`locked_lp` 字段），这是为了防止池子被掏空，后面的安全性分析会详细说明。

### 4.2 后续添加流动性

当池子中已有流动性时，新 LP 必须按照当前储备比例存入代币，否则会打破池子的价格平衡。LP Token 的数量按照以下公式计算：

```
lp_amount = min(
    x_desired * total_supply / reserve_x,
    y_desired * total_supply / reserve_y
)
```

取两者的最小值，确保 LP 不会因为单边投入过多而获得超额的 LP Token。

举例：假设池子当前状态为 reserve_x = 110 亿 USD，reserve_y = 90.9091 亿 RMB，LP Token 总量为 100 亿。

如果用户希望存入 11 亿 USD 和 9.09091 亿 RMB（按当前比例 110:90.9091 = 11:9.09091）：

```
x_lp = 11 亿 * 100 亿 / 110 亿 = 10 亿
y_lp = 9.09091 亿 * 100 亿 / 90.9091 亿 = 10 亿
lp_amount = min(10 亿, 10 亿) = 10 亿
```

用户获得 10 亿 LP Token，池子储备变为 121 亿 USD 和 100 亿 RMB。

### 4.3 无损添加逻辑

在实际操作中，用户可能并不知道精确的存入比例。LetSwap 实现了一个"无损添加"机制，允许用户传入期望的最大值和最小值，合约自动按比例计算实际需要存入的量：

```move
public fun get_no_loss_values(
    x_desired: u64, y_desired: u64,
    x_min: u64, y_min: u64,
    reserves_x: u64, reserves_y: u64
): (u64, u64)
```

这个函数的逻辑是：

1. 如果池子为空，直接返回用户期望的 (x_desired, y_desired)
2. 如果池子已有储备，先按比例计算 x_desired 对应的 y 值（`y_returned = x_desired * reserve_y / reserve_x`）
3. 如果 y_returned 小于等于 y_desired，说明用户提供的 Y 足够，实际存入 (x_desired, y_returned)
4. 否则反过来，用 y_desired 计算 x_returned，实际存入 (x_returned, y_desired)

这个设计确保了添加流动性不会改变池子的价格比例，多出的代币会退还给用户。

---

## 5. 手续费机制

### 5.1 手续费的作用

手续费是 AMM 经济模型的核心驱动力。每笔交易收取的手续费是 LP 提供流动性的收益来源，也是维持系统运转的经济激励。

在 LetSwap 中，手续费分为两部分：

- **dao_fee**：DAO 手续费，用于协议治理和开发维护
- **lp_fee**：LP 手续费，归流动性提供者所有

### 5.2 手续费的计算

手续费的基数为 100000（即 0.001% 为一个基点）。默认费率在 `constants.move` 中定义：

```move
/// 0.05% dao 手续费, 0.25% lp 手续费
public fun get_default_fee(): (u64, u64) { (50, 250) }
```

换算为百分比：

- dao_fee = 50 / 100000 = 0.05%
- lp_fee = 250 / 100000 = 0.25%
- 总手续费 = 0.30%

手续费的计算函数为：

```move
public fun get_fee(amount: u64, fee: u64): u64 {
    ((fee as u128) * (amount as u128) / (get_fee_base_of_percentage() as u128) as u64)
}
```

### 5.3 手续费的扣除流程

在执行 Swap 时，手续费从用户的输入金额中扣除。以 `swap_x_to_y` 为例：

```move
let dao_fee = get_fee(in_value, pool.dao_fee);
let lp_fee = get_fee(in_value, pool.lp_fee);
let dao_coin = coin::split(&mut in, dao_fee, ctx);
coin::put(&mut pool.fee_x, dao_coin);

let output_amount = get_amount_out(in_value - dao_fee - lp_fee, reserve_in, reserve_out);
```

流程如下：

1. 从输入金额中计算出 dao_fee 和 lp_fee
2. 将 dao_fee 直接存入池子的 `fee_x` 字段（LP 手续费留在储备中，间接归所有 LP 所有）
3. 用扣除手续费后的金额（in_value - dao_fee - lp_fee）代入恒定乘积公式计算输出量

这种设计将手续费和储备分开管理。`fee_x` 和 `fee_y` 是独立的余额字段，DAO 管理员可以通过 `withdraw_fee` 函数提取 dao_fee 部分。

### 5.4 费率管理

池子的费率可以通过管理员地址修改：

```move
public entry fun set_dao_fee<X, Y>(pool: &mut Pool<X, Y>, g: &Global, fee: u64, ctx: &mut TxContext)
public entry fun set_lp_fee<X, Y>(pool: &mut Pool<X, Y>, g: &Global, fee: u64, ctx: &mut TxContext)
```

只有 `global.move` 中配置的两个 manager_address 之一才能修改费率。系统还定义了最大费率限制：

```move
/// 单项最大费率 1%
public fun get_max_fee(): u64 { 1000 }
```

这确保了费率不会被恶意设置为过高的值。

---

## 6. LetSwap 项目架构

### 6.1 六个模块的职责

LetSwap 项目由六个 Move 模块组成，各模块职责明确，分层清晰。

**constants.move -- 常量配置模块**

定义系统级的常量参数：手续费基数（100000）、默认费率（dao_fee=50, lp_fee=250）、最大费率（1000）、最小 LP 锁定值（1000）。这些常量集中管理，方便维护和调整。

**global.move -- 全局配置模块**

管理全局状态，包括：

- 池子注册表：使用 `Table<String, ID>` 存储所有已创建的池子，键为 "CoinXType-CoinYType" 格式的字符串，值为池子对象的 ID
- 权限管理：存储 withdraw_address（手续费提取地址）和两个 manager_address（费率管理员地址）
- 防重复创建：通过 `exist_pool<X, Y>` 函数检查某个币对的池子是否已存在

**pool.move -- 池子核心模块**

这是整个项目最核心的模块，定义了 Pool 结构体和所有池子操作：

- Pool 结构体包含储备余额、手续费余额、LP 供应量等所有池子状态
- `create_pool`：创建新的交易对池子
- `add_liquidity`：添加流动性
- `remove_liquidity`：移除流动性
- `swap_x_to_y` / `swap_y_to_x`：两个方向的 Swap 操作
- `get_reserve`：查询当前储备量和 LP 总量

**core_amm.move -- AMM 数学模块**

纯粹的数学计算模块，不涉及任何状态修改：

- `get_amount_out`：恒定乘积公式计算输出量
- `get_lp_coin_by_coinx_coiny_amount`：LP Token 铸造数量计算
- `get_coinx_coiny_by_lp_coin`：LP Token 赎回时计算两种代币的数量
- `get_no_loss_values`：无损添加流动性的比例计算
- `get_fee`：手续费计算

**swap.move -- 入口函数模块**

面向用户的入口层，封装了 pool.move 中的函数，处理代币转账逻辑：

- `create_pool`：创建池子并注册到全局配置
- `add_liquidity`：接收用户代币，调用池子添加流动性，将 LP Token 和多余代币转回用户
- `remove_liquidity`：接收用户的 LP Token，调用池子移除流动性，将赎回的代币转给用户
- `swap_x_to_y` / `swap_y_to_x`：接收用户输入代币，调用池子执行 Swap，将输出代币转给用户

**events.move -- 事件模块**

定义所有链上事件结构体并在关键操作时发射事件，供链下系统监听和索引：

- `CreatePoolEvent`：创建池子事件
- `AddLpEvent`：添加流动性事件
- `RemoveLpEvent`：移除流动性事件
- `SwapEvent`：交易事件

### 6.2 模块间的调用关系

整个系统的数据流可以用以下调用链来描述：

```
用户交易
  |
  v
swap.move（入口函数层）
  |--- 创建池子 ---> global.move（注册池子）
  |                   |
  |                   v
  |                 pool.move（创建 Pool 对象）
  |
  |--- 添加/移除流动性 ---> pool.move
  |                          |
  |                          v
  |                        core_amm.move（计算 LP 数量或赎回数量）
  |                          |
  |                          v
  |                        events.move（发射事件）
  |
  |--- Swap 交易 ---> pool.move
                       |--- core_amm.move（计算手续费）
                       |--- core_amm.move（计算输出量）
                       |--- events.move（发射 Swap 事件）
```

分层的设计原则是：`core_amm.move` 只负责纯数学计算，不接触任何链上状态；`pool.move` 管理池子状态和调用 AMM 数学模块；`swap.move` 处理用户交互和代币转账。这种分层使得数学逻辑可以被独立测试，也便于将来替换不同的 AMM 算法。

---

## 7. 完整操作流程

本节给出从部署到操作的完整 CLI 命令示例，帮助读者在实践中理解 LetSwap 的工作流程。以下命令基于 Sui CLI，假设你已经安装并配置好了 Sui 开发环境。

### 7.1 部署合约

首先将 LetSwap 合约部署到链上：

```bash
sui move build
sui client publish --gas-budget 100000000
```

部署成功后，会输出交易摘要，其中包含 Global 对象的 ID。Global 对象在模块的 `init` 函数中自动创建并以共享对象的形式发布：

```move
fun init(ctx: &mut TxContext) {
    let address = sender(ctx);
    let global = Global {
        id: object::new(ctx),
        pools: table::new<String, ID>(ctx),
        withdraw_address: address,
        manager_address_1: address,
        manager_address_2: address
    };
    transfer::share_object(global)
}
```

部署者地址自动成为初始的管理员和手续费提取地址。

### 7.2 创建交易对池子

部署合约后，需要创建具体的交易对池子。以创建 USD/RMB 池子为例：

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module swap \
  --function create_pool \
  --type-args <USD_TYPE> <RMB_TYPE> \
  --args <GLOBAL_OBJECT_ID> \
  --gas-budget 10000000
```

此命令做了两件事：

1. 在 `pool.move` 中创建一个 `Pool<USD, RMB>` 对象，初始化储备为零，设置默认费率
2. 在 `global.move` 中将池子注册到全局注册表，键为 "USD-RMB"

创建成功后，会得到 Pool 对象的 ID，后续所有操作都需要引用这个 Pool 对象。注意合约会检查是否已存在相同币对的池子：

```move
assert!(!exist_pool<X, Y>(global) || !exist_pool<Y, X>(global), EPoolExist);
```

这防止了 USD/RMB 和 RMB/USD 两个池子同时存在的情况。

### 7.3 添加流动性

有了池子之后，LP 可以向其中存入代币：

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module swap \
  --function add_liquidity \
  --type-args <USD_TYPE> <RMB_TYPE> \
  --args <POOL_OBJECT_ID> \
    "[<USD_COIN_OBJECT_ID>]" \
    "[<RMB_COIN_OBJECT_ID>]" \
    <COIN_X_AMOUNT> <COIN_X_MIN> \
    <COIN_Y_AMOUNT> <COIN_Y_MIN> \
  --gas-budget 10000000
```

参数说明：

- `coin_x` 和 `coin_y`：用户持有的代币 Coin 对象，以向量形式传入（支持合并多个 Coin）
- `coin_x_amount` 和 `coin_y_amount`：期望存入的数量
- `coin_x_min` 和 `coin_y_min`：最小存入数量（滑点保护）

合约会自动计算按比例需要存入的实际数量，多余的代币退还给用户。作为回报，用户收到 LP Token。

如果是首次添加流动性，一部分 LP Token（默认 1000 个最小单位）会被锁定在池子中：

```move
if (lp_supply == 0) {
    let min_lp_value = get_min_lp_value();
    balance::join(&mut pool.locked_lp, balance::split(&mut balance_lp, min_lp_value));
    real_lp_amount = share_minted - min_lp_value;
}
```

### 7.4 执行 Swap

用户可以用一种代币兑换另一种代币：

```bash
# 用 USD 换 RMB
sui client call \
  --package <PACKAGE_ID> \
  --module swap \
  --function swap_x_to_y \
  --type-args <USD_TYPE> <RMB_TYPE> \
  --args <POOL_OBJECT_ID> \
    "[<USD_COIN_OBJECT_ID>]" \
    <IN_AMOUNT> <MIN_OUT_AMOUNT> \
  --gas-budget 10000000

# 用 RMB 换 USD
sui client call \
  --package <PACKAGE_ID> \
  --module swap \
  --function swap_y_to_x \
  --type-args <USD_TYPE> <RMB_TYPE> \
  --args <POOL_OBJECT_ID> \
    "[<RMB_COIN_OBJECT_ID>]" \
    <IN_AMOUNT> <MIN_OUT_AMOUNT> \
  --gas-budget 10000000
```

参数说明：

- `in_amount`：用户希望兑换的输入代币数量
- `min_out`：用户可接受的最低输出量（滑点保护）

合约内部的处理流程：

1. 从输入代币中拆分出指定数量
2. 扣除 dao_fee 和 lp_fee
3. 用扣除手续费后的金额，通过恒定乘积公式计算输出量
4. 检查输出量是否满足 min_out 要求
5. 从池子储备中取出输出代币，转给用户
6. 将输入代币（扣除手续费后）加入池子储备

### 7.5 移除流动性

LP 可以随时用 LP Token 赎回池子中对应比例的两种代币：

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module swap \
  --function remove_liquidity \
  --type-args <USD_TYPE> <RMB_TYPE> \
  --args <POOL_OBJECT_ID> \
    "[<LP_COIN_OBJECT_ID>]" \
    <LP_AMOUNT> <MIN_X> <MIN_Y> \
  --gas-budget 10000000
```

赎回数量的计算公式为：

```
x_out = lp_amount * reserve_x / total_supply
y_out = lp_amount * reserve_y / total_supply
```

这确保了 LP 赎回的资产与持有 LP Token 的比例完全对应。注意，如果池子通过手续费积累了额外的资产，赎回时每个 LP Token 对应的资产会比存入时更多。

---

## 8. 安全性分析

DeFi 合约的安全性至关重要，因为合约直接管理着用户的资产。LetSwap 在设计中考虑了多种安全防护措施。

### 8.1 整数溢出防护

Move 语言本身使用固定宽度的整数类型（u64、u128），算术溢出会导致运行时异常而非静默溢出。但即便如此，LetSwap 还是在关键计算中采用了额外的防护策略。

在 `get_amount_out` 中，两个 u64 值相乘（如 `amount_in_without_fee * reserve_out`）可能超过 u64 的最大值（约 1.84 * 10^19）。因此中间值被提升为 u128 进行计算：

```move
let numerator = (amount_in_without_fee as u128) * (reserve_out as u128);
let denominator = (reserve_in as u128) + (amount_in_without_fee as u128);
```

u128 的最大值约为 3.4 * 10^38，两个 u64 最大值相乘约为 3.4 * 10^38，刚好在 u128 的范围内。

此外，Pool 对单个储备量也设置了上限：

```move
const MAX_POOL_VALUE: u64 = 18446744073709551615 / 10000;
```

添加流动性时会检查：

```move
assert!(x_amount < MAX_POOL_VALUE, EPoolFull);
assert!(y_amount < MAX_POOL_VALUE, EPoolFull);
```

这进一步确保了储备量不会过大，使得后续的乘法运算不会溢出。

### 8.2 滑点保护

在 `swap.move` 的每个 Swap 入口函数中，都执行了滑点检查：

```move
let (out, out_amount) = pool::swap_x_to_y(pool, real, min_out, ctx);
assert!(out_amount >= min_out, EHaveSlippage);
```

用户在发起交易时指定 `min_out`（期望收到的最小输出量）。如果由于其他交易先执行导致池子状态变化，实际输出量低于 `min_out`，整笔交易会回滚。这是防止三明治攻击的基本手段：攻击者无法通过前置交易使受害者的成交价格低于其可接受范围。

同样，在 `remove_liquidity` 中也有类似的保护：

```move
assert!(x_removed >= min_x && y_removed >= min_y, EHaveSlippage);
```

在 `add_liquidity` 中，通过 `get_no_loss_values` 函数的 `x_min` 和 `y_min` 参数实现保护：

```move
assert!(y_returned >= y_min, ERR_INSUFFICIENT_Y_AMOUNT);
assert!(x_returned >= x_min, ERR_INSUFFICIENT_X_AMOUNT);
```

### 8.3 MIN_LP_VALUE 防止池子被掏空

首次添加流动性时，合约会锁定最小数量的 LP Token：

```move
if (lp_supply == 0) {
    let min_lp_value = get_min_lp_value();  // 默认值 1000
    balance::join(&mut pool.locked_lp, balance::split(&mut balance_lp, min_lp_value));
    real_lp_amount = share_minted - min_lp_value;
}
```

这 1000 个 LP Token 被永久锁定在池子的 `locked_lp` 字段中，永远不会被赎回。它的作用是：确保池子的 LP 总供应量永远不会归零。如果 LP 总供应量归零，池子中的剩余资产就会变成无主资产，任何人都可以通过首次添加流动性来获取它们。锁定一小部分 LP Token，即使所有 LP 都赎回了他们的份额，池子中仍然保留着与这 1000 个 LP Token 对应的微量资产，从而保持池子的状态一致。

同时，首次铸造 LP Token 时要求总量必须大于 MIN_LP_VALUE：

```move
assert!(lp > get_min_lp_value(), ERR_MIN_LP);
```

这确保了首次存入的代币数量足够产生合理的 LP Token。

### 8.4 权限控制

LetSwap 的权限控制分散在多个层面：

- **创建池子**：任何用户都可以创建新币对的池子，但不能重复创建
- **修改费率**：只有 Global 中配置的两个 manager_address 可以修改
- **提取手续费**：只有 withdraw_address 可以提取累积的手续费
- **Global 配置修改**：只有硬编码的 `@admin_address` 可以修改

```move
// global.move 中的管理员校验
public entry fun set_manager_address_1(g: &mut Global, addr: address, ctx: &mut TxContext) {
    assert!(sender(ctx) == @admin_address, ENotAdmin);
    g.manager_address_1 = addr;
}
```

这种多级权限设计确保了协议的治理安全。

---

## 9. 本章小结

本章系统讲解了 Uniswap V2 恒定乘积做市商的核心原理和在 Sui Move 中的实现。关键内容回顾如下：

恒定乘积公式 `x * y = k` 是整个 AMM 的数学基础。从它推导出的输出量公式 `y_out = (x_in * reserve_y) / (reserve_x + x_in)` 解决了"给定输入量，输出多少"这个核心问题。公式的数学性质天然产生了滑点效应：兑换量越大，平均汇率越差，这正是供需关系的自动价格调节。

LP Token 机制解决了"谁来提供流动性"的问题。首次添加用几何平均 sqrt(x*y) 计算，后续添加按储备比例取最小值，确保了 LP 的权益与贡献对等。

手续费分账机制（dao_fee + lp_fee）构成了 AMM 的经济飞轮：手续费激励 LP 提供流动性，充足的流动性降低滑点吸引更多交易，更多交易产生更多手续费。

LetSwap 的六模块架构体现了良好的工程实践：数学逻辑（core_amm）、状态管理（pool）、用户入口（swap）、全局配置（global）、常量定义（constants）、事件记录（events）各司其职，层次分明。

安全性方面，u128 中间值防止溢出、min_out 参数提供滑点保护、MIN_LP_VALUE 防止池子掏空、多级权限控制保障治理安全。这些都是编写 DeFi 合约时必须考虑的关键要素。

理解了恒定乘积模型之后，下一章我们将学习另一种常见的交易模型：订单簿（Order Book）。订单簿采用了完全不同的撮合思路，与 AMM 形成鲜明对比。
