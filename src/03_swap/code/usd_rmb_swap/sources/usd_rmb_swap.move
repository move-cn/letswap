module usd_rmb_swap::usd_rmb_swap;
use coin_owner::rmb::RMB;
use coin_owner::usd::USD;
use sui::balance;
use sui::balance::Balance;
use sui::coin;
use sui::coin::Coin;
use sui::transfer::{share_object, public_transfer,transfer};

public struct Bank  has key {
    id: UID,
    usd: Balance<USD>,
    rmb: Balance<RMB>
}

public struct AdminCap  has key {
    id: UID
}

fun init(ctx:&mut TxContext){
    let bank = Bank{
        id:object::new(ctx),
        usd:balance::zero(),
        rmb:balance::zero(),
    };
    share_object(bank);

    let admin_cap = AdminCap{
        id:object::new(ctx),
    };
    transfer(admin_cap,ctx.sender());
}

// 怎么存钱
public fun add_usd(bank:&mut Bank, in: Coin<USD>,_:&mut TxContext){
    bank.usd.join(coin::into_balance(in));
}

public fun add_rmb(bank:&mut Bank, in: Coin<RMB>,_:&mut TxContext){
    bank.rmb.join(coin::into_balance(in));
}


// 怎么交换
public fun usd_to_rmb(bank:&mut Bank,in:Coin<USD>,ctx:&mut TxContext){
  //  1 usd = 7.2RMB
    let usd_amt = in.value();

    // 真实的环境 汇率是动态的
    // 你怎么获取汇率  预言机 pyth
    let rmb_amt = usd_amt  * 72 / 10;
    bank.usd.join(coin::into_balance(in));
    let  rmb_b   =   bank.rmb.split(rmb_amt);
    public_transfer(coin::from_balance(rmb_b,ctx),ctx.sender());
}


public fun rmb_to_usd(bank:&mut Bank,in:Coin<RMB>,ctx:&mut TxContext){
    // 1 usd = 7.2RMB
    let  rmb_amt = in.value();
    let  usd_amt = rmb_amt  *  10 /  72;
    bank.rmb.join(coin::into_balance(in));
    let  usd_b   =   bank.usd.split(usd_amt);
    public_transfer(coin::from_balance(usd_b,ctx),ctx.sender());
}


// 怎么取钱

public fun remove_rmb(_:&AdminCap, bank:&mut Bank, amt:u64,_:&mut TxContext){
     let out =  bank.rmb.split(amt);
    public_transfer(coin::from_balance(out,ctx),ctx.sender());
}

