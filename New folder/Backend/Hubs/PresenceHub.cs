using Microsoft.AspNetCore.SignalR;
using PTVBTPM.Helper;
using System;
using System.Collections.Concurrent;
using System.Threading.Tasks;

namespace PTVBTPM.Hubs
{
    public class PresenceHub : Hub
    {
        // simple in-memory last heartbeat map
        private static readonly ConcurrentDictionary<int, DateTime> LastHeartbeat = new();

        public override Task OnConnectedAsync()
        {
            Console.WriteLine($"[PresenceHub] Connected: {Context.ConnectionId}");
            try
            {
                var http = Context.GetHttpContext();
                if (http != null)
                {
                    Console.WriteLine($"[PresenceHub] HttpContext available for connection {Context.ConnectionId}");
                }
                else
                {
                    Console.WriteLine($"[PresenceHub] HttpContext is null for connection {Context.ConnectionId}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[PresenceHub] Error getting HttpContext: {ex.Message}");
            }
            return base.OnConnectedAsync();
        }

        public override Task OnDisconnectedAsync(Exception? exception)
        {
            Console.WriteLine($"[PresenceHub] Disconnected: {Context.ConnectionId}");
            return base.OnDisconnectedAsync(exception);
        }

        // Client calls this periodically to indicate user is active
        public async Task Heartbeat()
        {
            try
            {
                var http = Context.GetHttpContext();
                if (http == null)
                {
                    Console.WriteLine($"[PresenceHub] HttpContext is null during Heartbeat from {Context.ConnectionId}");
                    return;
                }

                var userId = AuthHelper.GetCurrentUserId(http);
                if (userId.HasValue)
                {
                    LastHeartbeat[userId.Value] = DateTime.UtcNow;
                    Console.WriteLine($"[PresenceHub] Heartbeat from user {userId.Value}");
                    await Clients.All.SendAsync("UserActive", userId.Value);
                }
                else
                {
                    Console.WriteLine($"[PresenceHub] Heartbeat from unauthenticated user (connection {Context.ConnectionId})");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[PresenceHub] Error in Heartbeat: {ex.Message}");
            }
        }
    }
}


