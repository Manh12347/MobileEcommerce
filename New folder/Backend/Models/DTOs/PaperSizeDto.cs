namespace PTVBTPM.Models.DTOs;

public class PaperSizeDto
{
    public int PaperSizeId { get; set; }
    public string Code { get; set; } = string.Empty;
    public string? Description { get; set; }
    public decimal? Price { get; set; }
}

