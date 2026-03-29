// Models cho Digital Payment
class DigitalWallet {
  final String id;
  final String residentId;
  final double balance;
  final String currency; // VND, USD
  final List<WalletTransaction> transactions;
  final DateTime lastUpdated;

  DigitalWallet({
    required this.id,
    required this.residentId,
    required this.balance,
    this.currency = 'VND',
    this.transactions = const [],
    required this.lastUpdated,
  });

  factory DigitalWallet.fromJson(Map<String, dynamic> json) {
    return DigitalWallet(
      id: json['id'] as String,
      residentId: json['residentId'] as String,
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'VND',
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((t) => WalletTransaction.fromJson(t))
              .toList() ??
          [],
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }
}

class WalletTransaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String description;
  final DateTime timestamp;
  final TransactionStatus status;
  final String? referenceId; // Invoice ID, Booking ID, etc.

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    this.status = TransactionStatus.completed,
    this.referenceId,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => TransactionType.other,
      ),
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: TransactionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => TransactionStatus.completed,
      ),
      referenceId: json['referenceId'] as String?,
    );
  }
}

enum TransactionType {
  topUp, // Nạp tiền
  payment, // Thanh toán
  refund, // Hoàn tiền
  transfer, // Chuyển khoản
  other,
}

enum TransactionStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

class PaymentMethod {
  final String id;
  final PaymentMethodType type;
  final String name;
  final String? accountNumber;
  final String? bankName;
  final bool isDefault;
  final String? qrCode; // QR code for bank transfer

  PaymentMethod({
    required this.id,
    required this.type,
    required this.name,
    this.accountNumber,
    this.bankName,
    this.isDefault = false,
    this.qrCode,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String,
      type: PaymentMethodType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => PaymentMethodType.wallet,
      ),
      name: json['name'] as String,
      accountNumber: json['accountNumber'] as String?,
      bankName: json['bankName'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      qrCode: json['qrCode'] as String?,
    );
  }
}

enum PaymentMethodType {
  wallet, // Ví điện tử
  bankTransfer, // Chuyển khoản ngân hàng
  qrBank, // QR Bank
  creditCard, // Thẻ tín dụng
  cash, // Tiền mặt
}

class PaymentReminder {
  final String id;
  final String invoiceId;
  final String description;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final int daysUntilDue;

  PaymentReminder({
    required this.id,
    required this.invoiceId,
    required this.description,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
    required this.daysUntilDue,
  });

  bool get isOverdue => !isPaid && DateTime.now().isAfter(dueDate);
  bool get isDueSoon => !isPaid && daysUntilDue <= 3 && daysUntilDue >= 0;

  factory PaymentReminder.fromJson(Map<String, dynamic> json) {
    final dueDate = DateTime.parse(json['dueDate'] as String);
    final now = DateTime.now();
    final daysUntilDue = dueDate.difference(now).inDays;

    return PaymentReminder(
      id: json['id'] as String,
      invoiceId: json['invoiceId'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      dueDate: dueDate,
      isPaid: json['isPaid'] as bool? ?? false,
      daysUntilDue: daysUntilDue,
    );
  }
}

