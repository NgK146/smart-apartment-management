class PaymentTransactionModel {
  final String id;
  final String invoiceId;
  final double amount;
  final String paymentMethod; // VNPay, BankTransfer, Cash, etc.
  final String status; // Pending, Success, Failed
  final DateTime? paidAtUtc;
  final String? transactionRef;
  final String? transactionCode;
  final String? blockchainTxHash; // Hash giao dịch blockchain (proof minh bạch)
  final DateTime createdAtUtc;

  PaymentTransactionModel({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    this.paidAtUtc,
    this.transactionRef,
    this.transactionCode,
    this.blockchainTxHash,
    required this.createdAtUtc,
  });

  factory PaymentTransactionModel.fromJson(Map<String, dynamic> json) => PaymentTransactionModel(
        id: json['id'],
        invoiceId: json['invoiceId'],
        amount: (json['amount'] as num).toDouble(),
        paymentMethod: json['method']?.toString() ?? 'Cash',
        status: json['status']?.toString() ?? 'Pending',
        paidAtUtc: json['paidAtUtc'] != null ? DateTime.parse(json['paidAtUtc']) : null,
        transactionRef: json['transactionRef'],
        transactionCode: json['transactionCode'],
        blockchainTxHash: json['blockchainTxHash'],
        createdAtUtc: DateTime.parse(json['createdAtUtc']),
      );

  String get statusText {
    switch (status) {
      case 'Pending': return 'Đang xử lý';
      case 'Success': return 'Thành công';
      case 'Failed': return 'Thất bại';
      default: return status;
    }
  }

  /// Check if this payment has been recorded on blockchain
  bool get hasBlockchainRecord => blockchainTxHash != null && blockchainTxHash!.isNotEmpty;

  /// Get shortened blockchain hash for display (0x1234...5678)
  String get shortBlockchainHash {
    if (!hasBlockchainRecord) return '';
    final hash = blockchainTxHash!;
    if (hash.length <= 12) return hash;
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
  }
}

