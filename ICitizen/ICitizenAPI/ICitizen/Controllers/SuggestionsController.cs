using ICitizen.Application.Interfaces;
using ICitizen.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SuggestionsController : ControllerBase
{
    private readonly ISuggestionService _suggestionService;
    private readonly ApplicationDbContext _db;

    public SuggestionsController(ISuggestionService suggestionService, ApplicationDbContext db)
    {
        _suggestionService = suggestionService;
        _db = db;
    }

    /// <summary>
    /// Lấy danh sách gợi ý hoạt động cho cư dân hiện tại
    /// </summary>
    [HttpGet("my-suggestions")]
    public async Task<IActionResult> GetMySuggestions()
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userId))
            return Unauthorized(new { message = "User not authenticated" });

        var resident = await _db.ResidentProfiles
            .Include(r => r.Apartment)
            .FirstOrDefaultAsync(r => r.UserId == userId);

        if (resident == null)
            return NotFound(new { message = "Resident profile not found" });

        var suggestions = await _suggestionService.GetSuggestionsAsync(resident.Id);
        return Ok(new { 
            residentId = resident.Id,
            residentName = resident.Apartment?.Code,
            building = resident.Building ?? resident.Apartment?.Building,
            floor = resident.Floor ?? resident.Apartment?.Floor,
            age = resident.Age,
            lifeStyle = resident.LifeStyle,
            suggestions 
        });
    }

    /// <summary>
    /// Lấy danh sách gợi ý hoạt động cho một cư dân cụ thể (admin/manager)
    /// </summary>
    [HttpGet("resident/{residentId}")]
    [Authorize(Roles = "Manager,Admin")]
    public async Task<IActionResult> GetSuggestionsForResident(Guid residentId)
    {
        var suggestions = await _suggestionService.GetSuggestionsAsync(residentId);
        return Ok(new { suggestions });
    }

    /// <summary>
    /// Test endpoint - không cần auth (chỉ dùng trong development)
    /// </summary>
    [HttpGet("test/{residentId}")]
    [AllowAnonymous]
    public async Task<IActionResult> TestSuggestions(Guid residentId)
    {
        try
        {
            var suggestions = await _suggestionService.GetSuggestionsAsync(residentId);
            return Ok(new
            {
                suggestions = suggestions.OrderByDescending(s => s.Score).ToList(),
                summary = new
                {
                    total = suggestions.Count,
                    topScore = suggestions.Any() ? suggestions.Max(s => s.Score) : 0,
                    averageScore = suggestions.Any() ? suggestions.Average(s => s.Score) : 0
                }
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message, stackTrace = ex.StackTrace });
        }
    }

    /// <summary>
    /// Lấy danh sách tất cả residents để test
    /// </summary>
    [HttpGet("test/residents")]
    [AllowAnonymous]
    public async Task<IActionResult> GetTestResidents()
    {
        var residents = await _db.ResidentProfiles
            .Include(r => r.Apartment)
            .Select(r => new
            {
                id = r.Id,
                apartmentCode = r.Apartment != null ? r.Apartment.Code : null,
                building = r.Building ?? (r.Apartment != null ? r.Apartment.Building : null),
                floor = r.Floor ?? (r.Apartment != null ? r.Apartment.Floor : 0),
                age = r.Age,
                lifeStyle = r.LifeStyle,
                userId = r.UserId
            })
            .ToListAsync();

        return Ok(new { residents, count = residents.Count });
    }
}
