module deny_coin::deny_coin ;

use std::option;
use sui::coin::{create_regulated_currency_v2};
use sui::url::Url;

public struct DENY_COIN has drop {}


fun init(witness: DENY_COIN, ctx: &mut TxContext) {
    let (treasury, deny_cap, metadata) =
        create_regulated_currency_v2<DENY_COIN>(witness, 8, b"deny", b"deny", b"deny",
            option::none<Url>(),true, ctx);


    transfer::public_freeze_object(metadata);
    transfer::public_transfer(deny_cap, tx_context::sender(ctx));
    transfer::public_transfer(treasury, tx_context::sender(ctx));
}


