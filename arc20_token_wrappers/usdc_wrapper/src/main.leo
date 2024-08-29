import usdc_perps_v1.aleo;
import pool_perps_v1.aleo;

program usdc_wrapper_perps_v1.aleo {
    const THIS_ADDR: address = aleo1lvtuh6aekjcm6nu30rhv32v7jd770xtj97gtkmtfsd8q7ynd9ggq2e6za9;
    const POOL_ADDR: address = aleo10x6sqsc8d353upatyuelqa4864leds5kuk3xqmgj7gxzfhux6vxsrne96y;

    const TOKEN_SALT: u128 = 1u128;

    struct TokenId {
        base: address, // pool address
        creator: address, // creator address
        salt: u128,  // tokenId param provided by the creator
    }

    //============================================= initialize func =============================================
    // Initialize the program after deployment.
    // 1. init_wrapper wusdt, wusdc, wbtc, weth use different token_salt
    // 2. above four wrapper arc20-token info will be stored in whiteListTokenWrapper
    transition init_wrapper(public name: field, public symbol: field, public decimals: u8) {
        pool_perps_v1.aleo/create_token(
            name, 
            symbol,
            decimals,  // 6
            0u128,
            THIS_ADDR,
            TOKEN_SALT   
        );
    }

    //============================================= public func =============================================

    // 1. user transfer arc20-token into this contract
    // 2. wrapper contract as self.caller invoke whiteListTokenWrapper contract to mint wrapper token for user
    // @param: amount is token decimal
    transition wrap_public(public amount: u128, public receiver: address) {
        usdc_perps_v1.aleo/transfer_from_public(self.caller, THIS_ADDR, amount);
        pool_perps_v1.aleo/mint(get_token_id(), receiver, amount);
    }

    transition unwrap_public(public amount: u128, public receiver: address) {
        pool_perps_v1.aleo/burn_from(get_token_id(), self.caller, amount);
        usdc_perps_v1.aleo/transfer_public(receiver, amount);
    }


    inline get_token_id() -> field {
      return BHP256::hash_to_field(TokenId {
       base: POOL_ADDR,
       creator: THIS_ADDR,
       salt: TOKEN_SALT,
      });
    } 
}