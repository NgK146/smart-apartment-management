namespace ICitizen.Domain;

public enum NotificationType { General, PowerCut, WaterCut, LiftMaintenance, Event } // :contentReference[oaicite:3]{index=3}
public enum ComplaintCategory { Sanitation, Security, Service, Other }                // :contentReference[oaicite:4]{index=4}
public enum ComplaintStatus { Pending, InProgress, Resolved, Rejected }              // :contentReference[oaicite:5]{index=5}
public enum PeriodType { OneTime, Monthly, Quarterly, Yearly }
public enum InvoiceStatus { Draft, Unpaid, PartiallyPaid, Paid, Overdue, Cancelled }
public enum InvoiceType { ManagementFee, Utility, Service, Marketplace }
public enum PaymentMethod { Cash, BankTransfer, Momo, ZaloPay, ViettelPay, VNPay, PayOS, Other }   // :contentReference[oaicite:6]{index=6}
public enum PaymentStatus { Pending, Success, Failed }
public enum FeeCalculationMethod { Fixed, PerM2, PerUnit, Metered }
public enum AmenityBookingStatus { Pending, Approved, Rejected, Cancelled, Completed }
public enum LockerBoxSize { Small, Medium, Large }
public enum LockerTransactionStatus 
{ 
    ReceivedBySecurity,  // Security received package from shipper
    Stored,              // Package stored in locker, resident can pick up
    PickedUp,           // Resident picked up the package
    Expired,            // OTP/token expired
    Cancelled           // Transaction cancelled
}
public enum CompartmentStatus 
{ 
    Empty,              // Compartment is available for new package
    Occupied            // Compartment currently holds a package
}
public enum ApartmentStatus { Available, Occupied, Maintenance, Reserved } // Trạng thái căn hộ: Có sẵn, Đã có người ở, Đang bảo trì, Đã đặt chỗ
public enum SupportTicketStatus { New, InProgress, Resolved, Closed }
public enum PostType { News = 0, Discussion = 1, Suggestion = 2 } // TIN TỨC, THẢO LUẬN, KIẾN NGHỊ
public enum SuggestionStatus { New = 0, InProgress = 1, Completed = 2, Rejected = 3 } // Mới, Đang xử lý, Đã hoàn thành, Đã từ chối

public enum ConciergeRequestStatus { Pending, InProgress, Completed, Cancelled }

// Marketplace enums
public enum ProductType { Physical, Service } // Hàng hóa, Dịch vụ
public enum OrderStatus { Pending, Confirmed, Delivering, Completed, Cancelled } // Chờ xác nhận, Đã xác nhận, Đang giao, Hoàn thành, Đã hủy
