module deny_coin::deny_coin {

    use std::option;
    use sui::coin::create_regulated_currency;
    use sui::deny_list;

    struct DENY_COIN has drop {}


    fun init(witness: DENY_COIN, ctx: &mut TxContext) {

        // decimals: u8,
        // symbol: vector<u8>,
        // name: vector<u8>,
        // description: vector<u8>,
        // icon_url: Option<Url>,
        // ctx: &mut TxContext

        let (treasury,deny_cap, metadata) =
            create_regulated_currency<DENY_COIN>(DENY_COIN,8,b"deny",b"deny", b"deny",
        option::none<>(),ctx);

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(deny_cap, tx_context::sender(ctx));
        transfer::public_transfer(treasury, tx_context::sender(ctx));

    }

}
