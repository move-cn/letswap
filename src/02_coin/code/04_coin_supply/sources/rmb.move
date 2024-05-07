module coin_supply::rmb {
    use std::option;
    use sui::balance;
    use sui::balance::Supply;
    use sui::coin;
    use sui::coin::{Coin, balance};
    use sui::object;
    use sui::object::UID;
    use sui::transfer;
    use sui::transfer::{transfer, public_transfer, share_object};
    use sui::tx_context::{Self, TxContext, sender};

    public struct RMB has drop {}


    public struct SupplyHold has key {
        id: UID,
        supply: Supply<RMB>
    }


    fun init(witness: RMB, ctx: &mut TxContext) {
        let (treasury, metadata) =
            coin::create_currency(witness, 6, b"RMB", b"", b"", option::none(), ctx);

        transfer::public_freeze_object(metadata);

        let supply = coin::treasury_into_supply(treasury);





        let supply_hold = SupplyHold {
            id: object::new(ctx),
            supply
        };
        transfer(supply_hold,sender(ctx));
    }


    public fun mint2(sup: &mut SupplyHold, amount: u64, ctx: &mut TxContext): Coin<RMB> {


        let rmbBalance = balance::increase_supply(&mut sup.supply, amount);
        coin::from_balance(rmbBalance, ctx)
    }




    public entry fun mint_to(admin_cap:&AdminCap, sup: &mut SupplyHold, amount: u64, to: address, ctx: &mut TxContext) {
        let rmb = mint(admin_cap,sup, amount, ctx);
        public_transfer(rmb, to);
    }
}