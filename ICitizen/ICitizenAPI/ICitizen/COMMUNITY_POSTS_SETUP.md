# Community Posts API - Hướng dẫn Setup

## Tổng quan

Đã tạo đầy đủ backend API cho tính năng Bảng tin cư dân với các chức năng:
- CRUD bài đăng (TIN TỨC, THẢO LUẬN, KIẾN NGHỊ)
- Like/Unlike bài đăng
- Bình luận (CRUD)
- Phân quyền (Admin/BQT vs Cư dân)
- Tìm kiếm và phân trang

## Các file đã tạo/cập nhật

### 1. Domain Entities
- `Domain/CommunityPost.cs` - Entity bài đăng
- `Domain/PostComment.cs` - Entity bình luận
- `Domain/PostLike.cs` - Entity lượt thích
- `Domain/Enums.cs` - Thêm `PostType` và `SuggestionStatus`

### 2. Database Context
- `Data/ApplicationDbContext.cs` - Đã thêm DbSet và cấu hình cho các entities mới

### 3. Controller
- `Controllers/CommunityPostsController.cs` - Controller đầy đủ với tất cả endpoints

## Các API Endpoints

### Bài đăng (Posts)

#### GET /api/community/posts
Lấy danh sách bài đăng với phân trang
- Query params:
  - `type`: "News" | "Discussion" | "Suggestion" (optional)
  - `page`: số trang (default: 1)
  - `pageSize`: số item mỗi trang (default: 20, max: 100)
  - `search`: từ khóa tìm kiếm (optional)

#### GET /api/community/posts/{id}
Lấy chi tiết một bài đăng

#### POST /api/community/posts
Tạo bài đăng mới
- Body:
```json
{
  "type": "News" | "Discussion" | "Suggestion",
  "title": "Tiêu đề",
  "content": "Nội dung",
  "imageUrls": ["url1", "url2"] // optional
}
```
- **Lưu ý**: Chỉ Admin/BQT được đăng TIN TỨC (type = "News")

#### PUT /api/community/posts/{id}
Cập nhật bài đăng
- Body:
```json
{
  "title": "Tiêu đề mới", // optional
  "content": "Nội dung mới", // optional
  "imageUrls": ["url1", "url2"] // optional
}
```

#### DELETE /api/community/posts/{id}
Xóa bài đăng (soft delete)

#### POST /api/community/posts/{id}/like
Thích/Bỏ thích bài đăng

#### PUT /api/community/posts/{id}/status
Cập nhật trạng thái kiến nghị (chỉ Admin)
- Body:
```json
{
  "status": "New" | "InProgress" | "Completed" | "Rejected"
}
```

### Bình luận (Comments)

#### GET /api/community/posts/{id}/comments
Lấy danh sách bình luận
- Query params:
  - `page`: số trang (default: 1)
  - `pageSize`: số item mỗi trang (default: 50, max: 100)

#### POST /api/community/posts/{id}/comments
Tạo bình luận mới
- Body:
```json
{
  "content": "Nội dung bình luận"
}
```

#### PUT /api/community/posts/{postId}/comments/{commentId}
Cập nhật bình luận

#### DELETE /api/community/posts/{postId}/comments/{commentId}
Xóa bình luận

## Phân quyền

- **TIN TỨC (News)**: Chỉ Admin/BQT (Manager/Security) được tạo
- **THẢO LUẬN (Discussion)**: Tất cả cư dân
- **KIẾN NGHỊ (Suggestion)**: Tất cả cư dân
- **Sửa/Xóa**: Chỉ người tạo hoặc Admin
- **Cập nhật trạng thái kiến nghị**: Chỉ Admin

## Bước tiếp theo

### 1. Tạo Migration
```bash
cd ICitizen/ICitizenAPI/ICitizen
dotnet ef migrations add AddCommunityPosts
```

### 2. Cập nhật Database
```bash
dotnet ef database update
```

### 3. Kiểm tra API
Sử dụng Swagger hoặc Postman để test các endpoints

## Lưu ý

1. **ImageUrls**: Hiện tại chỉ lưu URL. Cần implement upload service riêng nếu muốn upload ảnh trực tiếp.
2. **Soft Delete**: Tất cả entities sử dụng soft delete (IsDeleted flag)
3. **Indexes**: Đã thêm indexes cho performance:
   - CommunityPost: (Type, CreatedAtUtc), CreatedById
   - PostComment: PostId, CreatedById
   - PostLike: (PostId, UserId) unique

## Response Format

Tất cả responses trả về JSON với format:
- Success: Trả về data object hoặc array
- Error: 
```json
{
  "error": "Mô tả lỗi",
  "message": "Chi tiết lỗi"
}
```

## Testing

Có thể test các endpoints bằng:
1. Swagger UI (nếu đã enable)
2. Postman
3. Flutter app (đã implement sẵn)

