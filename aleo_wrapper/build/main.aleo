import credits.aleo;
import oracle_perps_v1.aleo;
import pool_perps_v1.aleo;
program aleo_wrapper_perps_v1.aleo;


struct TokenId:
    base as address;
    creator as address;
    salt as u128;


function init_wrapper:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as u8.public;
    call pool_perps_v1.aleo/create_token r0 r1 r2 0u128 aleo1yn57ctczge8htddah42wggt587wstwut5fr72mpga96xzwejncpsn6skqh 0u128 into r3;
    async init_wrapper r3 into r4;
    output r4 as aleo_wrapper_perps_v1.aleo/init_wrapper.future;

finalize init_wrapper:
    input r0 as pool_perps_v1.aleo/create_token.future;
    await r0;




function wrap_private_to_public:
    input r0 as credits.aleo/credits.record;
    input r1 as u64.public;
    input r2 as address.public;
    call credits.aleo/transfer_private_to_public r0 aleo1yn57ctczge8htddah42wggt587wstwut5fr72mpga96xzwejncpsn6skqh r1 into r3 r4;
    cast aleo10x6sqsc8d353upatyuelqa4864leds5kuk3xqmgj7gxzfhux6vxsrne96y aleo1yn57ctczge8htddah42wggt587wstwut5fr72mpga96xzwejncpsn6skqh 0u128 into r5 as TokenId;
    hash.bhp256 r5 into r6 as field;
    cast r1 into r7 as u128;
    call pool_perps_v1.aleo/mint r6 r2 r7 into r8;
    async wrap_private_to_public r4 r8 into r9;
    output r3 as credits.aleo/credits.record;
    output r9 as aleo_wrapper_perps_v1.aleo/wrap_private_to_public.future;

finalize wrap_private_to_public:
    input r0 as credits.aleo/transfer_private_to_public.future;
    input r1 as pool_perps_v1.aleo/mint.future;
    await r0;
    await r1;


function unwrap_public_to_private:
    input r0 as u64.public;
    input r1 as address.private;
    cast aleo10x6sqsc8d353upatyuelqa4864leds5kuk3xqmgj7gxzfhux6vxsrne96y aleo1yn57ctczge8htddah42wggt587wstwut5fr72mpga96xzwejncpsn6skqh 0u128 into r2 as TokenId;
    hash.bhp256 r2 into r3 as field;
    cast r0 into r4 as u128;
    call pool_perps_v1.aleo/burn_from r3 self.caller r4 into r5;
    call credits.aleo/transfer_public_to_private r1 r0 into r6 r7;
    async unwrap_public_to_private r5 r7 into r8;
    output r6 as credits.aleo/credits.record;
    output r8 as aleo_wrapper_perps_v1.aleo/unwrap_public_to_private.future;

finalize unwrap_public_to_private:
    input r0 as pool_perps_v1.aleo/burn_from.future;
    input r1 as credits.aleo/transfer_public_to_private.future;
    await r0;
    await r1;
