module coin_test::my_coin ;
use sui::coin_registry;
use std::string;

public struct MY_COIN has drop {}

fun init(witness: MY_COIN, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"CYN"),
        string::utf8(b"RMB"),
        string::utf8(b"this is qian"),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);
    transfer::public_transfer(treasury, ctx.sender());
}
