namespace ICitizen.Auth;

public record RegisterDto(string Username, string Password, string FullName, string Email, string PhoneNumber);
public record LoginDto(string Username, string Password);
public record AuthResponse(string AccessToken, string Username, string FullName, string[] Roles);
