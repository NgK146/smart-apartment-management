using Nethereum.Web3;
using Nethereum.Web3.Accounts;
using Nethereum.Contracts;
using Nethereum.Hex.HexTypes;

namespace ICitizen.Services;

/// <summary>
/// Service ghi lại payments lên Blockchain để đảm bảo minh bạch
/// </summary>
public class PaymentBlockchainService
{
    private readonly Web3 _web3;
    private readonly string _contractAddress;
    private readonly ILogger<PaymentBlockchainService> _logger;
    
    // ABI của PaymentRegistry contract
    private const string ContractABI = @"[{""inputs"":[{""internalType"":""string"",""name"":""_invoiceId"",""type"":""string""},{""internalType"":""string"",""name"":""_apartmentId"",""type"":""string""},{""internalType"":""address"",""name"":""_payer"",""type"":""address""},{""internalType"":""uint256"",""name"":""_amount"",""type"":""uint256""},{""internalType"":""string"",""name"":""_paymentMethod"",""type"":""string""},{""internalType"":""string"",""name"":""_status"",""type"":""string""}],""name"":""recordPayment"",""outputs"":[],""stateMutability"":""nonpayable"",""type"":""function""},{""inputs"":[{""internalType"":""string"",""name"":""_invoiceId"",""type"":""string""}],""name"":""getPayment"",""outputs"":[{""internalType"":""string"",""name"":""invoiceId"",""type"":""string""},{""internalType"":""string"",""name"":""apartmentId"",""type"":""string""},{""internalType"":""address"",""name"":""payer"",""type"":""address""},{""internalType"":""uint256"",""name"":""amount"",""type"":""uint256""},{""internalType"":""uint256"",""name"":""timestamp"",""type"":""uint256""},{""internalType"":""string"",""name"":""paymentMethod"",""type"":""string""},{""internalType"":""string"",""name"":""status"",""type"":""string""}],""stateMutability"":""view"",""type"":""function""}]";
    
    public PaymentBlockchainService(
        IConfiguration configuration,
        ILogger<PaymentBlockchainService> logger)
    {
        _logger = logger;
        
        var rpcUrl = configuration["Blockchain:RpcUrl"] ?? "http://127.0.0.1:7545";
        var privateKey = configuration["Blockchain:PrivateKey"] 
            ?? throw new ArgumentNullException("Blockchain:PrivateKey required");
        _contractAddress = configuration["Blockchain:PaymentContractAddress"] 
            ?? throw new ArgumentNullException("Blockchain:PaymentContractAddress required");
        
        var account = new Account(privateKey);
        _web3 = new Web3(account, rpcUrl);
        
        _logger.LogInformation("PaymentBlockchain initialized: {Contract}", _contractAddress);
    }
    
    /// <summary>
    /// Ghi payment lên blockchain
    /// </summary>
    public async Task<string> RecordPaymentAsync(
        string invoiceId,
        string apartmentId,
        decimal amountVND,
        string paymentMethod,
        string status = "SUCCESS")
    {
        try
        {
            var contract = _web3.Eth.GetContract(ContractABI, _contractAddress);
            var function = contract.GetFunction("recordPayment");
            
            // Địa chỉ ví cư dân (có thể lấy từ user profile)
            var payerAddress = "0x0000000000000000000000000000000000000001";
            
            // Convert VND to Wei (multiply by 10^18)
            var amountWei = Web3.Convert.ToWei(amountVND);
            
            _logger.LogInformation(
                "Recording payment: Invoice={Invoice}, Amount={Amount}VND",
                invoiceId, amountVND);
            
            var receipt = await function.SendTransactionAndWaitForReceiptAsync(
                from: _web3.TransactionManager.Account.Address,
                gas: new HexBigInteger(300000),
                value: null,
                receiptRequestCancellationToken: null,
                invoiceId,
                apartmentId,
                payerAddress,
                amountWei,
                paymentMethod,
                status
            );
            
            _logger.LogInformation(
                "Payment recorded on blockchain: TxHash={TxHash}",
                receipt.TransactionHash);
            
            return receipt.TransactionHash;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to record payment on blockchain");
            throw new Exception($"Blockchain error: {ex.Message}", ex);
        }
    }
    
    /// <summary>
    /// Lấy thông tin payment từ blockchain
    /// </summary>
    public async Task<PaymentBlockchainInfo?> GetPaymentAsync(string invoiceId)
    {
        try
        {
            var contract = _web3.Eth.GetContract(ContractABI, _contractAddress);
            var function = contract.GetFunction("getPayment");
            
            var result = await function.CallDeserializingToObjectAsync<PaymentBlockchainInfo>(
                invoiceId
            );
            
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to get payment from blockchain");
            return null;
        }
    }
}

public class PaymentBlockchainInfo
{
    public string InvoiceId { get; set; } = string.Empty;
    public string ApartmentId { get; set; } = string.Empty;
    public string Payer { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public long Timestamp { get; set; }
    public string PaymentMethod { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
}
