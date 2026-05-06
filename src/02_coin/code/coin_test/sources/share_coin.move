module coin_test::share_coin ;
use sui::coin_registry;
use std::string;

public struct SHARE_COIN has drop {}

fun init(witness: SHARE_COIN, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"FAUCET"),
        string::utf8(b"Faucet Coin"),
        string::utf8(b"this is Faucet Coin"),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);
    transfer::public_share_object(treasury);
}
