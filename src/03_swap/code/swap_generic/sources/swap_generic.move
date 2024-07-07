module swap_generic::swap_generic {
    use sui::balance;
    use sui::balance::Balance;
    use sui::coin;
    use sui::coin::Coin;
    use sui::object;
    use sui::object::UID;
    use sui::transfer::{transfer, share_object, public_transfer};
    use sui::tx_context::{TxContext, sender};


    public struct AdminCap has key {
        id: UID,
    }

    public struct Bank<phantom CoinA, phantom CoinB> has key {
        id: UID,
        coin_a: Balance<CoinA>,
        coin_b: Balance<CoinB>,
        a_: u64,
        b_: u64,
    }

    fun init(ctx: &mut TxContext) {
        let admin_cap = AdminCap { id: object::new(ctx) };
        transfer(admin_cap, sender(ctx));
    }

    public entry fun create_bank<CoinA, CoinB>(a: u64, b: u64, ctx: &mut TxContext) {
        let bank = Bank {
            id: object::new(ctx),
            coin_a: balance::zero<CoinA>(),
            coin_b: balance::zero<CoinB>(),
            a_: a,
            b_: b
        };
        share_object(bank);
    }


    /// 1 a = 1 b
    public entry fun swap_a_b<CoinA, CoinB>(bank: &mut Bank<CoinA, CoinB>,
                                            in: Coin<CoinA>, ctx: &mut TxContext) {
        let amt = coin::value(&in);
        balance::join(&mut bank.coin_a, coin::into_balance(in));

        let amt_b = amt * bank.a_ / bank.b_;

        let b_balance = balance::split(&mut bank.coin_b, amt_b);

        let b = coin::from_balance(b_balance, ctx);

        public_transfer(b, sender(ctx));
    }


    public entry fun deposit_coin_a<CoinA, CoinB>(
        bank: &mut Bank<CoinA, CoinB>,
        a: Coin<CoinA>,
        _: &mut TxContext
    ) {
        let a_balance = coin::into_balance(a);
        balance::join(&mut bank.coin_a, a_balance);
    }


    public entry fun withdraw_a<CoinA, CoinB>(_: &AdminCap,
                                              bank: &mut Bank<CoinA, CoinB>,
                                              amt: u64, ctx: &mut TxContext) {
        let a_balance = balance::split<CoinA>(&mut bank.coin_a, amt);

        let a = coin::from_balance(a_balance, ctx);
        public_transfer(a, sender(ctx));
    }
}
