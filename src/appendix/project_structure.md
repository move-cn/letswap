# 项目结构与图表

本附录整理全书的代码目录、主线项目和关键关系图，帮助读者区分哪些是基础示例，哪些是完整项目。

## 代码目录说明

| 路径 | 作用 |
|------|------|
| `src/02_coin/code/02_coin_owner` | 独享所有权 Coin |
| `src/02_coin/code/03_coin_share` | 共享 `TreasuryCap` 的测试币 |
| `src/02_coin/code/04_coin_supply` | `Supply<T>` 与发行量控制 |
| `src/02_coin/code/05_coin_lock` | 时间锁 Coin |
| `src/02_coin/code/06_deny_coin` | 受监管 Coin |
| `src/02_coin/code/07_token_coin` | Token 扩展入口 |
| `src/03_swap/code/02_swap_usd_rmb` | 固定 USD/RMB 兑换 |
| `src/03_swap/code/03_swap_generic` | 泛型固定汇率池 |
| `src/05_swap_univ2/code/letswap` | 完整 AMM 项目 |
| `src/05_swap_univ2/code/univ2` | 简化版恒定乘积示例 |

`coin_test`、历史日志和 `Published.toml` 属于辅助材料，读者应优先跟随正文引用的路径。

## Coin 类型关系图

```text
One-Time Witness
        |
        v
coin_registry::new_currency_with_otw
        |
        +--> TreasuryCap<T> ---- coin::mint ----> Coin<T>
        |                              |
        |                              v
        |                       coin::into_balance
        |                              |
        v                              v
Currency Registry metadata       Balance<T>
```

## TreasuryCap 与 Supply

```text
TreasuryCap<T>
     |
     | coin::treasury_into_supply
     v
Supply<T>
     |
     | increase_supply
     v
Balance<T>
     |
     | coin::from_balance
     v
Coin<T>
```

## 固定汇率 Swap 资金流

```text
用户 Coin<RMB>
     |
     v
Bank.rmb += input
     |
     | 按固定公式计算输出
     v
Bank.usd -= output
     |
     v
用户 Coin<USD>
```

## AMM 调用关系

```text
swap.move
   |
   v
pool.move
   |
   v
core_amm.move
   |
   v
数学公式与边界检查
```

## V2 / V3 / StableSwap 对比

| 模型 | 定价方式 | 适合场景 | 实现难度 |
|------|----------|----------|----------|
| 固定汇率 | 人工固定 | 教学、内部兑换 | 低 |
| Uniswap V2 | `x * y = k` | 通用资产对 | 中 |
| 订单簿 | 用户挂单撮合 | 高流动性市场 | 高 |
| Uniswap V3 | 集中流动性 | 专业 LP、稳定区间 | 很高 |
| StableSwap | 稳定币曲线 | 稳定币/锚定资产 | 高 |

## 建议阅读路径

1. 先跑通 `02_coin_owner`
2. 再理解 `Supply<T>` 和 `Balance<T>`
3. 跑通固定汇率 Swap
4. 阅读经济模型
5. 深入 LetSwap V2 项目
6. 最后阅读订单簿、V3 和 StableSwap 进阶章节
