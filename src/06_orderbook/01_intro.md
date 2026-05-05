# 订单簿

## 本章目标

本章将系统讲解订单簿（Order Book）模式的核心原理，并探讨如何在 Sui Move 中设计订单簿智能合约。学完本章后，你将理解：

- 订单簿的基本概念与撮合机制
- 限价单的挂单、撤单、成交流程
- Move 合约中订单与订单簿的结构体设计
- 价格优先、时间优先的撮合算法
- 订单簿模式与 AMM 模式的本质区别

## 什么是订单簿

订单簿（Order Book）是一种记录所有买卖订单的机制。它按照价格排列所有的买单和卖单，让买卖双方能够找到彼此并完成交易。传统金融市场中，股票交易所就是典型的订单簿模式。

在区块链上，订单簿由智能合约来管理。用户的挂单、撤单、成交等操作都通过调用智能合约来完成，整个过程的记录保存在链上，公开透明。

与前面章节学习的 AMM（自动做市商）模式不同，订单簿模式不依赖数学公式来确定价格，而是由用户自主报价，等待对手方匹配成交。这种模式更接近传统金融市场的交易方式。

## 限价单的工作原理

订单簿中最核心的概念是限价单（Limit Order）。限价单表示用户愿意以某个特定价格进行交易。

- **买单（Bid）**：你愿意花多少 CoinY 去买 1 个 CoinX。比如你愿意花 7.2 人民币买 1 美元，这就是一个买单，价格为 7.2。
- **卖单（Ask）**：你愿意以多少 CoinY 卖出 1 个 CoinX。比如你愿意以 7.2 人民币卖出 1 美元，这就是一个卖单，价格为 7.2。

当你提交一个限价单时，如果当前市场上没有匹配的价格，这个订单就会挂在订单簿上等待。直到有人提交了价格匹配的对向订单，撮合引擎才会自动完成交易。

## 订单撮合机制

订单撮合（Order Matching）是订单簿的核心逻辑。

撮合规则很简单：当一个买单的价格大于或等于一个卖单的价格时，这两个订单就可以成交。

举个例子：

| 角色     | 方向   | 数量      | 价格      |
|----------|--------|-----------|-----------|
| Alice    | 买 1 USD | 7.2 RMB |           |
| Bob      | 买 1 USD | 7.0 RMB |           |
| Carol    | 卖 1 USD | 7.1 RMB |           |
| Dave     | 卖 1 USD | 7.3 RMB |           |

- Alice 愿意以 7.2 买，Carol 愿意以 7.1 卖。Alice 的出价高于 Carol 的要价，成交！成交价通常取中间价或先挂单方的价格。
- Bob 愿意以 7.0 买，Dave 愿意以 7.3 卖。Bob 出价不够 Dave 的要价，无法成交，两人继续等待。

智能合约会自动按照价格优先的原则进行撮合：买单价格越高越优先成交，卖单价格越低越优先成交。

## Move 合约设计思路

在 Sui Move 中实现订单簿，需要设计合理的结构体和核心函数。下面介绍一种典型的设计方案。

### Order 结构体

每个挂单对应一个 Order 对象，记录订单的关键信息：

```
struct Order<phantom CoinTypeA, phantom CoinTypeB> has key, store {
    id: UID,                    // Sui 对象唯一标识
    maker: address,             // 挂单者地址
    coin_type_a: Coin<CoinTypeA>, // 挂单存入的代币
    amount_a: u64,              // 存入数量
    price: u64,                 // 期望的兑换价格（以 CoinTypeB 计价）
    is_buy: bool,               // true 为买单，false 为卖单
    timestamp: u64,             // 挂单时间戳，用于时间优先排序
}
```

关键字段说明：

- `phantom` 泛型参数确保类型安全，不同币对的订单不会混淆
- `price` 以 CoinTypeB 为单位，表示每单位 CoinTypeA 的价格
- `is_buy` 区分买单和卖单，撮合时只匹配方向相反的订单
- `timestamp` 记录挂单时间，用于价格相同时的时间优先排序

### OrderBook 结构体

订单簿管理同一交易对的所有挂单：

```
struct OrderBook<phantom CoinTypeA, phantom CoinTypeB> has key {
    id: UID,
    bids: vector<Order<CoinTypeA, CoinTypeB>>,   // 买单列表，按价格降序
    asks: vector<Order<CoinTypeA, CoinTypeB>>,   // 卖单列表，按价格升序
}
```

买单和卖单分别存储在两个列表中。买单列表按价格从高到低排列（最优买单在最前面），卖单列表按价格从低到高排列（最优卖单在最前面），这样撮合时可以快速找到最优订单。

### 核心函数签名

```
// 挂单：用户存入代币，创建一个新的 Order
public entry fun place_order<CoinTypeA, CoinTypeB>(
    order_book: &mut OrderBook<CoinTypeA, CoinTypeB>,
    coin: Coin<CoinTypeA>,
    price: u64,
    is_buy: bool,
    clock: &Clock,
    ctx: &mut TxContext,
);

// 撤单：用户取消自己的挂单，取回代币
public entry fun cancel_order<CoinTypeA, CoinTypeB>(
    order_book: &mut OrderBook<CoinTypeA, CoinTypeB>,
    order_id: ID,
    ctx: &mut TxContext,
);

// 撮合：尝试匹配买单和卖单，完成交易
public fun match_orders<CoinTypeA, CoinTypeB>(
    order_book: &mut OrderBook<CoinTypeA, CoinTypeB>,
    coin_a: &mut Coin<CoinTypeA>,
    coin_b: &mut Coin<CoinTypeB>,
): bool;
```

## 撮合算法详解

撮合算法遵循两个核心原则：

**第一原则：价格优先。** 买单出价越高越优先成交，卖单要价越低越优先成交。这保证了市场中最有意愿成交的订单首先被匹配。

**第二原则：时间优先。** 当多个订单的价格相同时，先提交的订单优先成交。这鼓励用户尽早挂单。

撮合算法的伪代码逻辑如下：

```
fun match_orders(order_book) {
    while (order_book.bids 不为空 && order_book.asks 不为空) {
        best_bid = order_book.bids[0];   // 最高买价
        best_ask = order_book.asks[0];   // 最低卖价

        if (best_bid.price >= best_ask.price) {
            // 价格匹配，可以成交
            match_price = 取先挂单方的价格 或 中间价;
            match_amount = min(best_bid.amount, best_ask.amount);

            // 执行代币交换
            transfer(best_bid.maker, best_ask 的代币);
            transfer(best_ask.maker, best_bid 的代币);

            // 更新订单状态
            if (best_bid 完全成交) { 从列表移除; }
            else { 减少剩余数量; }

            if (best_ask 完全成交) { 从列表移除; }
            else { 减少剩余数量; }
        } else {
            break;  // 最优买价低于最优卖价，无法继续撮合
        }
    }
}
```

实际在 Sui Move 中，每次用户提交新订单时，合约会尝试立即撮合。如果新订单无法完全成交，剩余部分会挂入订单簿等待后续匹配。

## 一个完整的成交场景

假设当前市场汇率是 1 USD = 7.1 RMB。

1. Alice 有 1 USD，她想要 7.2 RMB，于是她提交了一个卖单：卖 1 USD，要价 7.2 RMB。此时订单簿中没有匹配的买单，订单挂起等待。
2. Bob 有 7.2 RMB，他觉得 1 USD 值 7.2 RMB，于是他提交了一个买单：买 1 USD，出价 7.2 RMB。
3. 撮合引擎检测到 Alice 的卖单价 7.2 和 Bob 的买单价 7.2 完全匹配，自动撮合成交。
4. Alice 的 1 USD 给了 Bob，Bob 的 7.2 RMB 给了 Alice。

交易完成，双方都按照自己期望的价格完成了交换。这就是订单簿模式的基本原理：每个人自己定价，等待对手方出现，然后由智能合约撮合成交。

## 与 letswap（AMM）的对比总结

前面章节中，letswap 使用的是 Uniswap V2 的恒定乘积模型 `x * y = k`，属于 AMM 模式。下面对比两种模式的核心差异：

| 对比项       | 订单簿模式              | AMM 模式（letswap / Uniswap V2） |
|-------------|------------------------|----------------------------------|
| 定价方式     | 用户自己定价            | 由公式自动计算价格                |
| 成交条件     | 需要对手方出价匹配      | 只要池子里有流动性就能成交        |
| 流动性来源   | 依赖挂单数量            | 依赖 LP 存入的资金               |
| 滑点        | 无滑点（按挂单价成交）   | 有滑点（大额交易价格会偏移）      |
| 做市门槛    | 任何用户均可挂单         | 需要同时存入两种代币做 LP        |
| 合约复杂度   | 撮合逻辑和排序较复杂     | 公式简单，合约实现简洁            |
| 用户体验    | 可能需要等待成交         | 即时成交                         |
| 大额交易    | 适合，无价格冲击         | 大额交易会产生较大滑点            |

在实际的 DeFi 生态中，两种模式各有适用场景。AMM 适合长尾资产和需要即时成交的场景，订单簿适合主流资产和追求精确价格的大额交易。

## 本章小结

本章介绍了订单簿模式的核心原理与 Move 合约设计思路。要点如下：

- 订单簿通过记录买卖双方的限价单，撮合方向相反且价格匹配的订单完成交易
- 核心撮合原则是价格优先、时间优先
- Move 合约中需要设计 Order 和 OrderBook 两个关键结构体，以及 place_order、cancel_order、match_orders 三个核心函数
- 订单簿模式与 AMM 模式在定价方式、成交机制、用户体验等方面有本质区别

订单簿模式是 DeFi 中除 AMM 之外的另一种重要交易模型。理解它的原理有助于全面掌握去中心化交易的设计思想。下一章将介绍 Uniswap V3 的集中流动性机制。
