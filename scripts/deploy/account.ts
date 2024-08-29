import { Account, AleoKeyProvider, AleoNetworkClient, NetworkRecordProvider, ProgramManager } from '@aleohq/sdk';

async function deploy() {
    let privateKeyLocal: string = "APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH";
    const account = new Account({privateKey: privateKeyLocal});
    console.log(account.toString());

    // // Create a record provider that will be used to find records and transaction data for Aleo programs
    const networkClient = new AleoNetworkClient("http://localhost:3030");
    const keyProvider = new AleoKeyProvider();
    const recordProvider = new NetworkRecordProvider(account, networkClient);

    // Initialize a program manager to talk to the Aleo network with the configured key and record providers
    const programManager = new ProgramManager("http://localhost:3030", keyProvider, recordProvider);
    programManager.setAccount(account);
    console.log(programManager);



    // Define an Aleo program to deploy
    const program = "program hello_test.aleo;\n\nfunction hello:\n    input r0 as u32.public;\n    input r1 as u32.private;\n    add r0 r1 into r2;\n    output r2 as u32.private;\n";

    // Define a fee to pay to deploy the program
    const fee = 3.5; // 1.8 Aleo credits

    // Deploy the program to the Aleo network
    const tx_id = await programManager.deploy(program, fee, false);
    console.log(tx_id);

    // // Verify the transaction was successful
    // const transaction = (await networkClient.getTransaction(tx_id));
    // console.log(transaction);
}

Promise.resolve(deploy())
