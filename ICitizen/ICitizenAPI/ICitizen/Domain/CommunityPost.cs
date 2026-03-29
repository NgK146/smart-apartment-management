namespace ICitizen.Domain;

public class CommunityPost : BaseEntity
{
    public PostType Type { get; set; } = PostType.Discussion;
    public string Title { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public string CreatedById { get; set; } = string.Empty;
    public string CreatedByName { get; set; } = string.Empty;
    public string? ApartmentCode { get; set; }
    public List<string> ImageUrls { get; set; } = new();
    public SuggestionStatus? SuggestionStatus { get; set; } // Chỉ dùng cho kiến nghị
    public Guid? NotificationId { get; set; } // Liên kết với Notification nếu được tạo từ Notification
    
    // Navigation properties
    public virtual ICollection<PostComment> Comments { get; set; } = new List<PostComment>();
    public virtual ICollection<PostLike> Likes { get; set; } = new List<PostLike>();
}

