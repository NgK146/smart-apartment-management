# Hướng dẫn sử dụng Payment Gateway

## Thông tin xác thực

Payment Gateway đã được cấu hình với các thông tin sau:
- **Client ID**: `5ecc19df-bc6a-4fa6-b9c7-f2731a212437`
- **API Key**: `857525cb-f356-47d4-8d34-6ac48aa1d621`
- **Checksum Key**: `37531a5f183f60d948abee2645e11e38efa1f9496818559e79009a403b97ff54`

## Cấu trúc Service

### PaymentGatewayService

Service chính để tích hợp với Payment Gateway, nằm tại:
`lib/core/services/payment_gateway_service.dart`

### PaymentService

Service đã được mở rộng với các phương thức mới để sử dụng Payment Gateway:
`lib/core/services/payment_service.dart`

## Cách sử dụng

### 1. Tạo yêu cầu thanh toán

```dart
import '../../core/api_client.dart';
import '../../core/services/payment_service.dart';

final paymentService = PaymentService(api.dio);

// Tạo yêu cầu thanh toán
final result = await paymentService.createGatewayPayment(
  amount: 100000, // Số tiền (VND)
  orderId: 'INV_12345', // Mã đơn hàng/hóa đơn
  orderDescription: 'Thanh toán hóa đơn tháng 12/2024',
  returnUrl: 'https://yourapp.com/payment/success',
  cancelUrl: 'https://yourapp.com/payment/cancel',
);
```

### 2. Tạo QR Code thanh toán

```dart
final result = await paymentService.createGatewayQRCode(
  amount: 100000,
  orderId: 'INV_12345',
  orderDescription: 'Nạp tiền vào ví',
);

// Lấy QR code data
final qrCode = result['qrCode'] ?? result['qrData'];
```

### 3. Kiểm tra trạng thái thanh toán

```dart
final status = await paymentService.checkGatewayPaymentStatus(
  'transaction_id_from_gateway'
);

// Kiểm tra trạng thái
if (status['status'] == 'success') {
  // Thanh toán thành công
}
```

### 4. Xác thực callback từ Payment Gateway

```dart
// Khi nhận callback từ payment gateway
final callbackData = {
  'transactionId': '...',
  'amount': 100000,
  'status': 'success',
  'checksum': '...',
};

final isValid = paymentService.verifyGatewayCallback(callbackData);
if (isValid) {
  // Xử lý callback hợp lệ
}
```

### 5. Hoàn tiền (Refund)

```dart
final result = await paymentService.refundGatewayPayment(
  transactionId: 'original_transaction_id',
  amount: 50000, // Số tiền hoàn (null = hoàn toàn bộ)
  reason: 'Khách hàng yêu cầu hoàn tiền',
);
```

## Tích hợp vào UI

### Sử dụng trong Digital Payment Page

Payment Gateway đã được tích hợp vào `DigitalPaymentPage`. Khi người dùng nhấn nút "Nạp tiền", hệ thống sẽ:

1. Hiển thị dialog nhập số tiền
2. Tạo yêu cầu thanh toán qua Payment Gateway
3. Hiển thị QR code để người dùng quét và thanh toán

### Ví dụ trong code

```dart
// Trong _TopUpDialog
final result = await widget.paymentService.createGatewayQRCode(
  amount: amount,
  orderId: orderId,
  orderDescription: 'Nạp tiền vào ví',
);

// Hiển thị QR code
if (result.containsKey('qrCode')) {
  showDialog(
    context: context,
    builder: (context) => QRCodeDialog(
      qrCode: result['qrCode'],
    ),
  );
}
```

## Bảo mật

### Checksum Generation

Mỗi request đều được ký bằng HMAC-SHA256 với Checksum Key để đảm bảo tính toàn vẹn dữ liệu.

### Xác thực Request

- **API Key**: Được gửi trong header `Authorization: Bearer {apiKey}`
- **Client ID**: Được gửi trong header `X-Client-Id: {clientId}`
- **Checksum**: Được tính từ tất cả các tham số và gửi kèm trong body

## Lưu ý

1. **API Endpoint**: Hiện tại service đang gọi các endpoint:
   - `/api/PaymentGateway/create-payment` - Tạo thanh toán
   - `/api/PaymentGateway/check-status` - Kiểm tra trạng thái
   - `/api/PaymentGateway/refund` - Hoàn tiền

   Bạn cần đảm bảo backend đã implement các endpoint này hoặc cập nhật URL trong `PaymentGatewayService` cho phù hợp.

2. **Callback URL**: Cần cấu hình callback URL trên payment gateway để nhận thông báo khi thanh toán hoàn tất.

3. **Error Handling**: Luôn xử lý exception khi gọi các phương thức payment gateway.

## Testing

Để test payment gateway:

1. Sử dụng số tiền nhỏ (ví dụ: 10,000 VND)
2. Kiểm tra logs để xem request/response
3. Verify checksum được tạo đúng
4. Test các trường hợp: thành công, thất bại, timeout

## Troubleshooting

### Lỗi "Invalid checksum"
- Kiểm tra Checksum Key có đúng không
- Đảm bảo dữ liệu được sắp xếp đúng thứ tự khi tạo checksum

### Lỗi "Unauthorized"
- Kiểm tra API Key và Client ID
- Đảm bảo headers được gửi đúng format

### Lỗi "Invalid amount"
- Kiểm tra số tiền >= 10,000 VND (hoặc theo quy định của gateway)
- Đảm bảo amount là số nguyên (không có phần thập phân)

