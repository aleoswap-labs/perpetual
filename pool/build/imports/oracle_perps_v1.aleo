program oracle_perps_v1.aleo;



mapping max_price:
	key as field.public;
	value as u128.public;


mapping min_price:
	key as field.public;
	value as u128.public;

function set_max_price:
    input r0 as field.public;
    input r1 as u128.public;
    async set_max_price r0 r1 into r2;
    output r2 as oracle_perps_v1.aleo/set_max_price.future;

finalize set_max_price:
    input r0 as field.public;
    input r1 as u128.public;
    set r1 into max_price[r0];


function set_min_price:
    input r0 as field.public;
    input r1 as u128.public;
    async set_min_price r0 r1 into r2;
    output r2 as oracle_perps_v1.aleo/set_min_price.future;

finalize set_min_price:
    input r0 as field.public;
    input r1 as u128.public;
    set r1 into min_price[r0];
