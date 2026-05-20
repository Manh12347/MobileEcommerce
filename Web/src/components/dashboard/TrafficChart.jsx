import { useState } from "react"
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  Legend,
} from "recharts"
import { Badge } from "../ui/badge"

const data = [
  { name: "T2", visits: 80, unique: 60, pageviews: 100, newUsers: 40 },
  { name: "T3", visits: 120, unique: 80, pageviews: 140, newUsers: 55 },
  { name: "T4", visits: 90, unique: 70, pageviews: 110, newUsers: 45 },
  { name: "T5", visits: 140, unique: 95, pageviews: 160, newUsers: 70 },
  { name: "T6", visits: 100, unique: 75, pageviews: 130, newUsers: 50 },
  { name: "T7", visits: 180, unique: 120, pageviews: 200, newUsers: 85 },
  { name: "CN", visits: 150, unique: 100, pageviews: 170, newUsers: 65 },
]

const metrics = [
  { key: "visits", label: "Lượt truy cập", value: "29.703", percent: "40%", color: "#4A89DC" },
  { key: "unique", label: "Người dùng mới", value: "24.093", percent: "20%", color: "#48CFAD" },
  { key: "pageviews", label: "Lượt xem trang", value: "78.706", percent: "60%", color: "#FFCE54" },
  { key: "newUsers", label: "Đơn hàng mới", value: "22.123", percent: "80%", color: "#ED5565" },
]

export function TrafficChart() {
  const [period, setPeriod] = useState("month")
  const [activeMetrics, setActiveMetrics] = useState(["visits", "unique", "pageviews", "newUsers"])

  const toggleMetric = (key) => {
    if (activeMetrics.includes(key)) {
      if (activeMetrics.length > 1) {
        setActiveMetrics(activeMetrics.filter(m => m !== key))
      }
    } else {
      setActiveMetrics([...activeMetrics, key])
    }
  }

  return (
    <div className="bg-card rounded-lg border border-border">
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b border-border flex-wrap gap-4">
        <div>
          <h3 className="text-lg font-semibold text-foreground">Lưu lượng truy cập</h3>
          <p className="text-sm text-muted-foreground">Tháng 5, 2026</p>
        </div>
        <div className="flex gap-1 bg-secondary rounded-lg p-1">
          {["day", "month", "year"].map((p) => (
            <button
              key={p}
              onClick={() => setPeriod(p)}
              className={`px-3 py-1.5 text-sm font-medium rounded-md transition-colors ${
                period === p
                  ? "bg-primary text-primary-foreground"
                  : "text-muted-foreground hover:text-foreground"
              }`}
            >
              {p === "day" ? "Ngày" : p === "month" ? "Tháng" : "Năm"}
            </button>
          ))}
        </div>
      </div>

      {/* Chart */}
      <div className="p-4">
        <div className="h-72">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={data}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
              <XAxis
                dataKey="name"
                stroke="var(--muted-foreground)"
                fontSize={12}
                tickLine={false}
                axisLine={false}
              />
              <YAxis
                stroke="var(--muted-foreground)"
                fontSize={12}
                tickLine={false}
                axisLine={false}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: "var(--card)",
                  border: "1px solid var(--border)",
                  borderRadius: "8px",
                }}
                labelStyle={{ color: "var(--foreground)" }}
              />
              {activeMetrics.includes("visits") && (
                <Line
                  type="monotone"
                  dataKey="visits"
                  stroke="#4A89DC"
                  strokeWidth={2}
                  dot={false}
                  name="Lượt truy cập"
                />
              )}
              {activeMetrics.includes("unique") && (
                <Line
                  type="monotone"
                  dataKey="unique"
                  stroke="#48CFAD"
                  strokeWidth={2}
                  dot={false}
                  name="Người dùng mới"
                />
              )}
              {activeMetrics.includes("pageviews") && (
                <Line
                  type="monotone"
                  dataKey="pageviews"
                  stroke="#FFCE54"
                  strokeWidth={2}
                  dot={false}
                  strokeDasharray="5 5"
                  name="Lượt xem trang"
                />
              )}
              {activeMetrics.includes("newUsers") && (
                <Line
                  type="monotone"
                  dataKey="newUsers"
                  stroke="#ED5565"
                  strokeWidth={2}
                  dot={false}
                  name="Đơn hàng mới"
                />
              )}
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Metrics */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6 pt-4 border-t border-border">
          {metrics.map((metric) => (
            <div key={metric.key} className="text-center">
              <div 
                className="flex items-center justify-center gap-2 mb-1 cursor-pointer hover:opacity-80 transition-opacity"
                onClick={() => toggleMetric(metric.key)}
              >
                <div
                  className="w-3 h-3 rounded-full transition-opacity"
                  style={{ 
                    backgroundColor: metric.color,
                    opacity: activeMetrics.includes(metric.key) ? 1 : 0.3
                  }}
                />
                <span className={`text-xs transition-opacity ${activeMetrics.includes(metric.key) ? 'text-muted-foreground' : 'text-muted-foreground/50'}`}>
                  {metric.label}
                </span>
              </div>
              <p className="text-xl font-bold text-foreground">{metric.value}</p>
              <p className="text-xs text-muted-foreground">({metric.percent})</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
