module coin_supply::hk ;
use sui::balance;
use sui::balance::Supply;
use sui::coin::{Self, Coin};
use sui::coin_registry;
use std::string;

public struct HK has drop {}

public struct HKTreasuryCap has key, store {
    id: UID,
    supply: Supply<HK>
}

fun init(hk: HK, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        hk,
        6,
        string::utf8(b"HK"),
        string::utf8(b""),
        string::utf8(b""),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);

    let supply = coin::treasury_into_supply(treasury);

    let hk_treasury_cap = HKTreasuryCap {
        id: object::new(ctx),
        supply
    };

    transfer::public_transfer(hk_treasury_cap, ctx.sender());
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
