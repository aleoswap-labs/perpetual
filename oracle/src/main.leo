program oracle_perps_v1.aleo {
    // tokenId -> price
    mapping max_price: field => u128;
    mapping min_price: field => u128;

    // only for test
    transition set_max_price (public token_id: field, public price: u128){
        return then finalize(token_id, price);
    }

    finalize set_max_price (public token_id: field, public price: u128) {
        max_price.set(token_id, price);
    }

    transition set_min_price (public token_id: field, public price: u128){
        return then finalize(token_id, price);
    }

    finalize set_min_price (public token_id: field, public price: u128) {
        min_price.set(token_id, price);
    }

}


