import 'package:flutter/material.dart';

class InvoiceModel {
  final String id;
  final String status;
  final String type;
  final double totalAmount;
  final int month;
  final int year;
  final DateTime dueDate;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String? apartmentId;
  final String? apartmentCode;
  final List<InvoiceLine> lines;
  final String? blockchainTxHash; // Hash giao dịch blockchain
  
  InvoiceModel({
    required this.id,
    required this.status,
    this.type = 'ManagementFee',
    required this.totalAmount,
    required this.month,
    required this.year,
    required this.dueDate,
    required this.periodStart,
    required this.periodEnd,
    this.apartmentId,
    this.apartmentCode,
    required this.lines,
    this.blockchainTxHash,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> j) => InvoiceModel(
    id: j['id'],
    status: j['status'].toString(),
    type: j['type']?.toString() ?? 'ManagementFee',
    totalAmount: (j['totalAmount'] as num).toDouble(),
    month: j['month'] ?? 1,
    year: j['year'] ?? DateTime.now().year,
    dueDate: j['dueDate'] != null ? DateTime.parse(j['dueDate']) : DateTime.now(),
    periodStart: j['periodStart'] != null ? DateTime.parse(j['periodStart']) : DateTime.now(),
    periodEnd: j['periodEnd'] != null ? DateTime.parse(j['periodEnd']) : DateTime.now(),
    apartmentId: j['apartmentId'],
    apartmentCode: j['apartment']?['code'],
    lines: (j['lines'] as List? ?? []).map((e) => InvoiceLine.fromJson(Map<String, dynamic>.from(e))).toList(),
    blockchainTxHash: j['blockchainTxHash'] ?? j['payment']?['blockchainTxHash'],
  );

  bool get hasBlockchainRecord => blockchainTxHash != null && blockchainTxHash!.isNotEmpty;

  String get statusText {
    if (isOverdue) return 'Quá hạn';
    switch (status) {
      case 'Unpaid': return 'Chưa thanh toán';
      case 'Paid': return 'Đã thanh toán';
      case 'PartiallyPaid': return 'Thanh toán một phần';
      case 'Overdue': return 'Quá hạn';
      case 'Cancelled': return 'Đã hủy';
      default: return status;
    }
  }

  Color get statusColor {
    if (isOverdue) return Colors.red;
    switch (status) {
      case 'Unpaid': return Colors.orange;
      case 'Paid': return Colors.green;
      case 'PartiallyPaid': return Colors.blue;
      case 'Overdue': return Colors.red;
      case 'Cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }

  bool get isOverdue {
    // Nếu đã thanh toán rồi thì không bao giờ quá hạn
    if (status == 'Paid' || status == 'PartiallyPaid') return false;
    // Chỉ hiển thị quá hạn nếu status là Overdue hoặc Unpaid và đã quá hạn
    return status == 'Overdue' || (status == 'Unpaid' && DateTime.now().isAfter(dueDate));
  }
  bool get isManagementFee => type == 'ManagementFee';
}

class InvoiceLine {
  final String feeName; // Tên khoản phí
  final String description; // Mô tả (ví dụ: "100m² x 15.000đ")
  final double amount;
  final double quantity;
  final double unitPrice;
  
  InvoiceLine({
    required this.feeName,
    required this.description,
    required this.amount,
    required this.quantity,
    required this.unitPrice,
  });
  
  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
    feeName: j['feeName'] ?? j['description'] ?? '',
    description: j['description'] ?? '',
    amount: (j['amount'] as num).toDouble(),
    quantity: (j['quantity'] as num).toDouble(),
    unitPrice: (j['unitPrice'] as num).toDouble(),
  );
}
