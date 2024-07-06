module coin_test::supply_coin {

    use std::option;
    use sui::balance;
    use sui::balance::Supply;
    use sui::coin;
    use sui::coin::Coin;
    use sui::object;
    use sui::transfer::{share_object, freeze_object, public_transfer, public_freeze_object, public_share_object};
    use sui::tx_context::sender;
    use sui::url::Url;

    public struct SUPPLY_COIN has drop {}

    public struct SupplyHold<phantom T>  has key {
        id: UID,
        supply: Supply<T>
    }


    fun init(witness: SUPPLY_COIN, ctx: &mut TxContext) {
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
            coin::create_currency(witness, 6, b"SUPPLY Coin", b"SUPPLY Coin", b"this is SUPPLY Coin", icon_url, ctx);

        // 所有权共享  不可变共享
        public_freeze_object(coin_metadata);

        // 只有store 能力 没法使用所有权
        let supply = coin::treasury_into_supply(treasury_cap);


        let suplly_hold = SupplyHold {
            id: object::new(ctx),
            supply
        };

        share_object(suplly_hold);
    }


    public fun mint(suplly_hold: &mut SupplyHold<SUPPLY_COIN>, amt: u64, ctx: &mut TxContext): Coin<SUPPLY_COIN> {
        let call_address = sender(ctx);

        if (amt < 10000) {
            abort 0
        };
        let supply_balance =
            balance::increase_supply(&mut suplly_hold.supply, amt);
        let supply_coin = coin::from_balance(supply_balance, ctx);

        supply_coin
    }

    public entry fun mint_and_trasfer(suplly_hold: &mut SupplyHold<SUPPLY_COIN>,
                                      amt: u64, to:address, ctx: &mut TxContext) {
        let supply_coin = mint(suplly_hold,amt,ctx);
        public_transfer(supply_coin,to);
    }
}

