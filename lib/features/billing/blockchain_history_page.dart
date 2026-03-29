import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import '../../core/ui/snackbar.dart';
import 'blockchain_service.dart';
import 'blockchain_transaction_detail_model.dart';
import 'blockchain_transaction_detail_page.dart';

class BlockchainHistoryPage extends StatefulWidget {
  final bool isAdminView;

  const BlockchainHistoryPage({
    super.key,
    this.isAdminView = false,
  });

  @override
  State<BlockchainHistoryPage> createState() => _BlockchainHistoryPageState();
}

class _BlockchainHistoryPageState extends State<BlockchainHistoryPage> {
  late BlockchainService _blockchainService;
  List<BlockchainTransactionSummary> _transactions = [];
  List<BlockchainTransactionSummary> _filteredTransactions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _blockchainService = BlockchainService(ApiClient());
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    
    try {
      final transactions = widget.isAdminView
          ? await _blockchainService.getAllBlockchainTransactions()
          : await _blockchainService.getMyBlockchainTransactions();
      
      setState(() {
        _transactions = transactions;
        _filteredTransactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnack(context, 'Không thể tải lịch sử blockchain: $e', error: true);
      }
    }
  }

  void _filterTransactions() {
    setState(() {
      _filteredTransactions = _transactions.where((tx) {
        final matchesSearch = _searchQuery.isEmpty ||
            tx.invoiceId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            tx.apartmentNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            tx.transactionHash.toLowerCase().contains(_searchQuery.toLowerCase());
        
        final matchesStatus = _selectedStatus == 'All' || tx.status == _selectedStatus;
        
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdminView ? 'Tất cả giao dịch Blockchain' : 'Lịch sử Blockchain'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                    ? _buildEmptyState(theme)
                    : RefreshIndicator(
                        onRefresh: _loadTransactions,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final tx = _filteredTransactions[index];
                            return _buildTransactionCard(theme, tx);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Tìm theo mã hóa đơn, căn hộ, hash...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[100],
            ),
            onChanged: (value) {
              _searchQuery = value;
              _filterTransactions();
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'Tất cả'),
                const SizedBox(width: 8),
                _buildFilterChip('Success', 'Thành công'),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', 'Đang xử lý'),
                const SizedBox(width: 8),
                _buildFilterChip('Failed', 'Thất bại'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = value;
          _filterTransactions();
        });
      },
      selectedColor: Colors.blue.withValues(alpha: 0.2),
      checkmarkColor: Colors.blue,
    );
  }

  Widget _buildTransactionCard(ThemeData theme, BlockchainTransactionSummary tx) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlockchainTransactionDetailPage(
                transactionHash: tx.transactionHash,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.link, color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hóa đơn: ${tx.invoiceId}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.isAdminView) ...[
                          if (tx.userName != null)
                            Text(
                              tx.userName!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          Text(
                            'Căn hộ: ${tx.apartmentNumber}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildStatusBadge(tx.status),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    tx.formattedAmount,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    tx.formattedDate,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tag, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tx.shortHash,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: tx.transactionHash));
                        showSnack(context, 'Đã copy hash vào clipboard');
                      },
                      tooltip: 'Copy hash',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    
    switch (status.toLowerCase()) {
      case 'success':
        color = Colors.green;
        text = 'Thành công';
        break;
      case 'pending':
        color = Colors.orange;
        text = 'Đang xử lý';
        break;
      case 'failed':
        color = Colors.red;
        text = 'Thất bại';
        break;
      default:
        color = Colors.grey;
        text = status;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.link_off,
            size: 80,
            color: theme.disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có giao dịch blockchain',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.disabledColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Các thanh toán thành công sẽ được ghi lên blockchain',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.disabledColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
