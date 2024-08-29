import credits.aleo;
import pool_perps_v1.aleo;

// wrapped aleo token(waleo), info is recorded in pool contract
program aleo_wrapper_perps_v1.aleo {
    
    // Replace the value when the program id changes
    const THIS_ADDR: address = aleo1yn57ctczge8htddah42wggt587wstwut5fr72mpga96xzwejncpsn6skqh;
    const POOL_ADDR: address = aleo10x6sqsc8d353upatyuelqa4864leds5kuk3xqmgj7gxzfhux6vxsrne96y;

    const ALEO_TOKEN_SALT: u128 = 0u128;

    struct TokenId {
        base: address, // pool address
        creator: address, // creator address
        salt: u128,  // tokenId param provided by the creator
    }

    //============================================= initialize func =============================================
    // Initialize the program after deployment.
    // create waleo token which info will be stored in pool
    transition init_wrapper(public name: field, public symbol: field, public decimals: u8) {
        pool_perps_v1.aleo/create_token(
            name, 
            symbol,
            decimals,
            0u128,
            THIS_ADDR,
            ALEO_TOKEN_SALT,
        );
    }

    //============================================= public func =============================================   

    // transfer private aleo into this contract and mint waleo for self.caller
    transition wrap_private_to_public(
        private input: credits.aleo/credits,
        public amount: u64,   
        public receiver: address,
    ) -> (credits.aleo/credits) {
        let aleo_change: credits.aleo/credits = credits.aleo/transfer_private_to_public(input, THIS_ADDR, amount);
        pool_perps_v1.aleo/mint(get_token_id(), receiver, amount as u128);
        return aleo_change;
    }

    transition unwrap_public_to_private(
        public amount: u64,
        private receiver: address
    ) -> (credits.aleo/credits) {
        pool_perps_v1.aleo/burn_from(get_token_id(), self.caller, amount as u128);
        let aleo_out: credits.aleo/credits = credits.aleo/transfer_public_to_private(receiver, amount);
        return aleo_out;
    }

    inline get_token_id() -> field {
        return BHP256::hash_to_field(TokenId {
            base: POOL_ADDR,
            creator: THIS_ADDR,
            salt: ALEO_TOKEN_SALT,
        });
    }
    
}

