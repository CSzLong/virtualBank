module bank::liquidity {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Supply, Balance};
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{TxContext};
    use std::vector;
    use sui::bag::Bag;
    use sui::bag;

    const ErrZeroAmount: u64 = 1001;
    const ErrNotEnoughXInPool: u64 = 1002;
    const ErrNotEnoughYInPool: u64 = 1003;
    const ErrInvalidVecotrType: u64 = 1004;
    const ErrBalanceNotMatch: u64 = 1005;
    const ErrNotEnoughBalanceLP: u64 = 1006;

    //Liquidity provider, parameter 'X' and 'Y'
    //are coins held in the pool.
    struct LP<phantom X, phantom Y> has drop {}

    // Pool with exchange
    struct Pool<phantom X, phantom Y> has key {
        id: UID,
        coin_x: Balance<X>,
        coin_y: Balance<Y>,
        lp_supply: Supply<LP<X, Y>>
    }

    //create a new pool
    public(friend) fun generate_pool<X, Y>(ctx: &mut TxContext) {
        let new_pool = Pool<X, Y> {
            id: object::new(ctx),
            coin_x: balance::zero(),
            coin_y: balance::zero(),
            lp_supply: balance::create_supply<LP<X, Y>>(LP {})
        };
        transfer::share_object(new_pool);
    }

    //Add liquidity into pool, exchange rate is 1 between X and Y
    public(friend) fun add_liquidity<X, Y>(pool: &mut Pool<X, Y>,
                                           coin_x: Coin<X>,
                                           coin_y: Coin<Y>,
                                           ctx: &mut TxContext): (Coin<LP<X, Y>>, vector<u64>) {
        let coin_x_value = coin::value(&coin_x);
        let coin_y_value = coin::value(&coin_y);
        assert!(coin_x_value > 0 && coin_y_value > 0, ErrZeroAmount);
        coin::put(&mut pool.coin_x, coin_x);
        coin::put(&mut pool.coin_y, coin_y);
        let lp_bal = balance::increase_supply(&mut pool.lp_supply, coin_x_value + coin_y_value);
        let vec_value = vector::empty<u64>();
        vector::push_back(&mut vec_value, coin_x_value);
        vector::push_back(&mut vec_value, coin_y_value);
        (coin::from_balance(lp_bal, ctx), vec_value)
    }

    public(friend) fun remove_liquidity<X, Y>(pool: &mut Pool<X, Y>,
                                              lp: Coin<LP<X, Y>>,
                                              bag: &mut Bag,
                                              ctx: &mut TxContext): (Coin<X>, Coin<Y>) {
        let lp_id = object::id(&lp);
        let vec_value: &mut vector<u64> = bag::borrow_mut<ID, vector<u64>>(bag, lp_id);
        assert!(vector::length(vec_value) == 2, ErrInvalidVecotrType);
        let lp_balance_value = coin::value(&lp);
        let coin_x_out = *vector::borrow(vec_value, 0);
        let coin_y_out = *vector::borrow(vec_value, 1);
        assert!(lp_balance_value == coin_x_out + coin_y_out, ErrBalanceNotMatch);
        assert!(balance::value(&mut pool.coin_x) > coin_x_out, ErrNotEnoughXInPool);
        assert!(balance::value(&mut pool.coin_y) > coin_y_out, ErrNotEnoughYInPool);
        balance::decrease_supply(&mut pool.lp_supply, coin::into_balance(lp));
        vector::remove(vec_value, 0);
        vector::remove(vec_value, 0);
        vector::destroy_empty(*vec_value);
        (
            coin::take(&mut pool.coin_x, coin_x_out, ctx),
            coin::take(&mut pool.coin_y, coin_y_out, ctx)
        )
    }

    public(friend) fun withdraw<X, Y>(pool: &mut Pool<X, Y>,
                                      lp: &mut Coin<LP<X, Y>>,
                                      vec: &mut vector<u64>,
                                      coin_x_out: u64,
                                      coin_y_out: u64,
                                      ctx: &mut TxContext): (Coin<X>, Coin<Y>) {
        assert!(balance::value(&mut pool.coin_x) > coin_x_out, ErrNotEnoughXInPool);
        assert!(balance::value(&mut pool.coin_y) > coin_y_out, ErrNotEnoughYInPool);
        assert!(coin::value(lp) >= coin_x_out + coin_y_out, ErrNotEnoughBalanceLP);
        let coin_x_balance = vector::borrow_mut(vec, 0);
        *coin_x_balance = *coin_x_balance - coin_x_out;
        let coin_y_balance = vector::borrow_mut(vec, 1);
        *coin_y_balance = *coin_y_balance - coin_y_out;
        let coin_x = coin::take(&mut pool.coin_x, coin_x_out, ctx);
        let coin_y = coin::take(&mut pool.coin_y, coin_y_out, ctx);
        let lp_split = coin::split(lp, coin_x_out + coin_y_out, ctx);
        balance::decrease_supply(&mut pool.lp_supply, coin::into_balance(lp_split));
        (coin_x, coin_y)
    }

    //swap Coin X to Y, return Coin Y
    public(friend) fun swap_x_out_y<X, Y>(pool: &mut Pool<X, Y>,
                                          paid_in: Coin<X>,
                                          ctx: &mut TxContext): Coin<Y> {
        let paid_value = coin::value(&paid_in);
        coin::put(&mut pool.coin_x, paid_in);
        assert!(paid_value < balance::value(&mut pool.coin_y), ErrNotEnoughYInPool);
        coin::take(&mut pool.coin_y, paid_value, ctx)
    }

    //swap Coin Y to X, return Coin X
    public(friend) fun swap_y_into_x<X, Y>(pool: &mut Pool<X, Y>,
                                           paid_in: Coin<Y>,
                                           ctx: &mut TxContext): Coin<X> {
        let paid_value = coin::value(&paid_in);
        coin::put(&mut pool.coin_y, paid_in);
        assert!(paid_value < balance::value(&mut pool.coin_x), ErrNotEnoughXInPool);
        coin::take(&mut pool.coin_x, paid_value, ctx)
    }
}