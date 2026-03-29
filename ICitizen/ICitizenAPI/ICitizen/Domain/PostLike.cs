namespace ICitizen.Domain;

public class PostLike : BaseEntity
{
    public Guid PostId { get; set; }
    public string UserId { get; set; } = string.Empty;
    
    // Navigation properties
    public virtual CommunityPost Post { get; set; } = null!;
}

