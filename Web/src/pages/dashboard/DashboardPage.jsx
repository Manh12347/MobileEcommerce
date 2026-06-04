import { useEffect, useState } from "react"
import { StatCard } from "../../components/dashboard/StatCard"
import { TrafficChart } from "../../components/dashboard/TrafficChart"
import { ordersAPI } from "../../api/client"
import { catalogAPI } from "../../api/client"
import { useToast } from "../../hooks/use-toast"

const formatCurrency = (value) => {
  if (value == null) return "0đ"
  return new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 0 }).format(value) + "đ"
}

export function DashboardPage() {
  const { toast } = useToast()
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalOrders: 0,
    totalProducts: 0,
    totalRevenue: 0,
    pendingOrders: 0,
    shippingOrders: 0,
    completedOrders: 0,
    cancelledOrders: 0,
  })
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    const loadStats = async () => {
      try {
        setIsLoading(true)
        const [orderStats, productsResp] = await Promise.all([
          ordersAPI.getStats(),
          catalogAPI.getProducts({ page: 1, size: 1 }),
        ])
        const data = orderStats?.data?.data
        const productsData = productsResp?.data?.data

        if (data) {
          setStats({
            totalUsers: data.totalUsers || 0,
            totalOrders: data.totalOrders || 0,
            totalProducts: data.totalProducts || productsData?.page?.totalElements || 0,
            totalRevenue: data.totalRevenue || 0,
            pendingOrders: data.pendingOrders || 0,
            shippingOrders: data.shippingOrders || 0,
            completedOrders: data.completedOrders || 0,
            cancelledOrders: data.cancelledOrders || 0,
          })
        }
      } catch (error) {
        toast({
          title: "Lỗi",
          description: "Không tải được thống kê dashboard",
          variant: "destructive",
        })
      } finally {
        setIsLoading(false)
      }
    }
    loadStats()
  }, [])

  const statsData = [
    {
      title: "Người dùng",
      value: isLoading ? "..." : stats.totalUsers.toLocaleString(),
      color: "blue",
      data: [30, 45, 35, 50, 40, 55, 45, 60, stats.totalUsers > 0 ? Math.min(Math.floor(stats.totalUsers / 200), 65) : 50],
      trend: 12,
    },
    {
      title: "Đơn hàng",
      value: isLoading ? "..." : stats.totalOrders.toLocaleString(),
      color: "teal",
      data: [20, 35, 25, 40, 30, 45, 55, 50, stats.totalOrders > 0 ? Math.min(Math.floor(stats.totalOrders / 30), 65) : 60],
      trend: 8,
    },
    {
      title: "Sản phẩm",
      value: isLoading ? "..." : stats.totalProducts.toLocaleString(),
      color: "yellow",
      data: [40, 55, 45, 60, 50, 65, 55, 70, stats.totalProducts > 0 ? Math.min(Math.floor(stats.totalProducts / 80), 70) : 60],
      trend: 5,
    },
    {
      title: "Doanh thu",
      value: isLoading ? "..." : formatCurrency(stats.totalRevenue),
      color: "red",
      data: [25, 40, 30, 45, 35, 50, 45, 55, stats.totalRevenue > 0 ? Math.min(Math.floor(Number(stats.totalRevenue) / 2_000_000), 65) : 65],
      trend: 15,
    },
  ]

  return (
    <>
      {/* Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        {statsData.map((stat) => (
          <StatCard
            key={stat.title}
            title={stat.title}
            value={stat.value}
            color={stat.color}
            data={stat.data}
            trend={stat.trend}
          />
        ))}
      </div>

      {/* Traffic Chart */}
      <TrafficChart />
    </>
  )
}
