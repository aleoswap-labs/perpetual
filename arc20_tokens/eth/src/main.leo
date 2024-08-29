program eth_perps_v1.aleo {
    // for local testnet: aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px
    // const DEPLOYER: address = aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px;
    const DEPLOYER: address = aleo1cnm2w8qlrhahlsmalph7t0jh3adny5pj4m38jgpcdzt2reqthurqaen3dp;
    const MAX_U128: u128 = 340282366920938463463374607431768211455u128;

    mapping account: address => u128;
    // ApprovalKey => amount
    mapping approvals: field => u128;
    mapping metadata: bool => MetaData;


    struct MetaData {
        name: field,
        symbol: field,
        decimals: u8,
        total_supply: u128,
    }

    // Mapping key of approvals
    struct ApprovalKeyData {
        approver: address,
        spender: address,
    }

    // ==================================== Init ================================
    transition init(public name: field, public symbol: field, public decimals: u8, public init_supply: u128, public banker: address) {
        assert_eq(self.caller, DEPLOYER);
        return then finalize(name, symbol, decimals, init_supply, banker);
    }

    finalize init(public name: field, public symbol: field, public decimals: u8, public init_supply: u128, public banker: address) {
        assert(!metadata.contains(true));
        metadata.set(true, MetaData {
            name: name,
            symbol: symbol,
            decimals: decimals,
            total_supply: init_supply,
        });
        account.set(banker, init_supply);
    }

    // ================================ Transfer ================================

    // Transfer public: transfer self.caller amount to
    transition transfer_public(public to: address, public amount: u128) {
        return then finalize(self.caller, to, amount);
    }

    finalize transfer_public(public from: address, public to: address, public amount: u128) {
        let bal_from: u128 = account.get(from);
        account.set(from, bal_from - amount);

        let bal_to: u128 = account.get_or_use(to, 0u128);
        account.set(to, bal_to + amount);
    }

    // ================================ Approval ================================

    // Increase the amount of the approval
    transition approve_public(public spender: address, public amount: u128) {
        let key: field = get_approval_key(self.caller, spender);
        return then finalize(key, amount);
    }

    finalize approve_public(public key: field, public amount: u128) {
        let pre_approval: u128 = approvals.get_or_use(key, 0u128);
        let new_approval: u128 = amount < MAX_U128 - pre_approval ? pre_approval.add_wrapped(amount) : MAX_U128;
        approvals.set(key, new_approval);
    }

    // Decrease the amount of the approval
    transition unapprove_public(public spender: address, public amount: u128) {
        let key: field = get_approval_key(self.caller, spender);
        return then finalize(key, amount);
    }

    finalize unapprove_public(public key: field, public amount: u128) {
        let pre_approval: u128 = approvals.get(key);
        let new_approval: u128 = pre_approval > amount ? pre_approval.sub_wrapped(amount) : 0u128;
        approvals.set(key, new_approval);
    }

    // Transfer public tokens from other accounts.
    transition transfer_from_public(
        public from: address,
        public to: address,
        public amount: u128
     ) {
        let key: field = get_approval_key(from, self.caller);
        return then finalize(key, from, to, amount);
    }

    finalize transfer_from_public(
        public key: field,
        public from: address,
        public to: address,
        public amount: u128
    ) {
        approvals.set(key, approvals.get(key) - amount);

        let bal_from: u128 = account.get(from);
        account.set(from, bal_from - amount);

        let bal_to: u128 = account.get_or_use(to, 0u128);
        account.set(to, bal_to + amount);
    }

    // ================================ Utils ================================

    // Build a key of the mapping `approvals`
    inline get_approval_key(approver: address, spender: address) -> field {
        return BHP256::hash_to_field(ApprovalKeyData {approver, spender});
    }

    // =============================== only for test ==================================
    transition mint_test(public amount: u128) {
        return then finalize(self.caller, amount);
    }

    finalize mint_test(public caller: address, public amount: u128) {
        assert(metadata.contains(true));
        let info: MetaData = metadata.get(true);
        
        metadata.set(true, MetaData {
            name: info.name,
            symbol: info.symbol,
            decimals: info.decimals,
            total_supply: info.total_supply + amount,
        });

        account.set(caller, account.get_or_use(caller, 0u128) + amount);

    }
}
