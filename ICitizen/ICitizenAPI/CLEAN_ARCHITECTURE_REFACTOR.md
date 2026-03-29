# Clean Architecture Refactor - Activity Suggestions

## Cấu trúc mới

### Application Layer
```
Application/
├── DTOs/
│   └── SuggestionDto.cs          # DTO cho API response
├── Recommendation/
│   ├── SuggestionContext.cs      # Context chứa thông tin để tính điểm
│   ├── ISuggestionRuleEngine.cs  # Interface cho rule engine
│   └── SuggestionRuleEngine.cs   # Logic tính điểm (tách riêng để dễ test)
├── Interfaces/
│   ├── ISuggestionRepository.cs  # Interface cho data access
│   └── ISuggestionService.cs     # Interface cho business logic
└── Services/
    └── SuggestionService.cs       # Service ghép data + gọi rule engine
```

### Infrastructure Layer
```
Infrastructure/
├── Repositories/
│   └── EfSuggestionRepository.cs # EF Core implementation
└── Weather/
    ├── IWeatherService.cs        # Interface cho weather service
    └── OpenWeatherService.cs      # OpenWeatherMap implementation
```

### Controllers
```
Controllers/
└── SuggestionsController.cs       # Thin controller, chỉ gọi service
```

## Lợi ích

1. **Tách biệt concerns**: Logic tính điểm tách riêng khỏi data access
2. **Dễ test**: RuleEngine có thể test độc lập không cần database
3. **Dễ mở rộng**: Thêm rule mới chỉ cần sửa SuggestionRuleEngine
4. **Dễ maintain**: Code được tổ chức rõ ràng theo từng layer

## Dependency Injection

Đã đăng ký trong `Program.cs`:
```csharp
builder.Services.AddScoped<ISuggestionRepository, EfSuggestionRepository>();
builder.Services.AddScoped<ISuggestionRuleEngine, SuggestionRuleEngine>();
builder.Services.AddScoped<ISuggestionService, SuggestionService>();
builder.Services.AddHttpClient<IWeatherService, OpenWeatherService>();
```

## API Endpoints

- `GET /api/Suggestions/my-suggestions` - Gợi ý cho cư dân hiện tại
- `GET /api/Suggestions/resident/{residentId}` - Gợi ý cho cư dân cụ thể (Manager/Admin)
- `GET /api/Suggestions/test/{residentId}` - Test endpoint (không cần auth)
- `GET /api/Suggestions/test/residents` - Lấy danh sách residents để test

## Response Format

```json
{
  "suggestions": [
    {
      "code": "PAY_SERVICE_BILL",
      "title": "Thanh toán phí dịch vụ tháng này",
      "description": "...",
      "tags": "tai_chinh,bat_buoc,buoi_sang",
      "score": 130.0,
      "priority": 5
    }
  ]
}
```

## Priority Mapping

- Priority 5: Score ≥ 100 (Rất quan trọng - đỏ)
- Priority 4: Score ≥ 70 (Quan trọng - cam)
- Priority 3: Score ≥ 40 (Bình thường - xanh dương)
- Priority 2: Score ≥ 20 (Thấp - xám)
- Priority 1: Score < 20 (Rất thấp - xám nhạt)

## Testing

Để test RuleEngine, có thể tạo test project:

```bash
dotnet new xunit -n ICitizen.Tests
dotnet add ICitizen.Tests reference ICitizen
```

Sau đó viết test cho `SuggestionRuleEngine.BuildSuggestions()` với mock context.

