# Uniswap V3 集中流动性

## 本章目标

本章将深入讲解 Uniswap V3 的集中流动性机制，重点理解 Tick 系统的数学原理以及在 Sui Move 中的实现思路。学完本章后，你将理解：

- Uniswap V2 资金利用率低的问题及 V3 的改进方案
- Tick 系统的数学原理：价格与 Tick 的映射关系
- 集中流动性的 Move 合约结构设计
- Swap 跨越 Tick 边界的处理逻辑
- 手续费收集机制与 V3 的实现复杂度

## V2 的问题：资金利用率低

在 Uniswap V2 中，流动性提供者（LP）存入的资金会均匀分布在从 0 到无穷大的所有价格区间上。

这意味着什么？假设 USDC/USDT 这个交易对，价格几乎永远在 0.99 到 1.01 之间波动，但 V2 会把你的资金分散到 0.01 到 9999 的所有价格上。真正在 0.99 - 1.01 这个区间里发挥作用的资金只是很小一部分，大量资金被浪费在永远不会触及的极端价格区间。

可以用一个具体数字来感受这种浪费：如果价格在 0.99 - 1.01 之间波动，那么在这个区间内真正发挥作用的资金大约只占总资金的 0.5% 左右。剩余 99.5% 的资金永远处于闲置状态。

资金利用率低，LP 赚到的手续费就少。这就是 V3 要解决的核心问题。

## 集中流动性：选择你的价格范围

Uniswap V3 允许 LP 自主选择一个价格区间（Price Range），只在这个区间内提供流动性。

举个例子：

- V2 方式：你提供 1000 USDC + 1000 USDT，资金分散在所有价格上
- V3 方式：你选择只在 0.99 - 1.01 这个价格区间提供流动性

在 V3 中，同样 1000 USDC + 1000 USDT 的资金，如果只集中在 0.99 - 1.01 区间，这个区间内的资金密度会大幅增加。当交易发生在这个区间时，你赚取的手续费比例会远高于 V2。

假设 0.99 - 1.01 区间覆盖了 90% 的交易量，那么 V3 中你的资金利用率大约是 V2 的 180 倍。这就是"资本效率提升"：用更少的资金赚取更多的手续费。

## Tick 数学原理

Uniswap V3 用 Tick 来表示价格，这是整个 V3 设计的数学基础。理解 Tick 系统是理解 V3 的关键。

### 价格与 Tick 的关系

Tick 是价格的离散表示。每个 Tick 对应一个具体的价格值，两者的关系如下：

```
price = 1.0001^tick
```

即 Tick i 对应的价格 p(i) = 1.0001^i。

这个公式的设计非常巧妙：

- 当 tick = 0 时，price = 1.0001^0 = 1，即 1:1 的价格
- 当 tick = 1 时，price = 1.0001^1 = 1.0001，价格上升了万分之一（0.01%）
- 当 tick = -1 时，price = 1.0001^-1 = 0.9999，价格下降了万分之一
- 当 tick = 100 时，price = 1.0001^100 = 1.01005，价格上升了约 1%
- 当 tick = 10000 时，price = 1.0001^10000 = e = 2.7183，价格约为原来的 2.7 倍

相邻两个 Tick 之间的价格差异恒定为 0.01%，这提供了足够精细的价格粒度，同时保证了 Tick 的数量在合理范围内。

### Tick 间距

不同的手续费档位对应不同的 Tick 间距（Tick Spacing）。手续费越高，允许的 Tick 间距越大：

| 手续费档位 | Tick 间距 | 可选价格点数量 |
|-----------|-----------|---------------|
| 0.01%     | 1         | 最密集，适合稳定币 |
| 0.05%     | 10        | 较密集        |
| 0.30%     | 60        | 标准，适合主流币 |
| 1.00%     | 200       | 稀疏，适合长尾资产 |

Tick 间距的作用是限制 LP 可选的价格点数量。比如在 0.30% 手续费的池子中，LP 只能选择 tick 为 0、60、120、-60、-120 等整数倍的位置，不能选择 tick = 37 这样的位置。这样做的好处是减少合约的状态存储量，提高 Gas 效率。

### 数值示例

假设 USDC/USDT 池子使用 0.01% 手续费（Tick 间距为 1）：

- Tick 0 对应价格 1.0000（1 USDC = 1 USDT）
- Tick 10 对应价格 1.0001^10 = 1.001（1 USDC = 1.001 USDT）
- Tick -10 对应价格 1.0001^-10 = 0.999（1 USDC = 0.999 USDT）

LP 可以在 Tick -10 到 Tick 10 之间提供流动性，覆盖 0.999 到 1.001 的价格范围。对于稳定币交易对来说，这个范围已经足够覆盖日常波动。

## 集中流动性的 Move 实现思路

在 Sui Move 中实现 V3 的集中流动性，需要设计以下核心结构和管理逻辑。

### Position 结构体

每个 LP 的流动性仓位表示为一个 Position 对象：

```
struct Position<phantom CoinTypeA, phantom CoinTypeB> has key, store {
    id: UID,
    tick_lower: int,        // 价格区间下界对应的 Tick 索引
    tick_upper: int,        // 价格区间上界对应的 Tick 索引
    liquidity: u128,        // 该区间内的流动性数量（以 L^2 为单位）
    fee_growth_inside_a: u256,  // 区间内累计的手续费（CoinTypeA）
    fee_growth_inside_b: u256,  // 区间内累计的手续费（CoinTypeB）
    tokens_owed_a: u64,     // 待领取的 CoinTypeA 手续费
    tokens_owed_b: u64,     // 待领取的 CoinTypeB 手续费
}
```

关键字段说明：

- `tick_lower` 和 `tick_upper` 定义了流动性覆盖的价格区间
- `liquidity` 使用 `L^2` 为单位存储，避免浮点数运算，其中 L 是流动性参数
- `fee_growth_inside_*` 记录该区间内的手续费累计增长，用于计算 LP 应得的手续费

### Tick 状态管理

每个被使用的 Tick 需要维护状态信息：

```
struct TickState has store {
    tick_index: int,            // Tick 索引值
    liquidity_gross: u128,      // 该 Tick 处的总流动性（所有引用该 Tick 的 Position 之和）
    liquidity_net: int,         // 跨过该 Tick 时流动性的净变化量
    fee_growth_outside_a: u256, // 该 Tick 之上的手续费累计（CoinTypeA）
    fee_growth_outside_b: u256, // 该 Tick 之上的手续费累计（CoinTypeB）
}
```

Tick 状态的核心作用是：当 swap 价格跨越某个 Tick 时，合约需要根据 `liquidity_net` 调整当前可用的流动性总量。`liquidity_gross` 用于判断该 Tick 是否仍被任何 Position 引用，从而决定是否可以清理该 Tick 的状态。

### Swap 跨 Tick 的处理逻辑

Swap 是 V3 中最复杂的逻辑。当交易导致价格移动到当前 Tick 区间的边界时，需要跨越到下一个 Tick：

```
fun swap(pool: &mut Pool, amount_in: u64, zero_for_one: bool) {
    // 计算当前价格
    let current_tick = pool.current_tick;
    let current_price = 1.0001 ^ current_tick;

    // 确定跨 Tick 方向
    let next_tick = if (zero_for_one) {
        当前 Tick 下方最近的已初始化 Tick
    } else {
        当前 Tick 上方最近的已初始化 Tick
    };

    // 第一阶段：在当前 Tick 区间内计算可用的交换量
    let (amount_used, new_price) = compute_swap_step(
        current_price,
        next_tick 的价格,
        pool.liquidity,
        amount_in,
        pool.fee_rate,
    );

    // 更新全局状态
    pool.current_price = new_price;

    // 第二阶段：如果价格到达了 Tick 边界，跨越到下一个 Tick
    if (new_price == next_tick 的价格) {
        // 跨越 Tick：更新当前活跃的流动性
        pool.liquidity = pool.liquidity + next_tick.liquidity_net;
        pool.current_tick = next_tick.tick_index;

        // 如果还有剩余的输入金额，继续在新的 Tick 区间内交换
        if (amount_in - amount_used > 0) {
            swap(pool, amount_in - amount_used, zero_for_one);
        }
    }
}
```

这个递归结构的含义是：Swap 可能在一次交易中跨越多个 Tick，每次跨越都需要更新流动性并重新计算交换参数。每个 Tick 区间内的交换使用恒定乘积公式的局部版本，但流动性参数 L 只取决于该区间内 LP 存入的资金量。

## 手续费收集机制

V3 的手续费机制比 V2 复杂得多。在 V2 中，手续费简单地按 LP 代币比例分配。但在 V3 中，每个 Position 覆盖的价格区间不同，只有当交易发生在该区间内时，该 Position 才能获得手续费。

核心设计如下：

1. **全局累计器**：合约维护一个全局的手续费累计值 `fee_growth_global`，记录自池子创建以来的总手续费增长。
2. **Tick 外部累计器**：每个 Tick 维护 `fee_growth_outside`，记录该 Tick 一侧的手续费累计。
3. **区间内手续费**：Position 的手续费 = 全局累计 - tick_lower 外部累计 - tick_upper 外部累计，再乘以该 Position 的流动性比例。

LP 随时可以调用 `collect` 函数领取已累积的手续费。由于手续费计算依赖于区间边界，每个 Position 必须精确跟踪自己在各个 Tick 处的费用快照。

## 一个池子多个仓位

在 V2 中，一个交易对的所有流动性是混在一起的，每个 LP 提供的流动性无法区分。

在 V3 中，同一个交易对池子里可以有多个不同的流动性仓位。每个 LP 可以选择不同的价格区间：

- Alice 在 0.99 - 1.01 区间提供流动性
- Bob 在 0.95 - 1.05 区间提供流动性
- Carol 在 1.00 - 1.10 区间提供流动性

这些仓位独立存在，各自赚取自己区间内的手续费。这就好比多个人在不同的价位上摆摊，每个人只负责自己那一段价格区间。

## 非同质化 LP 仓位

在 Uniswap V2 中，LP 代币是同质化代币，每个 LP 提供的流动性都完全一样，可以互相替换。

但在 V3 中，因为每个 LP 选择的价格区间不同，每个流动性仓位都是独一无二的。所以 V3 的 LP 仓位用 NFT 来表示，而不是同质化代币。

一个 V3 的 LP 仓位 NFT 包含了以下信息：

- 交易对（比如 USDC/USDT）
- 下界 Tick
- 上界 Tick
- 提供的流动性数量

这使得 LP 仓位不能像 V2 那样简单地合并或拆分，但也赋予了每个 LP 更精确的控制权。在 Sui Move 中，Position 对象天然具有对象所有权属性，无需额外引入 NFT 标准。

## V2 与 V3 实现复杂度对比

| 对比项          | Uniswap V2              | Uniswap V3                    |
|---------------|-------------------------|-------------------------------|
| 流动性分布      | 均匀分布在所有价格区间    | LP 自选价格区间，集中分布       |
| 资本效率        | 低，大量资金闲置         | 高，资金集中在活跃价格区间      |
| LP 代币类型     | 同质化代币（FT）         | 非同质化对象（NFT）            |
| 价格表示        | 连续的 reserve 比值      | 离散的 Tick 系统               |
| 合约复杂度      | 低，核心约 200 行        | 高，核心约 800 行以上          |
| 手续费计算      | 简单按比例分配           | 基于 Tick 区间的增量累计        |
| Swap 逻辑      | 单步恒定乘积计算         | 多步跨 Tick 计算               |
| 状态存储       | 极少（仅 reserve 和 LP 总量） | 较多（每个 Tick 的状态）       |

从实现角度看，V3 的复杂度远高于 V2。Tick 状态管理、跨 Tick 的 Swap 逻辑、手续费增量计算等都需要精确的数学实现。在 Sui Move 中，还需要考虑对象模型的限制，例如 Tick 状态适合存储在 Pool 对象内部的动态字段中，而 Position 可以作为独立对象转移。

## 本章小结

本章深入讲解了 Uniswap V3 的集中流动性机制及其在 Move 中的实现思路。要点如下：

- V3 通过允许 LP 自选价格区间，将资金集中在活跃价格区间，大幅提升资本效率
- Tick 系统将连续价格离散化，价格与 Tick 的关系为 `price = 1.0001^tick`
- 核心数据结构包括 Position（流动性仓位）和 TickState（Tick 状态），在 Move 中可通过结构体和动态字段实现
- Swap 跨 Tick 时需要更新流动性参数并重新计算交换参数，这是 V3 最复杂的部分
- 手续费通过全局累计器和 Tick 外部累计器精确计算，确保每个 Position 公平地获得手续费
- V3 的实现复杂度远高于 V2，但带来的资本效率提升使它成为当前 DeFi 的主流方案

下一章将介绍稳定币交换算法，探索 Curve 的 StableSwap 不变量如何为稳定币交易提供极低滑点。
