import oracle_perps_v1.aleo;
import pool_perps_v1.aleo;
import eth_perps_v1.aleo;
program eth_wrapper_perps_v1.aleo;

struct TokenId:
    base as address;
    creator as address;
    salt as u128;


function init_wrapper:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as u8.public;
    call pool_perps_v1.aleo/create_token r0 r1 r2 0u128 aleo1h2s5xvnudzh5hzahvd2x93qf9y2fjp36r4ssgv6tfluqatyelg9q2v8j6k 1u128 into r3;
    async init_wrapper r3 into r4;
    output r4 as eth_wrapper_perps_v1.aleo/init_wrapper.future;

finalize init_wrapper:
    input r0 as pool_perps_v1.aleo/create_token.future;
    await r0;




function wrap_public:
    input r0 as u128.public;
    input r1 as address.public;
    call eth_perps_v1.aleo/transfer_from_public self.caller aleo1h2s5xvnudzh5hzahvd2x93qf9y2fjp36r4ssgv6tfluqatyelg9q2v8j6k r0 into r2;
    cast aleo10x6sqsc8d353upatyuelqa4864leds5kuk3xqmgj7gxzfhux6vxsrne96y aleo1h2s5xvnudzh5hzahvd2x93qf9y2fjp36r4ssgv6tfluqatyelg9q2v8j6k 1u128 into r3 as TokenId;
    hash.bhp256 r3 into r4 as field;
    call pool_perps_v1.aleo/mint r4 r1 r0 into r5;
    async wrap_public r2 r5 into r6;
    output r6 as eth_wrapper_perps_v1.aleo/wrap_public.future;

finalize wrap_public:
    input r0 as eth_perps_v1.aleo/transfer_from_public.future;
    input r1 as pool_perps_v1.aleo/mint.future;
    await r0;
    await r1;


function unwrap_public:
    input r0 as u128.public;
    input r1 as address.public;
    cast aleo10x6sqsc8d353upatyuelqa4864leds5kuk3xqmgj7gxzfhux6vxsrne96y aleo1h2s5xvnudzh5hzahvd2x93qf9y2fjp36r4ssgv6tfluqatyelg9q2v8j6k 1u128 into r2 as TokenId;
    hash.bhp256 r2 into r3 as field;
    call pool_perps_v1.aleo/burn_from r3 self.caller r0 into r4;
    call eth_perps_v1.aleo/transfer_public r1 r0 into r5;
    async unwrap_public r4 r5 into r6;
    output r6 as eth_wrapper_perps_v1.aleo/unwrap_public.future;

finalize unwrap_public:
    input r0 as pool_perps_v1.aleo/burn_from.future;
    input r1 as eth_perps_v1.aleo/transfer_public.future;
    await r0;
    await r1;
