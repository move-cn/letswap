module token_coin::token_coin ;
use sui::coin_registry;
use std::string;

public struct TOKEN_COIN has drop {}

fun init(witness: TOKEN_COIN, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"TOKEN_COIN"),
        string::utf8(b""),
        string::utf8(b""),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);

    // token::new_policy()

    transfer::public_transfer(treasury, ctx.sender())
}
