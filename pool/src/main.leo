import oracle_perps_v1.aleo;

program pool_perps_v1.aleo {
    const THIS_ADDR: address = aleo10x6sqsc8d353upatyuelqa4864leds5kuk3xqmgj7gxzfhux6vxsrne96y;
    const DEPLOYER: address = aleo1cnm2w8qlrhahlsmalph7t0jh3adny5pj4m38jgpcdzt2reqthurqaen3dp;

    const ALP_TOKEN_ID: field = 6769995254802454894577392401849975163810476770055238272962759031196088045850field;
    const USDA_TOKEN_ID: field = 5831693778411205416925069027464809696308596398099265250571387651489705378046field; 

    const MAX_TOKEN_DECIMAL: u8 = 6u8;
    const MAX_U128: u128 = 340282366920938463463374607431768211455u128;
   
    mapping tokens: field => TokenInfo;
    mapping account: field => u128;  
    mapping approvals: field => u128;

    struct TokenInfo {
        name: field,
        symbol: field,
        decimals: u8,
        total_supply: u128,
        admin: address,
    }

    struct TokenId {
        base: address,
        creator: address,
        salt: u128,
    }

    struct AccountKey {
        token_id: field, 
        user: address,
    }

    struct ApprovalKey {
        token_id: field, 
        approver: address,
        spender: address,
    }

    transition init(public name: field, public symbol: field, public decimals: u8, public init_supply: u128, public banker: address, public salt: u128) {
        assert_eq(self.caller, DEPLOYER);
        let token_id: field = get_token_id(DEPLOYER, salt);
        let aid_banker: field = get_account_id(token_id, banker);
        return then finalize(token_id, name, symbol, decimals, init_supply, aid_banker);
    }

    finalize init(public token_id: field, public name: field, public symbol: field, public decimals: u8, public init_supply: u128, public aid_banker: field) {
        assert(!tokens.contains(token_id));
        tokens.set(token_id, TokenInfo {
            name: name,
            symbol: symbol,
            decimals: decimals,
            total_supply: init_supply,
            admin: THIS_ADDR,
        });
        account.set(aid_banker, init_supply);
    }

    transition create_token(
        public name: field,
        public symbol: field,
        public decimals: u8,
        public total_supply: u128,
        public admin: address,
        public salt: u128,
    ) {
        assert(name > 0field);
        return then finalize(name, symbol, decimals, total_supply, admin, self.caller, salt);
    }

    finalize create_token(
        public name: field,
        public symbol: field,
        public decimals: u8,
        public total_supply: u128,
        public admin: address,
        public caller: address, // arc20_token_wrapper / aleo_wrapper contract
        public salt: u128
    ) {
        assert_eq(caller, admin);
        let token_id: field = get_token_id(caller, salt);
        assert(!tokens.contains(token_id));

        let info: TokenInfo = TokenInfo {
            name, symbol, decimals, total_supply,admin
        };
        tokens.set(token_id, info);

        let account_id: field = get_account_id(token_id, caller);
        account.set(account_id, total_supply);
    }

    transition mint(public token_id: field, public to: address, public amount: u128) {
        return then finalize(self.caller, token_id, to, amount);
    }

    finalize mint(public caller: address, public token_id: field, public to: address, public amount: u128) {
        let info: TokenInfo = tokens.get(token_id);
       
        assert_eq(caller, info.admin);
        let mint_amount: u128 = amount.mul(10u128.pow(MAX_TOKEN_DECIMAL)).div(10u128.pow(info.decimals));

        tokens.set(token_id, TokenInfo {
            name: info.name,
            symbol: info.symbol,
            decimals: info.decimals,
            total_supply: info.total_supply + mint_amount,
            admin: info.admin,
        });

        let aid_to: field = get_account_id(token_id, to);
        account.set(aid_to, account.get_or_use(aid_to, 0u128) + mint_amount);
    }

    transition burn_from(public token_id: field, public from: address, public amount: u128) {
        let approval_id: field = get_approval_key(token_id, from, self.caller);
        return then finalize(self.caller, token_id, approval_id, from, amount);
    }

    finalize burn_from(public caller: address, public token_id: field, public approval_id: field, public from: address, public amount: u128) {
        let info: TokenInfo = tokens.get(token_id);
        assert_eq(caller, info.admin);

        let burn_amount: u128 = amount.mul(10u128.pow(MAX_TOKEN_DECIMAL)).div(10u128.pow(info.decimals));
        approvals.set(approval_id, approvals.get(approval_id) - burn_amount);
        tokens.set(token_id, TokenInfo {
            name: info.name,
            symbol: info.symbol,
            decimals: info.decimals,
            total_supply: info.total_supply - burn_amount,
            admin: info.admin,
        });

        let aid_from: field = get_account_id(token_id, from);
        account.set(aid_from, account.get(aid_from) - burn_amount);
    }

    transition transfer_public(public token_id: field, public to: address, public amount: u128) {
        return then finalize(token_id, self.caller, to, amount);
    }

    finalize transfer_public(public token_id: field, public from: address, public to: address, public amount: u128) {
        assert(tokens.contains(token_id));
        let aid_from: field = get_account_id(token_id, from);
        let bal_from: u128 = account.get(aid_from);
        account.set(aid_from, bal_from - amount);

        let aid_to: field = get_account_id(token_id, to);
        let bal_to: u128 = account.get_or_use(aid_to, 0u128);
        account.set(aid_to, bal_to + amount);
    }

    transition approve_public(public token_id: field, public spender: address, public amount: u128) {
        let key: field = get_approval_key(token_id, self.caller, spender);
        return then finalize(token_id, key, amount);
    }

    finalize approve_public(public token_id: field, public key: field, public amount: u128) {
        assert(tokens.contains(token_id));
        let pre_approval: u128 = approvals.get_or_use(key, 0u128);
        let new_approval: u128 = amount < MAX_U128 - pre_approval ? pre_approval.add_wrapped(amount) : MAX_U128;
        approvals.set(key, new_approval);
    }

    transition unapprove_public(public token_id: field, public spender: address, public amount: u128) {
        let key: field = get_approval_key(token_id, self.caller, spender);
        return then finalize(token_id, key, amount);
    }

    finalize unapprove_public(public token_id: field, public key: field, public amount: u128) {
        assert(tokens.contains(token_id));
        let pre_approval: u128 = approvals.get(key);
        let new_approval: u128 = pre_approval > amount ? pre_approval.sub_wrapped(amount) : 0u128;
        approvals.set(key, new_approval);
    }

    transition transfer_from(
        public token_id: field,
        public from: address,
        public to: address,
        public amount: u128
     ) {
        let key: field = get_approval_key(token_id, from, self.caller);
        return then finalize(token_id, key, from, to, amount);
    }

    finalize transfer_from(
        public token_id: field,
        public key: field,
        public from: address,
        public to: address,
        public amount: u128
    ) {
        assert(tokens.contains(token_id));

        approvals.set(key, approvals.get(key) - amount);

        let aid_from: field = get_account_id(token_id, from);
        account.set(aid_from, account.get(aid_from) - amount);

        let aid_to: field = get_account_id(token_id, to);
        account.set(aid_to, account.get_or_use(aid_to, 0u128) + amount);
    }


    // ============================================= perpetual func ============================================
    const MAX_TOKEN_NUMS: u8 = 5u8;
    const PRICE_PRECISION_DECIMAL: u8 = 6u8;
    const FUNDING_INTERVAL_BLOCKS: u32 = 5760u32;
    const MAX_COOLDOWN_DURATION:u32 = 34560u32;
    const has_dynamic_fees: bool = false;
    const liquidation_fee_usd: u128 = 5000000u128;
    const MAX_LEVERAGE: u128 = 500000u128;  
    const mint_burn_fee_basis_points:u128 = 30u128;
    const tax_basis_points: u128 = 50u128;
    const swap_fee_basis_points: u128 = 30u128;
    const stable_swap_fee_basis_points: u128 = 4u128;  
    const stable_tax_basis_points: u128 = 20u128; 
    const margin_fee_basis_points: u128 = 10u128; 
    const FUNDING_RATE_PRECISION: u128 = 1000000u128; 
    const BASIS_DIVISOR: u128 = 10000u128;
    
    mapping whitelist_token_ids: bool => [field; 5];
    mapping cooldown_duration: bool => u32;
    mapping aum_config:  bool => AumConfig;
    mapping funding_rate_config: bool => FundingRateConfig;
    mapping stable_tokens: field => bool;  
    mapping token_weights: field => u128;
    mapping total_token_weights: bool => u128;
    mapping max_usda_amounts: field => u128;
    mapping min_profit_basis_points: field => u32; 
    mapping min_profit_block: bool => u32;
    mapping pool_amounts: field => u128;
    mapping reserve_amounts: field => u128;
    mapping usda_amounts: field => u128;
    mapping cumulative_funding_rates: field => u128;
    mapping fee_reserves: field => u128;
    mapping positions: field => Position;
    mapping guaranteed_usd: field => u128;
    mapping global_short_sizes: field => u128;
    mapping global_short_average_prices: field => u128;
    mapping last_funding_blocks: field => u32;
    mapping last_added_at: address => u32;
    mapping super_admin: bool => address; 
    mapping is_governor: address => bool;

    struct AumConfig {
        addition: u128,
        deduction: u128,
    }

    struct FundingRateConfig {
        stable_funding_rate_factor: u128,
        funding_rate_factor: u128
    }

    struct PositionKey {
        user: address,
        collateral_token_id: field,
        index_token_id: field,
        is_long: bool,
    }

    struct Position {
        size: u128, // in usd
        collateral: u128,  //in usd
        average_price: u128,
        entry_funding_rate: u128,
        reserve_amount: u128,
        realised_pnl: i128,
        last_increased_block: u32,  // todo: convert time to blocks
    }

    transition add_liquidity(public token_id: field,  public amount_in: u128, public min_usd: u128, public min_alp_amount: u128){
        assert(amount_in > 0u128);
        let aid_from: field = get_account_id(token_id, self.caller);
        let aid_to: field = get_account_id(token_id, THIS_ADDR);

        return then finalize(self.caller, token_id, amount_in, min_usd, min_alp_amount, aid_from, aid_to);
    }

    finalize add_liquidity(public caller: address, public token_id: field, public amount_in: u128, public min_usda: u128, public min_alp_amount: u128, public aid_from: field, public aid_to: field) {
        assert(tokens.contains(token_id));
        assert(whitelist_token_ids.contains(true));
        assert(validate_whitelist_token(token_id, whitelist_token_ids.get(true)));

        account.set(aid_from, account.get(aid_from) - amount_in);
        account.set(aid_to, account.get_or_use(aid_to, 0u128) + amount_in);

        assert(aum_config.contains(true));
        let config: AumConfig = aum_config.get(true);
        let aum: u128 = config.addition;
        let short_profits: u128 = 0u128;
        assert(whitelist_token_ids.contains(true));
        let whitelist_tokens: [field; 5] = whitelist_token_ids.get(true);
        for i: u8 in 0u8..MAX_TOKEN_NUMS {
            let tmp_token_id: field = whitelist_tokens[i];
            let max_price: u128 = Mapping::get(oracle_perps_v1.aleo/max_price, tmp_token_id);
            let pool_amount: u128 = pool_amounts.get_or_use(tmp_token_id, 0u128); 
            
            let is_stable: bool = stable_tokens.get(tmp_token_id); 
            aum = is_stable ? aum.add(pool_amount.mul(max_price).div(10u128.pow(MAX_TOKEN_DECIMAL))) : aum;

            let size: u128 = !is_stable ? global_short_sizes.get_or_use(tmp_token_id, 0u128) : 0u128;
            let gs_average_price: u128 = (!is_stable && size > 0u128) ? global_short_average_prices.get_or_use(tmp_token_id, 0u128) : 0u128;
            let price_delta: u128 = gs_average_price > max_price ? gs_average_price.sub_wrapped(max_price) : max_price.sub_wrapped(gs_average_price);
            
            let div_constant: u128 =  gs_average_price == 0u128 ? 1u128 : gs_average_price;
            let delta: u128 = gs_average_price != 0u128 ? size.mul(price_delta).div_wrapped(div_constant) : 0u128;
            
            let has_profit: bool = gs_average_price > max_price; 

            aum = !has_profit ? aum + delta : aum;
            short_profits = has_profit ? short_profits + delta : short_profits;

            aum = !is_stable ? aum.add(guaranteed_usd.get_or_use(tmp_token_id, 0u128)) : aum;

            let reserve_amount: u128 = reserve_amounts.get_or_use(tmp_token_id, 0u128);
            aum = !is_stable ? aum.add(pool_amount.sub_wrapped(reserve_amount).mul(max_price).div(10u128 ** MAX_TOKEN_DECIMAL)) : aum;
        }
        aum = short_profits > aum ? 0u128 : aum.sub(short_profits);
        aum = config.deduction > aum ? 0u128 : aum.sub(config.deduction);
        aum = aum.mul(10u128.pow(MAX_TOKEN_DECIMAL)).div(10u128.pow(PRICE_PRECISION_DECIMAL));

        let current_lfb: u32 = last_funding_blocks.get_or_use(token_id, 0u32);
        let bh: u32 = (block.height).div(FUNDING_INTERVAL_BLOCKS).mul(FUNDING_INTERVAL_BLOCKS);

        let new_lfb: u32 = current_lfb == 0u32 ? bh : ( current_lfb != 0u32 && current_lfb.add(FUNDING_INTERVAL_BLOCKS) > block.height ? current_lfb : bh);
        let tmp_pool_amount: u128 = pool_amounts.get_or_use(token_id, 0u128);
        let intervals: u32 = (block.height).sub(current_lfb).div(FUNDING_INTERVAL_BLOCKS); 

        assert(funding_rate_config.contains(true));
        let fr_config: FundingRateConfig = funding_rate_config.get(true);
        let funding_rate_factor: u128 = stable_tokens.get(token_id) ? fr_config.stable_funding_rate_factor : fr_config.funding_rate_factor;
        let div_cnst: u128 = (tmp_pool_amount == 0u128 || (current_lfb + FUNDING_INTERVAL_BLOCKS) > block.height) ? 1u128 : tmp_pool_amount;
        let next_funding_rate: u128 = (tmp_pool_amount == 0u128 || (current_lfb + FUNDING_INTERVAL_BLOCKS) > block.height) ? 0u128 :  funding_rate_factor.mul(reserve_amounts.get_or_use(token_id, 0u128)).mul(intervals as u128).div_wrapped(div_cnst);
    
        cumulative_funding_rates.set(token_id, cumulative_funding_rates.get_or_use(token_id, 0u128) + next_funding_rate);
        last_funding_blocks.set(token_id, new_lfb);
        let min_price: u128 = Mapping::get(oracle_perps_v1.aleo/min_price, token_id);
        let usda_amount: u128 = amount_in.mul(min_price).div(10u128.pow(PRICE_PRECISION_DECIMAL));
        assert(usda_amount > 0u128);
        
        let initial_amount: u128 = usda_amounts.get_or_use(token_id, 0u128);
        let usda_info: TokenInfo = tokens.get(USDA_TOKEN_ID); 
        assert(total_token_weights.contains(true));
        let ttws: u128 = total_token_weights.get(true);
        let div_ttw: u128 = ttws == 0u128 ? 1u128 : ttws;
        let target_amount: u128 = token_weights.get_or_use(token_id, 0u128).mul(usda_info.total_supply).div(div_ttw);
        let fee_basis_points: u128 = cal_fee_basis_points(true, initial_amount, usda_amount, target_amount, mint_burn_fee_basis_points, tax_basis_points);

        let sf: (u128, u128) = collect_swap_fees(amount_in, fee_basis_points);
        fee_reserves.set(token_id, fee_reserves.get_or_use(token_id, 0u128) + sf.1); 
        let usda_mint_amount: u128 = (sf.0).mul(min_price).div(10u128.pow(PRICE_PRECISION_DECIMAL));
        usda_amounts.set(token_id, usda_amounts.get_or_use(token_id, 0u128) + usda_mint_amount);
        let max_usda_amount: u128 = max_usda_amounts.get_or_use(token_id, 0u128);
        let valid: bool = max_usda_amount > 0u128 ? usda_amounts.get(token_id) <= max_usda_amount : true;
        assert_eq(valid, true);

        pool_amounts.set(token_id, pool_amounts.get_or_use(token_id, 0u128) + sf.0);

        assert(usda_mint_amount >= min_usda); 
        tokens.set(USDA_TOKEN_ID, TokenInfo {
            name: usda_info.name,
            symbol: usda_info.symbol,
            decimals: usda_info.decimals,
            total_supply: usda_info.total_supply + usda_mint_amount,
            admin: usda_info.admin,
        });
        let aid_usda_pool: field = get_account_id(USDA_TOKEN_ID, THIS_ADDR);
        account.set(aid_usda_pool, account.get_or_use(aid_usda_pool, 0u128) + usda_mint_amount);
        let alp_info: TokenInfo = tokens.get(ALP_TOKEN_ID); 
        let div_aum_cnst: u128 = aum == 0u128 ? 1u128 : aum;
        let alp_mint_amount: u128 = (aum == 0u128 || alp_info.total_supply == 0u128)? usda_mint_amount : usda_mint_amount.mul(alp_info.total_supply).div(div_aum_cnst);
        assert(alp_mint_amount >= min_alp_amount);

        tokens.set(ALP_TOKEN_ID, TokenInfo {
            name: alp_info.name,
            symbol: alp_info.symbol,
            decimals: alp_info.decimals,
            total_supply: alp_info.total_supply + alp_mint_amount,
            admin: alp_info.admin,
        });
        let aid_alp_caller: field = get_account_id(ALP_TOKEN_ID, caller);
        account.set(aid_alp_caller, account.get_or_use(aid_alp_caller, 0u128) + alp_mint_amount);
        last_added_at.set(caller, block.height);
    }

    transition remove_liquidity(public token_out_id: field, public alp_amount: u128, public min_out_amount: u128, public receiver: address) {
        assert(alp_amount > 0u128);
        return then finalize(self.caller, token_out_id, alp_amount, min_out_amount, receiver);
    }

    finalize remove_liquidity (public caller: address, public token_out_id: field, public alp_amount: u128, public min_out_amount: u128, public receiver: address) {
        // 1. validate params
        assert(tokens.contains(token_out_id));
        assert(whitelist_token_ids.contains(true));
        assert(validate_whitelist_token(token_out_id, whitelist_token_ids.get(true)));
        assert(cooldown_duration.contains(true));
        assert(last_added_at.get(caller).add(cooldown_duration.get(true)) <= block.height);
        
        // 2. compute pool total value in usda: aum
        assert(aum_config.contains(true));
        let config: AumConfig = aum_config.get(true);
        let aum: u128 = config.addition;
        let short_profits: u128 = 0u128;
        assert(whitelist_token_ids.contains(true));
        let whitelist_tokens: [field; 5] = whitelist_token_ids.get(true);
        for i: u8 in 0u8..MAX_TOKEN_NUMS {
            let tmp_token_id: field = whitelist_tokens[i];
            let min_price: u128 = Mapping::get(oracle_perps_v1.aleo/min_price, tmp_token_id);
            let pool_amount: u128 = pool_amounts.get_or_use(tmp_token_id, 0u128);

            let is_stable: bool = stable_tokens.get(tmp_token_id); 
            // is_stable: cal updatable aum
            aum = is_stable ? aum.add(pool_amount.mul(min_price).div(10u128.pow(MAX_TOKEN_DECIMAL))) : aum;

            // !is_stable: cal tmp_aum
            let size: u128 = !is_stable ? global_short_sizes.get_or_use(tmp_token_id, 0u128) : 0u128;
            let gs_average_price: u128 = (!is_stable && size > 0u128) ? global_short_average_prices.get_or_use(tmp_token_id, 0u128) : 0u128;
            let price_delta: u128 = gs_average_price > min_price ? gs_average_price.sub_wrapped(min_price) : min_price.sub_wrapped(gs_average_price);
            let div_gap_cnst: u128 = gs_average_price == 0u128 ? 1u128 : gs_average_price;
            let delta: u128 = gs_average_price != 0u128 ? size.mul(price_delta).div_wrapped(div_gap_cnst) : 0u128;
            
            let has_profit: bool = gs_average_price > min_price; 

            aum = !has_profit ? aum + delta : aum;
            short_profits = has_profit ? short_profits + delta : short_profits;

            aum = !is_stable ? aum.add(guaranteed_usd.get_or_use(tmp_token_id, 0u128)) : aum;

            let reserve_amount: u128 = reserve_amounts.get_or_use(tmp_token_id, 0u128);
            aum = !is_stable ? aum.add(pool_amount.sub_wrapped(reserve_amount).mul(min_price).div(10u128 ** MAX_TOKEN_DECIMAL)) : aum;
        }
        // end for loop
        aum = short_profits > aum ? 0u128 : aum.sub(short_profits);
        aum = config.deduction > aum ? 0u128 : aum.sub(config.deduction);
        // cal aum in usd
        aum = aum.mul(10u128.pow(MAX_TOKEN_DECIMAL)).div(10u128.pow(PRICE_PRECISION_DECIMAL));
        
        // 3. cal remove alp_amount value in usda
        let alp_info: TokenInfo = tokens.get(ALP_TOKEN_ID); 
        let usda_amount: u128 = alp_amount.mul(aum).div(alp_info.total_supply);
        // 3.1. check whether need to mint usda if usda[pool] balance is not enough 
        // do not need since it will be burned by pool, so we will check that if 
        // pool usda balance is not enough, we burn all, else just burn usda_amount

        // 4. burn alp_amount for caller
        assert_eq(alp_info.admin, THIS_ADDR);
        tokens.set(ALP_TOKEN_ID, TokenInfo {
            name: alp_info.name,
            symbol: alp_info.symbol,
            decimals: alp_info.decimals,
            total_supply: alp_info.total_supply - alp_amount,
            admin: alp_info.admin,
        });
        // update balance
        let aid_alp_caller: field = get_account_id(ALP_TOKEN_ID, caller);
        assert(account.get(aid_alp_caller) >= alp_amount);
        account.set(aid_alp_caller, account.get(aid_alp_caller) - alp_amount);

        // 5. sellUSDA 
        // 5.1. updateCumulativeFundingRate(token_out_id)
        let current_lfb: u32 = last_funding_blocks.get_or_use(token_out_id, 0u32);
        let bh: u32 = block.height.div(FUNDING_INTERVAL_BLOCKS).mul(FUNDING_INTERVAL_BLOCKS);

        let new_lfb: u32 = current_lfb == 0u32 ? bh : ( current_lfb != 0u32 && current_lfb.add(FUNDING_INTERVAL_BLOCKS) > block.height ? current_lfb : bh);

        // getNextFundingRate
        let tmp_pool_amount: u128 = pool_amounts.get_or_use(token_out_id, 0u128);
        let intervals: u32 = (block.height).sub(current_lfb).div(FUNDING_INTERVAL_BLOCKS); 
        
        assert(funding_rate_config.contains(true));
        let fr_config: FundingRateConfig = funding_rate_config.get(true);
        let funding_rate_factor: u128 = stable_tokens.get(token_out_id) ? fr_config.stable_funding_rate_factor : fr_config.funding_rate_factor;
        let div_pa_cnst: u128 = (tmp_pool_amount == 0u128 || (current_lfb + FUNDING_INTERVAL_BLOCKS) > block.height) ? 1u128 : tmp_pool_amount;
        let next_funding_rate: u128 = (tmp_pool_amount == 0u128 || (current_lfb + FUNDING_INTERVAL_BLOCKS) > block.height) ? 0u128 :  funding_rate_factor.mul(reserve_amounts.get_or_use(token_out_id, 0u128)).mul(intervals as u128).div_wrapped(div_pa_cnst);
        
        // update cumulativeFundingRates && lastFundingTimes
        cumulative_funding_rates.set(token_out_id, cumulative_funding_rates.get_or_use(token_out_id, 0u128) + next_funding_rate);
        last_funding_blocks.set(token_out_id, new_lfb);

        // 5.2. cal usda_amount can withdraw tokenOut amount
        let max_price: u128 = Mapping::get(oracle_perps_v1.aleo/max_price, token_out_id);
        let redemption_amount: u128 = usda_amount.mul(10u128.pow(PRICE_PRECISION_DECIMAL)).div(max_price);
        assert(redemption_amount > 0u128);

        // 5.3. update usdaAmounts map: reference to 3.1.
        let current_amount: u128 = usda_amounts.get_or_use(token_out_id, 0u128);
        let new_usda_amount: u128 = usda_amount <= current_amount ? current_amount.sub_wrapped(usda_amount) : 0u128;
        usda_amounts.set(token_out_id, new_usda_amount);

        // 5.4. update poolAmounts
        assert(pool_amounts.get(token_out_id) >= redemption_amount);
        pool_amounts.set(token_out_id, pool_amounts.get(token_out_id) - redemption_amount);
        assert(pool_amounts.get(token_out_id) >= reserve_amounts.get_or_use(token_out_id, 0u128));
        
        // 5.5. burn usda_amount usda for POOL: reference 3.1.
        let aid_usda_pool: field = get_account_id(USDA_TOKEN_ID, THIS_ADDR);
        let usda_pool_amount: u128 = account.get_or_use(aid_usda_pool, 0u128);
        let usda_burn_amount: u128 = usda_pool_amount > usda_amount ?  usda_amount : usda_pool_amount;
        
        let usda_info: TokenInfo = tokens.get(USDA_TOKEN_ID);
        assert_eq(usda_info.admin, THIS_ADDR);
        tokens.set(USDA_TOKEN_ID, TokenInfo {
            name: usda_info.name,
            symbol: usda_info.symbol,
            decimals: usda_info.decimals,
            total_supply: usda_info.total_supply - usda_burn_amount,
            admin: usda_info.admin,
        });
        // update pool usda balance
        account.set(aid_usda_pool, usda_pool_amount - usda_burn_amount);

        // 5.6. cal feeBasisPoints to get swapFee
        let initial_amount: u128 = usda_amounts.get_or_use(token_out_id, 0u128);
        // tokenWeights[tokenId] * supply / totalTokenWeights
        assert(total_token_weights.contains(true));
        let ttws: u128 = total_token_weights.get(true);
        let div_ttw: u128 = ttws == 0u128 ? 1u128 : ttws;
        let target_amount: u128 = token_weights.get_or_use(token_out_id, 0u128).mul(usda_info.total_supply).div(div_ttw);
        let fee_basis_points: u128 = cal_fee_basis_points(false, initial_amount, usda_amount, target_amount, mint_burn_fee_basis_points, tax_basis_points);
        
        // 5.7 cal swap fees sf = (amount_after_fee, fee_amount)
        let sf: (u128, u128) = collect_swap_fees(redemption_amount, fee_basis_points);
        // 5.7.1. update feeReserves
        fee_reserves.set(token_out_id, fee_reserves.get_or_use(token_out_id, 0u128) + sf.1); 
    
        // 5.8. tranfer out tokenOut amount_after_fee(sf.0) for receiver
        assert(sf.0 >= min_out_amount);
        let aid_out_pool: field = get_account_id(token_out_id, THIS_ADDR);
        account.set(aid_out_pool, account.get(aid_out_pool) - sf.0);

        let aid_out_receiver: field = get_account_id(token_out_id, receiver);
        account.set(aid_out_receiver, account.get_or_use(aid_out_receiver, 0u128) + sf.0);
    }

    transition increase_position(public collateral_token_id: field, public amount_in: u128, public index_token_id: field, public size_delta: u128, public is_long: bool, public limit_price: u128){
        assert(amount_in > 0u128);
        return then finalize(self.caller, collateral_token_id, amount_in, index_token_id, size_delta, is_long, limit_price);
    }

    finalize increase_position(public caller: address, public collateral_token_id: field, public amount_in: u128, public index_token_id: field, public size_delta: u128, public is_long: bool, public limit_price: u128) {
        assert(whitelist_token_ids.contains(true));
        assert(validate_whitelist_token(collateral_token_id, whitelist_token_ids.get(true)));
        assert(validate_whitelist_token(index_token_id, whitelist_token_ids.get(true)));
        assert(tokens.contains(collateral_token_id));
        assert(tokens.contains(index_token_id));
       
        let index_max_price: u128 = Mapping::get(oracle_perps_v1.aleo/max_price, index_token_id);
        let index_min_price: u128 = Mapping::get(oracle_perps_v1.aleo/min_price, index_token_id);
        let valid_price: bool = is_long ? index_max_price <= limit_price : index_min_price >= limit_price;
        assert(valid_price);

        let aid_col_caller: field = get_account_id(collateral_token_id, caller);
        let aid_col_pool: field = get_account_id(collateral_token_id, THIS_ADDR);
        assert(account.get(aid_col_caller) >= amount_in);
        account.set(aid_col_caller, account.get(aid_col_caller) - amount_in);
        account.set(aid_col_pool, account.get_or_use(aid_col_pool, 0u128) + amount_in);

        let current_lfb: u32 = last_funding_blocks.get_or_use(collateral_token_id, 0u32);
        let bh: u32 = block.height.div(FUNDING_INTERVAL_BLOCKS).mul(FUNDING_INTERVAL_BLOCKS);
        let new_lfb: u32 = current_lfb == 0u32 ? bh : ( current_lfb != 0u32 && current_lfb.add(FUNDING_INTERVAL_BLOCKS) > block.height ? current_lfb : bh);

        let pool_amount_col: u128 = pool_amounts.get_or_use(collateral_token_id, 0u128);
        let intervals: u32 = block.height.sub(current_lfb).div(FUNDING_INTERVAL_BLOCKS); 
        
        assert(funding_rate_config.contains(true));
        let fr_config: FundingRateConfig = funding_rate_config.get(true);
        let funding_rate_factor: u128 = stable_tokens.get(collateral_token_id) ? fr_config.stable_funding_rate_factor : fr_config.funding_rate_factor;
        let div_cnst: u128 = (pool_amount_col == 0u128 || (current_lfb + FUNDING_INTERVAL_BLOCKS) > block.height) ? 1u128 : pool_amount_col;
        let next_funding_rate: u128 = (pool_amount_col == 0u128 || (current_lfb + FUNDING_INTERVAL_BLOCKS) > block.height) ? 0u128 :  funding_rate_factor.mul(reserve_amounts.get_or_use(collateral_token_id, 0u128)).mul(intervals as u128).div_wrapped(div_cnst);
        
        cumulative_funding_rates.set(collateral_token_id, cumulative_funding_rates.get_or_use(collateral_token_id, 0u128) + next_funding_rate);
        last_funding_blocks.set(collateral_token_id, new_lfb);

        let pos_key: field = get_position_key(caller, collateral_token_id, index_token_id, is_long);
        let zero_pos: Position = Position {
            size: 0u128, // in usd
            collateral: 0u128,  //in usd
            average_price: 0u128,
            entry_funding_rate: 0u128,
            reserve_amount: 0u128,
            realised_pnl: 0i128,
            last_increased_block: 0u32,
        };
        let pos: Position = positions.get_or_use(pos_key, zero_pos);

        let next_price: u128 = is_long ? index_max_price :  index_min_price;
        let delta_price: u128 = is_long ?  index_min_price : index_max_price;
        assert(min_profit_block.contains(true));
        let min_bps: u32 = block.height > pos.last_increased_block.add(min_profit_block.get(true)) ? 0u32 : min_profit_basis_points.get_or_use(index_token_id, 0u32);
        let next_average_price: u128 = get_next_average_price(pos.size, pos.average_price, delta_price, is_long, min_bps, next_price, size_delta);
        let new_average_price: u128 = (pos.size == 0u128) ? next_price : (pos.size > 0u128 && size_delta > 0u128 ? next_average_price : pos.average_price);
        
        let cumulative_fr: u128 = cumulative_funding_rates.get_or_use(collateral_token_id, 0u128);
        let margin_fees: u128 = get_position_fee(size_delta) + get_funding_fee(cumulative_fr, pos.entry_funding_rate, pos.size);

        let collateral_max_price: u128 = Mapping::get(oracle_perps_v1.aleo/max_price, collateral_token_id);
        let margin_fees_token: u128 = margin_fees.mul(10u128.pow(MAX_TOKEN_DECIMAL)).div(collateral_max_price);
        fee_reserves.set(collateral_token_id, fee_reserves.get_or_use(collateral_token_id, 0u128) + margin_fees_token);

        let collateral_min_price: u128 = Mapping::get(oracle_perps_v1.aleo/min_price, collateral_token_id);
        let collateral_delta_usd: u128 = amount_in.mul(collateral_min_price).div(10u128.pow(MAX_TOKEN_DECIMAL));

        let new_pos_collateral: u128 = pos.collateral + collateral_delta_usd - margin_fees;
        assert(new_pos_collateral >= 0u128);

        let new_entry_funding_rate: u128 = cumulative_fr;
        let new_pos_size: u128 = pos.size.add(size_delta);
        assert(new_pos_size >= new_pos_collateral);
        let reserve_delta: u128 = size_delta.mul(10u128.pow(MAX_TOKEN_DECIMAL)).div(collateral_min_price);
        let new_reserve_amount: u128 = pos.reserve_amount + reserve_delta;
        positions.set(pos_key, Position {
            size: new_pos_size, // in usd
            collateral: new_pos_collateral,  //in usd
            average_price: new_average_price,
            entry_funding_rate: new_entry_funding_rate,
            reserve_amount: new_reserve_amount,
            realised_pnl: pos.realised_pnl,
            last_increased_block: block.height,   
        });

       
        let new_pos: Position = positions.get(pos_key);
        let tp: (bool, u128) = get_delta(new_pos.size, new_pos.average_price, delta_price, is_long, min_bps);
        let new_margin_fees: u128 = get_position_fee(new_pos.size) + get_funding_fee(new_entry_funding_rate, new_pos.entry_funding_rate, new_pos.size);
        let liq_state: (u8, u128)  = validate_liquidation(new_pos_collateral, new_pos_size, tp.0, tp.1, new_margin_fees);
        assert(liq_state.0 == 0u8);
        reserve_amounts.set(collateral_token_id, reserve_amounts.get_or_use(collateral_token_id, 0u128) + reserve_delta);
        assert(reserve_amounts.get(collateral_token_id) <= pool_amounts.get(collateral_token_id));

        let now_grt_usd: u128 = guaranteed_usd.get_or_use(collateral_token_id, 0u128);
        let new_grt_usd: u128 = is_long ? now_grt_usd.add(size_delta).add(margin_fees).sub_wrapped(collateral_delta_usd) : now_grt_usd;
        let new_pool_amount: u128 = is_long ? pool_amounts.get_or_use(collateral_token_id, 0u128).add(amount_in).sub_wrapped(margin_fees_token) : pool_amounts.get_or_use(collateral_token_id, 0u128);
        guaranteed_usd.set(collateral_token_id, new_grt_usd);
        pool_amounts.set(collateral_token_id, new_pool_amount);

        let now_gs_size: u128 = global_short_sizes.get_or_use(index_token_id, 0u128);
        let now_gs_average_price: u128 = global_short_average_prices.get_or_use(index_token_id, 0u128); 

        let next_gs_average_price: u128 = (!is_long && now_gs_size != 0u128) ? get_next_global_short_average_price(now_gs_size, now_gs_average_price, next_price, size_delta) : 0u128;
        let new_gs_average_price: u128 = (!is_long && now_gs_size == 0u128) ? next_price : ((!is_long && now_gs_size != 0u128) ? next_gs_average_price : now_gs_average_price);
        global_short_average_prices.set(index_token_id, new_gs_average_price);

        let new_gs_size: u128 = is_long ? now_gs_size : now_gs_size + size_delta;
        global_short_sizes.set(index_token_id, new_gs_size);
    }

    transition decrease_position(public collateral_token_id: field, public index_token_id: field, public collateral_delta: u128, public size_delta: u128, public is_long: bool, public receiver: address, public limit_price: u128) {
        return then finalize(self.caller, collateral_token_id, index_token_id, collateral_delta, size_delta, is_long, receiver, limit_price);
    }

    finalize decrease_position(public caller: address, public collateral_token_id: field, public index_token_id: field, public collateral_delta: u128, public size_delta: u128, public is_long: bool, public receiver: address, public limit_price: u128) {
        assert(tokens.contains(collateral_token_id));
        assert(tokens.contains(index_token_id));
        assert(whitelist_token_ids.contains(true));
        assert(validate_whitelist_token(collateral_token_id, whitelist_token_ids.get(true)));
        assert(validate_whitelist_token(index_token_id, whitelist_token_ids.get(true)));

        let index_max_price: u128 = Mapping::get(oracle_perps_v1.aleo/max_price, index_token_id);
        let index_min_price: u128 = Mapping::get(oracle_perps_v1.aleo/min_price, index_token_id);
        let valid_price: bool = is_long ? index_min_price >= limit_price : index_max_price <= limit_price;
        assert(valid_price);

        let current_lfb: u32 = last_funding_blocks.get_or_use(collateral_token_id, 0u32);
        let bh: u32 = block.height.div(FUNDING_INTERVAL_BLOCKS).mul(FUNDING_INTERVAL_BLOCKS);
        let new_lfb: u32 = current_lfb == 0u32 ? bh : ( current_lfb != 0u32 && current_lfb.add(FUNDING_INTERVAL_BLOCKS) > block.height ? current_lfb : bh);
        let pool_amount_col: u128 = pool_amounts.get_or_use(collateral_token_id, 0u128);
        let intervals: u32 = block.height.sub(current_lfb).div(FUNDING_INTERVAL_BLOCKS); 
        
        assert(funding_rate_config.contains(true));
        let fr_config: FundingRateConfig = funding_rate_config.get(true);
        let funding_rate_factor: u128 = stable_tokens.get(collateral_token_id) ? fr_config.stable_funding_rate_factor : fr_config.funding_rate_factor;
        let div_pa_cnst: u128 = (pool_amount_col == 0u128 || (current_lfb + FUNDING_INTERVAL_BLOCKS) > block.height) ? 1u128 : pool_amount_col;
        let next_funding_rate: u128 = (pool_amount_col == 0u128 || (current_lfb + FUNDING_INTERVAL_BLOCKS) > block.height) ? 0u128 :  funding_rate_factor.mul(reserve_amounts.get_or_use(collateral_token_id, 0u128)).mul(intervals as u128).div_wrapped(div_pa_cnst);
        cumulative_funding_rates.set(collateral_token_id, cumulative_funding_rates.get_or_use(collateral_token_id, 0u128) + next_funding_rate);
        last_funding_blocks.set(collateral_token_id, new_lfb);
        
  
        let pos_key: field = get_position_key(caller, collateral_token_id, index_token_id, is_long);
        let pos: Position = positions.get(pos_key);
        assert(pos.size > 0u128);
        assert(pos.size >= size_delta);
        assert(pos.collateral >= collateral_delta);

        let reserve_delta: u128 = pos.reserve_amount.mul(size_delta).div(pos.size);
        let new_reserve_amount: u128 = pos.size == size_delta ? 0u128 : pos.reserve_amount.sub(reserve_delta);
        reserve_amounts.set(collateral_token_id, reserve_amounts.get(collateral_token_id) - reserve_delta);

        let cumulative_fr: u128 = cumulative_funding_rates.get(collateral_token_id);
        let margin_fees: u128 = get_position_fee(size_delta) + get_funding_fee(cumulative_fr, pos.entry_funding_rate, pos.size);

        let collateral_max_price: u128 = Mapping::get(oracle_perps_v1.aleo/max_price, collateral_token_id);
        let margin_fees_token: u128 = margin_fees.mul(10u128.pow(MAX_TOKEN_DECIMAL)).div(collateral_max_price);
        fee_reserves.set(collateral_token_id, fee_reserves.get_or_use(collateral_token_id, 0u128) + margin_fees_token);

        let delta_price: u128 = is_long ? index_min_price : index_max_price;
        assert(min_profit_block.contains(true));
        let min_bps: u32 = block.height > pos.last_increased_block.add(min_profit_block.get(true)) ? 0u32 : min_profit_basis_points.get_or_use(index_token_id, 0u32);
        let tp: (bool, u128) = get_delta(pos.size, pos.average_price, delta_price, is_long, min_bps);
        let adjusted_delta: u128 = size_delta.mul(tp.1).div(pos.size);  // delta in pnl
        let has_profit: bool = tp.0;

        
        let usd_out_receiver: u128 = has_profit ? adjusted_delta : 0u128;
        let new_realised_pnl: i128 = has_profit ? pos.realised_pnl.add(adjusted_delta as i128) : pos.realised_pnl.sub_wrapped(adjusted_delta as i128);
        let new_pos_collateral: u128 = has_profit ? pos.collateral : pos.collateral.sub_wrapped(adjusted_delta);

        usd_out_receiver += collateral_delta;
        new_pos_collateral -= collateral_delta; 

        usd_out_receiver = pos.size == size_delta ? usd_out_receiver + new_pos_collateral : usd_out_receiver;
        new_pos_collateral = pos.size == size_delta ? 0u128 : new_pos_collateral;

        let delta_pool_amount: u128 = adjusted_delta.mul(10u128.pow(MAX_TOKEN_DECIMAL)).div(collateral_max_price);
        let new_pool_amount: u128 = is_long ? pool_amount_col : (has_profit ? pool_amount_col.sub_wrapped(delta_pool_amount) : pool_amount_col.add(delta_pool_amount));
        pool_amounts.set(collateral_token_id, new_pool_amount);

        let usd_out_after_fee: u128 = (usd_out_receiver > margin_fees) ? usd_out_receiver.sub_wrapped(margin_fees) : usd_out_receiver;
        new_pos_collateral = (usd_out_receiver <= margin_fees) ? new_pos_collateral.sub_wrapped(margin_fees) : new_pos_collateral;
        let decrease_pool_amount: u128 = (usd_out_receiver <= margin_fees && is_long) ? margin_fees_token : 0u128;
        pool_amounts.set(collateral_token_id, pool_amounts.get(collateral_token_id) - decrease_pool_amount);
        assert(reserve_amounts.get_or_use(collateral_token_id, 0u128) <= pool_amounts.get(collateral_token_id));

        let new_pos_size: u128 = pos.size == size_delta ? 0u128 : pos.size - size_delta;
        let new_entry_funding_rate: u128 = pos.size == size_delta ? 0u128 : cumulative_fr;
        let new_average_price: u128 = pos.size == size_delta ? 0u128 : pos.average_price;
        let new_last_increased_block: u32 = pos.size == size_delta ? 0u32 : pos.last_increased_block;

        positions.set(pos_key, Position {
            size: new_pos_size, // in usd
            collateral: new_pos_collateral,  //in usd
            average_price: new_average_price,  // do not change or zero
            entry_funding_rate: new_entry_funding_rate,
            reserve_amount: new_reserve_amount,
            realised_pnl: new_realised_pnl,   // we do not set zero for pos.size = size_delta
            last_increased_block: new_last_increased_block,
        });

        
        let new_pos: Position = positions.get(pos_key);
        let tmp: (bool, u128) = get_delta(new_pos.size, new_pos.average_price, delta_price, is_long, min_bps);
        let new_margin_fees: u128 = get_position_fee(new_pos.size) + get_funding_fee(cumulative_fr, new_pos.entry_funding_rate, new_pos.size);
        let liq_state: (u8, u128)  = validate_liquidation(new_pos_collateral, new_pos_size, tmp.0, tmp.1, new_margin_fees);
        let expected_liq_state: u8 = pos.size == size_delta ? 0u8 : liq_state.0;
        assert(expected_liq_state == 0u8);

        let now_grted_usd: u128 = guaranteed_usd.get_or_use(collateral_token_id, 0u128);
        let new_grted_usd: u128 = (is_long && pos.size != size_delta) ? (now_grted_usd.add(pos.collateral).sub_wrapped(new_pos.collateral).sub_wrapped(size_delta)) : ((is_long && pos.size == size_delta) ? now_grted_usd.add(pos.collateral).sub_wrapped(size_delta) : now_grted_usd);
        guaranteed_usd.set(collateral_token_id, new_grted_usd);

        let now_gs_size: u128 = global_short_sizes.get_or_use(index_token_id, 0u128);
        let new_gs_size: u128 = (!is_long && size_delta > now_gs_size) ? 0u128 : ((!is_long && size_delta <= now_gs_size) ? now_gs_size.sub_wrapped(size_delta) : now_gs_size);
        global_short_sizes.set(index_token_id, new_gs_size);
    
        let now_pool_amount: u128 = pool_amounts.get(collateral_token_id);
        let usd_out_receiver_token: u128 = usd_out_receiver.mul(10u128.pow(MAX_TOKEN_DECIMAL)).div(collateral_max_price);
        let newest_pool_amount: u128 = (usd_out_receiver > 0u128 && is_long) ? now_pool_amount.sub_wrapped(usd_out_receiver_token) : now_pool_amount; 
        pool_amounts.set(collateral_token_id, newest_pool_amount);

        let amount_out_after_fee: u128 = usd_out_after_fee.mul(10u128.pow(MAX_TOKEN_DECIMAL)).div(collateral_max_price);
        
        let aid_col_receiver: field = get_account_id(collateral_token_id, receiver);
        let aid_col_pool: field = get_account_id(collateral_token_id, THIS_ADDR);
        account.set(aid_col_receiver, account.get_or_use(aid_col_receiver, 0u128) + amount_out_after_fee);
        account.set(aid_col_pool, account.get(aid_col_pool) - amount_out_after_fee);
    }

    transition init_super_admin(public admin: address) {
        assert_eq(self.caller, DEPLOYER);
        return then finalize(admin);
    }

    finalize init_super_admin(public admin: address) {
        assert(!super_admin.contains(true));
        super_admin.set(true, admin);
    }

    // only admin can change to be new_admin
    transition change_admin(public new_admin: address) {
        return then finalize(self.caller, new_admin);
    }

    finalize change_admin(public caller: address, public new_admin: address) {
        assert(super_admin.contains(true));
        assert_eq(caller, super_admin.get(true));
        super_admin.set(true, new_admin);
    }

    transition set_governor(public governor: address, public is_govr: bool) {
        return then finalize(self.caller, governor, is_govr);
    }

    finalize set_governor(public caller: address, public governor: address, public is_govr: bool) {
        assert(super_admin.contains(true));
        assert_eq(caller, super_admin.get(true));
        is_governor.set(governor, is_govr);
    }

    transition withdraw_fee(public token_id: field, public receiver: address) {
        let aid_receiver: field = get_account_id(token_id, receiver);
        let aid_pool: field = get_account_id(token_id, THIS_ADDR);
        return then finalize(self.caller, token_id, aid_receiver, aid_pool);
    }

    finalize withdraw_fee(public caller: address, public token_id: field, public aid_receiver: field, public aid_pool: field) {
        assert(super_admin.contains(true));
        assert_eq(caller, super_admin.get(true));

        let amount: u128 = fee_reserves.get_or_use(token_id, 0u128);
        assert(amount > 0u128);
        fee_reserves.set(token_id, 0u128);

        account.set(aid_receiver, account.get_or_use(aid_receiver, 0u128) + amount);
        account.set(aid_pool, account.get(aid_pool) - amount);
    }

    // =================================================== governor func =============================================================
    transition init_whitelist_token_ids(public whl_token_ids: [field; 5]) {
        return then finalize(self.caller, whl_token_ids);
    }

    finalize init_whitelist_token_ids(public caller: address, public whl_token_ids: [field; 5]) {
        assert(!whitelist_token_ids.contains(true));
        assert_eq(is_governor.get_or_use(caller, false), true);

        whitelist_token_ids.set(true, whl_token_ids);
    }

    transition set_cooldown_duration(public duration: u32) {
        return then finalize(self.caller, duration);
    }

    finalize set_cooldown_duration(public caller: address, public duration: u32) {
        assert(is_governor.get_or_use(caller, false));
        assert(duration <= MAX_COOLDOWN_DURATION);
        cooldown_duration.set(true, duration);  
    }

    transition set_aum_config(public addition: u128, public deduction: u128) {
        return then finalize(self.caller, addition, deduction);
    }

    finalize set_aum_config(public caller: address, public addition: u128, public deduction: u128) {
        assert(is_governor.get_or_use(caller, false)); 
        aum_config.set(true, AumConfig {
            addition: addition,
            deduction: deduction,
        });
    }

    transition set_funding_rate_config(public stable_frf: u128, public frf: u128) {
        return then finalize(self.caller, stable_frf, frf);
    }

    finalize set_funding_rate_config(public caller: address, public stable_frf: u128, public frf: u128) {
        assert(is_governor.get(caller));
        funding_rate_config.set(true, FundingRateConfig{
            stable_funding_rate_factor: stable_frf,
            funding_rate_factor: frf,
        });
    }

    transition set_token_config(public token_id: field, public token_weight: u128, public max_usda_amount: u128, public min_profit_bps: u32, public is_stable: bool) {
        return then finalize(self.caller, token_id, token_weight, max_usda_amount, min_profit_bps, is_stable);
    }

    finalize set_token_config(public caller: address, public token_id: field, public token_weight: u128, public max_usda_amount: u128, public min_profit_bps: u32, public is_stable: bool) {
        assert(is_governor.get(caller));
        assert(whitelist_token_ids.contains(true));
        assert(validate_whitelist_token(token_id, whitelist_token_ids.get(true)));

        // cal update totalTokenWeights
        let total_tws: u128 = total_token_weights.get_or_use(true, 0u128);
        // total_token_weights += new_token_weight - last_token_weight
        total_tws = total_tws + token_weight - token_weights.get_or_use(token_id, 0u128);

        total_token_weights.set(true, total_tws);

        
        stable_tokens.set(token_id, is_stable);
        token_weights.set(token_id, token_weight);
        max_usda_amounts.set(token_id, max_usda_amount);
        min_profit_basis_points.set(token_id, min_profit_bps);
    }

    transition set_usda_amount(public token_id: field, public amount: u128) {
        return then finalize(self.caller, token_id, amount);
    }

    finalize set_usda_amount(public caller: address, public token_id: field, public amount: u128) {
        assert(is_governor.get(caller));
        let now_usda_amount: u128 = usda_amounts.get(token_id);
        // let delta_usda_amount: u128 = amount > now_usda_amount ? amount - now_usda_amount : now_usda_amount - amount;
        let increment: bool = amount > now_usda_amount;

        usda_amounts.set(token_id, amount);

        let max_usda_amount: u128 = max_usda_amounts.get_or_use(token_id, 0u128);
        if(increment && max_usda_amount != 0u128) {
            // increasePoolAmount: check maxUsdaAmount
            // assert(usda_amounts.get(token_id) <= max_usda_amount);
            assert(amount <= max_usda_amount);
        }
    }

    transition set_min_profit_block(public min_pft_block: u32) {
        return then finalize(self.caller, min_pft_block);
    }

    finalize set_min_profit_block(public caller: address, public min_pft_block: u32) {
        assert(is_governor.get(caller));
        min_profit_block.set(true, min_pft_block);
    }
    
    // =================================================== inline =============================================================
    inline get_token_id(creator: address, salt: u128) -> field {
      return BHP256::hash_to_field(TokenId {
        base: THIS_ADDR,
        creator: creator,
        salt: salt,
      });
    } 
    
    inline get_account_id(token_id: field, user: address) -> field {
        return BHP256::hash_to_field(AccountKey {
            token_id: token_id,
            user: user,
        });
    }

    inline get_approval_key(token_id: field, approver: address, spender: address) -> field {
        return BHP256::hash_to_field(ApprovalKey {token_id: token_id, approver, spender});
    }

    inline  cal_fee_basis_points(increment: bool, initial_amount: u128, usda_amount_delta: u128, target_amount: u128, base_bps: u128, tax_bps: u128) -> u128 {        
        let fee_bps: u128 = 0u128;

        let next_amount: u128 = increment ? initial_amount.add(usda_amount_delta) : (usda_amount_delta > initial_amount ? 0u128 : initial_amount.sub_wrapped(usda_amount_delta));
        
        let initial_diff: u128 = initial_amount > target_amount ? initial_amount.sub_wrapped(target_amount) : target_amount.sub_wrapped(initial_amount);
        let next_diff: u128 = next_amount > target_amount ? next_amount.sub_wrapped(target_amount) : target_amount.sub_wrapped(next_amount);
        
        let div_ta_one: u128 = (target_amount != 0u128 && next_diff < initial_diff) ? target_amount : 1u128;

        let rebate_bps: u128 = (next_diff < initial_diff  && target_amount != 0u128)? tax_bps.mul(initial_diff).div(div_ta_one) : 0u128;
        rebate_bps = (next_diff < initial_diff && rebate_bps <= base_bps ) ? base_bps.sub_wrapped(rebate_bps) : 0u128;

        let average_diff: u128 = next_diff > initial_diff ? initial_diff.add(next_diff).div(2u128) : 0u128;
        average_diff = average_diff > target_amount ? target_amount : average_diff;
        
        let div_ta_two: u128 = target_amount == 0u128 ? 2u128 : target_amount;
        fee_bps = (!has_dynamic_fees || target_amount == 0u128) ? base_bps : (next_diff < initial_diff ? rebate_bps : base_bps.add(tax_bps.mul(average_diff).div(div_ta_two)));
        return fee_bps;

  
        // if (!has_dynamic_fees || target_amount == 0u128){
        //     return base_bps;
        // } 
        // let next_amount: u128 = 0u128;
        // if (increment == true) {  // buy
        //     next_amount = initial_amount.add(usda_amount_delta);
        // } else { // sell
        //     next_amount = usda_amount_delta > initial_amount ? 0u128 : initial_amount.sub(usda_amount_delta);
        // }

        // if (next_diff < initial_diff) {
        //     let rebate_bps: u128 = tax_bps.mul(initial_diff).div(target_amount);
        //     return rebate_bps > base_bps ? 0u128 : base_bps.sub(rebate_bps);
        // }
        
        // let average_diff: u128 = initial_diff.add(next_diff).div(2u128);
        // average_diff = average_diff > target_amount ? target_amount : average_diff;

        // return base_bps.add(tax_bps.mul(average_diff).div(target_amount));
    }

    inline collect_swap_fees(amount_in: u128, fee_basis_points: u128) -> (u128, u128) {
        let amount_after_fee: u128 = amount_in.mul(BASIS_DIVISOR.sub(fee_basis_points)).div(BASIS_DIVISOR);
        let fee_amount: u128 = amount_in.sub(amount_after_fee);
        return (amount_after_fee, fee_amount);
    }

    inline get_position_key(user: address, collateral_token_id: field, index_token_id: field, is_long: bool) -> field {
        return BHP256::hash_to_field(PositionKey {
            user: user,
            collateral_token_id: collateral_token_id,
            index_token_id: index_token_id,
            is_long: is_long,
        });
    }

    inline get_delta(pos_size: u128, average_price: u128, delta_price: u128, is_long: bool, min_bps: u32) -> (bool, u128){
        let price_delta: u128 = average_price > delta_price ? average_price.sub_wrapped(delta_price): delta_price.sub_wrapped(average_price);
        let div_aver_price: u128 = average_price == 0u128 ? 1u128 : average_price;

        let delta: u128 = average_price == 0u128 ? 0u128 : pos_size.mul(price_delta).div_wrapped(div_aver_price);

        let has_profit: bool = is_long ? delta_price > average_price : average_price > delta_price;
        
        delta = (has_profit && delta.mul(BASIS_DIVISOR) <= pos_size.mul(min_bps as u128)) ? 0u128 : delta;
        return (has_profit, delta);
    }

    inline get_next_average_price(pos_size: u128, average_price: u128, delta_price: u128, is_long: bool, min_bps: u32, next_price: u128, size_delta: u128) -> u128 {
        let tmp: (bool, u128) = get_delta(pos_size, average_price, delta_price, is_long, min_bps);
        let next_size: u128 = pos_size.add(size_delta);

        let divisor_long: u128 = tmp.0 ? next_size.add(tmp.1) : next_size.sub_wrapped(tmp.1);
        let divisor_short: u128 = tmp.0 ? next_size.sub_wrapped(tmp.1) : next_size.add(tmp.1);

        let divisor: u128 = is_long ? divisor_long : divisor_short;

        return next_price.mul(next_size).div(divisor);
    }

    inline get_position_fee(size_delta: u128) -> u128 {
        if(size_delta == 0u128) {
            return 0u128;
        }
        let pos_fee_usd: u128 = size_delta.sub(size_delta.mul(BASIS_DIVISOR.sub(margin_fee_basis_points)).div(BASIS_DIVISOR));
        return pos_fee_usd;
    }

    inline get_funding_fee(cumulative_fr: u128, pos_entry_funding_rate: u128, pos_size: u128) -> u128{
        let funding_rate: u128 = cumulative_fr.sub(pos_entry_funding_rate);
        
        let funding_fee: u128 = (pos_size == 0u128 || funding_rate == 0u128) ? 0u128 : pos_size.mul(funding_rate).div(FUNDING_RATE_PRECISION);
        return funding_fee;
    }

    inline validate_liquidation(new_pos_collateral: u128, new_pos_size: u128, has_profit: bool, delta: u128, new_margin_fees: u128) -> (u8, u128) {
        let remain_collateral: u128 = has_profit ? new_pos_collateral : (!has_profit && new_pos_collateral >= delta ? new_pos_collateral.sub_wrapped(delta) : 0u128);
        let condition_one: bool = (remain_collateral != 0u128) && remain_collateral < new_margin_fees;
        let condition_two: bool =  (remain_collateral != 0u128) &&  remain_collateral >= new_margin_fees && remain_collateral < new_margin_fees + liquidation_fee_usd;
        let condition_three: bool = (remain_collateral != 0u128) && remain_collateral >= new_margin_fees + liquidation_fee_usd && remain_collateral * MAX_LEVERAGE < new_pos_size * BASIS_DIVISOR;

        let liq_state: u8 = (remain_collateral == 0u128 || condition_one || condition_two) ? 1u8 : (condition_three ? 2u8 : 0u8);

        let fee: u128 = condition_one ? remain_collateral : new_margin_fees;

        return (liq_state, fee);
    }

    inline get_next_global_short_average_price(gs_size: u128, gs_average_price: u128, next_price: u128, size_delta: u128) -> u128{
        let price_delta: u128 = gs_average_price > next_price ? gs_average_price.sub_wrapped(next_price) : next_price.sub_wrapped(gs_average_price);

        let div_gs_aver_price: u128 = gs_average_price == 0u128 ? 1u128 : gs_average_price;

        let delta: u128 = gs_average_price == 0u128 ? 0u128 : gs_size.mul(price_delta).div(div_gs_aver_price);
        
        let has_profit: bool = gs_average_price > next_price;  

        let next_size: u128 = gs_size.add(size_delta);
        let divisor: u128 = has_profit ? next_size.sub(delta) : next_size.add(delta);
        return next_price.mul(next_size).div(divisor);
    }

    inline validate_whitelist_token(token_id: field, whl_token_ids: [field; 5]) -> bool{
        let res: bool = whl_token_ids[0u8] == token_id || whl_token_ids[1u8] == token_id || whl_token_ids[2u8] == token_id || whl_token_ids[3u8] == token_id || whl_token_ids[4u8] == token_id;
        return res;
    }
}