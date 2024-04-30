## deny list
-  @0x403





## deny coin


```rust
    public fun deny_list_add<T>(
       deny_list: &mut DenyList,
       _deny_cap: &mut DenyCap<T>,
       addr: address,
       _ctx: &mut TxContext
    ) {
        let `type` =
            type_name::into_string(type_name::get_with_original_ids<T>()).into_bytes();
        deny_list::add(
            deny_list,
            DENY_LIST_COIN_INDEX,
            `type`,
            addr,
        )
    }
```


```rust
    public fun deny_list_remove<T>(
       deny_list: &mut DenyList,
       _deny_cap: &mut DenyCap<T>,
       addr: address,
       _ctx: &mut TxContext
    ) {
        let `type` =
            type_name::into_string(type_name::get_with_original_ids<T>()).into_bytes();
        deny_list::remove(
            deny_list,
            DENY_LIST_COIN_INDEX,
            `type`,
            addr,
        )
    }
```

```rust
/// Returns true iff the given address is denied for the given coin type. It will
/// return false if given a non-coin type.
public fun deny_list_contains<T>(
    freezer: &DenyList,
    addr: address,
): bool {
    let name = type_name::get_with_original_ids<T>();
    if (type_name::is_primitive(&name)) return false;
    
    let `type` = type_name::into_string(name).into_bytes();
    freezer.contains(DENY_LIST_COIN_INDEX, `type`, addr)
}
```