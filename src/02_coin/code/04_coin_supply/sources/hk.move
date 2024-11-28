module coin_supply::hk;
use std::address;
use sui::balance;
use sui::balance::Supply;
use sui::coin;
use sui::coin::Coin;
use sui::transfer::{public_freeze_object, public_transfer, share_object};
use sui::vec_set::VecSet;

public struct HK has drop {}


public struct HKTreasuryCap has key, store {
    id: UID,
    supply: Supply<HK>
}

public struct Pools has key, store {
    id: UID,
    supply: Supply<HK>,
    // addresses:VecSet<address>
    ///
}






fun init(hk: HK, ctx: &mut TxContext) {
    let (treasury, metadata) =
        coin::create_currency(hk, 6, b"HK", b"", b"", option::none(), ctx);


    public_freeze_object(metadata);

    let supply = coin::treasury_into_supply(treasury);

    let hk_treasury_cap = HKTreasuryCap {
        id: object::new(ctx),
        supply
    };

    public_transfer(hk_treasury_cap, ctx.sender());


    let pool = Pools {
        id: object::new(ctx),
        supply
    };

   share_object(pool);


}

public fun mint(hk_cap: &mut HKTreasuryCap, amt: u64, ctx: &mut TxContext): Coin<HK> {
    let supply_amt = balance::supply_value(&hk_cap.supply);
    let total = amt + supply_amt;
    //  MAX 100亿
    assert!(total <= 10000_000000000, 0x2);

    let balance = hk_cap.supply.increase_supply(amt);

    let hk_coin = coin::from_balance(balance, ctx);

    hk_coin
}

public fun mint2pool(pool: &mut Pools, amt: u64,who:address, ctx: &mut TxContext): Coin<HK> {
    let supply_amt = balance::supply_value(&hk_cap.supply);
    let total = amt + supply_amt;
    //  MAX 100亿

   /// assert!(,111)

    let balance = pool.supply.increase_supply(amt);

    let hk_coin = coin::from_balance(balance, ctx);

    hk_coin
}


