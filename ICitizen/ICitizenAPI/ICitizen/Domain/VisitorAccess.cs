using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ICitizen.Domain
{
    /// <summary>
    /// Entity cho Visitor Access - Quản lý khách vào tòa nhà bằng QR code
    /// </summary>
    public class VisitorAccess
    {
        [Key]
        public Guid Id { get; set; }

        [Required]
        public Guid ResidentId { get; set; }

        [ForeignKey("ResidentId")]
        public ResidentProfile? Resident { get; set; }

        [Required]
        [MaxLength(20)]
        public string ApartmentCode { get; set; } = string.Empty;

        [Required]
        [MaxLength(200)]
        public string VisitorName { get; set; } = string.Empty;

        [MaxLength(20)]
        public string? VisitorPhone { get; set; }

        [MaxLength(200)]
        public string? VisitorEmail { get; set; }

        [Required]
        public DateTime VisitDate { get; set; }

        [MaxLength(10)]
        public string? VisitTime { get; set; } // Format: "14:00"

        [MaxLength(500)]
        public string? Purpose { get; set; }

        [Required]
        [MaxLength(100)]
        public string QrCode { get; set; } = string.Empty; // Format: VISITOR_{timestamp}_{hash}

        [MaxLength(500)]
        public string? QrCodeUrl { get; set; }

        [Required]
        [MaxLength(20)]
        public string Status { get; set; } = "pending"; // pending, checkedIn, checkedOut, expired, cancelled

        public DateTime? CheckedInAt { get; set; }

        public DateTime? CheckedOutAt { get; set; }

        [Required]
        public DateTime CreatedAt { get; set; }

        [Required]
        public DateTime ExpiresAt { get; set; }
    }
}



