module swap_generic::swap_generic;
use sui::balance;
use sui::balance::Balance;
use sui::coin;
use sui::coin::Coin;
use sui::transfer::{share_object, public_transfer,transfer};

public struct Bank<phantom CoinA, phantom CoinB>  has key {
    id: UID,
    a: Balance<CoinA>,
    b: Balance<CoinB>,
    x: u64,
    y: u64,
}

public struct AdminCap  has key {
    id: UID
}


fun init(ctx:&mut TxContext){
    let admin_cap = AdminCap{
        id:object::new(ctx),
    };
    transfer(admin_cap,ctx.sender());
}


public fun add_bank<CoinA, CoinB>(x:u64,y:u64,ctx:&mut TxContext){
    let bank = Bank<CoinA,CoinB>{
        id:object::new(ctx),
        a:balance::zero(),
        b:balance::zero(),
        x,
        y
    };
    share_object(bank);
}



// 怎么交换
public fun a_to_b<CoinA, CoinB>(bank:&mut Bank<CoinA, CoinB>,in:Coin<CoinA>,ctx:&mut TxContext){
    //  1 usd = 7.2RMB
    let a_amt = in.value();

    let b_amt = a_amt  * bank.x / bank.y;
    bank.a.join(coin::into_balance(in));
    let  b_b   =   bank.b.split(b_amt);
    public_transfer(coin::from_balance(b_b,ctx),ctx.sender());
}


public fun b_to_a<CoinA, CoinB>(bank:&mut Bank<CoinA, CoinB>,in:Coin<CoinB>,ctx:&mut TxContext){
    //  1 usd = 7.2RMB
    let b_amt = in.value();
    let a_amt = b_amt  *  bank.y / bank.x ;
    bank.b.join(coin::into_balance(in));
    let  a_b   =   bank.a.split(a_amt);
    public_transfer(coin::from_balance(a_b,ctx),ctx.sender());
}





// 怎么存钱
public fun add_a<CoinA, CoinB> (bank:&mut Bank<CoinA,CoinB>, in: Coin<CoinA>,_:&mut TxContext){
    bank.a.join(coin::into_balance(in));
}

public fun add_b<CoinA, CoinB> (bank:&mut Bank<CoinA,CoinB>, in: Coin<CoinB>,_:&mut TxContext){
    bank.b.join(coin::into_balance(in));
}


/// 取钱的方法
///

public fun remove_a<CoinA, CoinB>(_:&AdminCap, bank:&mut Bank<CoinA, CoinB> , amt:u64,ctx:&mut TxContext){
    let out =  bank.a.split(amt);
    public_transfer(coin::from_balance(out,ctx),ctx.sender());
}

