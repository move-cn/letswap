module swap_rmb_usd::swap_rmb_usd {

    use sui::balance;
    use sui::balance::Balance;
    use sui::coin;
    use sui::coin::{Coin, from_balance};
    use sui::object;
    use sui::transfer::{share_object, transfer, public_transfer, public_share_object};
    use sui::tx_context::sender;
    use coin_owner::rmb::RMB;
    use coin_owner::usd::USD;

    public struct Bank has key {
        id: object::UID,
        rmb: Balance<RMB>,
        usd: Balance<USD>,
    }

    public struct AdminCap has key {
        id: object::UID,
    }

    fun init(ctx: &mut TxContext) {
        let bank = Bank {
            id: object::new(ctx),
            rmb: balance::zero<RMB>(),
            usd: balance::zero()
        };
        share_object(bank);

        let admin_cap = AdminCap {
            id: object::new(ctx)
        };
        transfer(admin_cap, sender(ctx));
    }


    public fun swap_usd_rmb_(bank: &mut Bank,in:Coin<USD>,ctx: &mut TxContext):Coin<RMB>{
        let in_value = coin::value(&in);

        let out_amt = in_value * 73u64 / 10u64;


        // 把美元存在银行
        balance::join(&mut bank.usd, coin::into_balance(in));
        let out_balance =   balance::split(&mut bank.rmb,out_amt);
        let out = from_balance(out_balance,ctx);
        out
    }

    public entry fun swap_usd_rmb(bank: &mut Bank, in: Coin<USD>, ctx: &mut TxContext) {
        let coin = swap_usd_rmb_(bank, in, ctx);
        public_transfer(coin, sender(ctx));
    }


    public fun swap_rmb_usd_(bank: &mut Bank,in:Coin<RMB>, ctx: &mut TxContext):Coin<USD>{
        let in_value = coin::value(&in);
        let out_amt = in_value * 10u64  / 73u64  ;
        // 把人民币存在银行
        balance::join(&mut bank.rmb, coin::into_balance(in));
        // 从银行把美刀取出来
        let out_balance =   balance::split(&mut bank.usd,out_amt);
        let out = from_balance(out_balance,ctx);

        out
    }

    public entry fun swap_rmb_usd(bank: &mut Bank, in: Coin<RMB>, ctx: &mut TxContext) {
        let coin = swap_rmb_usd_(bank, in, ctx);
        public_transfer(coin, sender(ctx));
    }



    public entry fun add_rmd(bank: &mut Bank, in: Coin<RMB>, ctx: &mut TxContext) {
        let in_balance = coin::into_balance(in);
        balance::join(&mut bank.rmb, in_balance);
    }


    public entry fun remove_rmd( _:&AdminCap, bank: &mut Bank,amt:u64, ctx: &mut TxContext) {
          let out_balance =   balance::split(&mut bank.rmb,amt);
          let out = coin::from_balance(out_balance, ctx);
          public_transfer(out, sender(ctx));
    }

    public entry fun add_usd(bank: &mut Bank, in: Coin<USD>, ctx: &mut TxContext) {
        let in_balance = coin::into_balance(in);
        balance::join(&mut bank.usd, in_balance);
    }

    public entry fun remove_usd( _:&AdminCap, bank: &mut Bank,amt:u64, ctx: &mut TxContext) {
        let out_balance =   balance::split(&mut bank.usd,amt);
        let out = coin::from_balance(out_balance, ctx);
        public_transfer(out, sender(ctx));
    }

}
