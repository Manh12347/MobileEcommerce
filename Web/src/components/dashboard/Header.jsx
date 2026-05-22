import { Bell, Search, Settings, User, Menu as MenuIcon } from "lucide-react"
import { useLocation } from "react-router-dom"
import { Button } from "../ui/button"
import { Input } from "../ui/input"

const breadcrumbMap = {
  "/dashboard": { parent: "Trang chủ", current: "Tổng quan" },
  "/dashboard/discounts": { parent: "Trang chủ", current: "Giảm giá" },
  "/dashboard/brands": { parent: "Trang chủ", current: "Thương hiệu" },
}

export function Header({ sidebarCollapsed, onMenuClick }) {
  const location = useLocation()
  const breadcrumb = breadcrumbMap[location.pathname] || { parent: "Trang chủ", current: "Admin" }

  return (
    <header
      className="fixed top-0 right-0 z-30 h-16 bg-card border-b border-border flex items-center justify-between px-6 transition-all duration-300"
      style={{ 
        left: sidebarCollapsed ? "64px" : "256px",
        width: `calc(100% - ${sidebarCollapsed ? "64px" : "256px"})`
      }}
    >
      {/* Mobile Menu Button */}
      <Button 
        variant="ghost" 
        size="icon" 
        className="md:hidden"
        onClick={onMenuClick}
      >
        <MenuIcon className="w-5 h-5" />
      </Button>

      {/* Breadcrumb */}
      <div className="hidden md:flex items-center gap-2 text-sm">
        <span className="text-muted-foreground">{breadcrumb.parent}</span>
        <span className="text-muted-foreground">/</span>
        <span className="text-primary">Admin</span>
        <span className="text-muted-foreground">/</span>
        <span className="text-foreground font-medium">{breadcrumb.current}</span>
      </div>

      {/* Right Actions */}
      <div className="flex items-center gap-3">
        <div className="relative hidden md:block">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm kiếm..."
            className="pl-9 w-64 bg-secondary border-none"
          />
        </div>

        <Button variant="ghost" size="icon" className="relative">
          <Bell className="w-5 h-5" />
          <span className="absolute top-1 right-1 w-2 h-2 bg-destructive rounded-full" />
        </Button>

        <Button variant="ghost" size="icon">
          <Settings className="w-5 h-5" />
        </Button>

        <Button variant="ghost" size="icon" className="rounded-full bg-primary/10">
          <User className="w-5 h-5 text-primary" />
        </Button>
      </div>
    </header>
  )
}
