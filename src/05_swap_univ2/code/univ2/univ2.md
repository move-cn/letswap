# 发布日志示例

使用以下命令发布合约：

```shell
sui client publish
```

发布成功后，会输出类似如下信息：

```
Transaction Digest: <DIGEST>

Created Objects:
  ┌──
  │ ObjectID: <TREASURY_CAP_ID>
  │ Sender: <SENDER_ADDRESS>
  │ Owner: Account Address ( <SENDER_ADDRESS> )
  │ ObjectType: 0x2::coin::TreasuryCap<0x2::coin::CoinMetadata<PACKAGE_ID>::hk::HK>
  │ Version: <VERSION>
  │ Digest: <DIGEST>
  └──

Mutated Objects:
  ┌──
  │ ObjectID: <GAS_COIN_ID>
  │ Sender: <SENDER_ADDRESS>
  │ Owner: Account Address ( <SENDER_ADDRESS> )
  │ ObjectType: 0x2::coin::Coin<0x2::sui::SUI>
  │ Version: <VERSION>
  │ Digest: <DIGEST>
  └──

Published Objects:
  ┌──
  │ PackageID: <PACKAGE_ID>
  │ Version: 1
  │ Digest: <DIGEST>
  | Modules: hk, rmb, usd
  └──
```

关键字段说明：

- **PackageID**: 发布的合约包地址，后续调用合约时需要使用
- **TreasuryCap**: 铸造权限对象，持有者可以铸造新 Coin
- **CoinMetadata**: Coin 元数据（名称、精度等），发布时被冻结为不可变对象
