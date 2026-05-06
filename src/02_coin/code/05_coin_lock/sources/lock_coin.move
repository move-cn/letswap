#[allow(lint(self_transfer))]
module coin_lock::lock_coin ;
use sui::balance::Balance;
use sui::coin::{Self, TreasuryCap};
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
        string::utf8(b"LOCK"),
        string::utf8(b"Locked Coin"),
        string::utf8(b""),
        string::utf8(b""),
        ctx
    );
    coin_registry::finalize_and_delete_metadata_cap(init, ctx);
    transfer::public_transfer(treasury, ctx.sender());
}

public fun mint_and_lock(
    treasury: &mut TreasuryCap<LOCK_COIN>,
    amount: u64,
    lock_day: u64,
    to: address,
    ctx: &mut TxContext
) {
    let minted = coin::mint(treasury, amount, ctx);
    let current_ms = tx_context::epoch_timestamp_ms(ctx);

    let lock = LockCoin {
        id: object::new(ctx),
        balance: coin::into_balance(minted),
        release_time: current_ms + (lock_day * 24 * 3600 * 1000)
    };

    transfer::transfer(lock, to);
}

public fun unlock_coin(lock_coin: LockCoin, ctx: &mut TxContext) {
    let current_ms = tx_context::epoch_timestamp_ms(ctx);
    assert!(current_ms > lock_coin.release_time, ErrNotRelease);

    let LockCoin { id, balance, release_time: _ } = lock_coin;

    let unlocked = coin::from_balance(balance, ctx);

    transfer::public_transfer(unlocked, ctx.sender());

    object::delete(id);
}
