module token_coin::token_coin {
    use std::option;
    use sui::coin;
    use sui::token;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    public struct TOKEN_COIN has drop {}

    fun init(witness: TOKEN_COIN, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 6, b"TOKEN_COIN", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);

        // token::new_policy()

        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }
}