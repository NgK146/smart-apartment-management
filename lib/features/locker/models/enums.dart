enum LockerTransactionStatus {
  receivedBySecurity,
  stored,
  pickedUp,
  expired,
  cancelled;

  String get displayName {
    switch (this) {
      case LockerTransactionStatus.receivedBySecurity:
        return 'Đã nhận bởi bảo vệ';
      case LockerTransactionStatus.stored:
        return 'Đã lưu trong tủ';
      case LockerTransactionStatus.pickedUp:
        return 'Đã lấy hàng';
      case LockerTransactionStatus.expired:
        return 'Đã hết hạn';
      case LockerTransactionStatus.cancelled:
        return 'Đã hủy';
    }
  }

  static LockerTransactionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'receivedbysecurity':
        return LockerTransactionStatus.receivedBySecurity;
      case 'stored':
        return LockerTransactionStatus.stored;
      case 'pickedup':
        return LockerTransactionStatus.pickedUp;
      case 'expired':
        return LockerTransactionStatus.expired;
      case 'cancelled':
        return LockerTransactionStatus.cancelled;
      default:
        return LockerTransactionStatus.receivedBySecurity;
    }
  }
}

enum CompartmentStatus {
  empty,
  occupied;

  String get displayName {
    switch (this) {
      case CompartmentStatus.empty:
        return 'Trống';
      case CompartmentStatus.occupied:
        return 'Đang có hàng';
    }
  }

  static CompartmentStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'empty':
        return CompartmentStatus.empty;
      case 'occupied':
        return CompartmentStatus.occupied;
      default:
        return CompartmentStatus.empty;
    }
  }
}
