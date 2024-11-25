
module swap_generic::swap_generic {

    use sui::balance;
    use sui::balance::Balance;
    use sui::coin;
    use sui::coin::Coin;
    use sui::object;
    use sui::object::UID;
    use sui::transfer::{share_object, public_transfer};
    use sui::tx_context::{TxContext, sender};

    public struct AdminCap has key {
        id: UID,
    }

    public struct Bank<phantom CoinA, phantom CoinB> has key {
        id: UID,
        a: Balance<CoinA>,
        b: Balance<CoinB>
    }

    fun init(ctx: &mut TxContext) {
        // let admin_cap = AdminCap { id: object::new(ctx) };
        // transfer(admin_cap, sender(ctx));
    }


    public entry fun create<CoinA,CoinB>(ctx: &mut TxContext){
        let pool = Bank<CoinA,CoinB>{
            id:object::new(ctx),
            a:balance::zero(),
            b:balance::zero(),
        };
        share_object(pool);
    }


    public entry fun deposit_a<CoinA,CoinB>(bank:&mut Bank<CoinA,CoinB>,a:Coin<CoinA>,_:&mut TxContext){
        let a_balance = coin::into_balance(a);
        bank.a.join(a_balance);
    }

    public entry fun deposit_b<CoinA,CoinB>(bank:&mut Bank<CoinA,CoinB>,b:Coin<CoinB>,_:&mut TxContext){
        let b_balance = coin::into_balance(b);
        bank.b.join(b_balance);
    }


    public entry fun swap_a_b<CoinA,CoinB>(bank: &mut Bank<CoinA,CoinB>, a: Coin<CoinA>, ctx: &mut TxContext) {
        let amt = coin::value(&a);

        bank.a.join(coin::into_balance(a));


        let amt_b = amt;


        let b_balance = bank.b.split(amt_b);


        let b = coin::from_balance(b_balance, ctx);

        public_transfer(b, sender(ctx));
    }



}
