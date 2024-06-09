from web3 import Web3


class contractInterface:
    def __init__(self, rpc_url, private_key, contract_address, contract_abi) -> None:
        # Connect to the Ethereum network
        self.web3 = web3 = Web3(Web3.HTTPProvider(rpc_url))
        # Verify the connection
        if not web3.is_connected():
            raise Exception("Failed to connect to Ethereum network")

        # Create the contract instance
        self.contract = web3.eth.contract(
            address=contract_address, abi=contract_abi)

        # Set up account to interact with the contract
        self.private_key = private_key
        self.account = account = web3.eth.account.from_key(private_key)
        self.address = account.address

    def send_transaction(self, function_call):
        nonce = self.web3.eth.get_transaction_count(self.address)
        print(nonce)
        txn = function_call.build_transaction({
            'chainId': 84532,  # Mainnet chain ID
            'gas': 500000,
            'gasPrice': self.web3.to_wei('0.1', 'gwei'),
            'nonce': nonce,
        })
        signed_txn = self.web3.eth.account.sign_transaction(
            txn, private_key=self.private_key)
        tx_hash = self.web3.eth.send_raw_transaction(signed_txn.rawTransaction)
        tx_receipt = self.web3.eth.wait_for_transaction_receipt(tx_hash)
        return tx_receipt

    # Function to read a variable from the contract

    def read_contract_variable(self, variable_name):
        contract_function = getattr(self.contract.functions, variable_name)
        result = contract_function().call()
        return result
