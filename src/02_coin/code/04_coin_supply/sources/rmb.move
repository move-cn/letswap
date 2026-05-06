module coin_supply::rmb ;
use sui::balance;
use sui::balance::Supply;
use sui::coin::{Self, Coin};
use sui::coin_registry;
use std::string;

public struct RMB has drop {}

public struct SupplyHold has key {
    id: UID,
    supply: Supply<RMB>
}

fun init(witness: RMB, ctx: &mut TxContext) {
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

    let supply_hold = SupplyHold {
        id: object::new(ctx),
        supply
    };
    transfer::share_object(supply_hold);
}

public fun mint2(sup: &mut SupplyHold, amount: u64, ctx: &mut TxContext): Coin<RMB> {
    let rmb_balance = balance::increase_supply(&mut sup.supply, amount);
    coin::from_balance(rmb_balance, ctx)
}
