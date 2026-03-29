import 'package:intl/intl.dart';

/// Model cho chi tiết giao dịch blockchain
class BlockchainTransactionDetail {
  final String transactionHash;
  final String invoiceId;
  final String apartmentId;
  final String? apartmentNumber;
  final double amount;
  final DateTime timestamp;
  final String paymentMethod;
  final String status;
  final int? blockNumber;
  final String? gasUsed;
  final String? fromAddress;
  final String? toAddress;
  
  BlockchainTransactionDetail({
    required this.transactionHash,
    required this.invoiceId,
    required this.apartmentId,
    this.apartmentNumber,
    required this.amount,
    required this.timestamp,
    required this.paymentMethod,
    required this.status,
    this.blockNumber,
    this.gasUsed,
    this.fromAddress,
    this.toAddress,
  });

  factory BlockchainTransactionDetail.fromJson(Map<String, dynamic> json) {
    return BlockchainTransactionDetail(
      transactionHash: json['transactionHash'] ?? json['txHash'] ?? '',
      invoiceId: json['invoiceId'] ?? '',
      apartmentId: json['apartmentId'] ?? '',
      apartmentNumber: json['apartmentNumber'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      paymentMethod: json['paymentMethod'] ?? 'Unknown',
      status: json['status'] ?? 'Unknown',
      blockNumber: json['blockNumber'] as int?,
      gasUsed: json['gasUsed']?.toString(),
      fromAddress: json['fromAddress'] ?? json['from'],
      toAddress: json['toAddress'] ?? json['to'],
    );
  }

  /// Get shortened transaction hash for display
  String get shortHash {
    if (transactionHash.length <= 12) return transactionHash;
    return '${transactionHash.substring(0, 6)}...${transactionHash.substring(transactionHash.length - 4)}';
  }

  /// Get formatted amount with currency
  String get formattedAmount {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    return formatter.format(amount);
  }

  /// Get formatted timestamp
  String get formattedTimestamp {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp);
  }

  /// Get blockchain explorer URL (Ganache local)
  String get explorerUrl {
    // For Ganache, we'll use a placeholder. In production, use real explorer
    return 'http://127.0.0.1:7545/tx/$transactionHash';
  }

  /// Status text in Vietnamese
  String get statusText {
    switch (status.toLowerCase()) {
      case 'success':
        return 'Thành công';
      case 'pending':
        return 'Đang xử lý';
      case 'failed':
        return 'Thất bại';
      default:
        return status;
    }
  }

  /// Payment method text in Vietnamese
  String get methodText {
    switch (paymentMethod.toLowerCase()) {
      case 'payos':
        return 'PayOS';
      case 'vnpay':
        return 'VNPay';
      case 'momo':
        return 'MoMo';
      case 'cash':
        return 'Tiền mặt';
      case 'banktransfer':
        return 'Chuyển khoản';
      default:
        return paymentMethod;
    }
  }
}

/// Model đơn giản cho danh sách blockchain transactions
class BlockchainTransactionSummary {
  final String id;
  final String transactionHash;
  final String invoiceId;
  final String apartmentNumber;
  final String? userName;
  final double amount;
  final DateTime timestamp;
  final String status;
  final String paymentMethod;

  BlockchainTransactionSummary({
    required this.id,
    required this.transactionHash,
    required this.invoiceId,
    required this.apartmentNumber,
    this.userName,
    required this.amount,
    required this.timestamp,
    required this.status,
    required this.paymentMethod,
  });

  factory BlockchainTransactionSummary.fromJson(Map<String, dynamic> json) {
    return BlockchainTransactionSummary(
      id: json['id'] ?? '',
      transactionHash: json['blockchainTxHash'] ?? json['transactionHash'] ?? '',
      invoiceId: json['invoiceId'] ?? '',
      apartmentNumber: json['apartmentCode'] ?? json['apartmentNumber'] ?? 'N/A',
      userName: json['userName'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'])
          : (json['paidAtUtc'] != null 
              ? DateTime.parse(json['paidAtUtc'])
              : DateTime.now()),
      status: json['status'] ?? 'Unknown',
      paymentMethod: json['method'] ?? json['paymentMethod'] ?? 'Unknown',
    );
  }

  String get shortHash {
    if (transactionHash.length <= 12) return transactionHash;
    return '${transactionHash.substring(0, 6)}...${transactionHash.substring(transactionHash.length - 4)}';
  }

  String get formattedAmount {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    return formatter.format(amount);
  }

  String get formattedDate {
    // Convert UTC to Vietnam timezone (UTC+7)
    final vnTime = timestamp.add(const Duration(hours: 7));
    return DateFormat('dd/MM/yyyy HH:mm').format(vnTime);
  }
}
