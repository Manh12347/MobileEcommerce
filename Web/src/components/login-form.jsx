import { useEffect, useState } from "react"
import { Eye, EyeOff, Smartphone, Loader2, AlertCircle, CheckCircle } from "lucide-react"
import { Button } from "./ui/button"
import { Input } from "./ui/input"
import { Label } from "./ui/label"
import { Checkbox } from "./ui/checkbox"
import { authAPI } from "../api/client"
import { isAdminSessionActive, saveAdminSession } from "../api/authSession"

export function LoginForm() {
  const [showPassword, setShowPassword] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [otp, setOtp] = useState("")
  const [pending2FAUser, setPending2FAUser] = useState(null)
  const [errors, setErrors] = useState({})
  const [success, setSuccess] = useState("")

  useEffect(() => {
    if (isAdminSessionActive()) {
      window.location.href = '/dashboard'
    }
  }, [])

  // Email validation regex
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

  // Validation function
  const validateForm = () => {
    const newErrors = {}

    // Email validation
    if (!email.trim()) {
      newErrors.email = "Email không được để trống"
    } else if (!emailRegex.test(email)) {
      newErrors.email = "Email không đúng định dạng (ví dụ: example@domain.com)"
    }

    // Password validation
    if (!password) {
      newErrors.password = "Mật khẩu không được để trống"
    } else if (password.length < 6) {
      newErrors.password = "Mật khẩu phải có ít nhất 6 ký tự"
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const validateOtp = () => {
    const newErrors = {}

    if (!otp.trim()) {
      newErrors.otp = "Vui lòng nhập mã OTP"
    } else if (!/^\d{6}$/.test(otp.trim())) {
      newErrors.otp = "Mã OTP phải gồm 6 chữ số"
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setSuccess("")
    
    // Clear previous errors on submit attempt
    setErrors({})

    if (pending2FAUser) {
      if (!validateOtp()) {
        return
      }

      setIsLoading(true)

      try {
        const response = await authAPI.verifyLoginOtp(email, otp.trim())

        if (response.data?.success) {
          saveAdminSession(pending2FAUser)
          setSuccess("Xác thực OTP thành công!")

          setTimeout(() => {
            window.location.href = '/dashboard'
          }, 700)
        } else {
          setErrors({ otp: response.data?.message || "Mã OTP không chính xác" })
        }
      } catch (err) {
        const errorMsg = err.response?.data?.message || err.message || "Lỗi xác thực OTP"
        setErrors({ otp: errorMsg })
      } finally {
        setIsLoading(false)
      }

      return
    }

    // Validate before submitting
    if (!validateForm()) {
      return
    }

    setIsLoading(true)

    try {
      const response = await authAPI.login(email, password)
      
      if (response.data?.success) {
        const userData = response.data.data;
        
        const isAdmin = userData?.role?.toUpperCase() === 'ADMIN' || userData?.isAdmin === true || userData?.accountType?.toUpperCase() === 'ADMIN';
        
        if (!isAdmin) {
          setErrors({ general: "Tài khoản không tồn tại hoặc không có quyền truy cập" });
          setIsLoading(false);
          return;
        }
        
        const requires2FA =
          userData?.require2FA === true ||
          userData?.require2fa === true ||
          userData?.requires2FA === true ||
          userData?.requires2fa === true

        if (requires2FA) {
          await authAPI.sendLoginOtp(userData.email || email)
          setPending2FAUser(userData)
          setOtp("")
          setSuccess("Tài khoản đã bật 2FA. Mã OTP đã được gửi đến email.")
          setIsLoading(false)
          return
        }

        saveAdminSession(userData)
        setSuccess(response.data.message || "Đăng nhập thành công!")
        
        setTimeout(() => {
          window.location.href = '/dashboard'
        }, 1000)
      }
    } catch (err) {
      const errorMsg = err.response?.data?.message || err.message || "Lỗi đăng nhập"
      setErrors({ general: errorMsg })
    } finally {
      setIsLoading(false)
    }
  }

  // Handle real-time validation on blur
  const handleEmailBlur = () => {
    if (email && !emailRegex.test(email)) {
      setErrors(prev => ({ ...prev, email: "Email không đúng định dạng (ví dụ: example@domain.com)" }))
    } else {
      setErrors(prev => { const { email, ...rest } = prev; return rest })
    }
  }

  const handlePasswordBlur = () => {
    if (password && password.length < 6) {
      setErrors(prev => ({ ...prev, password: "Mật khẩu phải có ít nhất 6 ký tự" }))
    } else {
      setErrors(prev => { const { password, ...rest } = prev; return rest })
    }
  }

  const handleRegisterClick = () => {
    window.location.href = '/register'
  }

  const handleForgotPassword = () => {
    window.location.href = '/forgot-password'
  }

  const handleBackToPassword = () => {
    setPending2FAUser(null)
    setOtp("")
    setSuccess("")
    setErrors({})
  }

  return (
    <div className="min-h-screen flex">
      {/* Left Panel - Features */}
      <div className="hidden lg:flex lg:w-1/2 bg-card relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-primary/10 via-transparent to-primary/5" />
        
        {/* Decorative grid */}
        <div className="absolute inset-0 opacity-[0.03]">
          <div className="h-full w-full" style={{
            backgroundImage: `linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px),
                              linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)`,
            backgroundSize: '60px 60px'
          }} />
        </div>

        <div className="relative z-10 flex flex-col items-center justify-center p-12 xl:p-16 h-full text-center">
          {/* Logo */}
          <div className="flex items-center gap-4 mb-12">
            <div className="w-16 h-16 rounded-2xl bg-primary flex items-center justify-center">
              <Smartphone className="w-8 h-8 text-primary-foreground" />
            </div>
            <span className="text-3xl font-bold text-foreground">Ecommerce Shop Admin</span>
          </div>

          <h1 className="text-6xl xl:text-7xl font-bold text-foreground leading-tight mb-10 text-balance max-w-2xl">
            Quản lý ứng dụng
            <br />
            <span className="text-primary text-7xl xl:text-8xl">Mobile Ecommerce</span>
            <br />
            của bạn
          </h1>

          <p className="text-muted-foreground text-xl max-w-2xl">
            Bảng điều khiển mạnh mẽ để quản lý sản phẩm, đơn hàng và khách hàng trên ứng dụng di động của bạn.
          </p>
        </div>
      </div>

      {/* Right Panel - Login Form */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-6 sm:p-8 lg:p-12 bg-background">
        <div className="w-full max-w-2xl">
          {/* Mobile Logo */}
          <div className="flex items-center gap-3 mb-8 lg:hidden">
            <div className="w-10 h-10 rounded-xl bg-primary flex items-center justify-center">
              <Smartphone className="w-5 h-5 text-primary-foreground" />
            </div>
            <span className="text-xl font-semibold text-foreground">Ecommerce Shop Admin</span>
          </div>

          <div className="mb-12">
            <h2 className="text-4xl sm:text-5xl font-bold text-foreground mb-4">
              Chào mừng trở lại
            </h2>
            <p className="text-lg text-muted-foreground">
              Đăng nhập vào tài khoản quản trị của bạn
            </p>
          </div>

          {errors.general && (
            <div className="mb-6 p-4 bg-destructive/15 border-l-4 border-destructive rounded-lg text-destructive animate-in fade-in slide-in-from-top-2 duration-300">
              <div className="flex items-start gap-3">
                <AlertCircle className="w-5 h-5 mt-0.5 flex-shrink-0" />
                <div>
                  <p className="font-medium text-sm">{errors.general}</p>
                </div>
              </div>
            </div>
          )}

          {success && (
            <div className="mb-6 p-4 bg-primary/15 border-l-4 border-primary rounded-lg text-primary animate-in fade-in slide-in-from-top-2 duration-300">
              <div className="flex items-start gap-3">
                <CheckCircle className="w-5 h-5 mt-0.5 flex-shrink-0" />
                <div>
                  <p className="font-medium text-sm">{success}</p>
                </div>
              </div>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-8">
            <div className={`space-y-3 ${pending2FAUser ? 'hidden' : ''}`}>
              <Label htmlFor="email" className="text-lg font-semibold text-foreground">
                Email
              </Label>
              <Input
                id="email"
                type="email"
                placeholder="admin@mobileshop.com"
                value={email}
                disabled={Boolean(pending2FAUser)}
                onChange={(e) => {
                  setEmail(e.target.value)
                  // Clear error when user starts typing
                  if (errors.email) {
                    setErrors(prev => { const { email, ...rest } = prev; return rest })
                  }
                }}
                onBlur={handleEmailBlur}
                className={`h-14 text-base ${errors.email ? 'border-destructive border-2' : ''}`}
              />
              {errors.email && (
                <p className="text-sm text-destructive flex items-center gap-1 mt-1">
                  <AlertCircle className="w-4 h-4" />
                  {errors.email}
                </p>
              )}
            </div>

            <div className={`space-y-3 ${pending2FAUser ? 'hidden' : ''}`}>
              <div className="flex items-center justify-between">
                <Label htmlFor="password" className="text-lg font-semibold text-foreground">
                  Mật khẩu
                </Label>
                <button
                  type="button"
                  onClick={handleForgotPassword}
                  className="text-base text-primary hover:text-primary/80 transition-colors"
                >
                  Quên mật khẩu?
                </button>
              </div>
              <div className="relative">
                <Input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  placeholder="••••••••"
                  value={password}
                  disabled={Boolean(pending2FAUser)}
                  onChange={(e) => {
                    setPassword(e.target.value)
                    // Clear error when user starts typing
                    if (errors.password) {
                      setErrors(prev => { const { password, ...rest } = prev; return rest })
                    }
                  }}
                  onBlur={handlePasswordBlur}
                  className={`h-14 pr-14 text-base ${errors.password ? 'border-destructive border-2' : ''}`}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-4 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                >
                  {showPassword ? (
                    <EyeOff className="w-6 h-6" />
                  ) : (
                    <Eye className="w-6 h-6" />
                  )}
                </button>
              </div>
              {errors.password && (
                <p className="text-sm text-destructive flex items-center gap-1 mt-1">
                  <AlertCircle className="w-4 h-4" />
                  {errors.password}
                </p>
              )}
            </div>

            {pending2FAUser && (
              <div className="space-y-3">
                <div className="text-center space-y-3 mb-8">
                  <h3 className="text-3xl font-bold text-foreground">Xác minh OTP</h3>
                  <p className="text-base text-muted-foreground">
                    Nhập mã gồm 6 chữ số đã được gửi đến email của bạn.
                  </p>
                </div>
                <div className="flex items-center justify-between">
                  <Label htmlFor="otp" className="text-lg font-semibold text-foreground">
                    Mã OTP
                  </Label>
                  <button
                    type="button"
                    onClick={handleBackToPassword}
                    className="text-base text-primary hover:text-primary/80 transition-colors"
                  >
                    Đổi tài khoản
                  </button>
                </div>
                <Input
                  id="otp"
                  inputMode="numeric"
                  pattern="[0-9]*"
                  maxLength={6}
                  placeholder="123456"
                  value={otp}
                  onChange={(e) => {
                    setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))
                    if (errors.otp) {
                      setErrors(prev => { const { otp, ...rest } = prev; return rest })
                    }
                  }}
                  className={`h-14 text-center text-xl tracking-[0.5em] ${errors.otp ? 'border-destructive border-2' : ''}`}
                  autoFocus
                />
                {errors.otp && (
                  <p className="text-sm text-destructive flex items-center gap-1 mt-1">
                    <AlertCircle className="w-4 h-4" />
                    {errors.otp}
                  </p>
                )}
              </div>
            )}

            <div className={`flex items-center gap-3 ${pending2FAUser ? 'hidden' : ''}`}>
              <Checkbox id="remember" className="w-5 h-5" />
              <Label htmlFor="remember" className="text-base text-muted-foreground cursor-pointer">
                Ghi nhớ đăng nhập
              </Label>
            </div>

            {pending2FAUser && (
              <Button
                type="submit"
                className="w-full h-14 text-lg font-semibold"
                disabled={isLoading}
              >
                {isLoading ? (
                  <>
                    <Loader2 className="w-5 h-5 animate-spin mr-2" />
                    Đang xác thực...
                  </>
                ) : (
                  "Xác thực OTP"
                )}
              </Button>
            )}

            {!pending2FAUser && (
              <Button
                type="submit"
                className="w-full h-14 text-lg font-semibold"
                disabled={isLoading}
              >
                {isLoading ? (
                  <>
                    <Loader2 className="w-5 h-5 animate-spin mr-2" />
                    Đang đăng nhập...
                  </>
                ) : (
                  "Đăng nhập"
                )}
              </Button>
            )}
          </form>

          {/* Divider */}
          <div className={`relative my-8 ${pending2FAUser ? 'hidden' : ''}`}>
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-border" />
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-4 bg-background text-muted-foreground">
                hoặc đăng nhập với
              </span>
            </div>
          </div>

          {/* Social Login */}
          <div className={`grid grid-cols-2 gap-4 ${pending2FAUser ? 'hidden' : ''}`}>
            <Button
              type="button"
              variant="outline"
              className="h-12"
            >
              <svg className="w-5 h-5 mr-2" viewBox="0 0 24 24">
                <path
                  fill="currentColor"
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                />
                <path
                  fill="currentColor"
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                />
                <path
                  fill="currentColor"
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                />
                <path
                  fill="currentColor"
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                />
              </svg>
              Google
            </Button>
            <Button
              type="button"
              variant="outline"
              className="h-12"
            >
              <svg className="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 2C6.477 2 2 6.477 2 12c0 4.42 2.865 8.166 6.839 9.489.5.092.682-.217.682-.482 0-.237-.008-.866-.013-1.7-2.782.604-3.369-1.341-3.369-1.341-.454-1.155-1.11-1.462-1.11-1.462-.908-.62.069-.608.069-.608 1.003.07 1.531 1.03 1.531 1.03.892 1.529 2.341 1.087 2.91.831.092-.646.35-1.086.636-1.336-2.22-.253-4.555-1.11-4.555-4.943 0-1.091.39-1.984 1.029-2.683-.103-.253-.446-1.27.098-2.647 0 0 .84-.269 2.75 1.025A9.578 9.578 0 0112 6.836c.85.004 1.705.114 2.504.336 1.909-1.294 2.747-1.025 2.747-1.025.546 1.377.203 2.394.1 2.647.64.699 1.028 1.592 1.028 2.683 0 3.842-2.339 4.687-4.566 4.935.359.309.678.919.678 1.852 0 1.336-.012 2.415-.012 2.743 0 .267.18.578.688.48C19.138 20.163 22 16.418 22 12c0-5.523-4.477-10-10-10z" />
              </svg>
              GitHub
            </Button>
          </div>

          {/* Footer */}
          <p className={`mt-8 text-center text-sm text-muted-foreground ${pending2FAUser ? 'hidden' : ''}`}>
            Chưa có tài khoản?{" "}
            <button 
              type="button"
              onClick={handleRegisterClick}
              className="text-primary hover:text-primary/80 font-medium transition-colors"
            >
              Liên hệ quản trị viên
            </button>
          </p>

          <p className={`mt-6 text-center text-xs text-muted-foreground ${pending2FAUser ? 'hidden' : ''}`}>
            © 2025 Ecommerce Shop Admin. All rights reserved.
          </p>
        </div>
      </div>
    </div>
  )
}
