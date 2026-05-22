import { StatCard } from "../../components/dashboard/StatCard"
import { TrafficChart } from "../../components/dashboard/TrafficChart"

const statsData = [
  {
    title: "Người dùng",
    value: "9,823",
    color: "blue",
    data: [30, 45, 35, 50, 40, 55, 45, 60, 50],
    trend: 12,
  },
  {
    title: "Đơn hàng",
    value: "1,256",
    color: "teal",
    data: [20, 35, 25, 40, 30, 45, 55, 50, 60],
    trend: 8,
  },
  {
    title: "Sản phẩm",
    value: "3,456",
    color: "yellow",
    data: [40, 55, 45, 60, 50, 65, 55, 70, 60],
    trend: 5,
  },
  {
    title: "Doanh thu",
    value: "₫89.5M",
    color: "red",
    data: [25, 40, 30, 45, 35, 50, 45, 55, 65],
    trend: 15,
  },
]

export function DashboardPage() {
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
