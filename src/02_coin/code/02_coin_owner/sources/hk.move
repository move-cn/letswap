module coin_owner::hk ;
use sui::coin_registry;
use std::string;

public struct HK has drop {}

fun init(hk: HK, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        hk,
        8,
        string::utf8(b"HK"),
        string::utf8(b"HK made in hongkong"),
        string::utf8(b"HK made in hongkong"),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);
    transfer::public_transfer(treasury, ctx.sender())
}
