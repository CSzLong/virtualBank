module bank::interface {
    use bank::liquidity;

    use sui::tx_context::{TxContext};
    use sui::pay;
    use sui::coin;
    use sui::balance;
    use sui::table;
    use sui::table::Table;
    use sui::object::{UID, ID};

    struct Pocket has key{
        id: UID,
        bag: Table<ID, vector<u64>>
    }

    fun init(ctx: &mut TxContext){

    }
}
