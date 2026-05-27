using Microsoft.AspNetCore.SignalR;

namespace PTVBTPM.Hubs
{
    /// <summary>
    /// SignalR Hub để gửi thông báo thanh toán real-time
    /// Client sẽ subscribe vào group theo gencode để nhận notification
    /// </summary>
    public class PaymentHub : Hub
    {
        /// <summary>
        /// Client join vào group theo gencode để nhận notification
        /// </summary>
        public async Task JoinPaymentGroup(string gencode)
        {
            if (!string.IsNullOrWhiteSpace(gencode))
            {
                var groupName = $"payment_{gencode}";
                Console.WriteLine($"[PaymentHub] Client {Context.ConnectionId} joining group: {groupName}");
                await Groups.AddToGroupAsync(Context.ConnectionId, groupName);
                await Clients.Caller.SendAsync("JoinedGroup", gencode);
                Console.WriteLine($"[PaymentHub] Client {Context.ConnectionId} successfully joined group: {groupName}");
            }
            else
            {
                Console.WriteLine($"[PaymentHub] Warning: Client {Context.ConnectionId} attempted to join with empty gencode");
            }
        }

        /// <summary>
        /// Client leave khỏi group
        /// </summary>
        public async Task LeavePaymentGroup(string gencode)
        {
            if (!string.IsNullOrWhiteSpace(gencode))
            {
                var groupName = $"payment_{gencode}";
                Console.WriteLine($"[PaymentHub] Client {Context.ConnectionId} leaving group: {groupName}");
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);
                Console.WriteLine($"[PaymentHub] Client {Context.ConnectionId} successfully left group: {groupName}");
            }
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            if (exception != null)
            {
                Console.WriteLine($"[PaymentHub] Client {Context.ConnectionId} disconnected with error: {exception.Message}");
            }
            else
            {
                Console.WriteLine($"[PaymentHub] Client {Context.ConnectionId} disconnected normally");
            }
            await base.OnDisconnectedAsync(exception);
        }
    }
}

