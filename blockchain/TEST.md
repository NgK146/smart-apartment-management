# Test Blockchain Payment

## Bước 1: Kiểm tra Ganache đang chạy

Mở Ganache → Quickstart → Xem RPC Server: `http://127.0.0.1:7545`

## Bước 2: Deploy Smart Contract (nếu chưa)

```bash
cd d:\icitizen_app\blockchain
npm install
truffle compile
truffle migrate
```

**Lưu lại Contract Address!**

## Bước 3: Update appsettings.json

Thêm vào `appsettings.json`:

```json
{
  "Blockchain": {
    "RpcUrl": "http://127.0.0.1:7545",
    "PaymentContractAddress": "0xYOUR_CONTRACT_ADDRESS",
    "PrivateKey": "0xYOUR_PRIVATE_KEY_FROM_GANACHE"
  }
}
```

## Bước 4: Run Migration

```bash
cd d:\icitizen_app\ICitizen\ICitizenAPI\ICitizen
dotnet ef database update
```

## Bước 5: Test Payment!

1. Start API: `dotnet run`
2. Mở app Flutter
3. Thanh toán hóa đơn qua PayOS
4. **Check console log** → Sẽ thấy:
   ```
   ✅ Updated invoice {id} status to Paid
   🔗 Blockchain recorded: 0x123abc...
   ✅ Updated payment {id} status to Success
   ```
5. **Mở Ganache** → Tab "Transactions" → Thấy transaction mới!

## Xem Blockchain Proof trong Database

```sql
SELECT Id, BlockchainTxHash, Amount, Status 
FROM Payments 
WHERE BlockchainTxHash IS NOT NULL
```

**Perfect!** Mỗi lần thanh toán = 1 proof blockchain! 🔗✨
