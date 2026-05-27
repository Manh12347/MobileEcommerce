using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace PTVBTPM.Models.Entities;

public partial class WebDbContext : DbContext
{
    private readonly IConfiguration? _configuration;

    public WebDbContext()
    {
    }

    public WebDbContext(DbContextOptions<WebDbContext> options, IConfiguration? configuration = null)
        : base(options)
    {
        _configuration = configuration;
    }

    public virtual DbSet<BankTransaction> BankTransactions { get; set; }

    public virtual DbSet<Document> Documents { get; set; }

    public virtual DbSet<LoginHistory> LoginHistories { get; set; }

    public virtual DbSet<PaperSize> PaperSizes { get; set; }

    public virtual DbSet<PrintJob> PrintJobs { get; set; }


    public virtual DbSet<Printer> Printers { get; set; }

    public virtual DbSet<PrinterCapability> PrinterCapabilities { get; set; }

    public virtual DbSet<Ink> Inks { get; set; }

    public virtual DbSet<PurchaseTransaction> PurchaseTransactions { get; set; }

    public virtual DbSet<User> Users { get; set; }

    public virtual DbSet<SystemConfig> SystemConfigs { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        if (!optionsBuilder.IsConfigured)
        {
            if (_configuration != null)
            {
                var connectionString = _configuration.GetConnectionString("DefaultConnection");
                if (!string.IsNullOrEmpty(connectionString))
                {
                    optionsBuilder.UseNpgsql(connectionString);
                }
            }
        }
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<BankTransaction>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("bank_transactions_pkey");

            entity.ToTable("bank_transactions", tb => tb.HasComment("Bảng lưu giao dịch ngân hàng từ webhook"));

            entity.HasIndex(e => e.Accountnumber, "idx_bank_transactions_accountnumber");

            entity.HasIndex(e => e.Gateway, "idx_bank_transactions_gateway");

            entity.HasIndex(e => e.Referencecode, "idx_bank_transactions_referencecode");

            entity.HasIndex(e => e.Transactiondate, "idx_bank_transactions_transactiondate").IsDescending();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Accountnumber)
                .HasMaxLength(50)
                .HasColumnName("accountnumber");
            entity.Property(e => e.Accumulated)
                .HasPrecision(18, 2)
                .HasColumnName("accumulated");
            entity.Property(e => e.Code)
                .HasMaxLength(255)
                .HasColumnName("code");
            entity.Property(e => e.Content).HasColumnName("content");
            entity.Property(e => e.CreatedBy)
                .HasMaxLength(100)
                .HasColumnName("created_by");
            entity.Property(e => e.CreatedOn)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp with time zone")
                .HasColumnName("created_on");
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.Gateway)
                .HasMaxLength(100)
                .HasColumnName("gateway");
            entity.Property(e => e.ModifiedBy)
                .HasMaxLength(100)
                .HasColumnName("modified_by");
            entity.Property(e => e.ModifiedOn)
                .HasColumnType("timestamp with time zone")
                .HasColumnName("modified_on");
            entity.Property(e => e.Referencecode)
                .HasMaxLength(255)
                .HasColumnName("referencecode");
            entity.Property(e => e.Subaccount)
                .HasMaxLength(50)
                .HasColumnName("subaccount");
            entity.Property(e => e.Transactiondate)
                .HasColumnType("timestamp with time zone")
                .HasColumnName("transactiondate");
            entity.Property(e => e.Transferamount)
                .HasPrecision(18, 2)
                .HasColumnName("transferamount");
            entity.Property(e => e.Transfertype)
                .HasMaxLength(10)
                .HasColumnName("transfertype");
        });

        modelBuilder.Entity<Document>(entity =>
        {
            entity.HasKey(e => e.DocumentId).HasName("documents_pkey");

            entity.ToTable("documents", tb => tb.HasComment("Bảng lưu tài liệu in"));

            entity.HasIndex(e => e.UserId, "idx_documents_user");

            entity.Property(e => e.DocumentId)
                .HasColumnName("document_id")
                .ValueGeneratedOnAdd();
            entity.Property(e => e.CreatedBy)
                .HasMaxLength(100)
                .HasColumnName("created_by");
            entity.Property(e => e.CreatedOn)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_on");
            entity.Property(e => e.FileName)
                .HasMaxLength(255)
                .HasColumnName("file_name");
            entity.Property(e => e.FileSize).HasColumnName("file_size");
            entity.Property(e => e.FileType)
                .HasMaxLength(20)
                .HasColumnName("file_type");
            entity.Property(e => e.ModifiedBy)
                .HasMaxLength(100)
                .HasColumnName("modified_by");
            entity.Property(e => e.ModifiedOn)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("modified_on");
            entity.Property(e => e.PageCount).HasColumnName("page_count");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .HasDefaultValueSql("'UPLOADED'::character varying")
                .HasColumnName("status");
            entity.Property(e => e.UploadPath).HasColumnName("upload_path");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.User).WithMany(p => p.Documents)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.Cascade)
                .HasConstraintName("documents_user_id_fkey");
        });

        modelBuilder.Entity<LoginHistory>(entity =>
        {
            entity.HasKey(e => e.LoginId).HasName("login_history_pkey");

            entity.ToTable("login_history");

            entity.Property(e => e.LoginId)
                .HasColumnName("login_id")
                .ValueGeneratedOnAdd();
            entity.Property(e => e.CreatedBy)
                .HasMaxLength(100)
                .HasColumnName("created_by");
            entity.Property(e => e.CreatedOn)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_on");
            entity.Property(e => e.Device)
                .HasMaxLength(100)
                .HasColumnName("device");
            entity.Property(e => e.IpAddress)
                .HasMaxLength(50)
                .HasColumnName("ip_address");
            entity.Property(e => e.Description)
                .HasColumnType("text")
                .HasColumnName("description");
            entity.Property(e => e.LoginTime)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("login_time");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.User).WithMany(p => p.LoginHistories)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("login_history_user_id_fkey");
        });

        modelBuilder.Entity<PaperSize>(entity =>
        {
            entity.HasKey(e => e.PaperSizeId).HasName("paper_sizes_pkey");

            entity.ToTable("paper_sizes", tb => tb.HasComment("Danh mục khổ giấy in (A0–A4)"));

            entity.HasIndex(e => e.Code, "paper_sizes_code_key").IsUnique();

            entity.Property(e => e.PaperSizeId)
                .HasColumnName("paper_size_id")
                .ValueGeneratedOnAdd();
            entity.Property(e => e.Code)
                .HasMaxLength(10)
                .HasColumnName("code");
            entity.Property(e => e.CreatedBy)
                .HasMaxLength(100)
                .HasColumnName("created_by");
            entity.Property(e => e.CreatedOn)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_on");
            entity.Property(e => e.Description)
                .HasMaxLength(255)
                .HasColumnName("description");
            entity.Property(e => e.Price)
                .HasPrecision(10, 2)
                .HasColumnName("price");
            entity.Property(e => e.ModifiedBy)
                .HasMaxLength(100)
                .HasColumnName("modified_by");
            entity.Property(e => e.ModifiedOn)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("modified_on");
        });

        modelBuilder.Entity<PrintJob>(entity =>
        {
            entity.HasKey(e => e.PrintJobId).HasName("print_jobs_pkey");

            entity.ToTable("print_jobs", tb => tb.HasComment("Quản lý job in và lịch sử in"));

            entity.HasIndex(e => e.PrinterId, "idx_print_jobs_printer");

            entity.HasIndex(e => e.Status, "idx_print_jobs_status");

            entity.HasIndex(e => e.UserId, "idx_print_jobs_user");

            entity.Property(e => e.PrintJobId)
                .HasColumnName("print_job_id")
                .ValueGeneratedOnAdd();
            entity.Property(e => e.CompletedAt)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("completed_at");
            entity.Property(e => e.Copies)
                .HasDefaultValue(1)
                .HasColumnName("copies");
            entity.Property(e => e.CreatedBy)
                .HasMaxLength(100)
                .HasColumnName("created_by");
            entity.Property(e => e.CreatedOn)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_on");
            entity.Property(e => e.DocumentId).HasColumnName("document_id");
            entity.Property(e => e.IsColor)
                .HasDefaultValue(false)
                .HasColumnName("is_color");
            entity.Property(e => e.ModifiedBy)
                .HasMaxLength(100)
                .HasColumnName("modified_by");
            entity.Property(e => e.ModifiedOn)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("modified_on");
            entity.Property(e => e.PagesToPrint)
                .HasMaxLength(50)
                .HasColumnName("pages_to_print");
            entity.Property(e => e.PaperSizeId).HasColumnName("paper_size_id");
            entity.Property(e => e.PrinterId).HasColumnName("printer_id");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .HasDefaultValueSql("'PENDING'::character varying")
                .HasColumnName("status");
            entity.Property(e => e.TotalPages).HasColumnName("total_pages");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.Document).WithMany(p => p.PrintJobs)
                .HasForeignKey(d => d.DocumentId)
                .HasConstraintName("print_jobs_document_id_fkey");

            entity.HasOne(d => d.PaperSize).WithMany(p => p.PrintJobs)
                .HasForeignKey(d => d.PaperSizeId)
                .HasConstraintName("print_jobs_paper_size_id_fkey");

            entity.HasOne(d => d.Printer).WithMany(p => p.PrintJobs)
                .HasForeignKey(d => d.PrinterId)
                .HasConstraintName("print_jobs_printer_id_fkey");

            entity.HasOne(d => d.User).WithMany(p => p.PrintJobs)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("print_jobs_user_id_fkey");
        });


        modelBuilder.Entity<Printer>(entity =>
        {
            entity.HasKey(e => e.PrinterId).HasName("printers_pkey");

            entity.ToTable("printers", tb => tb.HasComment("Danh sách máy in trong hệ thống"));

            entity.HasIndex(e => e.PrinterCode, "printers_printer_code_key").IsUnique();

            entity.Property(e => e.PrinterId)
                .HasColumnName("printer_id")
                .ValueGeneratedOnAdd();
            entity.Property(e => e.Brand)
                .HasMaxLength(50)
                .HasColumnName("brand");
            
            entity.Property(e => e.CreatedBy)
                .HasMaxLength(100)
                .HasColumnName("created_by");
            entity.Property(e => e.CreatedOn)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_on");
            entity.Property(e => e.Location)
                .HasMaxLength(255)
                .HasColumnName("location");
            entity.Property(e => e.Model)
                .HasMaxLength(50)
                .HasColumnName("model");
            entity.Property(e => e.ModifiedBy)
                .HasMaxLength(100)
                .HasColumnName("modified_by");
            entity.Property(e => e.ModifiedOn)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("modified_on");
            entity.Property(e => e.PaperCapacity).HasColumnName("paper_capacity");
            entity.Property(e => e.CurrentPaper)
                .HasComment("Số trang giấy còn lại trong máy in")
                .HasColumnName("current_paper");
            // AdditionalPaper is not stored in printers table; ignore mapping
            entity.Ignore(e => e.AdditionalPaper);
            entity.Property(e => e.InkId).HasColumnName("ink_id");
            entity.Property(e => e.PrinterCode)
                .HasMaxLength(50)
                .HasColumnName("printer_code");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .HasDefaultValueSql("'AVAILABLE'::character varying")
                .HasColumnName("status");
            // Note: is_disable column removed from DB; no mapping.
        });

        modelBuilder.Entity<PrinterCapability>(entity =>
        {
            entity.HasKey(e => e.PrinterCapabilityId).HasName("printer_capabilities_pkey");

            entity.ToTable("printer_capabilities", tb => tb.HasComment("Cấu hình khả năng in của máy in (khổ giấy, màu/trắng đen)"));

            entity.HasIndex(e => e.PrinterId, "idx_printer_capabilities_printer");

            entity.Property(e => e.PrinterCapabilityId)
                .HasColumnName("printer_capability_id")
                .ValueGeneratedOnAdd();
            entity.Property(e => e.CreatedBy)
                .HasMaxLength(100)
                .HasColumnName("created_by");
            entity.Property(e => e.CreatedOn)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_on");
            entity.Property(e => e.IsBwSupported)
                .HasDefaultValue(true)
                .HasColumnName("is_bw_supported");
            entity.Property(e => e.IsColorSupported)
                .HasDefaultValue(false)
                .HasColumnName("is_color_supported");
            entity.Property(e => e.PaperSizeId).HasColumnName("paper_size_id");
            entity.Property(e => e.PrinterId).HasColumnName("printer_id");

            entity.HasOne(d => d.PaperSize).WithMany(p => p.PrinterCapabilities)
                .HasForeignKey(d => d.PaperSizeId)
                .HasConstraintName("printer_capabilities_paper_size_id_fkey");

            entity.HasOne(d => d.Printer).WithMany(p => p.PrinterCapabilities)
                .HasForeignKey(d => d.PrinterId)
                .OnDelete(DeleteBehavior.Cascade)
                .HasConstraintName("printer_capabilities_printer_id_fkey");
        });

        modelBuilder.Entity<Ink>(entity =>
        {
            entity.HasKey(e => e.InkId).HasName("inks_pkey");

            entity.ToTable("inks", tb => tb.HasComment("Danh sách cuộn mực trong hệ thống"));

            entity.HasIndex(e => e.InkCode, "inks_ink_code_key").IsUnique();

            entity.Property(e => e.InkId)
                .HasColumnName("ink_id")
                .ValueGeneratedOnAdd();
            entity.Property(e => e.InkCode)
                .HasMaxLength(50)
                .HasColumnName("ink_code");
            entity.Property(e => e.InkType)
                .HasMaxLength(20)
                .HasColumnName("ink_type");
            entity.Property(e => e.Color)
                .HasMaxLength(20)
                .HasColumnName("color");
            entity.Property(e => e.CapacityPages)
                .HasDefaultValue(0)
                .HasComment("Số trang in tối đa theo hãng")
                .HasColumnName("capacity_pages");
            entity.Property(e => e.CurrentPages)
                .HasDefaultValue(0)
                .HasComment("Số trang còn lại")
                .HasColumnName("current_pages");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .HasDefaultValueSql("'AVAILABLE'::character varying")
                .HasColumnName("status");
            entity.Property(e => e.Brand)
                .HasMaxLength(50)
                .HasColumnName("brand");
            // inks table no longer stores current_printer_id/current_printer_name
            entity.Property(e => e.CreatedBy)
                .HasMaxLength(100)
                .HasColumnName("created_by");
            entity.Property(e => e.CreatedOn)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_on");
            entity.Property(e => e.ModifiedBy)
                .HasMaxLength(100)
                .HasColumnName("modified_by");
            entity.Property(e => e.ModifiedOn)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("modified_on");
        });

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.UserId).HasName("users_pkey");

            entity.ToTable("users", tb => tb.HasComment("Bảng người dùng hệ thống in ấn (Student & SPSO)"));

            entity.HasIndex(e => e.Email, "users_email_key").IsUnique();

            entity.HasIndex(e => e.StudentCode, "users_student_code_key").IsUnique();

            entity.Property(e => e.UserId)
                .HasColumnName("user_id")
                .ValueGeneratedOnAdd();
            entity.Property(e => e.CreatedBy)
                .HasMaxLength(100)
                .HasColumnName("created_by");
            entity.Property(e => e.CreatedOn)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_on");
            entity.Property(e => e.Email)
                .HasMaxLength(100)
                .HasColumnName("email");
            entity.Property(e => e.EmailConfirmed)
                .HasDefaultValue(false)
                .HasComment("Trạng thái xác nhận email đã được xác thực chưa")
                .HasColumnName("email_confirmed");
            entity.Property(e => e.FullName)
                .HasMaxLength(100)
                .HasColumnName("full_name");
            entity.Property(e => e.ModifiedBy)
                .HasMaxLength(100)
                .HasColumnName("modified_by");
            entity.Property(e => e.ModifiedOn)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("modified_on");
            entity.Property(e => e.PageDefaultBalance)
                .HasDefaultValue(0)
                .HasComment("Số trang in mặc định được hệ thống cấp (ví dụ theo học kỳ)")
                .HasColumnName("page_default_balance");
            entity.Property(e => e.PagePurchasedBalance)
                .HasDefaultValue(0)
                .HasComment("Số trang in do người dùng mua thêm")
                .HasColumnName("page_purchased_balance");
            entity.Property(e => e.PasswordHash).HasColumnName("password_hash");
            entity.Property(e => e.Role)
                .HasMaxLength(20)
                .HasColumnName("role");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .HasDefaultValueSql("'ACTIVE'::character varying")
                .HasColumnName("status");
            entity.Property(e => e.StudentCode)
                .HasMaxLength(20)
                .HasColumnName("student_code");
            entity.Property(e => e.TwoFactorEnabled)
                .HasDefaultValue(false)
                .HasComment("Trạng thái bật/tắt 2FA")
                .HasColumnName("two_factor_enabled");
            entity.Property(e => e.TwoFactorMethod)
                .HasComment("Phương thức 2FA: authenticator, email, both")
                .HasColumnName("two_factor_method");
            entity.Property(e => e.TwoFactorRecoveryCodes)
                .HasComment("Chuỗi JSON chứa mã khôi phục 2FA")
                .HasColumnName("two_factor_recovery_codes");
            entity.Property(e => e.TwoFactorSecret)
                .HasComment("Secret key đã mã hóa cho TOTP")
                .HasColumnName("two_factor_secret");
            entity.Property(e => e.AvatarUrl)
                .HasComment("URL ảnh đại diện (avatar)")
                .HasColumnName("avatar_url");
            entity.Property(e => e.DateOfBirth)
                .HasComment("Ngày sinh")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("date_of_birth");
            entity.Property(e => e.Address)
                .HasComment("Địa chỉ")
                .HasColumnName("address");
            entity.Property(e => e.PhoneNumber)
                .HasMaxLength(20)
                .HasComment("Số điện thoại")
                .HasColumnName("phone_number");
        });

        modelBuilder.Entity<SystemConfig>(entity =>
        {
            entity.HasKey(e => e.ConfigId).HasName("system_config_pkey");

            entity.ToTable("system_config", tb => tb.HasComment("Bảng cấu hình hệ thống - chỉ có 1 record duy nhất"));

            entity.Property(e => e.ConfigId)
                .HasColumnName("config_id")
                .ValueGeneratedOnAdd();
            entity.Property(e => e.SystemName)
                .HasMaxLength(255)
                .HasComment("Tên hệ thống")
                .HasColumnName("system_name");
            entity.Property(e => e.MaintenanceMode)
                .HasComment("Chế độ bảo trì (true/false)")
                .HasColumnName("maintenance_mode");
            entity.Property(e => e.MaxFileSize)
                .HasComment("Kích thước file tải lên tối đa cho mỗi tài liệu (bytes)")
                .HasColumnName("max_file_size");
            entity.Property(e => e.AllowedFileFormats)
                .HasMaxLength(255)
                .HasComment("Định dạng file cho phép, ngăn cách bằng dấu phẩy (.pdf,.docx)")
                .HasColumnName("allowed_file_formats");
            entity.Property(e => e.DefaultPagesForStudent)
                .HasComment("Số trang mặc định cấp cho sinh viên")
                .HasColumnName("default_pages_for_student");
            entity.Property(e => e.PaperPrice)
                .HasPrecision(18, 2)
                .HasComment("Giá giấy mặc định (VNĐ/trang)")
                .HasColumnName("paper_price");
            entity.Property(e => e.PageFactor)
                .HasPrecision(10, 4)
                .HasComment("Hệ số nhân để tính số trang thực tế từ số trang đếm được (ví dụ: 1.2 = tăng 20% số trang)")
                .HasColumnName("page_factor");
            entity.Property(e => e.AutoAssignPages)
                .HasComment("Tự động cấp giấy cho sinh viên (true/false)")
                .HasColumnName("auto_assign_pages");
            entity.Property(e => e.AutoAssignDays)
                .HasComment("Các mốc ngày cấp giấy, định dạng: 'ngày/tháng;ngày/tháng' (ví dụ: '7/10;20/12;1/1')")
                .HasColumnName("auto_assign_days");
            entity.Property(e => e.AutoAssignDayOfMonth)
                .HasDefaultValue(1)
                .HasComment("Ngày trong tháng để tự động tạo báo cáo tổng quát (1-31)")
                .HasColumnName("auto_assign_day_of_month");
            entity.Property(e => e.StorageLimitMb)
                .HasComment("Giới hạn dung lượng lưu trữ tổng cho hệ thống (MB)")
                .HasColumnName("storage_limit_mb");
            entity.Property(e => e.StoragePricePerMb)
                .HasPrecision(18, 2)
                .HasComment("Giá mỗi MB dung lượng lưu trữ (VNĐ/MB)")
                .HasColumnName("storage_price_per_mb");
            entity.Property(e => e.DefaultAdditionalPaper)
                .HasComment("Số giấy mặc định được gợi ý khi thêm giấy vào máy in")
                .HasColumnName("default_additional_paper");
            entity.Property(e => e.PictureUrl)
                .HasMaxLength(500)
                .HasComment("URL ảnh background của hệ thống")
                .HasColumnName("picture_url");
            entity.Property(e => e.PageDefaultCreate)
                .HasComment("Số trang giấy mặc định cấp cho tài khoản mới khi tạo")
                .HasColumnName("page_default_create");
            entity.Property(e => e.SessionTimeoutMinutes)
                .HasComment("Thời gian hết phiên (phút)")
                .HasColumnName("session_timeout_minutes");
            entity.Property(e => e.MaxLoginAttempts)
                .HasComment("Số lần nhập sai tối đa")
                .HasColumnName("max_login_attempts");
            entity.Property(e => e.MinPasswordLength)
                .HasComment("Yêu cầu độ dài tối thiểu mật khẩu")
                .HasColumnName("min_password_length");
            entity.Property(e => e.RequirePasswordFormat)
                .HasComment("Yêu cầu định dạng mật khẩu (true/false)")
                .HasColumnName("require_password_format");
            entity.Property(e => e.CreatedBy)
                .HasMaxLength(100)
                .HasColumnName("created_by");
            entity.Property(e => e.CreatedOn)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_on");
            entity.Property(e => e.ModifiedBy)
                .HasMaxLength(100)
                .HasColumnName("modified_by");
            entity.Property(e => e.ModifiedOn)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("modified_on");
        });

        modelBuilder.Entity<PurchaseTransaction>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("purchase_transactions_pkey");

            entity.ToTable("purchase_transactions", tb => tb.HasComment("Bảng lưu lịch sử giao dịch mua giấy và dung lượng"));

            entity.HasIndex(e => e.UserId, "idx_purchase_transactions_user");

            entity.HasIndex(e => e.TransactionType, "idx_purchase_transactions_type");

            entity.HasIndex(e => e.Status, "idx_purchase_transactions_status");

            entity.Property(e => e.Id)
                .HasColumnName("id")
                .ValueGeneratedOnAdd();
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.TransactionType)
                .HasMaxLength(50)
                .HasColumnName("transaction_type");
            entity.Property(e => e.Quantity).HasColumnName("quantity");
            entity.Property(e => e.PricePerUnit)
                .HasPrecision(18, 2)
                .HasColumnName("price_per_unit");
            entity.Property(e => e.TotalAmount)
                .HasPrecision(18, 2)
                .HasColumnName("total_amount");
            entity.Property(e => e.TransactionCode)
                .HasMaxLength(255)
                .HasColumnName("transaction_code");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .HasDefaultValueSql("'PENDING'::character varying")
                .HasColumnName("status");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("updated_at");

            entity.HasOne(d => d.User).WithMany(p => p.PurchaseTransactions)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.Cascade)
                .HasConstraintName("purchase_transactions_user_id_fkey");
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
