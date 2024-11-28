
module univ2::univ2;
use std::u64;
use sui::balance;
use sui::balance::{Balance, Supply};
use sui::coin;
use sui::coin::Coin;
use sui::transfer::{share_object, public_transfer,transfer};

public struct Bank<phantom CoinA, phantom CoinB>  has key {
    id: UID,
    a: Balance<CoinA>,
    b: Balance<CoinB>,
    lp:Supply<LPCoin<CoinA,CoinB>>,
    scala:u64,
}

public struct AdminCap  has key {
    id: UID
}

// 存款凭证
public struct LPCoin<phantom CoinA, phantom CoinB> has drop  {}



fun init(ctx:&mut TxContext){
    let admin_cap = AdminCap{
        id:object::new(ctx),
    };
    transfer(admin_cap,ctx.sender());
}


public fun add_bank<CoinA, CoinB>(ctx:&mut TxContext){
    let lp = balance::create_supply(LPCoin<CoinA,CoinB>{});
    let bank = Bank<CoinA,CoinB>{
        id:object::new(ctx),
        a:balance::zero(),
        b:balance::zero(),
        lp,
        scala:100000000,
    };
    share_object(bank);
}






// 怎么交换
public fun a_to_b<CoinA, CoinB>(bank:&mut Bank<CoinA, CoinB>,in:Coin<CoinA>,ctx:&mut TxContext){
    let a_value = bank.a.value();
    let b_value = bank.b.value();

    let const_value = a_value * b_value;
    let in_amt = in.value();
    // 最终留在池子里面的钱
    let total_a = a_value + in_amt;
    // 最终留在池子里面的钱
    let total_b = const_value / total_a;
    let out_amt  =  b_value - total_b;

    bank.a.join(coin::into_balance(in));
    let  out_b   =   bank.b.split(out_amt);
    public_transfer(coin::from_balance(out_b,ctx),ctx.sender());
}



// 怎么交换
public fun b_to_a<CoinA, CoinB>(bank:&mut Bank<CoinA, CoinB>,in:Coin<CoinB>, out: u64,ctx:&mut TxContext){
    let a_value = bank.a.value();
    let b_value = bank.b.value();

    let const_value = a_value * b_value;
    let in_amt = in.value();
    // 最终留在池子里面的钱
    let total_b = b_value + in_amt;
    // 最终留在池子里面的钱
    let total_a = const_value / total_b;
    let out_amt  =  a_value - total_a;

    bank.b.join(coin::into_balance(in));
    let  out_b   =   bank.a.split(out_amt);
    public_transfer(coin::from_balance(out_b,ctx),ctx.sender());
}




public fun add<CoinA, CoinB> (bank:&mut Bank<CoinA,CoinB>, in_a: Coin<CoinA> ,in_b: Coin<CoinB>,_:&mut TxContext){
    // swap 添加池子的时候 不能改变汇率

    let a_value = bank.a.value();
    let b_value = bank.b.value();

    let in_a_value = in_a.value();
    let in_b_value = in_b.value();

   // let rate  = a_value * bank.scala  /  b_value;

   //  100 / 50          101  /  50;    /1%
   //  in_a_value

    assert!( a_value / b_value  == in_a_value / in_b_value,0x000222);

    bank.a.join(coin::into_balance(in_a));
    bank.b.join(coin::into_balance(in_b));



    // 你来银行存钱 给了你一个存款凭证
    let lp_coin_amt   =    u64::sqrt(in_a_value * in_b_value) ;
    let lp_b =  bank.lp.increase_supply(lp_coin_amt);

    public_transfer(coin::from_balance(lp_b,ctx),ctx.sender() );


}



/// 取钱的方法
///

public fun remove<CoinA, CoinB>(bank:&mut Bank<CoinA, CoinB> ,in:Coin<LPCoin<CoinA,CoinB>>,ctx:&mut TxContext){
   // 1000    / 1000000
   // a  *   1000    / 1000000
   //  in    ->  coina    coinb
}


