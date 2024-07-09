module swap_generic::swap_generic {
    use std::string;
    use std::type_name;
    use std::type_name::get;
    use sui::balance;
    use sui::balance::{Balance, Supply};
    use sui::coin;
    use sui::coin::Coin;
    use sui::object;
    use sui::object::UID;
    use sui::table;
    use sui::transfer::{transfer, share_object, public_transfer};
    use sui::tx_context::{TxContext, sender};


    const slip_base: u64 = 10000;
    const fee_base: u64 = 100000;
    const DefautFee:u64 = 100;
    const DefautFeeLp:u64 = 200;


    public struct AdminCap has key {
        id: UID,
    }


    public struct LPCoin<phantom X, phantom Y> has drop {}


    public struct Pair<phantom CoinX, phantom CoinY> has key {
        id: UID,
        x: Balance<CoinX>,
        y: Balance<CoinY>,
        dao_fee_x:Balance<CoinX>,
        dao_fee_y:Balance<CoinX>,
        defaut_fee:u64,
        defaut_fee_lp:u64,
        lp_coin: Supply<LPCoin<CoinX, CoinY>>,
        scala_num: u64,
    }

    public struct Global has key {
        id: UID,
        pools: table::Table<String, ID>,
    }

    fun init(ctx: &mut TxContext) {
        let admin_cap = AdminCap { id: object::new(ctx) };
        transfer(admin_cap, sender(ctx));
        let global = Global{
            id:object::new(ctx),
            pools: table::new(ctx)
        };
        share_object(global);
    }

    public entry fun create_pair<CoinX, CoinY>(g:&mut Global ,a: u64, b: u64, ctx: &mut TxContext) {

        let x_name = get<CoinX>();
        let y_name = get<CoinY>();

        // 0x2:sui:SUI
        let x_name_str = type_name::into_string(x_name);
        let y_name_str = type_name::into_string(y_name);

       // 0x2:sui:SUI & 0x2:sui:USDC
      //  0x2:sui:USDC  & 0x2:sui:SUI

       // assert!( !table::contains(&g.pools, x_name_str + y_name_str) , 0x20);
       //

        // table::add(&mut g.pools, x_name_str + y_name_str);




        let lp_coin = LPCoin<CoinX, CoinY>;
        let lp_spply = balance::create_supply<LPCoin<CoinX, CoinY>>(lp_coin);
        let bank = Pair {
            id: object::new(ctx),
            x: balance::zero<CoinX>(),
            y: balance::zero<CoinY>(),
            dao_fee_x:balance::zero(),
            dao_fee_y:balance::zero(),
            defaut_fee: DefautFee,
            defaut_fee_lp: DefautFeeLp,
            lp_coin: lp_spply,
            scala_num: 100000,
        };
        share_object(bank);
    }


    public fun update_dao_fee<CoinX,CoinY>(_:AdminCap, bank: &mut Pair<CoinX, CoinY> ,  fee:u64, ctx:&TxContext){
        bank.dao_fee_x = fee;
    }


   //


    /// 1 a = 1 b
    public entry fun swap_a_b<CoinX, CoinY>(bank: &mut Pair<CoinX, CoinY>,
                                            in: Coin<CoinX>, ctx: &mut TxContext) {
        let amt = coin::value(&in);


        let bank_x = balance::value(&bank.x);
        let bank_y = balance::value(&bank.y);


        let dao_fee = (bank.defaut_fee ) /fee_base * amt ;
        let defaut_fee_lp = (bank.defaut_fee ) /fee_base * amt ;
        let dao_fee = coin::split<CoinX>(in,dao_fee,ctx);
        balance::join(bank.dao_fee_x, coin::into_balance(dao_fee));


        balance::join(&mut bank.x, coin::into_balance(in));

        let in_x_value = coin::value(in) - defaut_fee_lp;

        let k = bank_x * bank_y;
        let remain   =  k /  (bank_x + in_x_value);
        let out_x_value =  bank_y - remain;

        let b_balance = balance::split(&mut bank.y, out_x_value);

        let b = coin::from_balance(b_balance, ctx);

        public_transfer(b, sender(ctx));
    }


    public fun deposit<CoinX, CoinY>(
        bank: &mut Pair<CoinX, CoinY>,
        a: Coin<CoinX>,
        b: Coin<CoinY>,
        slip: u64,
        _: &mut TxContext
    ) {
        let bank_x = balance::value(&bank.x);
        let bank_y = balance::value(&bank.y);

        let in_x = coin::value(a);
        let in_y = coin::value(b);

        assert!(in_x * in_y != 0, 0x1);

        if (bank_x == 0) {
            // 表示第一次存款 不处理
        }else {
            let xy = bank_x * bank.scala_num / bank_y;
            let in_xy = in_x * bank.scala_num / in_y ;
            assert!(xy = in_xy, 0x111);
        };


        let a_balance = coin::into_balance(a);
        balance::join(&mut bank.x, a_balance);


        let b_balance = coin::into_balance(b);
        balance::join(&mut bank.y, b_balance);


        /// 需要记账  记录每一个存了多少钱
        // 需要一个存钱的凭证
        // 存款凭证是怎么计算的

        let lp_balance = balance::increase_supply(bank.lp_coin, in_x * in_y);
        let lp = coin::from_balance<LPCoin<CoinX, CoinY>>(lp_balance, ctx) ;
        public_transfer(lp, sender(ctx));
    }


    public fun remove<CoinX, CoinY>(
        bank: &mut Pair<CoinX, CoinY>,
        lp:LPCoin<CoinX,CoinY>,
        _: &mut TxContext
    ) {
        let bank_x = balance::value(&bank.x);
        let bank_y = balance::value(&bank.y);

        //   let  x ,y

        // xy / bank_x*bank_y
        //
        // x = xy / bank_x*bank_y  * bank_x
        // y = xy / bank_x*bank_y  * bank_y

        // balance::decrease_supply()
       //  public_transfer(x, sender(ctx));
       //  public_transfer(y, sender(ctx));
    }
}
