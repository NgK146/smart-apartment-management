using System.Threading.Tasks;

namespace ICitizen.Services;

public interface ISmsSender
{
    Task SendAsync(string phoneNumber, string message);
}


