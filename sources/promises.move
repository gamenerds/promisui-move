#[allow(duplicate_alias)]
module promisui::promises {
    use sui::transfer::{Self, Receiving};
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use std::string::{Self, String};
    // use std::debug;

    public struct Promise has key {
        id: UID, 
        text: String,
        userAddy: address,
        timestamp: u32, // unix timestamp, seconds since 1/1/1970
    }

    public struct PromiseStorage has key {
        id: UID,
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(PromiseStorage {
            id: object::new(ctx)
        })
    }

    public fun promise_create(text: vector<u8>, 
                                timestamp: u32,
                                storage: &mut PromiseStorage,
                                ctx: &mut TxContext): address {
        let promise = Promise {
            id: object::new(ctx),
            text: string::utf8(text),
            userAddy: tx_context::sender(ctx),
            timestamp: timestamp
        };

        let obj_id = object::id(storage);
        let storage_addy = object::id_to_address(&obj_id);

        let p_id = object::id(&promise);

        transfer::transfer(promise, storage_addy);

        object::id_to_address(&p_id)
    }

    // accessors to read properties
    public fun promise_text(promise: &Promise): String {
        promise.text
    }

    public fun userAddy(promise: &Promise): address {
        promise.userAddy
    }

    public fun timestamp(promise: &Promise): u32 {
        promise.timestamp
    }

    public fun receive_promise(storage: &mut PromiseStorage, promise: Receiving<Promise>): Promise {
        transfer::receive(&mut storage.id, promise)
    }

    // === Tests ===

    #[test_only]
    // The `init` is not run in tests, and normally a test_only function is
    // provided so that the module can be initialized in tests. Having it public
    // is important for tests located in other modules.
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    // using a test-only attibute because this dependency can't be used in
    // production code and `sui move build` will complain about unused imports.
    //
    // the `sui::test_scenario` module is only available in tests.
    #[test_only] use sui::test_scenario;
    #[test_only] use std::vector;
    #[test_only] use sui::vec_map;

    #[test]
    // This test uses `test_scenario` to emulate actions performed by 3 accounts.
    // A single scenario follows this structure:
    //
    // - `begin` - starts the first tx and creates the sceanario
    // - `next_tx` ... - starts the next tx and sets the sender
    // - `end` - wraps up the scenario
    //
    // It provides functions to start transactions, get the `TxContext, pull
    // objects from account inventory and shared pool, and check transaction
    // effects.
    public fun test_promise_transactions() {
        let (admin, user) = (@0x1, @0x22);

        // create a test scenario with sender; initiates the first transaction
        let mut scenario = test_scenario::begin(admin);

        // === First transaction ===

        // run the module initializer
        // we use curly braces to explicitly scope the transaction;
        {
            let ctx = test_scenario::ctx(&mut scenario);
            init_for_testing(ctx);
        };

        // `next_tx` is used to initiate a new transaction in the scenario and
        // set the sender to the specified address. It returns `TransactionEffects`
        // which can be used to check object changes and events.
        let mut prev_effects = test_scenario::next_tx(&mut scenario, user);

        // make assertions on the effects of the first tx (init)
        let mut created_ids = test_scenario::created(&prev_effects);
        let mut shared_ids = test_scenario::shared(&prev_effects);
        let mut sent_ids = test_scenario::transferred_to_account(&prev_effects);
        let mut events_num = test_scenario::num_user_events(&prev_effects);

        // debug::print(&created_ids);

        assert!(vector::length(&created_ids) == 1, 0);
        assert!(vector::length(&shared_ids) == 1, 1);
        assert!(vec_map::size(&sent_ids) == 0, 2);
        assert!(events_num == 0, 3);

        // === Second Tx ===

        test_scenario::next_tx(&mut scenario, user);
        {
            let mut storage = test_scenario::take_shared<PromiseStorage>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);

            promise_create(b"I will eat my own shit if BAYC floor dips below 15 eth.", 1712642198, &mut storage, ctx);

            // debug::print(&p_id);

            test_scenario::return_shared(storage);

            // now return the store to the pool
        };

        prev_effects = test_scenario::next_tx(&mut scenario, user);

        // make assertions on the effects of the first tx (init)
        created_ids = test_scenario::created(&prev_effects);
        shared_ids = test_scenario::shared(&prev_effects);
        sent_ids = test_scenario::transferred_to_account(&prev_effects);
        events_num = test_scenario::num_user_events(&prev_effects);

        // debug::print(&sent_ids);

        assert!(vector::length(&created_ids) == 1, 4);
        assert!(vector::length(&shared_ids) == 1, 5);
        assert!(vec_map::size(&sent_ids) == 1, 6);
        assert!(events_num == 0, 7);

        test_scenario::end(scenario);
    }
}