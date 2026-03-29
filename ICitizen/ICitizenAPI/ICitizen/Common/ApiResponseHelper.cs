using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;

namespace ICitizen.Common;

/// <summary>
/// Helper class để xử lý response và error handling cho API
/// </summary>
public static class ApiResponseHelper
{
    /// <summary>
    /// Xử lý exception và trả về response an toàn (không expose thông tin nhạy cảm)
    /// </summary>
    public static IActionResult HandleException(Exception ex, string userMessage, ILogger? logger = null)
    {
        // Log chi tiết cho dev/internal
        logger?.LogError(ex, "API Error: {Message}", ex.Message);
        
        // Trong production, chỉ trả message chung chung
        var isDevelopment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") == "Development";
        
        return new ObjectResult(new
        {
            error = userMessage,
            message = isDevelopment ? ex.Message : null, // Chỉ show detail trong dev
            stackTrace = isDevelopment ? ex.StackTrace : null // Chỉ show stack trace trong dev
        })
        {
            StatusCode = 500
        };
    }

    /// <summary>
    /// Validate ModelState và trả về BadRequest nếu có lỗi
    /// </summary>
    public static IActionResult? ValidateModelState(ActionContext context)
    {
        if (!context.ModelState.IsValid)
        {
            var errors = context.ModelState
                .Where(x => x.Value?.Errors.Count > 0)
                .SelectMany(x => x.Value!.Errors.Select(e => new
                {
                    field = x.Key,
                    message = e.ErrorMessage
                }))
                .ToList();

            return new BadRequestObjectResult(new
            {
                error = "Dữ liệu không hợp lệ",
                errors
            });
        }
        return null;
    }
}



