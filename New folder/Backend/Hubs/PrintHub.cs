using Microsoft.AspNetCore.SignalR;

namespace PTVBTPM.Hubs
{
    /// <summary>
    /// SignalR Hub để gửi thông báo real-time về trạng thái in ấn:
    /// - Trạng thái máy in
    /// - Tài liệu đang in
    /// - Tiến trình in tài liệu
    /// </summary>
    public class PrintHub : Hub
    {
        /// <summary>
        /// Client join vào group theo userId để nhận notification về print jobs của mình
        /// </summary>
        public async Task JoinUserPrintGroup(int userId)
        {
            if (userId > 0)
            {
                var groupName = $"user_print_{userId}";
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} joining group: {groupName}");
                await Groups.AddToGroupAsync(Context.ConnectionId, groupName);
                await Clients.Caller.SendAsync("JoinedUserGroup", userId);
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} successfully joined group: {groupName}");
            }
            else
            {
                Console.WriteLine($"[PrintHub] Warning: Client {Context.ConnectionId} attempted to join with invalid userId: {userId}");
            }
        }

        /// <summary>
        /// Client leave khỏi user print group
        /// </summary>
        public async Task LeaveUserPrintGroup(int userId)
        {
            if (userId > 0)
            {
                var groupName = $"user_print_{userId}";
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} leaving group: {groupName}");
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} successfully left group: {groupName}");
            }
        }

        /// <summary>
        /// Client join vào group theo printerId để nhận notification về trạng thái máy in
        /// </summary>
        public async Task JoinPrinterGroup(int printerId)
        {
            if (printerId > 0)
            {
                var groupName = $"printer_{printerId}";
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} joining group: {groupName}");
                await Groups.AddToGroupAsync(Context.ConnectionId, groupName);
                await Clients.Caller.SendAsync("JoinedPrinterGroup", printerId);
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} successfully joined group: {groupName}");
            }
            else
            {
                Console.WriteLine($"[PrintHub] Warning: Client {Context.ConnectionId} attempted to join with invalid printerId: {printerId}");
            }
        }

        /// <summary>
        /// Client leave khỏi printer group
        /// </summary>
        public async Task LeavePrinterGroup(int printerId)
        {
            if (printerId > 0)
            {
                var groupName = $"printer_{printerId}";
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} leaving group: {groupName}");
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} successfully left group: {groupName}");
            }
        }

        /// <summary>
        /// Client join vào group theo printJobId để nhận notification về tiến trình in cụ thể
        /// </summary>
        public async Task JoinPrintJobGroup(int printJobId)
        {
            if (printJobId > 0)
            {
                var groupName = $"printjob_{printJobId}";
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} joining group: {groupName}");
                await Groups.AddToGroupAsync(Context.ConnectionId, groupName);
                await Clients.Caller.SendAsync("JoinedPrintJobGroup", printJobId);
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} successfully joined group: {groupName}");
            }
            else
            {
                Console.WriteLine($"[PrintHub] Warning: Client {Context.ConnectionId} attempted to join with invalid printJobId: {printJobId}");
            }
        }

        /// <summary>
        /// Client leave khỏi print job group
        /// </summary>
        public async Task LeavePrintJobGroup(int printJobId)
        {
            if (printJobId > 0)
            {
                var groupName = $"printjob_{printJobId}";
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} leaving group: {groupName}");
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} successfully left group: {groupName}");
            }
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            if (exception != null)
            {
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} disconnected with error: {exception.Message}");
            }
            else
            {
                Console.WriteLine($"[PrintHub] Client {Context.ConnectionId} disconnected normally");
            }
            await base.OnDisconnectedAsync(exception);
        }
    }
}

