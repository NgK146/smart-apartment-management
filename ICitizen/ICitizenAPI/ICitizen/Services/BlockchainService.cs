using Microsoft.Extensions.Configuration;
using Nethereum.Web3;
using Nethereum.Web3.Accounts;
using Nethereum.Contracts;

namespace ICitizen.Services;

/// <summary>
/// Service để ghi log lên Blockchain (Ganache) thông qua Smart Contract.
/// Cấu hình được đọc từ appsettings.json
/// </summary>
public sealed class BlockchainService
{
    private readonly Web3 _web3;
    private readonly Account _account;
    private readonly string _contractAddress;
    
    // ABI rút gọn của SmartHomeLog
    private const string Abi = @"[{""anonymous"":false,""inputs"":[{""indexed"":false,""internalType"":""string"",""name"":""device"",""type"":""string""},{""indexed"":false,""internalType"":""string"",""name"":""action"",""type"":""string""},{""indexed"":false,""internalType"":""uint256"",""name"":""timestamp"",""type"":""uint256""}],""name"":""ActionLogged"",""type"":""event""},{""inputs"":[{""internalType"":""string"",""name"":""_device"",""type"":""string""},{""internalType"":""string"",""name"":""_action"",""type"":""string""}],""name"":""logAction"",""outputs"":[],""stateMutability"":""nonpayable"",""type"":""function""}]";

    public BlockchainService(IConfiguration configuration)
    {
        var rpcUrl = configuration["Blockchain:RpcUrl"] ?? "http://127.0.0.1:7545";
        var privateKey = configuration["Blockchain:PrivateKey"] ?? throw new ArgumentNullException("Blockchain:PrivateKey is required");
        _contractAddress = configuration["Blockchain:ContractAddress"] ?? throw new ArgumentNullException("Blockchain:ContractAddress is required");
        
        _account = new Account(privateKey);
        _web3 = new Web3(_account, rpcUrl);
    }

    public async Task<string> WriteLogAsync(string device, string action)
    {
        try
        {
            var contract = _web3.Eth.GetContract(Abi, _contractAddress);
            var logFunction = contract.GetFunction("logAction");

            // Gửi giao dịch lên Blockchain
            var receipt = await logFunction.SendTransactionAndWaitForReceiptAsync(
                _account.Address, 
                new Nethereum.Hex.HexTypes.HexBigInteger(300000), 
                null, null, device, action
            );

            return receipt.TransactionHash; // Trả về mã Hash chứng thực
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Blockchain Error] {ex.Message}");
            return $"Lỗi Blockchain: {ex.Message}";
        }
    }
}
