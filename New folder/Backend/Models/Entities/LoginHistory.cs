using System;
using System.Collections.Generic;

namespace PTVBTPM.Models.Entities;

public partial class LoginHistory
{
    public int LoginId { get; set; }

    public int? UserId { get; set; }

    public DateTime? LoginTime { get; set; }

    public string? IpAddress { get; set; }

    public string? Device { get; set; }

    /// <summary>
    /// Additional description/message for the login event (e.g. failure reason)
    /// </summary>
    public string? Description { get; set; }

    public DateTime? CreatedOn { get; set; }

    public string? CreatedBy { get; set; }

    public virtual User? User { get; set; }
}
