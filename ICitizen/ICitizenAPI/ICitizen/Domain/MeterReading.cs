using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class MeterReading : BaseEntity
{
    public int Month { get; set; }
    public int Year { get; set; }
    public decimal Reading { get; set; } // Chỉ số mới (ví dụ: 150 kWh)
    public decimal PreviousReading { get; set; } // Chỉ số cũ (ví dụ: 100 kWh)
    public decimal Usage => Reading - PreviousReading; // (Tính toán)

    // --- Khóa ngoại ---
    public Guid ApartmentId { get; set; } // Liên kết với Căn hộ
    public virtual Apartment? Apartment { get; set; }
    
    public Guid FeeDefinitionId { get; set; } // Liên kết với Loại phí (ví dụ: "Điện" hoặc "Nước")
    public virtual FeeDefinition? FeeDefinition { get; set; }
}

