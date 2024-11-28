module coin_supply::my_coin ;
use std::option;
use sui::balance::{Balance, Supply};
use sui::coin;
use sui::transfer;
use sui::tx_context::{TxContext};

public struct MY_COIN has drop {}


public struct MyCoinB has key{
    id:UID,
    b:Balance<MY_COIN>
}

public struct HKTreasuryCap has key, store {
    id: UID,
    supply: Supply<MY_COIN>,
}

public struct Fees has key, store {
    id: UID,
    b: Balance<MY_COIN>,
}



fun init(witness: MY_COIN, ctx: &mut TxContext) {
    let (treasury, metadata) =
        coin::create_currency(witness, 6, b"RMB", b"", b"", option::none(), ctx);
    transfer::public_freeze_object(metadata);

    let supply = coin::treasury_into_supply(treasury);

    public_transfer(supply, ctx.sender());
    /// 所有人都能访问
   // transfer::public_share_object(treasury);
}

public fun mint(my_cap:HKTreasuryCap ,ctx: &mut TxContext) : MyCoinB{
    let my_supply = my_cap.supply.increase_supply(100);
    MyCoinB{
        id:object::new(ctx),
        b:my_supply
    }
}


public fun  my_t(fee:&mut Fees,my:MyCoinB,to:address ,ctx: &mut TxContext){
    //
    let fee1 =  my.b.split(10);
    fee.b.join(fee1);
    transfer(my, to);
}
