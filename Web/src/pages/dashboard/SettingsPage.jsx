import { useState, useEffect } from "react"
import { toast, useToast } from "../../hooks/use-toast"
import {
  User,
  Lock,
  ShieldCheck,
  Loader2,
  AlertCircle,
  CheckCircle,
  Eye,
  EyeOff,
  Smartphone,
  QrCode,
  Copy,
  Check,
} from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Label } from "../../components/ui/label"
import { Tabs, TabsList, TabsTrigger, TabsContent } from "../../components/ui/tabs"
import { profileAPI, twoFactorAPI, uploadAPI } from "../../api/client"
import { Camera } from "lucide-react"

export function SettingsPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Cài đặt</h1>
        <p className="text-muted-foreground mt-1">
          Quản lý thông tin cá nhân và bảo mật tài khoản
        </p>
      </div>

      <Tabs defaultValue="profile" className="w-full">
        <TabsList className="mb-6">
          <TabsTrigger value="profile">
            <User className="w-4 h-4 mr-2" />
            Hồ sơ
          </TabsTrigger>
          <TabsTrigger value="password">
            <Lock className="w-4 h-4 mr-2" />
            Mật khẩu
          </TabsTrigger>
          <TabsTrigger value="security">
            <ShieldCheck className="w-4 h-4 mr-2" />
            Bảo mật
          </TabsTrigger>
        </TabsList>

        <TabsContent value="profile">
          <ProfileTab />
        </TabsContent>

        <TabsContent value="password">
          <PasswordTab />
        </TabsContent>

        <TabsContent value="security">
          <SecurityTab />
        </TabsContent>
      </Tabs>
    </div>
  )
}

// ─── Profile Tab ──────────────────────────────────────────────────────────────

function ProfileTab() {
  const { toast } = useToast()
  const [isLoading, setIsLoading] = useState(false)
  const [isFetching, setIsFetching] = useState(true)
  const [profile, setProfile] = useState({
    fullName: "",
    phone: "",
    address: "",
    avatarUrl: "",
  })
  const [avatarPreview, setAvatarPreview] = useState("")
  const [isUploadingAvatar, setIsUploadingAvatar] = useState(false)
  const [errors, setErrors] = useState({})
  const [success, setSuccess] = useState("")

  useEffect(() => {
    fetchProfile()
  }, [])

  const fetchProfile = async () => {
    try {
      const res = await profileAPI.getProfile()
      const data = res?.data?.data
      if (data) {
        setProfile({
          fullName: data.fullName || "",
          phone: data.phone || "",
          address: data.address || "",
          avatarUrl: data.avatarUrl || "",
        })
        setAvatarPreview(data.avatarUrl || "")
      }
    } catch (err) {
      toast("Không thể tải thông tin hồ sơ", "error")
    } finally {
      setIsFetching(false)
    }
  }

  const handleChange = (field, value) => {
    setProfile((prev) => ({ ...prev, [field]: value }))
    if (errors[field]) {
      setErrors((prev) => ({ ...prev, [field]: "" }))
    }
    setSuccess("")
  }

  const handleAvatarChange = async (e) => {
    const file = e.target.files?.[0]
    if (!file) return

    if (!file.type.startsWith("image/")) {
      toast("Vui lòng chọn file ảnh", "error")
      return
    }
    if (file.size > 5 * 1024 * 1024) {
      toast("Kích thước file không được vượt quá 5MB", "error")
      return
    }

    const preview = URL.createObjectURL(file)
    setAvatarPreview(preview)
    setIsUploadingAvatar(true)
    setSuccess("")

    try {
      const res = await uploadAPI.uploadUserAvatar(file)
      if (res?.data?.success) {
        const newUrl = res.data.url
        setProfile((prev) => ({ ...prev, avatarUrl: newUrl }))
        toast("Upload ảnh thành công!", "success")
      } else {
        toast(res.data?.message || "Upload thất bại", "error")
      }
    } catch (err) {
      toast(err.response?.data?.message || "Upload ảnh thất bại", "error")
    } finally {
      setIsUploadingAvatar(false)
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setErrors({})
    setSuccess("")

    if (!profile.fullName?.trim()) {
      setErrors((prev) => ({ ...prev, fullName: "Họ tên không được để trống" }))
      return
    }

    setIsLoading(true)
    try {
      const res = await profileAPI.updateProfile({
        fullName: profile.fullName.trim(),
        phone: profile.phone?.trim() || null,
        address: profile.address?.trim() || null,
        avatarUrl: profile.avatarUrl || null,
      })
      if (res?.data?.success) {
        setSuccess("Cập nhật hồ sơ thành công")
        toast("Cập nhật hồ sơ thành công", "success")
      }
    } catch (err) {
      const msg = err.response?.data?.message || "Cập nhật thất bại"
      setErrors({ general: msg })
      toast(msg, "error")
    } finally {
      setIsLoading(false)
    }
  }

  if (isFetching) {
    return (
      <div className="flex items-center justify-center py-16">
        <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
      </div>
    )
  }

  return (
    <div className="max-w-2xl">
      <div className="bg-card rounded-xl border border-border p-6">
        <div className="flex items-center gap-6 mb-6">
          <div className="relative flex-shrink-0">
            {avatarPreview ? (
              <img
                src={avatarPreview}
                alt="Avatar"
                className="w-24 h-24 rounded-full object-cover border-2 border-border"
              />
            ) : (
              <div className="w-24 h-24 rounded-full bg-muted flex items-center justify-center border-2 border-border">
                <User className="w-10 h-10 text-muted-foreground" />
              </div>
            )}
            <label
              htmlFor="avatar-upload"
              className="absolute bottom-0 right-0 bg-primary text-primary-foreground rounded-full p-1.5 cursor-pointer hover:bg-primary/90 transition-colors shadow-md"
            >
              {isUploadingAvatar ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <Camera className="w-4 h-4" />
              )}
              <input
                id="avatar-upload"
                type="file"
                accept="image/*"
                className="sr-only"
                onChange={handleAvatarChange}
                disabled={isUploadingAvatar}
              />
            </label>
          </div>
          <div>
            <h2 className="text-lg font-semibold text-foreground">Thông tin cá nhân</h2>
            <p className="text-sm text-muted-foreground">
              Cập nhật thông tin hồ sơ của bạn
            </p>
          </div>
        </div>

        {errors.general && (
          <div className="mb-4 p-3 bg-destructive/15 border border-destructive/30 rounded-lg text-destructive text-sm flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            {errors.general}
          </div>
        )}

        {success && (
          <div className="mb-4 p-3 bg-primary/10 border border-primary/30 rounded-lg text-primary text-sm flex items-center gap-2">
            <CheckCircle className="w-4 h-4 flex-shrink-0" />
            {success}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="space-y-2">
            <Label htmlFor="fullName">Họ tên</Label>
            <Input
              id="fullName"
              value={profile.fullName}
              onChange={(e) => handleChange("fullName", e.target.value)}
              placeholder="Nhập họ tên của bạn"
              className={errors.fullName ? "border-destructive" : ""}
            />
            {errors.fullName && (
              <p className="text-xs text-destructive flex items-center gap-1">
                <AlertCircle className="w-3 h-3" />
                {errors.fullName}
              </p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="phone">Số điện thoại</Label>
            <Input
              id="phone"
              value={profile.phone}
              onChange={(e) => handleChange("phone", e.target.value)}
              placeholder="Nhập số điện thoại"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="address">Địa chỉ</Label>
            <Input
              id="address"
              value={profile.address}
              onChange={(e) => handleChange("address", e.target.value)}
              placeholder="Nhập địa chỉ của bạn"
            />
          </div>

          <div className="pt-2">
            <Button type="submit" disabled={isLoading}>
              {isLoading ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Đang lưu...
                </>
              ) : (
                "Lưu thay đổi"
              )}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}

// ─── Password Tab ──────────────────────────────────────────────────────────────

function PasswordTab() {
  const { toast } = useToast()
  const [isLoading, setIsLoading] = useState(false)
  const [showCurrent, setShowCurrent] = useState(false)
  const [showNew, setShowNew] = useState(false)
  const [showConfirm, setShowConfirm] = useState(false)
  const [form, setForm] = useState({
    currentPassword: "",
    newPassword: "",
    confirmPassword: "",
  })
  const [errors, setErrors] = useState({})
  const [success, setSuccess] = useState("")

  const handleChange = (field, value) => {
    setForm((prev) => ({ ...prev, [field]: value }))
    if (errors[field]) {
      setErrors((prev) => ({ ...prev, [field]: "" }))
    }
    setSuccess("")
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setErrors({})
    setSuccess("")

    const newErrors = {}
    if (!form.currentPassword) {
      newErrors.currentPassword = "Vui lòng nhập mật khẩu hiện tại"
    }
    if (!form.newPassword) {
      newErrors.newPassword = "Vui lòng nhập mật khẩu mới"
    } else if (form.newPassword.length < 6) {
      newErrors.newPassword = "Mật khẩu mới phải có ít nhất 6 ký tự"
    }
    if (!form.confirmPassword) {
      newErrors.confirmPassword = "Vui lòng xác nhận mật khẩu mới"
    } else if (form.newPassword !== form.confirmPassword) {
      newErrors.confirmPassword = "Mật khẩu xác nhận không khớp"
    }
    if (form.currentPassword === form.newPassword) {
      newErrors.newPassword = "Mật khẩu mới phải khác mật khẩu hiện tại"
    }

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors)
      return
    }

    setIsLoading(true)
    try {
      const res = await profileAPI.changePassword({
        currentPassword: form.currentPassword,
        newPassword: form.newPassword,
      })
      if (res?.data?.success) {
        setSuccess("Đổi mật khẩu thành công")
        setForm({ currentPassword: "", newPassword: "", confirmPassword: "" })
        toast("Đổi mật khẩu thành công", "success")
      }
    } catch (err) {
      const msg = err.response?.data?.message || "Đổi mật khẩu thất bại"
      if (msg.includes("hiện tại không đúng")) {
        setErrors({ currentPassword: msg })
      } else {
        setErrors({ general: msg })
      }
      toast(msg, "error")
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="max-w-2xl">
      <div className="bg-card rounded-xl border border-border p-6">
        <h2 className="text-lg font-semibold text-foreground mb-1">Đổi mật khẩu</h2>
        <p className="text-sm text-muted-foreground mb-6">
          Cập nhật mật khẩu để bảo vệ tài khoản của bạn
        </p>

        {errors.general && (
          <div className="mb-4 p-3 bg-destructive/15 border border-destructive/30 rounded-lg text-destructive text-sm flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            {errors.general}
          </div>
        )}

        {success && (
          <div className="mb-4 p-3 bg-primary/10 border border-primary/30 rounded-lg text-primary text-sm flex items-center gap-2">
            <CheckCircle className="w-4 h-4 flex-shrink-0" />
            {success}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="space-y-2">
            <Label htmlFor="currentPassword">Mật khẩu hiện tại</Label>
            <div className="relative">
              <Input
                id="currentPassword"
                type={showCurrent ? "text" : "password"}
                value={form.currentPassword}
                onChange={(e) => handleChange("currentPassword", e.target.value)}
                placeholder="Nhập mật khẩu hiện tại"
                className={errors.currentPassword ? "border-destructive pr-10" : "pr-10"}
              />
              <button
                type="button"
                onClick={() => setShowCurrent(!showCurrent)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
              >
                {showCurrent ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
            {errors.currentPassword && (
              <p className="text-xs text-destructive flex items-center gap-1">
                <AlertCircle className="w-3 h-3" />
                {errors.currentPassword}
              </p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="newPassword">Mật khẩu mới</Label>
            <div className="relative">
              <Input
                id="newPassword"
                type={showNew ? "text" : "password"}
                value={form.newPassword}
                onChange={(e) => handleChange("newPassword", e.target.value)}
                placeholder="Nhập mật khẩu mới (ít nhất 6 ký tự)"
                className={errors.newPassword ? "border-destructive pr-10" : "pr-10"}
              />
              <button
                type="button"
                onClick={() => setShowNew(!showNew)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
              >
                {showNew ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
            {errors.newPassword && (
              <p className="text-xs text-destructive flex items-center gap-1">
                <AlertCircle className="w-3 h-3" />
                {errors.newPassword}
              </p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="confirmPassword">Xác nhận mật khẩu mới</Label>
            <div className="relative">
              <Input
                id="confirmPassword"
                type={showConfirm ? "text" : "password"}
                value={form.confirmPassword}
                onChange={(e) => handleChange("confirmPassword", e.target.value)}
                placeholder="Nhập lại mật khẩu mới"
                className={errors.confirmPassword ? "border-destructive pr-10" : "pr-10"}
              />
              <button
                type="button"
                onClick={() => setShowConfirm(!showConfirm)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
              >
                {showConfirm ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
            {errors.confirmPassword && (
              <p className="text-xs text-destructive flex items-center gap-1">
                <AlertCircle className="w-3 h-3" />
                {errors.confirmPassword}
              </p>
            )}
          </div>

          <div className="pt-2">
            <Button type="submit" disabled={isLoading}>
              {isLoading ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Đang xử lý...
                </>
              ) : (
                "Đổi mật khẩu"
              )}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}

// ─── Security / 2FA Tab ────────────────────────────────────────────────────────

function SecurityTab() {
  const { toast } = useToast()
  const [isLoading, setIsLoading] = useState(false)
  const [isFetching2FA, setIsFetching2FA] = useState(true)
  const [is2FAEnabled, setIs2FAEnabled] = useState(false)
  const [step, setStep] = useState("view") // "view" | "setup" | "enable" | "disable"
  const [qrCode, setQrCode] = useState("")
  const [secret, setSecret] = useState("")
  const [manualKey, setManualKey] = useState("")
  const [code, setCode] = useState("")
  const [errors, setErrors] = useState({})
  const [success, setSuccess] = useState("")
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    fetch2FAStatus()
  }, [])

  const fetch2FAStatus = async () => {
    setIsFetching2FA(true)
    try {
      const res = await profileAPI.getProfile()
      const data = res?.data?.data
      setIs2FAEnabled(Boolean(data?.is2faEnabled))
    } catch {
      // ignore
    } finally {
      setIsFetching2FA(false)
    }
  }

  const handleSetup = async () => {
    setIsLoading(true)
    setErrors({})
    try {
      const res = await twoFactorAPI.setup()
      if (res?.data?.success) {
        const d = res.data.data
        setQrCode(d.qrCodeImage || "")
        setSecret(d.secret || "")
        setManualKey(d.manualEntryKey || d.secret || "")
        setStep("setup")
      }
    } catch (err) {
      toast(err.response?.data?.message || "Không thể tạo mã QR", "error")
    } finally {
      setIsLoading(false)
    }
  }

  const handleEnable = async () => {
    if (!code.trim() || !/^\d{6}$/.test(code.trim())) {
      setErrors({ code: "Vui lòng nhập mã gồm 6 chữ số" })
      return
    }
    setIsLoading(true)
    setErrors({})
    try {
      const res = await twoFactorAPI.enable(code.trim())
      if (res?.data?.success) {
        setSuccess("Bật xác thực hai yếu tố thành công!")
        setIs2FAEnabled(true)
        setStep("view")
        setCode("")
        toast("Bật 2FA thành công", "success")
        await fetch2FAStatus()
      }
    } catch (err) {
      setErrors({ code: err.response?.data?.message || "Mã xác thực không hợp lệ" })
      toast(err.response?.data?.message || "Lỗi khi bật 2FA", "error")
    } finally {
      setIsLoading(false)
    }
  }

  const handleDisable = async () => {
    if (!code.trim() || !/^\d{6}$/.test(code.trim())) {
      setErrors({ code: "Vui lòng nhập mã gồm 6 chữ số" })
      return
    }
    setIsLoading(true)
    setErrors({})
    try {
      const res = await twoFactorAPI.disable(code.trim())
      if (res?.data?.success) {
        setSuccess("Tắt xác thực hai yếu tố thành công!")
        setIs2FAEnabled(false)
        setStep("view")
        setCode("")
        toast("Tắt 2FA thành công", "success")
        await fetch2FAStatus()
      }
    } catch (err) {
      setErrors({ code: err.response?.data?.message || "Mã xác thực không hợp lệ" })
      toast(err.response?.data?.message || "Lỗi khi tắt 2FA", "error")
    } finally {
      setIsLoading(false)
    }
  }

  const handleCopySecret = () => {
    navigator.clipboard.writeText(manualKey)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const handleCancel = () => {
    setStep("view")
    setCode("")
    setErrors({})
    setQrCode("")
    setSecret("")
    setManualKey("")
  }

  if (isFetching2FA) {
    return (
      <div className="flex items-center justify-center py-16">
        <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
      </div>
    )
  }

  return (
    <div className="max-w-2xl space-y-6">
      {/* 2FA Status Card */}
      <div className="bg-card rounded-xl border border-border p-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className={`w-12 h-12 rounded-full flex items-center justify-center ${
              is2FAEnabled ? "bg-primary/15" : "bg-muted"
            }`}>
              <ShieldCheck className={`w-6 h-6 ${is2FAEnabled ? "text-primary" : "text-muted-foreground"}`} />
            </div>
            <div>
              <h3 className="text-base font-semibold text-foreground">Xác thực hai yếu tố (2FA)</h3>
              <p className="text-sm text-muted-foreground">
                {is2FAEnabled
                  ? "Tài khoản của bạn đang được bảo vệ bằng xác thực hai yếu tố"
                  : "Bảo vệ tài khoản bằng ứng dụng xác thực như Google Authenticator"
                }
              </p>
            </div>
          </div>
          <div className={`px-3 py-1 rounded-full text-xs font-medium ${
            is2FAEnabled
              ? "bg-primary/15 text-primary"
              : "bg-muted text-muted-foreground"
          }`}>
            {is2FAEnabled ? "Đã bật" : "Chưa bật"}
          </div>
        </div>
      </div>

      {/* Setup Flow */}
      {step === "view" && !is2FAEnabled && (
        <div className="bg-card rounded-xl border border-border p-6">
          <div className="flex items-start gap-4 mb-5">
            <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
              <QrCode className="w-5 h-5 text-primary" />
            </div>
            <div>
              <h3 className="text-base font-semibold text-foreground">Kích hoạt xác thực hai yếu tố</h3>
              <p className="text-sm text-muted-foreground mt-1">
                Sử dụng ứng dụng Google Authenticator hoặc bất kỳ ứng dụng TOTP nào để quét mã QR bên dưới.
              </p>
            </div>
          </div>
          <Button onClick={handleSetup} disabled={isLoading}>
            {isLoading ? (
              <><Loader2 className="w-4 h-4 mr-2 animate-spin" /> Đang tạo mã...</>
            ) : (
              <><QrCode className="w-4 h-4 mr-2" /> Thiết lập 2FA</>
            )}
          </Button>
        </div>
      )}

      {/* QR Code + Enable */}
      {step === "setup" && (
        <div className="bg-card rounded-xl border border-border p-6">
          <h3 className="text-base font-semibold text-foreground mb-1">Quét mã QR</h3>
          <p className="text-sm text-muted-foreground mb-5">
            Mở ứng dụng Google Authenticator và quét mã QR bên dưới, sau đó nhập mã gồm 6 chữ số để xác thực.
          </p>

          {errors.general && (
            <div className="mb-4 p-3 bg-destructive/15 border border-destructive/30 rounded-lg text-destructive text-sm flex items-center gap-2">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              {errors.general}
            </div>
          )}

          <div className="flex flex-col sm:flex-row gap-6 items-start">
            {qrCode && (
              <div className="flex-shrink-0">
                <img
                  src={qrCode}
                  alt="2FA QR Code"
                  className="w-48 h-48 rounded-lg border border-border"
                />
              </div>
            )}

            <div className="flex-1 space-y-4 w-full">
              <div className="space-y-2">
                <Label>Nhập mã từ ứng dụng</Label>
                <Input
                  inputMode="numeric"
                  pattern="[0-9]*"
                  maxLength={6}
                  value={code}
                  onChange={(e) => {
                    setCode(e.target.value.replace(/\D/g, "").slice(0, 6))
                    if (errors.code) setErrors((p) => ({ ...p, code: "" }))
                  }}
                  placeholder="123456"
                  className={`text-center text-xl tracking-[0.3em] ${errors.code ? "border-destructive" : ""}`}
                  autoFocus
                />
                {errors.code && (
                  <p className="text-xs text-destructive flex items-center gap-1">
                    <AlertCircle className="w-3 h-3" />
                    {errors.code}
                  </p>
                )}
              </div>

              <div className="space-y-2">
                <Label>Hoặc nhập thủ công</Label>
                <div className="flex items-center gap-2">
                  <Input
                    value={manualKey}
                    readOnly
                    className="font-mono text-sm"
                  />
                  <Button variant="outline" size="icon" onClick={handleCopySecret} title="Sao chép">
                    {copied ? <Check className="w-4 h-4 text-primary" /> : <Copy className="w-4 h-4" />}
                  </Button>
                </div>
              </div>

              <div className="flex gap-3 pt-2">
                <Button onClick={handleEnable} disabled={isLoading || code.length !== 6}>
                  {isLoading ? (
                    <><Loader2 className="w-4 h-4 mr-2 animate-spin" /> Đang xác thực...</>
                  ) : (
                    "Xác thực & Bật 2FA"
                  )}
                </Button>
                <Button variant="outline" onClick={handleCancel}>
                  Hủy
                </Button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Disable 2FA */}
      {step === "view" && is2FAEnabled && (
        <div className="bg-card rounded-xl border border-border p-6">
          <div className="flex items-start gap-4 mb-5">
            <div className="w-10 h-10 rounded-lg bg-destructive/10 flex items-center justify-center flex-shrink-0">
              <Smartphone className="w-5 h-5 text-destructive" />
            </div>
            <div>
              <h3 className="text-base font-semibold text-foreground">Tắt xác thực hai yếu tố</h3>
              <p className="text-sm text-muted-foreground mt-1">
                Nhập mã từ ứng dụng xác thực để xác nhận tắt 2FA.
              </p>
            </div>
          </div>

          {errors.general && (
            <div className="mb-4 p-3 bg-destructive/15 border border-destructive/30 rounded-lg text-destructive text-sm flex items-center gap-2">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              {errors.general}
            </div>
          )}

          <div className="space-y-4 max-w-sm">
            <div className="space-y-2">
              <Label>Mã xác thực</Label>
              <Input
                inputMode="numeric"
                pattern="[0-9]*"
                maxLength={6}
                value={code}
                onChange={(e) => {
                  setCode(e.target.value.replace(/\D/g, "").slice(0, 6))
                  if (errors.code) setErrors((p) => ({ ...p, code: "" }))
                }}
                placeholder="123456"
                className={`text-center text-xl tracking-[0.3em] ${errors.code ? "border-destructive" : ""}`}
              />
              {errors.code && (
                <p className="text-xs text-destructive flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {errors.code}
                </p>
              )}
            </div>
            <Button
              variant="destructive"
              onClick={handleDisable}
              disabled={isLoading || code.length !== 6}
            >
              {isLoading ? (
                <><Loader2 className="w-4 h-4 mr-2 animate-spin" /> Đang xử lý...</>
              ) : (
                "Tắt 2FA"
              )}
            </Button>
          </div>
        </div>
      )}

      {success && (
        <div className="p-3 bg-primary/10 border border-primary/30 rounded-lg text-primary text-sm flex items-center gap-2">
          <CheckCircle className="w-4 h-4 flex-shrink-0" />
          {success}
        </div>
      )}
    </div>
  )
}
