// Model cho Đơn hàng
import 'product_model.dart';

enum OrderStatus {
  pending, // Chờ Người bán xác nhận
  confirmed, // Người bán đã xác nhận
  delivering, // Đang giao hàng
  completed, // Đã hoàn thành/nhận hàng
  cancelled, // Đã hủy
}

class Order {
  final int id;
  final double totalAmount;
  final OrderStatus status;
  final String? notes;
  final String buyerId;
  final int storeId;
  final String? storeName;
  final String? buyerName;
  final DateTime? createdAt;
  final List<OrderDetail>? orderDetails;

  Order({
    required this.id,
    required this.totalAmount,
    required this.status,
    this.notes,
    required this.buyerId,
    required this.storeId,
    this.storeName,
    this.buyerName,
    this.createdAt,
    this.orderDetails,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] ?? json['Status'] ?? 'pending').toString().toLowerCase();
    OrderStatus orderStatus;
    switch (statusStr) {
      case 'confirmed':
        orderStatus = OrderStatus.confirmed;
        break;
      case 'delivering':
        orderStatus = OrderStatus.delivering;
        break;
      case 'completed':
        orderStatus = OrderStatus.completed;
        break;
      case 'cancelled':
        orderStatus = OrderStatus.cancelled;
        break;
      default:
        orderStatus = OrderStatus.pending;
    }

    DateTime? createdAt;
    if (json['createdAt'] != null || json['CreatedAt'] != null) {
      try {
        final dateStr = json['createdAt'] ?? json['CreatedAt'];
        if (dateStr is String) {
          createdAt = DateTime.parse(dateStr);
        } else if (dateStr is DateTime) {
          createdAt = dateStr;
        }
      } catch (_) {}
    }

    List<OrderDetail>? details;
    if (json['orderDetails'] != null || json['OrderDetails'] != null) {
      final detailsList = json['orderDetails'] ?? json['OrderDetails'];
      if (detailsList is List) {
        details = detailsList.map((e) => OrderDetail.fromJson(e)).toList();
      }
    }

    return Order(
      id: json['id'] ?? json['Id'] ?? 0,
      totalAmount: (json['totalAmount'] ?? json['TotalAmount'] ?? 0).toDouble(),
      status: orderStatus,
      notes: json['notes'] ?? json['Notes'],
      buyerId: json['buyerId'] ?? json['BuyerId'] ?? '',
      storeId: json['storeId'] ?? json['StoreId'] ?? 0,
      storeName: json['storeName'] ?? json['StoreName'],
      buyerName: json['buyerName'] ?? json['BuyerName'],
      createdAt: createdAt,
      orderDetails: details,
    );
  }

  Map<String, dynamic> toJson() {
    String statusStr;
    switch (status) {
      case OrderStatus.confirmed:
        statusStr = 'confirmed';
        break;
      case OrderStatus.delivering:
        statusStr = 'delivering';
        break;
      case OrderStatus.completed:
        statusStr = 'completed';
        break;
      case OrderStatus.cancelled:
        statusStr = 'cancelled';
        break;
      default:
        statusStr = 'pending';
    }

    return {
      'id': id,
      'totalAmount': totalAmount,
      'status': statusStr,
      'notes': notes,
      'buyerId': buyerId,
      'storeId': storeId,
    };
  }

  String get statusText {
    switch (status) {
      case OrderStatus.pending:
        return 'Chờ xác nhận';
      case OrderStatus.confirmed:
        return 'Đã xác nhận';
      case OrderStatus.delivering:
        return 'Đang giao hàng';
      case OrderStatus.completed:
        return 'Đã hoàn thành';
      case OrderStatus.cancelled:
        return 'Đã hủy';
    }
  }
}

// Model cho Chi tiết Đơn hàng
class OrderDetail {
  final int id;
  final int quantity;
  final double priceAtPurchase;
  final int orderId;
  final int productId;
  final Product? product;

  OrderDetail({
    required this.id,
    required this.quantity,
    required this.priceAtPurchase,
    required this.orderId,
    required this.productId,
    this.product,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    Product? product;
    if (json['product'] != null || json['Product'] != null) {
      product = Product.fromJson(json['product'] ?? json['Product']);
    }

    return OrderDetail(
      id: json['id'] ?? json['Id'] ?? 0,
      quantity: json['quantity'] ?? json['Quantity'] ?? 0,
      priceAtPurchase: (json['priceAtPurchase'] ?? json['PriceAtPurchase'] ?? 0).toDouble(),
      orderId: json['orderId'] ?? json['OrderId'] ?? 0,
      productId: json['productId'] ?? json['ProductId'] ?? 0,
      product: product,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quantity': quantity,
      'priceAtPurchase': priceAtPurchase,
      'orderId': orderId,
      'productId': productId,
    };
  }
}

