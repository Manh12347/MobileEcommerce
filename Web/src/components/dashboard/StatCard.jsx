import { LineChart, Line, ResponsiveContainer } from "recharts"

const colorMap = {
  blue: {
    bg: "bg-[#4A89DC]",
    line: "#FFFFFF",
  },
  teal: {
    bg: "bg-[#48CFAD]",
    line: "#FFFFFF",
  },
  yellow: {
    bg: "bg-[#F6BB42]",
    line: "#FFFFFF",
  },
  red: {
    bg: "bg-[#E9573F]",
    line: "#FFFFFF",
  },
}

export function StatCard({ title, value, color = "blue", data = [], trend }) {
  const colors = colorMap[color] || colorMap.blue
  const chartData = data.map((value, index) => ({ value, index }))

  return (
    <div className={`${colors.bg} rounded-lg p-4 text-white relative overflow-hidden h-32`}>
      <div className="relative z-10">
        <p className="text-3xl font-bold">{value}</p>
        <p className="text-sm opacity-90">{title}</p>
        {trend && (
          <p className="text-xs opacity-75 mt-1">
            {trend > 0 ? "+" : ""}{trend}% so với tháng trước
          </p>
        )}
      </div>
      <div className="absolute bottom-0 left-0 right-0 h-12 opacity-40">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={chartData}>
            <Line
              type="monotone"
              dataKey="value"
              stroke={colors.line}
              strokeWidth={2}
              dot={false}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
