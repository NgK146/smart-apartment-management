import 'dart:convert';
import '../../core/api_client.dart';
import 'blockchain_transaction_detail_model.dart';

/// Service để tương tác với Blockchain API
class BlockchainService {
  final ApiClient _apiClient;

  BlockchainService(this._apiClient);

  /// Lấy lịch sử giao dịch blockchain của user hiện tại
  Future<List<BlockchainTransactionSummary>> getMyBlockchainTransactions() async {
    try {
      final response = await _apiClient.dio.get('/api/Payments/my-blockchain-history');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        return data
            .map((json) => BlockchainTransactionSummary.fromJson(json))
            .where((tx) => tx.transactionHash.isNotEmpty)
            .toList();
      } else {
        throw Exception('Failed to load blockchain history: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Lấy tất cả giao dịch blockchain (Admin only)
  Future<List<BlockchainTransactionSummary>> getAllBlockchainTransactions() async {
    try {
      final response = await _apiClient.dio.get('/api/Payments/all-blockchain-history');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        return data
            .map((json) => BlockchainTransactionSummary.fromJson(json))
            .where((tx) => tx.transactionHash.isNotEmpty)
            .toList();
      } else {
        throw Exception('Failed to load blockchain history: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Lấy chi tiết giao dịch từ blockchain
  Future<BlockchainTransactionDetail?> getTransactionDetail(String txHash) async {
    try {
      final response = await _apiClient.dio.get('/api/Payments/blockchain/$txHash');
      
      if (response.statusCode == 200) {
        final data = response.data;
        return BlockchainTransactionDetail.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load transaction detail: ${response.statusCode}');
      }
    } catch (e) {
      return null;
    }
  }

  /// Xác minh giao dịch trên blockchain
  Future<bool> verifyTransaction(String txHash) async {
    try {
      final response = await _apiClient.dio.get('/api/Payments/verify-blockchain/$txHash');
      
      if (response.statusCode == 200) {
        final data = response.data;
        return data['verified'] == true || data['isValid'] == true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Lấy blockchain info từ payment
  Future<Map<String, dynamic>?> getPaymentBlockchainInfo(String invoiceId) async {
    try {
      final response = await _apiClient.dio.get('/api/Payments/invoice/$invoiceId/blockchain');
      
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Mock function để test (khi backend chưa có endpoint)
  Future<List<BlockchainTransactionSummary>> getMockBlockchainTransactions() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    return [
      BlockchainTransactionSummary(
        id: '1',
        transactionHash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        invoiceId: 'INV-001',
        apartmentNumber: 'A101',
        amount: 5000000,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        status: 'Success',
        paymentMethod: 'PayOS',
      ),
      BlockchainTransactionSummary(
        id: '2',
        transactionHash: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        invoiceId: 'INV-002',
        apartmentNumber: 'A102',
        amount: 3000000,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        status: 'Success',
        paymentMethod: 'VNPay',
      ),
    ];
  }

  /// Mock function để test chi tiết
  Future<BlockchainTransactionDetail?> getMockTransactionDetail(String txHash) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    return BlockchainTransactionDetail(
      transactionHash: txHash,
      invoiceId: 'INV-001',
      apartmentId: 'apt-123',
      apartmentNumber: 'A101',
      amount: 5000000,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      paymentMethod: 'PayOS',
      status: 'Success',
      blockNumber: 12345,
      gasUsed: '21000',
      fromAddress: '0x1234...5678',
      toAddress: '0xabcd...ef01',
    );
  }
}
