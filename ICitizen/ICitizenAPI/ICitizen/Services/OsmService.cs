using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using ICitizen.Models;
using Newtonsoft.Json.Linq;

namespace ICitizen.Services;

/// <summary>
/// Lấy địa điểm thật từ OpenStreetMap (miễn phí, không cần API key).
/// </summary>
public sealed class OsmService
{
    private readonly HttpClient _httpClient;

    public OsmService(HttpClient httpClient)
    {
        _httpClient = httpClient;
        // OSM yêu cầu User-Agent, không có dòng này là bị chặn
        _httpClient.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("ICitizenApp", "1.0"));
    }

    /// <summary>
    /// Lấy danh sách địa điểm dạng List&lt;PlaceInfo&gt; để Flutter có thể mở Google Maps.
    /// </summary>
    public async Task<List<PlaceInfo>> GetNearbyPlacesListAsync(double lat, double lng, string interestKeyword)
    {
        double offset = 0.02;
        var searchQueries = new[]
        {
            interestKeyword,
            "cafe",
            "restaurant",
            "shop"
        };

        try
        {
            var allPlaces = new List<PlaceInfo>();
            
            foreach (var query in searchQueries)
            {
                string url = $"https://nominatim.openstreetmap.org/search?q={Uri.EscapeDataString(query)}&format=json&viewbox={lng - offset},{lat + offset},{lng + offset},{lat - offset}&bounded=1&limit=5&addressdetails=1";
                
                try
                {
                    var res = await _httpClient.GetStringAsync(url);
                    var json = JArray.Parse(res);
                    
                    foreach (var item in json)
                    {
                        var name = item["name"]?.ToString();
                        if (string.IsNullOrEmpty(name))
                        {
                            var displayName = item["display_name"]?.ToString();
                            if (!string.IsNullOrEmpty(displayName))
                            {
                                var parts = displayName.Split(',');
                                name = parts[0].Trim();
                            }
                        }
                        
                        if (string.IsNullOrEmpty(name)) continue;
                        
                        // Lấy địa chỉ đầy đủ hoặc ngắn gọn
                        var address = item["address"] as JObject;
                        var addressParts = new List<string>();
                        if (address != null)
                        {
                            if (address["road"] != null) addressParts.Add(address["road"].ToString());
                            if (address["suburb"] != null) addressParts.Add(address["suburb"].ToString());
                            else if (address["ward"] != null) addressParts.Add(address["ward"].ToString());
                        }
                        
                        var shortAddress = addressParts.Count > 0 ? string.Join(", ", addressParts) : item["display_name"]?.ToString() ?? "";
                        
                        // Parse lat/lng
                        if (double.TryParse(item["lat"]?.ToString(), out var placeLat) &&
                            double.TryParse(item["lon"]?.ToString(), out var placeLng))
                        {
                            var placeInfo = new PlaceInfo
                            {
                                Name = name,
                                Address = shortAddress,
                                Lat = placeLat,
                                Lng = placeLng
                            };
                            
                            // Tránh trùng lặp (so sánh theo tên)
                            if (!allPlaces.Any(p => p.Name == placeInfo.Name))
                            {
                                allPlaces.Add(placeInfo);
                            }
                        }
                        
                        if (allPlaces.Count >= 5) break;
                    }
                    
                    if (allPlaces.Count >= 5) break;
                    await Task.Delay(500);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[OSM Error] Query '{query}': {ex.Message}");
                    continue;
                }
            }
            
            if (allPlaces.Count == 0)
            {
                // Fallback: Trả về địa điểm giả lập
                return GetFallbackPlacesList(interestKeyword, lat, lng);
            }
            
            return allPlaces;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[OSM Error] {ex.Message}");
            return GetFallbackPlacesList(interestKeyword, lat, lng);
        }
    }

    private List<PlaceInfo> GetFallbackPlacesList(string keyword, double lat, double lng)
    {
        var lowerKeyword = keyword.ToLower();
        var places = new List<PlaceInfo>();
        
        if (lowerKeyword.Contains("coffee") || lowerKeyword.Contains("cà phê") || lowerKeyword.Contains("cafe"))
        {
            places.Add(new PlaceInfo { Name = "Highlands Coffee", Address = "Gần đây", Lat = lat + 0.001, Lng = lng + 0.001 });
            places.Add(new PlaceInfo { Name = "The Coffee House", Address = "Cách 200m", Lat = lat + 0.002, Lng = lng + 0.002 });
            places.Add(new PlaceInfo { Name = "Cà phê Cóc Bà Tám", Address = "Cách 10m", Lat = lat + 0.0001, Lng = lng + 0.0001 });
        }
        else if (lowerKeyword.Contains("gym") || lowerKeyword.Contains("thể dục"))
        {
            places.Add(new PlaceInfo { Name = "California Fitness", Address = "Cách 500m", Lat = lat + 0.005, Lng = lng + 0.005 });
            places.Add(new PlaceInfo { Name = "City Gym Bình Dân", Address = "Cách 100m", Lat = lat + 0.001, Lng = lng + 0.001 });
        }
        else if (lowerKeyword.Contains("restaurant") || lowerKeyword.Contains("nhà hàng") || lowerKeyword.Contains("ăn"))
        {
            places.Add(new PlaceInfo { Name = "Nhà hàng Ngon", Address = "Cách 100m", Lat = lat + 0.001, Lng = lng + 0.001 });
            places.Add(new PlaceInfo { Name = "Pizza Hut", Address = "Cách 200m", Lat = lat + 0.002, Lng = lng + 0.002 });
        }
        else
        {
            places.Add(new PlaceInfo { Name = "Công viên nội khu", Address = "Cách 20m", Lat = lat + 0.0002, Lng = lng + 0.0002 });
            places.Add(new PlaceInfo { Name = "Siêu thị WinMart", Address = "Cách 50m", Lat = lat + 0.0005, Lng = lng + 0.0005 });
        }
        
        return places;
    }

    /// <summary>
    /// Method cũ (giữ lại để tương thích với endpoint ask-ai-location).
    /// </summary>
    public async Task<string> GetNearbyPlacesAsync(double lat, double lng, string interestKeyword)
    {
        // Tạo hộp tìm kiếm bán kính ~2km (tăng từ 1km)
        double offset = 0.02;
        
        // Thử nhiều cách tìm kiếm khác nhau
        var searchQueries = new[]
        {
            interestKeyword, // Từ khóa gốc
            "cafe", // Thử tiếng Anh
            "restaurant", // Nhà hàng
            "shop" // Cửa hàng
        };

        try
        {
            var allPlaces = new List<string>();
            
            foreach (var query in searchQueries)
            {
                // Tìm kiếm trong viewbox (hộp giới hạn)
                string url = $"https://nominatim.openstreetmap.org/search?q={Uri.EscapeDataString(query)}&format=json&viewbox={lng - offset},{lat + offset},{lng + offset},{lat - offset}&bounded=1&limit=5&addressdetails=1";
                
                try
                {
                    var res = await _httpClient.GetStringAsync(url);
                    var json = JArray.Parse(res);
                    
                    foreach (var item in json)
                    {
                        // Lấy tên địa điểm (ưu tiên name, nếu không có thì lấy từ display_name)
                        var name = item["name"]?.ToString();
                        if (string.IsNullOrEmpty(name))
                        {
                            // Nếu không có name, lấy phần đầu của display_name (trước dấu phẩy đầu tiên)
                            var displayName = item["display_name"]?.ToString();
                            if (!string.IsNullOrEmpty(displayName))
                            {
                                var parts = displayName.Split(',');
                                name = parts[0].Trim();
                            }
                        }
                        
                        if (string.IsNullOrEmpty(name)) continue;
                        
                        // Lấy địa chỉ ngắn gọn (chỉ lấy road và ward/suburb)
                        var address = item["address"] as JObject;
                        var addressParts = new List<string>();
                        if (address != null)
                        {
                            if (address["road"] != null) addressParts.Add(address["road"].ToString());
                            if (address["suburb"] != null) addressParts.Add(address["suburb"].ToString());
                            else if (address["ward"] != null) addressParts.Add(address["ward"].ToString());
                        }
                        
                        // Format: "Tên địa điểm - Đường ABC, Phường XYZ" hoặc chỉ "Tên địa điểm"
                        var shortAddress = addressParts.Count > 0 ? $" - {string.Join(", ", addressParts)}" : "";
                        var placeInfo = $"- {name}{shortAddress}";
                        
                        // Tránh trùng lặp
                        if (!allPlaces.Contains(placeInfo))
                        {
                            allPlaces.Add(placeInfo);
                        }
                        
                        if (allPlaces.Count >= 5) break; // Giới hạn 5 địa điểm
                    }
                    
                    if (allPlaces.Count >= 5) break;
                    
                    // Delay để tránh rate limit của OSM
                    await Task.Delay(500);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[OSM Error] Query '{query}': {ex.Message}");
                    continue;
                }
            }
            
            if (allPlaces.Count == 0)
            {
                // Fallback: Trả về địa điểm giả lập dựa trên keyword
                return GetFallbackPlaces(interestKeyword);
            }
            
            return string.Join("\n", allPlaces);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[OSM Error] {ex.Message}");
            return GetFallbackPlaces(interestKeyword);
        }
    }
    
    private string GetFallbackPlaces(string keyword)
    {
        var lowerKeyword = keyword.ToLower();
        
        if (lowerKeyword.Contains("coffee") || lowerKeyword.Contains("cà phê") || lowerKeyword.Contains("cafe"))
        {
            return "- Highlands Coffee (Gần đây): 4.5 sao. Ngay sảnh tòa nhà, máy lạnh mát.\n- The Coffee House (Cách 200m): 4.2 sao. Không gian yên tĩnh, nhạc hay.\n- Cà phê Cóc Bà Tám (Cách 10m): 5.0 sao. Thoáng mát, giá rẻ.";
        }
        else if (lowerKeyword.Contains("gym") || lowerKeyword.Contains("thể dục"))
        {
            return "- California Fitness (Cách 500m): 4.8 sao. Đầy đủ máy móc, có hồ bơi.\n- City Gym Bình Dân (Cách 100m): 4.0 sao. Giá rẻ, hơi đông.";
        }
        else if (lowerKeyword.Contains("restaurant") || lowerKeyword.Contains("nhà hàng") || lowerKeyword.Contains("ăn"))
        {
            return "- Nhà hàng Ngon (Cách 100m): 4.5 sao. Món Việt Nam đặc sắc.\n- Pizza Hut (Cách 200m): 4.0 sao. Pizza ngon, giá hợp lý.";
        }
        else
        {
            return "- Công viên nội khu (Cách 20m): Thoáng đãng, nhiều cây xanh.\n- Siêu thị WinMart (Cách 50m): Tiện mua sắm.\n- Trung tâm thương mại (Cách 100m): Nhiều cửa hàng đa dạng.";
        }
    }
}

