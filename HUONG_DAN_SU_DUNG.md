# Hướng Dẫn Sử Dụng Module Hóa Đơn và Module Gửi Xe

## Mục Lục
1. [Module Hóa Đơn](#module-hóa-đơn)
2. [Module Gửi Xe](#module-gửi-xe)

---

## Module Hóa Đơn

### Tổng Quan
Module Hóa Đơn cho phép cư dân xem, quản lý và thanh toán các hóa đơn dịch vụ căn hộ. Module này tích hợp với hệ thống thanh toán VNPAY để xử lý thanh toán trực tuyến.

### Các Tính Năng Chính

1. **Xem danh sách hóa đơn**
   - Hiển thị tất cả hóa đơn của cư dân
   - Phân trang tự động (20 hóa đơn/trang)
   - Kéo xuống để tải thêm (infinite scroll)
   - Kéo xuống để làm mới (pull to refresh)

2. **Xem chi tiết hóa đơn**
   - Thông tin hóa đơn: kỳ thanh toán, hạn thanh toán, căn hộ
   - Danh sách chi tiết các khoản phí
   - Tổng số tiền cần thanh toán
   - Trạng thái hóa đơn (Chưa thanh toán, Đã thanh toán, Thanh toán một phần, Quá hạn, Đã hủy)

3. **Thanh toán hóa đơn**
   - Tạo link thanh toán VNPAY
   - Mở trình duyệt để thanh toán
   - Tự động cập nhật trạng thái sau thanh toán

### Cấu Trúc File

```
lib/features/billing/
├── invoices_page.dart          # Trang danh sách hóa đơn
├── invoice_detail_page.dart    # Trang chi tiết hóa đơn
├── invoice_model.dart          # Model dữ liệu hóa đơn
├── invoices_service.dart       # Service xử lý API
├── billing_service.dart        # Service bổ sung
├── fee_definition_model.dart   # Model định nghĩa phí
├── fee_definitions_service.dart # Service quản lý phí
├── meter_reading_model.dart    # Model chỉ số công tơ
└── payment_transaction_model.dart # Model giao dịch thanh toán
```

### Hướng Dẫn Sử Dụng

#### 1. Xem Danh Sách Hóa Đơn

**File:** `lib/features/billing/invoices_page.dart`

**Cách sử dụng:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => InvoicesPage()),
);
```

**Tính năng:**
- Tự động tải hóa đơn khi mở trang
- Hiển thị thông tin: tháng/năm, trạng thái, hạn thanh toán, tổng tiền
- Màu sắc trạng thái:
  - 🟠 Chưa thanh toán (Unpaid) - Màu cam
  - 🟢 Đã thanh toán (Paid) - Màu xanh lá
  - 🔵 Thanh toán một phần (PartiallyPaid) - Màu xanh dương
  - 🔴 Quá hạn (Overdue) - Màu đỏ
  - ⚫ Đã hủy (Cancelled) - Màu xám
- Cảnh báo "Quá hạn" cho hóa đơn đã quá hạn thanh toán
- Nút "Thanh toán" cho hóa đơn chưa thanh toán hoặc thanh toán một phần

#### 2. Xem Chi Tiết Hóa Đơn

**File:** `lib/features/billing/invoice_detail_page.dart`

**Cách sử dụng:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => InvoiceDetailPage(invoiceId: 'invoice-id'),
  ),
);
```

**Thông tin hiển thị:**
- Thông tin chung:
  - Căn hộ
  - Kỳ thanh toán (từ ngày - đến ngày)
  - Hạn thanh toán
  - Trạng thái hóa đơn
  - Cảnh báo nếu quá hạn
- Chi tiết các khoản phí:
  - Tên khoản phí
  - Mô tả (ví dụ: "100m² x 15.000đ")
  - Số tiền
- Tổng cộng: Hiển thị tổng số tiền cần thanh toán

**Nút hành động:**
- Nút "Thanh toán ngay" (hiển thị ở bottom bar) cho hóa đơn chưa thanh toán hoặc thanh toán một phần

#### 3. Thanh Toán Hóa Đơn

**Quy trình:**
1. Người dùng nhấn nút "Thanh toán" hoặc "Thanh toán ngay"
2. Hệ thống gọi API tạo link thanh toán VNPAY
3. Mở trình duyệt với link thanh toán
4. Người dùng hoàn tất thanh toán trên VNPAY
5. Sau khi quay lại app, hóa đơn tự động cập nhật trạng thái

**API Endpoint:**
```
POST /api/Payment/{invoiceId}/create-vnpay-link
```

**Response:**
```json
{
  "paymentUrl": "https://sandbox.vnpayment.vn/..."
}
```

### Model Dữ Liệu

#### InvoiceModel

**File:** `lib/features/billing/invoice_model.dart`

**Các trường:**
- `id`: ID hóa đơn
- `status`: Trạng thái (Unpaid, Paid, PartiallyPaid, Overdue, Cancelled)
- `totalAmount`: Tổng số tiền
- `month`: Tháng
- `year`: Năm
- `dueDate`: Hạn thanh toán
- `periodStart`: Ngày bắt đầu kỳ
- `periodEnd`: Ngày kết thúc kỳ
- `apartmentId`: ID căn hộ
- `apartmentCode`: Mã căn hộ
- `lines`: Danh sách các khoản phí (InvoiceLine[])

**Các phương thức:**
- `statusText`: Trả về text trạng thái tiếng Việt
- `statusColor`: Trả về màu sắc tương ứng với trạng thái
- `isOverdue`: Kiểm tra hóa đơn có quá hạn không

#### InvoiceLine

**Các trường:**
- `feeName`: Tên khoản phí
- `description`: Mô tả chi tiết
- `amount`: Số tiền
- `quantity`: Số lượng
- `unitPrice`: Đơn giá

### Service API

**File:** `lib/features/billing/invoices_service.dart`

#### getMyInvoices
Lấy danh sách hóa đơn của cư dân hiện tại.

```dart
Future<List<InvoiceModel>> getMyInvoices({
  int page = 1,
  int pageSize = 20,
  String? status,
})
```

**Tham số:**
- `page`: Số trang (mặc định: 1)
- `pageSize`: Số lượng mỗi trang (mặc định: 20)
- `status`: Lọc theo trạng thái (tùy chọn)

**API Endpoint:**
```
GET /api/Invoices/my-invoices
```

#### get
Lấy chi tiết một hóa đơn.

```dart
Future<InvoiceModel> get(String id)
```

**API Endpoint:**
```
GET /api/Invoices/{id}
```

#### createVnPayLink
Tạo link thanh toán VNPAY.

```dart
Future<Map<String, dynamic>> createVnPayLink(String invoiceId)
```

**API Endpoint:**
```
POST /api/Payment/{invoiceId}/create-vnpay-link
```

**Response:**
```json
{
  "paymentUrl": "https://sandbox.vnpayment.vn/..."
}
```

### UI/UX Features

1. **Pull to Refresh**: Kéo xuống để làm mới danh sách
2. **Infinite Scroll**: Tự động tải thêm khi cuộn đến cuối
3. **Loading States**: Hiển thị indicator khi đang tải
4. **Empty States**: Hiển thị thông báo khi chưa có hóa đơn
5. **Error Handling**: Hiển thị thông báo lỗi khi có lỗi xảy ra
6. **Color Coding**: Màu sắc phân biệt trạng thái hóa đơn
7. **Responsive Design**: Giao diện thân thiện, dễ sử dụng

---

## Module Gửi Xe

### Tổng Quan
Module Gửi Xe cho phép cư dân quản lý thông tin xe và đăng ký vé gửi xe. Module này bao gồm:
- Quản lý thông tin xe (thêm, sửa, xóa)
- Đăng ký vé gửi xe
- Xem thông tin vé và QR code
- Gia hạn vé

### Các Tính Năng Chính

1. **Quản lý xe**
   - Thêm xe mới (chờ duyệt)
   - Sửa thông tin xe (chỉ khi đang chờ duyệt)
   - Xóa xe (chỉ khi đang chờ duyệt)
   - Xem trạng thái duyệt (Chờ duyệt, Đã duyệt, Đã từ chối)

2. **Đăng ký vé gửi xe**
   - Chọn xe đã được duyệt
   - Chọn gói vé phù hợp với loại xe
   - Chọn ngày bắt đầu
   - Tạo hóa đơn thanh toán

3. **Quản lý vé**
   - Xem danh sách vé đang hoạt động
   - Xem chi tiết vé và QR code
   - Cảnh báo khi vé sắp hết hạn (còn ≤ 3 ngày)
   - Gia hạn vé

### Cấu Trúc File

```
lib/features/vehicles/
├── vehicles_page.dart              # Trang quản lý xe và vé
├── register_pass_page.dart         # Trang đăng ký vé
├── parking_pass_detail_page.dart   # Trang chi tiết vé
├── vehicle_model.dart              # Model dữ liệu xe
├── parking_pass_model.dart         # Model dữ liệu vé
├── parking_plan_model.dart         # Model gói vé
└── vehicles_service.dart           # Service xử lý API
```

### Hướng Dẫn Sử Dụng

#### 1. Quản Lý Xe

**File:** `lib/features/billing/vehicles_page.dart`

**Tab "Xe của tôi":**

**Thêm xe mới:**
1. Nhấn nút "Thêm xe mới" (FAB)
2. Điền thông tin:
   - Biển số xe * (bắt buộc)
   - Loại xe * (Xe máy, Ô tô, Xe đạp)
   - Hãng xe (tùy chọn)
   - Model (tùy chọn)
   - Màu sắc (tùy chọn)
3. Nhấn "Thêm"
4. Xe sẽ ở trạng thái "Chờ duyệt" và chờ Admin duyệt

**Sửa thông tin xe:**
- Chỉ có thể sửa khi xe đang ở trạng thái "Chờ duyệt"
- Nhấn vào card xe hoặc nút "Sửa"
- Cập nhật thông tin và nhấn "Lưu"

**Xóa xe:**
- Chỉ có thể xóa khi xe đang ở trạng thái "Chờ duyệt"
- Nhấn nút "Xóa" và xác nhận

**Trạng thái xe:**
- 🟠 **Chờ duyệt (Pending)**: Xe mới thêm, chờ Admin duyệt
- 🟢 **Đã duyệt (Approved)**: Xe đã được duyệt, có thể mua vé
- 🔴 **Đã từ chối (Rejected)**: Xe bị từ chối, hiển thị lý do

**Mua vé cho xe:**
- Chỉ có thể mua vé khi xe ở trạng thái "Đã duyệt"
- Nhấn nút "Mua vé" trên card xe
- Chuyển đến trang đăng ký vé

#### 2. Đăng Ký Vé Gửi Xe

**File:** `lib/features/vehicles/register_pass_page.dart`

**Cách truy cập:**
1. Từ tab "Xe của tôi": Nhấn nút "Mua vé" trên xe đã được duyệt
2. Từ tab "Vé xe": Nhấn nút "Đăng ký vé xe" (FAB)

**Quy trình đăng ký:**
1. **Chọn xe** (nếu có nhiều xe được duyệt):
   - Nếu chỉ có 1 xe: Tự động chọn
   - Nếu có nhiều xe: Hiển thị dialog chọn xe
   - Nếu chưa có xe: Hiển thị thông báo và hướng dẫn thêm xe

2. **Chọn gói vé:**
   - Hiển thị danh sách gói vé phù hợp với loại xe
   - Mỗi gói hiển thị: Tên, mô tả, thời hạn, giá
   - Nhấn vào gói để chọn

3. **Chọn ngày bắt đầu:**
   - Nhấn vào ô ngày để chọn
   - Chọn ngày từ hôm nay trở đi

4. **Xem tóm tắt:**
   - Gói vé đã chọn
   - Giá
   - Thời hạn
   - Ngày bắt đầu
   - Ngày hết hạn (tự động tính)

5. **Đăng ký và thanh toán:**
   - Nhấn nút "Đăng ký và thanh toán"
   - Hệ thống tạo vé và hóa đơn
   - Chuyển đến trang hóa đơn để thanh toán

**Lưu ý:**
- Vé sẽ ở trạng thái "Chờ thanh toán" cho đến khi thanh toán xong
- Sau khi thanh toán, vé sẽ chuyển sang trạng thái "Đang hoạt động"

#### 3. Quản Lý Vé

**Tab "Vé xe":**

**Danh sách vé:**
- Hiển thị tất cả vé đang hoạt động
- Thông tin hiển thị:
  - Biển số xe
  - Tên gói vé
  - Ngày hết hạn
  - Số ngày còn lại
  - Cảnh báo "Sắp hết hạn" nếu còn ≤ 3 ngày

**Xem chi tiết vé:**
- Nhấn vào card vé
- Hiển thị:
  - Thẻ vé với QR code (nếu đang hoạt động)
  - Mã vé
  - Thông tin chi tiết: Gói vé, trạng thái, ngày bắt đầu, ngày hết hạn, số ngày còn lại
  - Nút "Gia hạn" hoặc "GIA HẠN NGAY" (nếu sắp hết hạn)

**QR Code:**
- Chỉ hiển thị khi vé đang hoạt động
- Sử dụng để quét tại cổng ra vào
- Mã QR chứa `passCode` của vé

**Gia hạn vé:**
- Nhấn nút "Gia hạn" hoặc "GIA HẠN NGAY"
- Chuyển đến màn hình chọn gói và thanh toán (tương tự đăng ký mới)

### Model Dữ Liệu

#### VehicleModel

**File:** `lib/features/vehicles/vehicle_model.dart`

**Các trường:**
- `id`: ID xe
- `licensePlate`: Biển số xe
- `vehicleType`: Loại xe (Xe máy, Ô tô, Xe đạp)
- `brand`: Hãng xe (tùy chọn)
- `model`: Model (tùy chọn)
- `color`: Màu sắc (tùy chọn)
- `residentProfileId`: ID cư dân
- `isActive`: Trạng thái hoạt động
- `status`: Trạng thái duyệt (Pending, Approved, Rejected)
- `rejectionReason`: Lý do từ chối (nếu bị từ chối)
- `createdAtUtc`: Ngày tạo

**Các phương thức:**
- `statusText`: Trả về text trạng thái tiếng Việt
- `canEdit`: Có thể sửa không (chỉ khi Pending)
- `canBuyPass`: Có thể mua vé không (chỉ khi Approved)

#### ParkingPassModel

**File:** `lib/features/vehicles/parking_pass_model.dart`

**Các trường:**
- `id`: ID vé
- `vehicleId`: ID xe
- `vehicleLicensePlate`: Biển số xe
- `parkingPlanId`: ID gói vé
- `parkingPlanName`: Tên gói vé
- `passCode`: Mã vé (dùng cho QR code)
- `validFrom`: Ngày bắt đầu
- `validTo`: Ngày hết hạn
- `status`: Trạng thái (PendingPayment, Active, Expired, Revoked)
- `invoiceId`: ID hóa đơn (nếu có)
- `activatedAt`: Ngày kích hoạt
- `revocationReason`: Lý do hủy (nếu bị hủy)
- `createdAtUtc`: Ngày tạo

**Các phương thức:**
- `isActive`: Vé đang hoạt động không
- `isExpired`: Vé đã hết hạn chưa
- `isPendingPayment`: Vé đang chờ thanh toán không
- `isRevoked`: Vé đã bị hủy chưa
- `daysRemaining`: Số ngày còn lại
- `statusText`: Trả về text trạng thái tiếng Việt
- `statusColor`: Trả về màu sắc tương ứng
- `needsRenewal`: Cần gia hạn không (còn ≤ 3 ngày)

#### ParkingPlanModel

**File:** `lib/features/vehicles/parking_plan_model.dart`

**Các trường:**
- `id`: ID gói vé
- `name`: Tên gói vé
- `description`: Mô tả (tùy chọn)
- `vehicleType`: Loại xe (Xe máy, Ô tô, Xe đạp)
- `price`: Giá
- `durationInDays`: Thời hạn (số ngày)
- `isActive`: Trạng thái hoạt động
- `createdAtUtc`: Ngày tạo

**Các phương thức:**
- `formattedPrice`: Giá đã định dạng (ví dụ: "500,000 đ")
- `durationText`: Thời hạn dạng text (ví dụ: "1 tháng", "12 tháng", "30 ngày")

### Service API

**File:** `lib/features/vehicles/vehicles_service.dart`

#### Vehicle Methods

**list**
Lấy danh sách xe.

```dart
Future<List<VehicleModel>> list({
  int page = 1,
  int pageSize = 20,
  String? search,
  String? residentProfileId,
  String? status,
})
```

**API Endpoint:**
```
GET /api/Vehicles
```

**get**
Lấy chi tiết một xe.

```dart
Future<VehicleModel> get(String id)
```

**API Endpoint:**
```
GET /api/Vehicles/{id}
```

**create**
Tạo xe mới.

```dart
Future<VehicleModel> create(VehicleModel vehicle)
```

**API Endpoint:**
```
POST /api/Vehicles
```

**update**
Cập nhật thông tin xe.

```dart
Future<void> update(String id, VehicleModel vehicle)
```

**API Endpoint:**
```
PUT /api/Vehicles/{id}
```

**delete**
Xóa xe.

```dart
Future<void> delete(String id)
```

**API Endpoint:**
```
DELETE /api/Vehicles/{id}
```

**approveVehicle** (Admin)
Duyệt xe.

```dart
Future<void> approveVehicle(String id)
```

**API Endpoint:**
```
POST /api/Vehicles/{id}/approve
```

**rejectVehicle** (Admin)
Từ chối xe.

```dart
Future<void> rejectVehicle(String id, String reason)
```

**API Endpoint:**
```
POST /api/Vehicles/{id}/reject
```

#### ParkingPlan Methods

**listPlans**
Lấy danh sách gói vé.

```dart
Future<List<ParkingPlanModel>> listPlans({
  int page = 1,
  int pageSize = 20,
  String? vehicleType,
  bool? isActive,
})
```

**API Endpoint:**
```
GET /api/ParkingPlans
```

**getPlan**
Lấy chi tiết một gói vé.

```dart
Future<ParkingPlanModel> getPlan(String id)
```

**API Endpoint:**
```
GET /api/ParkingPlans/{id}
```

#### ParkingPass Methods

**listPasses**
Lấy danh sách vé.

```dart
Future<List<ParkingPassModel>> listPasses({
  int page = 1,
  int pageSize = 20,
  String? vehicleId,
  String? status,
})
```

**API Endpoint:**
```
GET /api/ParkingPasses
```

**getPass**
Lấy chi tiết một vé.

```dart
Future<ParkingPassModel> getPass(String id)
```

**API Endpoint:**
```
GET /api/ParkingPasses/{id}
```

**registerPass**
Đăng ký mua vé.

```dart
Future<ParkingPassModel> registerPass({
  required String vehicleId,
  required String parkingPlanId,
  required DateTime validFrom,
})
```

**API Endpoint:**
```
POST /api/ParkingPasses/register
```

**Request Body:**
```json
{
  "vehicleId": "vehicle-id",
  "parkingPlanId": "plan-id",
  "validFrom": "2024-01-01T00:00:00Z"
}
```

**revokePass** (Admin)
Hủy vé.

```dart
Future<void> revokePass(String id, String reason)
```

**API Endpoint:**
```
POST /api/ParkingPasses/{id}/revoke
```

### UI/UX Features

1. **Tab Navigation**: Chuyển đổi giữa "Xe của tôi" và "Vé xe"
2. **Floating Action Button**: Nút hành động thay đổi theo tab
3. **Pull to Refresh**: Kéo xuống để làm mới
4. **Loading States**: Hiển thị indicator khi đang tải
5. **Empty States**: Hiển thị thông báo khi chưa có dữ liệu
6. **Error Handling**: Hiển thị thông báo lỗi
7. **Color Coding**: Màu sắc phân biệt trạng thái
8. **QR Code Display**: Hiển thị QR code cho vé đang hoạt động
9. **Expiration Warnings**: Cảnh báo khi vé sắp hết hạn
10. **Responsive Design**: Giao diện thân thiện, dễ sử dụng

### Quy Trình Tổng Thể

#### Quy trình đăng ký và sử dụng vé gửi xe:

1. **Thêm xe** → Trạng thái: Chờ duyệt
2. **Admin duyệt** → Trạng thái: Đã duyệt
3. **Đăng ký vé** → Chọn gói và ngày bắt đầu
4. **Tạo hóa đơn** → Trạng thái vé: Chờ thanh toán
5. **Thanh toán hóa đơn** → Trạng thái vé: Đang hoạt động
6. **Sử dụng QR code** → Quét tại cổng ra vào
7. **Gia hạn** (khi sắp hết hạn) → Lặp lại từ bước 3

### Lưu Ý Quan Trọng

1. **Quyền chỉnh sửa xe:**
   - Chỉ có thể sửa/xóa xe khi ở trạng thái "Chờ duyệt"
   - Sau khi được duyệt hoặc bị từ chối, không thể sửa/xóa

2. **Đăng ký vé:**
   - Chỉ có thể đăng ký vé cho xe đã được duyệt
   - Phải chọn gói vé phù hợp với loại xe

3. **Thanh toán:**
   - Vé sẽ không hoạt động cho đến khi thanh toán xong hóa đơn
   - Sau khi thanh toán, vé tự động chuyển sang trạng thái "Đang hoạt động"

4. **QR Code:**
   - Chỉ hiển thị khi vé đang hoạt động
   - QR code chứa mã vé để quét tại cổng

5. **Gia hạn:**
   - Nên gia hạn trước khi vé hết hạn
   - Hệ thống cảnh báo khi còn ≤ 3 ngày

---

## Tích Hợp Giữa Hai Module

Module Hóa Đơn và Module Gửi Xe được tích hợp với nhau:

1. **Khi đăng ký vé:**
   - Hệ thống tự động tạo hóa đơn cho vé
   - Chuyển người dùng đến trang hóa đơn để thanh toán

2. **Sau khi thanh toán:**
   - Hóa đơn cập nhật trạng thái "Đã thanh toán"
   - Vé tự động chuyển sang trạng thái "Đang hoạt động"

3. **Gia hạn vé:**
   - Tương tự đăng ký mới, tạo hóa đơn mới
   - Sau khi thanh toán, vé được gia hạn

---

## Xử Lý Lỗi

### Module Hóa Đơn
- **Lỗi tải hóa đơn**: Hiển thị thông báo và cho phép thử lại
- **Lỗi tạo link thanh toán**: Hiển thị thông báo lỗi
- **Lỗi mở trình duyệt**: Hiển thị thông báo và hướng dẫn

### Module Gửi Xe
- **Lỗi tải danh sách**: Hiển thị thông báo và cho phép thử lại
- **Lỗi thêm/sửa/xóa xe**: Hiển thị thông báo lỗi cụ thể
- **Lỗi đăng ký vé**: Hiển thị thông báo và không tạo vé
- **Lỗi tải gói vé**: Hiển thị thông báo và hướng dẫn liên hệ BQL

---

## Kết Luận

Hai module này cung cấp đầy đủ chức năng để cư dân quản lý hóa đơn và vé gửi xe một cách tiện lợi. Giao diện thân thiện, dễ sử dụng và tích hợp tốt với hệ thống thanh toán VNPAY.

Để biết thêm chi tiết về API, vui lòng tham khảo tài liệu API của backend.

