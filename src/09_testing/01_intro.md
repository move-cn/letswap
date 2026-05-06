# 测试与编译验证

出版级教程必须保证读者复制代码后能得到可验证结果。本章建立本书的统一验证流程：先编译，再测试，再检查警告，最后记录工具链版本。

## 本章目标

- 掌握 `sui move build` 和 `sui move test`
- 理解 warning、lint warning 和 deprecated warning 的区别
- 给每个示例项目建立验证表
- 形成提交前检查清单

## 基础命令

进入任意 Move 包目录后运行：

```shell
sui move build
```

如果包中有测试：

```shell
sui move test
```

查看工具链版本：

```shell
sui --version
```

## 如何判断结果

成功的构建通常会包含：

```text
INCLUDING DEPENDENCY MoveStdlib
INCLUDING DEPENDENCY Sui
BUILDING <package_name>
```

如果出现 `error[...]`，说明代码无法编译，必须修复。如果出现 `warning[...]`，代码可能能编译，但作为教材仍应尽量消除。

## 本书项目验证表

| 项目 | 路径 | 验证命令 |
|------|------|----------|
| 独享 Coin | `src/02_coin/code/02_coin_owner` | `sui move build` |
| 共享 Coin | `src/02_coin/code/03_coin_share` | `sui move build` |
| 发行量控制 | `src/02_coin/code/04_coin_supply` | `sui move build` |
| 时间锁 Coin | `src/02_coin/code/05_coin_lock` | `sui move build` |
| 黑名单 Coin | `src/02_coin/code/06_deny_coin` | `sui move build && sui move test` |
| Token 示例 | `src/02_coin/code/07_token_coin` | `sui move build && sui move test` |
| 固定汇率 Swap | `src/03_swap/code/02_swap_usd_rmb` | `sui move build` |
| 泛型 Swap | `src/03_swap/code/03_swap_generic` | `sui move build && sui move test` |
| LetSwap V2 | `src/05_swap_univ2/code/letswap` | `sui move build && sui move test` |
| Uniswap V2 简化版 | `src/05_swap_univ2/code/univ2` | `sui move build && sui move test` |

## 警告处理策略

| 类型 | 处理方式 |
|------|----------|
| deprecated warning | 优先迁移到新 API |
| unused alias | 删除多余 `use` |
| unused variable | 删除变量或改成 `_name` |
| public entry lint | 改成 `public fun` 或只保留必要的 `entry` |
| self transfer lint | 如果是教程中必须演示的对象返回，可局部 `#[allow(lint(self_transfer))]` |

不要为了“看起来干净”随意加 `allow`。只有当警告是教学场景中明确接受的设计取舍时，才应抑制。

## 推荐的提交前检查

```shell
for dir in \
  src/02_coin/code/02_coin_owner \
  src/02_coin/code/03_coin_share \
  src/02_coin/code/04_coin_supply \
  src/02_coin/code/05_coin_lock \
  src/02_coin/code/06_deny_coin \
  src/02_coin/code/07_token_coin \
  src/03_swap/code/02_swap_usd_rmb \
  src/03_swap/code/03_swap_generic \
  src/05_swap_univ2/code/letswap \
  src/05_swap_univ2/code/univ2
do
  (cd "$dir" && sui move build)
done
```

如果其中任何一个包失败，就不要更新正文或发布书稿。

## 本章小结

本书后续所有代码都应遵守同一条原则：正文代码块必须能在对应源码目录中编译。验证流程不是附加工作，而是教材质量的一部分。
