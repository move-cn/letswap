module deny_coin::deny_coin ;
use sui::coin_registry;
use std::string;

public struct DENY_COIN has drop {}

fun init(witness: DENY_COIN, ctx: &mut TxContext) {
    let (mut init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        8,
        string::utf8(b"DENY"),
        string::utf8(b"Deny Coin"),
        string::utf8(b"Deny list demo coin"),
        string::utf8(b""),
        ctx
    );
    let deny_cap = coin_registry::make_regulated(&mut init, true, ctx);
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);
    transfer::public_transfer(deny_cap, ctx.sender());
    transfer::public_transfer(treasury, ctx.sender());
}
