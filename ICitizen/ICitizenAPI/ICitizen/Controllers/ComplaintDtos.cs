using System.ComponentModel.DataAnnotations;

namespace ICitizen.Controllers
{
    public sealed class CreateComplaintRequest
    {
        [Required] public string Title { get; set; } = string.Empty;
        [Required] public string Content { get; set; } = string.Empty;
        public string? Category { get; set; }
        public string? EmailNguoiGui { get; set; }
        public string? TenNguoiGui { get; set; }
        /// <summary>
        /// Danh sách URL ảnh do client upload, phân tách bằng dấu phẩy.
        /// Tạm thời dùng string để tương thích với mobile app.
        /// </summary>
        public string? MediaUrls { get; set; }
    }

    public sealed class SetComplaintStatusRequest
    {
        [Required] public string Status { get; set; } = string.Empty;
    }

    public sealed class UpdateComplaintRequest
    {
        public string? TrangThai { get; set; }
        public string? PhanHoiAdmin { get; set; }
    }

    public sealed class AddCommentRequest
    {
        [Required]
        public string Message { get; set; } = string.Empty;
    }
}