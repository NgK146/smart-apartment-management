using System.Net.Http;
using System.Threading.Tasks;

namespace ICitizen.Services;

/// <summary>
/// Giả lập tìm địa điểm gần nhất (không cần Google Maps API key).
/// </summary>
public sealed class GooglePlacesService
{
    private readonly HttpClient _httpClient;
    // Để trống hoặc điền gì cũng được, vì ta đang giả lập
    private const string ApiKey = "FAKE_KEY_FOR_TESTING";

    public GooglePlacesService(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    /// <summary>
    /// Giả lập tìm địa điểm gần nhất dựa trên keyword.
    /// </summary>
    public async Task<string> SearchNearbyPlaces(double lat, double lng, string keyword)
    {
        // GIẢ LẬP: Thay vì gọi Google, ta tự trả về dữ liệu ảo dựa trên từ khóa
        // Cách này giúp bạn test luồng AI mà không tốn tiền/không cần thẻ.

        await Task.Delay(500); // Giả vờ đợi mạng lag 0.5s cho giống thật

        var fakePlaces = new List<string>();

        if (keyword.ToLower().Contains("coffee") || keyword.ToLower().Contains("cà phê"))
        {
            fakePlaces.Add($"- Highlands Coffee (Cách 50m): 4.5 sao. Ngay sảnh tòa nhà, máy lạnh mát.");
            fakePlaces.Add($"- The Coffee House (Cách 200m): 4.2 sao. Không gian yên tĩnh, nhạc hay.");
            fakePlaces.Add($"- Cà phê Cóc Bà Tám (Cách 10m): 5.0 sao. Thoáng mát, giá rẻ.");
        }
        else if (keyword.ToLower().Contains("gym"))
        {
            fakePlaces.Add($"- California Fitness (Cách 500m): 4.8 sao. Đầy đủ máy móc, có hồ bơi.");
            fakePlaces.Add($"- City Gym Bình Dân (Cách 100m): 4.0 sao. Giá rẻ, hơi đông.");
        }
        else
        {
            fakePlaces.Add($"- Công viên nội khu (Cách 20m): Thoáng đãng, nhiều cây xanh.");
            fakePlaces.Add($"- Siêu thị WinMart (Cách 50m): Tiện mua sắm.");
        }

        return string.Join("\n", fakePlaces);
    }
}

