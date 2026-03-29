namespace ICitizen.Domain;

public class PostComment : BaseEntity
{
    public Guid PostId { get; set; }
    public Guid? ParentCommentId { get; set; } // ID của comment cha (nếu là reply)
    public string Content { get; set; } = string.Empty;
    public string CreatedById { get; set; } = string.Empty;
    public string CreatedByName { get; set; } = string.Empty;
    public bool IsHidden { get; set; } = false; // Ẩn bình luận (thay vì xóa)
    
    // Navigation properties
    public virtual CommunityPost Post { get; set; } = null!;
    public virtual PostComment? ParentComment { get; set; }
    public virtual ICollection<PostComment> Replies { get; set; } = new List<PostComment>();
    public virtual ICollection<PostCommentLike> Likes { get; set; } = new List<PostCommentLike>();
}

