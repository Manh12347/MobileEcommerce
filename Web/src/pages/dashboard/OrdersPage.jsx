import { useEffect, useMemo, useState } from "react"
import {
  Search,
  Plus,
  MoreVertical,
  Eye,
  CreditCard,
  Truck,
  Package,
  Clock3,
  CheckCircle2,
  XCircle,
  MapPin,
} from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from "../../components/ui/table"
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
} from "../../components/ui/dropdown-menu"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "../../components/ui/dialog"
import { PaginationControls } from "../../components/dashboard/PaginationControls"

const mockOrders = [
  {
    id: 1,
    code: "OD-100245",
    customer: "Nguyễn Văn A",
    phone: "0901 234 567",
    email: "nva@gmail.com",
    address: "Q.1, TP. Hồ Chí Minh",
    items: [
      { name: "iPhone 15 Pro Max", variant: "256GB", qty: 1, price: 32990000 },
      { name: "AirPods Pro 2", variant: "USB-C", qty: 1, price: 5490000 },
    ],
    paymentMethod: "COD",
    paymentStatus: "paid",
    shippingMethod: "Giao nhanh",
    shippingStatus: "delivering",
    orderStatus: "processing",
    createdAt: "2026-05-22 09:35",
  },
  {
    id: 2,
    code: "OD-100244",
    customer: "Trần Thị B",
    phone: "0912 345 678",
    email: "ttb@gmail.com",
    address: "Ninh Kiều, Cần Thơ",
    items: [
      { name: "Samsung Galaxy S24 Ultra", variant: "512GB", qty: 1, price: 31990000 },
    ],
    paymentMethod: "VNPay",
    paymentStatus: "paid",
    shippingMethod: "Tiêu chuẩn",
    shippingStatus: "delivered",
    orderStatus: "completed",
    createdAt: "2026-05-21 14:12",
  },
  {
    id: 3,
    code: "OD-100243",
    customer: "Lê Minh C",
    phone: "0933 456 789",
    email: "lmc@gmail.com",
    address: "Thanh Xuân, Hà Nội",
    items: [
      { name: "Xiaomi Redmi Note 13 Pro", variant: "256GB", qty: 2, price: 10990000 },
    ],
    paymentMethod: "Momo",
    paymentStatus: "pending",
    shippingMethod: "Tiêu chuẩn",
    shippingStatus: "pending",
    orderStatus: "pending",
    createdAt: "2026-05-21 08:18",
  },
  {
    id: 4,
    code: "OD-100242",
    customer: "Phạm Thu D",
    phone: "0944 567 890",
    email: "ptd@gmail.com",
    address: "Hải Châu, Đà Nẵng",
    items: [
      { name: "iPad Pro M4 11 inch", variant: "256GB WiFi", qty: 1, price: 26990000 },
      { name: "Apple Pencil", variant: "USB-C", qty: 1, price: 1990000 },
    ],
    paymentMethod: "Chuyển khoản",
    paymentStatus: "paid",
    shippingMethod: "Hỏa tốc",
    shippingStatus: "packed",
    orderStatus: "shipping",
    createdAt: "2026-05-20 16:45",
  },
  {
    id: 5,
    code: "OD-100241",
    customer: "Hoàng Anh E",
    phone: "0977 888 999",
    email: "hae@gmail.com",
    address: "Nha Trang, Khánh Hòa",
    items: [
      { name: "AirPods Pro 2", variant: "USB-C", qty: 1, price: 5490000 },
    ],
    paymentMethod: "COD",
    paymentStatus: "failed",
    shippingMethod: "Tiêu chuẩn",
    shippingStatus: "cancelled",
    orderStatus: "cancelled",
    createdAt: "2026-05-20 11:30",
  },
  {
    id: 6,
    code: "OD-100240",
    customer: "Vũ Quốc F",
    phone: "0988 111 222",
    email: "vqf@gmail.com",
    address: "Thủ Đức, TP. Hồ Chí Minh",
    items: [
      { name: "OPPO Find X7 Pro", variant: "512GB", qty: 1, price: 22990000 },
    ],
    paymentMethod: "VNPay",
    paymentStatus: "paid",
    shippingMethod: "Giao nhanh",
    shippingStatus: "delivering",
    orderStatus: "processing",
    createdAt: "2026-05-19 19:02",
  },
]

const statusLabels = {
  pending: "Chờ xử lý",
  processing: "Đang xử lý",
  shipping: "Đang giao",
  completed: "Hoàn tất",
  cancelled: "Đã hủy",
}

const paymentLabels = {
  paid: "Đã thanh toán",
  pending: "Chưa thanh toán",
  failed: "Thanh toán lỗi",
}

const shippingLabels = {
  pending: "Chờ lấy hàng",
  packed: "Đã đóng gói",
  delivering: "Đang giao",
  delivered: "Đã giao",
  cancelled: "Đã hủy",
}

const formatCurrency = (value) => new Intl.NumberFormat("vi-VN").format(value) + "đ"

export function OrdersPage() {
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [paymentFilter, setPaymentFilter] = useState("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(5)
  const [orders, setOrders] = useState(mockOrders)
  const [selectedOrder, setSelectedOrder] = useState(null)
  const [detailDialogOpen, setDetailDialogOpen] = useState(false)

  useEffect(() => {
    setCurrentPage(1)
  }, [searchTerm, statusFilter, paymentFilter, pageSize])

  const stats = useMemo(() => {
    const total = orders.length
    const pending = orders.filter((order) => order.orderStatus === "pending").length
    const shipping = orders.filter((order) => order.orderStatus === "shipping").length
    const revenue = orders
      .filter((order) => order.paymentStatus === "paid")
      .reduce(
        (sum, order) =>
          sum + order.items.reduce((itemSum, item) => itemSum + item.price * item.qty, 0),
        0,
      )

    return { total, pending, shipping, revenue }
  }, [orders])

  const filteredOrders = orders.filter((order) => {
    const search = searchTerm.toLowerCase()
    const matchesSearch =
      order.code.toLowerCase().includes(search) ||
      order.customer.toLowerCase().includes(search) ||
      order.phone.toLowerCase().includes(search)
    const matchesStatus = statusFilter === "all" || order.orderStatus === statusFilter
    const matchesPayment = paymentFilter === "all" || order.paymentStatus === paymentFilter
    return matchesSearch && matchesStatus && matchesPayment
  })

  const pagedOrders = filteredOrders.slice((currentPage - 1) * pageSize, currentPage * pageSize)

  const openDetail = (order) => {
    setSelectedOrder(order)
    setDetailDialogOpen(true)
  }

  const getOrderBadge = (status) => {
    if (status === "completed") return "success"
    if (status === "shipping") return "info"
    if (status === "processing") return "warning"
    if (status === "cancelled") return "destructive"
    return "secondary"
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Đơn hàng</h1>
          <p className="text-muted-foreground">Quản lý trạng thái, thanh toán và vận chuyển đơn hàng</p>
        </div>
        <Button className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
          <Plus className="mr-2 h-5 w-5" />
          Tạo đơn hàng
        </Button>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Tổng đơn hàng</p>
              <p className="mt-2 text-2xl font-bold text-foreground">{stats.total}</p>
            </div>
            <div className="rounded-full bg-primary/10 p-3 text-primary">
              <Package className="h-5 w-5" />
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Chờ xử lý</p>
              <p className="mt-2 text-2xl font-bold text-foreground">{stats.pending}</p>
            </div>
            <div className="rounded-full bg-amber-500/10 p-3 text-amber-400">
              <Clock3 className="h-5 w-5" />
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Đang giao</p>
              <p className="mt-2 text-2xl font-bold text-foreground">{stats.shipping}</p>
            </div>
            <div className="rounded-full bg-blue-500/10 p-3 text-blue-400">
              <Truck className="h-5 w-5" />
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Doanh thu đã thanh toán</p>
              <p className="mt-2 text-2xl font-bold text-foreground">{formatCurrency(stats.revenue)}</p>
            </div>
            <div className="rounded-full bg-emerald-500/10 p-3 text-emerald-400">
              <CreditCard className="h-5 w-5" />
            </div>
          </div>
        </div>
      </div>

      <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div className="grid w-full gap-3 sm:grid-cols-2 xl:max-w-3xl xl:grid-cols-3">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder="Tìm theo mã đơn, khách hàng, số điện thoại..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-9"
            />
          </div>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="h-10 rounded-md border border-input bg-background px-3 text-sm text-foreground"
          >
            <option value="all">Tất cả trạng thái</option>
            <option value="pending">Chờ xử lý</option>
            <option value="processing">Đang xử lý</option>
            <option value="shipping">Đang giao</option>
            <option value="completed">Hoàn tất</option>
            <option value="cancelled">Đã hủy</option>
          </select>
          <select
            value={paymentFilter}
            onChange={(e) => setPaymentFilter(e.target.value)}
            className="h-10 rounded-md border border-input bg-background px-3 text-sm text-foreground"
          >
            <option value="all">Tất cả thanh toán</option>
            <option value="paid">Đã thanh toán</option>
            <option value="pending">Chưa thanh toán</option>
            <option value="failed">Thanh toán lỗi</option>
          </select>
        </div>
      </div>

      <div className="overflow-hidden rounded-lg border border-border bg-card">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="text-left">Mã đơn</TableHead>
              <TableHead className="text-left">Khách hàng</TableHead>
              <TableHead className="text-left">Sản phẩm</TableHead>
              <TableHead className="text-left">Thanh toán</TableHead>
              <TableHead className="text-left">Vận chuyển</TableHead>
              <TableHead className="text-center">Trạng thái</TableHead>
              <TableHead className="text-left">Ngày tạo</TableHead>
              <TableHead className="w-12 text-center"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {pagedOrders.map((order) => {
              const orderTotal = order.items.reduce((sum, item) => sum + item.price * item.qty, 0)

              return (
                <TableRow key={order.id}>
                  <TableCell className="text-left">
                    <div>
                      <p className="font-semibold text-foreground">{order.code}</p>
                      <p className="text-xs text-muted-foreground">{formatCurrency(orderTotal)}</p>
                    </div>
                  </TableCell>
                  <TableCell className="text-left">
                    <div>
                      <p className="font-medium text-foreground">{order.customer}</p>
                      <p className="text-xs text-muted-foreground">{order.phone}</p>
                    </div>
                  </TableCell>
                  <TableCell className="text-left text-muted-foreground">
                    {order.items.length} sản phẩm
                  </TableCell>
                  <TableCell className="text-left">
                    <Badge variant={order.paymentStatus === "paid" ? "success" : order.paymentStatus === "failed" ? "destructive" : "warning"}>
                      {paymentLabels[order.paymentStatus]}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-left">
                    <Badge variant={order.shippingStatus === "delivered" ? "success" : order.shippingStatus === "cancelled" ? "destructive" : "info"}>
                      {shippingLabels[order.shippingStatus]}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-center">
                    <Badge variant={getOrderBadge(order.orderStatus)}>
                      {statusLabels[order.orderStatus]}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-left text-muted-foreground">{order.createdAt}</TableCell>
                  <TableCell className="text-center">
                    <DropdownMenu>
                      <DropdownMenuTrigger>
                        <Button variant="ghost" size="icon" className="h-10 w-10 hover:bg-primary/10 hover:text-primary transition-colors">
                          <MoreVertical className="h-5 w-5" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end" className="w-44">
                        <DropdownMenuItem
                          className="flex items-center rounded-md px-4 py-3 text-base cursor-pointer"
                          onSelect={() => openDetail(order)}
                        >
                          <Eye className="mr-3 h-5 w-5 text-blue-500" />
                          Xem chi tiết
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      </div>

      <PaginationControls
        totalItems={filteredOrders.length}
        pageSize={pageSize}
        currentPage={currentPage}
        onPageChange={setCurrentPage}
        onPageSizeChange={(size) => {
          setPageSize(size)
          setCurrentPage(1)
        }}
      />

      <Dialog open={detailDialogOpen} onOpenChange={setDetailDialogOpen}>
        <DialogContent className="max-w-3xl">
          <DialogHeader className="text-left">
            <DialogTitle className="text-xl">Chi tiết đơn hàng {selectedOrder?.code}</DialogTitle>
            <DialogDescription>
              Thông tin khách hàng, sản phẩm và trạng thái xử lý đơn hàng.
            </DialogDescription>
          </DialogHeader>

          {selectedOrder && (
            <div className="space-y-5 py-2">
              <div className="grid gap-4 md:grid-cols-2">
                <div className="rounded-lg border border-border bg-secondary/20 p-4">
                  <p className="mb-3 text-sm font-semibold text-foreground">Thông tin khách hàng</p>
                  <div className="space-y-2 text-sm text-muted-foreground">
                    <p>{selectedOrder.customer}</p>
                    <p>{selectedOrder.phone}</p>
                    <p>{selectedOrder.email}</p>
                    <p className="flex items-start gap-2">
                      <MapPin className="mt-0.5 h-4 w-4 flex-shrink-0" />
                      <span>{selectedOrder.address}</span>
                    </p>
                  </div>
                </div>

                <div className="rounded-lg border border-border bg-secondary/20 p-4">
                  <p className="mb-3 text-sm font-semibold text-foreground">Trạng thái xử lý</p>
                  <div className="space-y-3 text-sm">
                    <div className="flex items-center justify-between">
                      <span className="text-muted-foreground">Thanh toán</span>
                      <Badge variant={selectedOrder.paymentStatus === "paid" ? "success" : selectedOrder.paymentStatus === "failed" ? "destructive" : "warning"}>
                        {paymentLabels[selectedOrder.paymentStatus]}
                      </Badge>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-muted-foreground">Vận chuyển</span>
                      <Badge variant={selectedOrder.shippingStatus === "delivered" ? "success" : selectedOrder.shippingStatus === "cancelled" ? "destructive" : "info"}>
                        {shippingLabels[selectedOrder.shippingStatus]}
                      </Badge>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-muted-foreground">Đơn hàng</span>
                      <Badge variant={getOrderBadge(selectedOrder.orderStatus)}>
                        {statusLabels[selectedOrder.orderStatus]}
                      </Badge>
                    </div>
                  </div>
                </div>
              </div>

              <div className="rounded-lg border border-border bg-secondary/20 p-4">
                <p className="mb-3 text-sm font-semibold text-foreground">Danh sách sản phẩm</p>
                <div className="space-y-3">
                  {selectedOrder.items.map((item, index) => (
                    <div key={`${item.name}-${index}`} className="flex items-center justify-between rounded-md border border-border bg-background px-4 py-3">
                      <div>
                        <p className="font-medium text-foreground">{item.name}</p>
                        <p className="text-xs text-muted-foreground">{item.variant} x {item.qty}</p>
                      </div>
                      <p className="font-semibold text-foreground">{formatCurrency(item.price * item.qty)}</p>
                    </div>
                  ))}
                </div>
              </div>

              <div className="flex items-center justify-between rounded-lg border border-border bg-primary/10 px-4 py-3">
                <div>
                  <p className="text-sm text-muted-foreground">Tổng tiền</p>
                  <p className="text-lg font-bold text-foreground">
                    {formatCurrency(selectedOrder.items.reduce((sum, item) => sum + item.price * item.qty, 0))}
                  </p>
                </div>
                <div className="flex items-center gap-2 text-sm text-muted-foreground">
                  <CreditCard className="h-4 w-4" />
                  {selectedOrder.paymentMethod} • {selectedOrder.shippingMethod}
                </div>
              </div>
            </div>
          )}

          <DialogFooter className="gap-3 pt-2">
            <Button variant="outline" onClick={() => setDetailDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Đóng
            </Button>
            <Button className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              <Truck className="mr-2 h-4 w-4" />
              Cập nhật trạng thái
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}