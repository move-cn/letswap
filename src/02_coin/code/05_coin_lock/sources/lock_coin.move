module coin_lock::lock_coin ;
use sui::balance::Balance;
use sui::coin::{TreasuryCap};
use sui::coin_registry;
use std::string;

const ErrNotRelease: u64 = 0x00001;

public struct LOCK_COIN has drop {}

public struct LockCoin has key {
    id: UID,
    balance: Balance<LOCK_COIN>,
    release_time: u64
}

fun init(witness: LOCK_COIN, ctx: &mut TxContext) {
    let (init, treasury) = coin_registry::new_currency_with_otw(
        witness,
        6,
        string::utf8(b"USD"),
        string::utf8(b""),
        string::utf8(b""),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);
    transfer::public_transfer(treasury, ctx.sender());
}

entry fun mint_and_lock(
    treasury: &mut TreasuryCap<LOCK_COIN>,
    amount: u64,
    lock_day: u64,
    to: address,
    ctx: &mut TxContext
) {
    let coin = coin::mint(treasury, amount, ctx);
    let current_ms = tx_context::epoch_timestamp_ms(ctx);

    let lock = LockCoin {
        id: object::new(ctx),
        balance: coin::into_balance(coin),
        release_time: current_ms + (lock_day * 24 * 3600 * 1000)
    };

    transfer::transfer(lock, to);
}

entry fun unlock_coin(lock_coin: LockCoin, ctx: &mut TxContext) {
    let current_ms = tx_context::epoch_timestamp_ms(ctx);
    assert!(current_ms > lock_coin.release_time, ErrNotRelease);

    let LockCoin { id, balance, release_time: _ } = lock_coin;

    let unlock_coin = coin::from_balance(balance, ctx);

    transfer::public_transfer(unlock_coin, ctx.sender());

    object::delete(id);
}
