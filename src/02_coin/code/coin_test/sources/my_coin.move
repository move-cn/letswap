module coin_test::my_coin {

    use std::option;
    use sui::coin;
    use sui::transfer::{share_object, freeze_object, public_transfer, public_freeze_object};
    use sui::tx_context::sender;
    use sui::url::Url;

    public struct MY_COIN has drop {}

    fun init(witness: MY_COIN, ctx: &mut TxContext) {
        // public fun create_currency<T: drop>(
        // witness: T,
        // decimals: u8,
        // symbol: vector<u8>,
        // name: vector<u8>,
        // description: vector<u8>,
        // icon_url: Option<Url>,
        // ctx: &mut TxContext
        // ): (TreasuryCap<T>, CoinMetadata<T>) {

        // move编程语言 没有小数
        // SUI USDC   0.01111

        //   0-> move 1   =  1
        //   1 -> move 1   =    0.1
        //   2 -> 1      = 0.01
        //   3-> 1      = 0.001
        //   6-> 1      = 0.001


        let icon_url = option::none<Url>();

        let (treasury_cap, coin_metadata) =
            coin::create_currency(witness, 6, b"CYN", b"RMB", b"this is qian", icon_url, ctx);

        // 所有权共享  不可变共享
        public_freeze_object(coin_metadata);

        // 独享 国库管理权限菜单
        public_transfer(treasury_cap, sender(ctx));
    }

}

