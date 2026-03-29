# Quick Start - Payment Blockchain

## 1️⃣ Setup Ganache
1. Mở Ganache desktop app
2. Click "Quickstart"
3. Copy private key của account đầu tiên

## 2️⃣ Deploy Smart Contract

```bash
cd d:\icitizen_app\blockchain
npm install
truffle compile
truffle migrate
```

**Lưu lại Contract Address!**

## 3️⃣ Update appsettings.json

```json
"Blockchain": {
  "RpcUrl": "http://127.0.0.1:7545",
  "PaymentContractAddress": "PASTE_CONTRACT_ADDRESS_HERE",
  "PrivateKey": "PASTE_PRIVATE_KEY_HERE"
}
```

## 4️⃣ Run Migration

```bash
cd d:\icitizen_app\ICitizen\ICitizenAPI\ICitizen
dotnet ef database update
```

## 5️⃣ Test!

1. Start API: `dotnet run`
2. Thanh toán invoice qua PayOS
3. Check console log → "🔗 Blockchain recorded: 0x..."
4. Mở Ganache → See transaction!

**Done!** 🎉
