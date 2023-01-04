module bank::interface {
    use bank::liquidity::{Self, Pool, LP};

    use sui::tx_context::{TxContext, sender};
    use sui::pay;
    use sui::coin;
    use sui::table;
    use sui::table::Table;
    use sui::object::{UID, ID};
    use sui::object;
    use sui::transfer;
    use sui::coin::Coin;

    use std::vector;

    const ErrRemoveFailed :u64 = 1011;

    struct Pocket has key {
        id: UID,
        table: Table<ID, vector<u64>>
    }

    public entry fun create_pocket(ctx: &mut TxContext) {
        let pocket = Pocket {
            id: object::new(ctx),
            table: table::new<ID, vector<u64>>(ctx)
        };
        transfer::transfer(pocket, sender(ctx));
    }

    public entry fun generate_pool<X, Y>(ctx: &mut TxContext) {
        liquidity::generate_pool<X, Y>(ctx);
    }

    public entry fun add_liquidity_totally<X, Y>(pool: &mut Pool<X, Y>,
                                                 coin_x: Coin<X>,
                                                 coin_y: Coin<Y>,
                                                 pocket: &mut Pocket,
                                                 ctx: &mut TxContext) {
        let (lp, vec) = liquidity::add_liquidity(pool, coin_x, coin_y, ctx);
        let lp_id = object::id(&lp);
        table::add(&mut pocket.table, lp_id, vec);
        transfer::transfer(lp, sender(ctx));
    }

    public entry fun add_liquidity_partly<X, Y>(pool: &mut Pool<X, Y>,
                                                coin_x_vec: vector<Coin<X>>,
                                                coin_y_vec: vector<Coin<Y>>,
                                                coin_x_amt: u64,
                                                coin_y_amt: u64,
                                                pocket: &mut Pocket,
                                                ctx: &mut TxContext) {
        let coin_x_new = coin::zero<X>(ctx);
        let coin_y_new = coin::zero<Y>(ctx);
        pay::join_vec(&mut coin_x_new, coin_x_vec);
        pay::join_vec(&mut coin_y_new, coin_y_vec);
        let coin_x_in = coin::split(&mut coin_x_new, coin_x_amt, ctx);
        let coin_y_in = coin::split(&mut coin_y_new, coin_y_amt, ctx);
        let (lp, vec) = liquidity::add_liquidity(pool, coin_x_in, coin_y_in, ctx);
        let lp_id = object::id(&lp);
        table::add(&mut pocket.table, lp_id, vec);
        transfer::transfer(lp, sender(ctx));
        transfer::transfer(coin_x_new, sender(ctx));
        transfer::transfer(coin_y_new, sender(ctx));
    }

    public entry fun remove_liquidity<X, Y>(pool: &mut Pool<X, Y>,
                                            lp: Coin<LP<X, Y>>,
                                            pocket: &mut Pocket,
                                            ctx: &mut TxContext) {
        let lp_id = object::id(&lp);
        let vec = *table::borrow(&mut pocket.table, lp_id);
        let (coin_x_out, coin_y_out) = liquidity::remove_liquidity(pool,lp,vec,ctx);
        assert!(coin::value(&coin_x_out) > 0 && coin::value(&coin_y_out) > 0, ErrRemoveFailed);
        let vec_out = table::remove(&mut pocket.table, lp_id);
        vector::remove(&mut vec_out, 0);
        vector::remove(&mut vec_out, 0);
        transfer::transfer(coin_x_out, sender(ctx));
        transfer::transfer(coin_y_out, sender(ctx));
    }

    public entry fun withdraw<X, Y>(pool: &mut Pool<X, Y>,
                                    lp_vec: vector<Coin<LP<X, Y>>>,
                                    coin_x_amt: u64,
                                    coin_y_amt: u64,
                                    pocket: &mut Pocket,
                                    ctx: &mut TxContext){
        let idx = 0;
        let vec_length = vector::length(&lp_vec);
        let lp_id;
        while (idx < vec_length){
            lp_id = object::id(&vector::pop_back(&mut lp_vec));


        }
    }
}
