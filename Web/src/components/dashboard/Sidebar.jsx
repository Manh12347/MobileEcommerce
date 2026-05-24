import { useState } from "react"
import { Link, useLocation } from "react-router-dom"
import {
  LayoutDashboard,
  Percent,
  Building2,
  ChevronLeft,
  ChevronRight,
  Smartphone,
  LogOut,
  FolderTree,
  Package,
  Layers3,
  ClipboardList,
  ShieldCheck,
  Users,
} from "lucide-react"
import { clearAdminSession } from "../../api/authSession"

const menuItems = [
  { icon: LayoutDashboard, label: "Tổng quan", href: "/dashboard" },
  { icon: Percent, label: "Giảm giá", href: "/dashboard/discounts" },
  { icon: ClipboardList, label: "Đơn hàng", href: "/dashboard/orders" },
  { icon: ShieldCheck, label: "Bảo hành", href: "/dashboard/warranty" },
  { icon: Users, label: "Người dùng", href: "/dashboard/users" },
  { icon: Building2, label: "Thương hiệu", href: "/dashboard/brands" },
  { icon: FolderTree, label: "Danh mục", href: "/dashboard/categories" },
  { icon: Package, label: "Sản phẩm", href: "/dashboard/products" },
  { icon: Layers3, label: "Biến thể", href: "/dashboard/variants" },
]

export function Sidebar({ collapsed, onCollapsedChange }) {
  const location = useLocation()

  return (
    <aside
      className={`fixed left-0 top-0 z-40 h-screen bg-sidebar border-r border-sidebar-border transition-all duration-300 flex flex-col ${
        collapsed ? "w-16" : "w-64"
      }`}
    >
      {/* Logo */}
      <div className="flex items-center gap-3 px-4 h-16 border-b border-sidebar-border">
        <div className="w-9 h-9 rounded-lg bg-primary flex items-center justify-center flex-shrink-0">
          <Smartphone className="w-5 h-5 text-primary-foreground" />
        </div>
        {!collapsed && (
          <span className="text-lg font-semibold text-sidebar-foreground whitespace-nowrap">
            MobileShop
          </span>
        )}
      </div>

      {/* Menu */}
      <nav className="flex-1 p-3 space-y-1 overflow-y-auto">
        {menuItems.map((item) => {
          const isActive = location.pathname === item.href
          return (
            <Link
              key={item.href}
              to={item.href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg transition-colors ${
                isActive
                  ? "bg-primary text-primary-foreground"
                  : "text-muted-foreground hover:bg-sidebar-accent hover:text-sidebar-foreground"
              }`}
            >
              <item.icon className="w-5 h-5 flex-shrink-0" />
              {!collapsed && (
                <span className="text-sm font-medium">{item.label}</span>
              )}
            </Link>
          )
        })}
      </nav>

      {/* Collapse Button */}
      <button
        onClick={() => onCollapsedChange(!collapsed)}
        className="absolute bottom-20 right-0 translate-x-1/2 w-6 h-6 rounded-full bg-sidebar-accent border border-sidebar-border flex items-center justify-center text-muted-foreground hover:text-sidebar-foreground transition-colors"
      >
        {collapsed ? (
          <ChevronRight className="w-4 h-4" />
        ) : (
          <ChevronLeft className="w-4 h-4" />
        )}
      </button>

      {/* Logout */}
      <div className="p-3 border-t border-sidebar-border">
        <button
          onClick={() => {
            clearAdminSession();
            window.location.href = '/';
          }}
          className={`flex items-center gap-3 px-3 py-2.5 rounded-lg transition-colors w-full text-muted-foreground hover:bg-sidebar-accent hover:text-destructive ${
            collapsed ? "justify-center" : ""
          }`}
        >
          <LogOut className="w-5 h-5 flex-shrink-0" />
          {!collapsed && <span className="text-sm font-medium">Đăng xuất</span>}
        </button>
      </div>
    </aside>
  )
}
