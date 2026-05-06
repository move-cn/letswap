module coin_supply::my_coin ;
use sui::balance::{Balance, Supply};
use sui::coin;
use sui::coin_registry;
use std::string;

public struct MY_COIN has drop {}

public struct MyCoinB has key {
    id: UID,
    b: Balance<MY_COIN>
}

public struct HKTreasuryCap has key, store {
    id: UID,
    supply: Supply<MY_COIN>,
}

public struct Fees has key, store {
    id: UID,
    b: Balance<MY_COIN>,
}

fun init(witness: MY_COIN, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"RMB"),
        string::utf8(b""),
        string::utf8(b""),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);

    let supply = coin::treasury_into_supply(treasury);

    transfer::public_transfer(HKTreasuryCap {
        id: object::new(ctx),
        supply,
    }, ctx.sender());
}

public fun mint(my_cap: &mut HKTreasuryCap, ctx: &mut TxContext): MyCoinB {
    let my_supply = my_cap.supply.increase_supply(100);
    MyCoinB {
        id: object::new(ctx),
        b: my_supply
    }
}


public fun my_t(fee: &mut Fees, mut my: MyCoinB, to: address, _ctx: &mut TxContext) {
    let fee1 = my.b.split(10);
    fee.b.join(fee1);
    transfer::transfer(my, to);
}
