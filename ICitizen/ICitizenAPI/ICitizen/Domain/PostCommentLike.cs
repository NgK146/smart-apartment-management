namespace ICitizen.Domain;

public class PostCommentLike : BaseEntity
{
    public Guid CommentId { get; set; }
    public string UserId { get; set; } = string.Empty;
    
    // Navigation properties
    public virtual PostComment Comment { get; set; } = null!;
}

