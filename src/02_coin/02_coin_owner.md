# 例子
我们先来看一下完整的一个产生Coin的例子
## 独享所有权


hk 的代码

```move
module coin_owner::hk {

    use sui::coin::create_currency;
    use sui::tx_context::{TxContext, sender};
    use std::option;
    use sui::transfer;

    public struct HK has drop {}
    const SendAddress: address = @0x01;
    fun init(hk: HK, ctx: &mut TxContext) {


        let (treasury_cap, coin_metadata) = create_currency(hk,
            8,
            b"HK",
            b"HK  made in hongkong",
            b"HK  made in hongkong",
            option::none(),
            ctx);

        transfer::public_freeze_object(coin_metadata);

        let my_address = sender(ctx);
        transfer::public_transfer(treasury_cap, my_address)
    }
}
```

rmb的代码
```move
module coin_owner::usd {
    use std::option;
    use sui::coin;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    public struct USD has drop {}

    fun init(witness: USD, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 6, b"USD", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }
}
```

大家可以看到 代码本身

###  create_currency
-   创建出来Coin 
-   返回值  treasury 是国库权限
-   metadata 是Coin的信息

```shell
sui client publish --gas-budget 100000000 
```


