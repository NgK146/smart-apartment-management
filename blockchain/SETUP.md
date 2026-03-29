# Blockchain Payment Setup Guide

## 1. Cài đặt Ganache

Download Ganache: https://trufflesuite.com/ganache/
- Mở Ganache
- Click "Quickstart"
- Lưu lại RPC SERVER: http://127.0.0.1:7545

## 2. Deploy Smart Contract

```bash
cd d:\icitizen_app\blockchain
npm install
truffle compile
truffle migrate
```

**Sau khi deploy, copy:**
- Contract Address (VD: 0x...)
- Private Key từ account đầu tiên trong Ganache

## 3. Update appsettings.json

```json
{
  "Blockchain": {
    "RpcUrl": "http://127.0.0.1:7545",
    "PaymentContractAddress": "0xYOUR_CONTRACT_ADDRESS_HERE",
    "PrivateKey": "0xYOUR_PRIVATE_KEY_HERE"
  }
}
```

## 4. Add Migration

```bash
cd d:\icitizen_app\ICitizen\ICitizenAPI\ICitizen
dotnet ef migrations add AddBlockchainToPayment
dotnet ef database update
```

## 5. Register Service

File: `Program.cs`
```csharp
builder.Services.AddSingleton<PaymentBlockchainService>();
```

## 6. Test

```bash
# Start API
dotnet run

# Thanh toán qua PayOS
# => Blockchain tự động ghi log!
```

Ready! 🚀
