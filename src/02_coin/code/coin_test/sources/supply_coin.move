module coin_test::supply_coin ;

use sui::balance;
use sui::balance::Supply;
use sui::coin::{Self, Coin};
use sui::coin_registry;
use std::string;

const EAmountTooSmall: u64 = 0;

public struct SUPPLY_COIN has drop {}

public struct SupplyHold<phantom T> has key {
    id: UID,
    supply: Supply<T>
}

fun init(witness: SUPPLY_COIN, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"SUPPLY"),
        string::utf8(b"SUPPLY Coin"),
        string::utf8(b"this is SUPPLY Coin"),
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

public fun mint(supply_hold: &mut SupplyHold<SUPPLY_COIN>, amt: u64, ctx: &mut TxContext): Coin<SUPPLY_COIN> {
    assert!(amt >= 10000, EAmountTooSmall);
    let supply_balance = balance::increase_supply(&mut supply_hold.supply, amt);
    coin::from_balance(supply_balance, ctx)
}

public fun mint_and_transfer(supply_hold: &mut SupplyHold<SUPPLY_COIN>, amt: u64, to: address, ctx: &mut TxContext) {
    let supply_coin = mint(supply_hold, amt, ctx);
    transfer::public_transfer(supply_coin, to);
}
