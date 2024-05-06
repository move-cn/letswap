module swap::swap {
    use sui::balance;
    use sui::balance::Balance;
    use sui::coin;
    use sui::coin::Coin;
    use sui::object;
    use sui::object::UID;
    use sui::transfer::{transfer, share_object, public_transfer};
    use sui::tx_context::{TxContext, sender};
    use coin_owner::usd::USD;
    use coin_owner::rmb::RMB;


    public struct AdminCap has key {
        id: UID,
    }

    public struct Bank has key {
        id: UID,
        rmb: Balance<RMB>,
        usd: Balance<USD>
    }


    fun init(ctx: &mut TxContext) {
        let bank = Bank {
            id: object::new(ctx),
            rmb: balance::zero<>(),
            usd: balance::zero<>()
        };

        share_object(bank);

        let admin_cap = AdminCap { id: object::new(ctx) };

        transfer(admin_cap, sender(ctx));
    }



    public entry fun deposit(){

    }

    public entry fun withdraw(){

    }



    public entry fun swap_rmb_usd(bank: &mut Bank, rmb: Coin<RMB>, ctx: &mut TxContext) {
        balance::join(&mut bank.rmb, coin::into_balance(rmb));
        let usd_balance = balance::split(&mut bank.usd, 1000);
        let usd = coin::from_balance(usd_balance, ctx);
        public_transfer(usd, sender(ctx));
    }
}