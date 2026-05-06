module coin_supply::usd ;
use sui::balance::Supply;
use sui::coin::{Self, Coin};
use sui::coin_registry;
use std::string;

const ErrNotLt100: u64 = 0x0001;

public struct USD has drop {}

public struct USDSupply has key {
    id: UID,
    supply: Supply<USD>
}

public struct AdminCap has key, store {
    id: UID
}

public struct USDMintCap has key, store {
    id: UID
}

fun init(witness: USD, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"USD"),
        string::utf8(b""),
        string::utf8(b""),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);
    let supply = coin::treasury_into_supply(treasury);
    transfer::share_object(USDSupply {
        id: object::new(ctx),
        supply
    });

    transfer::public_transfer(AdminCap { id: object::new(ctx) }, ctx.sender());
}

public fun give_cap(_: &AdminCap, to: address, ctx: &mut TxContext) {
    transfer::public_transfer(USDMintCap {
        id: object::new(ctx)
    }, to);
}

public fun mint(usd: &mut USDSupply, amount: u64, ctx: &mut TxContext): Coin<USD> {
    assert!(amount < 100, ErrNotLt100);
    let usd_balance = usd.supply.increase_supply(amount);
    coin::from_balance(usd_balance, ctx)
}

public fun mint_cap(_: &mut USDMintCap, usd: &mut USDSupply, amount: u64, ctx: &mut TxContext): Coin<USD> {
    let usd_balance = usd.supply.increase_supply(amount);
    coin::from_balance(usd_balance, ctx)
}
