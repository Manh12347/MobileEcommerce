import { useEffect, useMemo, useRef, useState } from "react"
import {
  Search,
  Plus,
  MoreVertical,
  Eye,
  CreditCard,
  Truck,
  Package,
  Clock3,
  RefreshCw,
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
import { ordersAPI } from "../../api/client"
import { useToast } from "../../hooks/use-toast"

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
  refunded: "Đã hoàn tiền",
}

const shippingLabels = {
  pending: "Chờ lấy hàng",
  packed: "Đã đóng gói",
  delivering: "Đang giao",
  delivered: "Đã giao",
  cancelled: "Đã hủy",
}

const formatCurrency = (value) => {
  if (value == null) return "—"
  return new Intl.NumberFormat("vi-VN").format(value) + "đ"
}

const formatDate = (dateStr) => {
  if (!dateStr) return "—"
  try {
    const d = new Date(dateStr)
    return d.toLocaleString("vi-VN", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    })
  } catch {
    return dateStr
  }
}

export function OrdersPage() {
  const { toast } = useToast()
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [paymentFilter, setPaymentFilter] = useState("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [orders, setOrders] = useState([])
  const [selectedOrder, setSelectedOrder] = useState(null)
  const [detailDialogOpen, setDetailDialogOpen] = useState(false)
  const [isLoading, setIsLoading] = useState(true)
  const [stats, setStats] = useState({ total: 0, pending: 0, shipping: 0, revenue: 0 })
  const isLoadingRef = useRef(false)

  const loadOrders = async () => {
    if (isLoadingRef.current) return
    try {
      isLoadingRef.current = true
      setIsLoading(true)
      const params = {}
      if (statusFilter !== "all") params.status = statusFilter
      const [ordersResp, statsResp] = await Promise.all([
        ordersAPI.getAll(params),
        ordersAPI.getStats(),
      ])
      const ordersData = ordersResp?.data?.data || []
      setOrders(ordersData)
      const statsData = statsResp?.data?.data
      if (statsData) {
        setStats({
          total: statsData.totalOrders || 0,
          pending: statsData.pendingOrders || 0,
          shipping: statsData.shippingOrders || 0,
          revenue: statsData.totalRevenue || 0,
        })
      }
    } catch (error) {
      toast({
        title: "Lỗi",
        description: error?.response?.data?.message || "Không tải được danh sách đơn hàng",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
      isLoadingRef.current = false
    }
  }

  useEffect(() => {
    loadOrders()
  }, [statusFilter])

  useEffect(() => {
    setCurrentPage(1)
  }, [searchTerm, statusFilter, paymentFilter, pageSize])

  const loadOrderDetail = async (orderId) => {
    try {
      const resp = await ordersAPI.getById(orderId)
      return resp?.data?.data
    } catch (error) {
      toast({
        title: "Lỗi",
        description: "Không tải được chi tiết đơn hàng",
        variant: "destructive",
      })
      return null
    }
  }

  const filteredOrders = useMemo(() => {
    const search = searchTerm.toLowerCase().trim()
    if (!search && paymentFilter === "all") return orders
    return orders.filter((order) => {
      const matchesSearch =
        !search ||
        order.orderCode?.toLowerCase().includes(search) ||
        order.customerName?.toLowerCase().includes(search) ||
        order.phone?.toLowerCase().includes(search)
      const matchesPayment =
        paymentFilter === "all" || order.paymentStatus === paymentFilter
      return matchesSearch && matchesPayment
    })
  }, [orders, searchTerm, paymentFilter])

  const pagedOrders = useMemo(
    () => filteredOrders.slice((currentPage - 1) * pageSize, currentPage * pageSize),
    [filteredOrders, currentPage, pageSize]
  )

  const openDetail = async (order) => {
    const detail = await loadOrderDetail(order.orderId)
    if (detail) {
      setSelectedOrder(detail)
      setDetailDialogOpen(true)
    }
  }

  const getOrderBadge = (status) => {
    switch (status) {
      case "completed": return "success"
      case "shipping": return "info"
      case "processing": return "warning"
      case "cancelled": return "destructive"
      default: return "secondary"
    }
  }

  const getPaymentBadge = (status) => {
    switch (status) {
      case "paid": return "success"
      case "failed": return "destructive"
      default: return "warning"
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Đơn hàng</h1>
          <p className="text-muted-foreground">Quản lý trạng thái, thanh toán và vận chuyển đơn hàng</p>
        </div>
        <Button
          className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20"
          onClick={loadOrders}
        >
          <RefreshCw className="mr-2 h-5 w-5" />
          Làm mới
        </Button>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Tổng đơn hàng</p>
              <p className="mt-2 text-2xl font-bold text-foreground">{stats.total.toLocaleString()}</p>
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
              <p className="mt-2 text-2xl font-bold text-amber-500">{stats.pending}</p>
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
              <p className="mt-2 text-2xl font-bold text-blue-500">{stats.shipping}</p>
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
            {isLoading ? (
              <TableRow>
                <TableCell colSpan={8} className="h-24 text-center text-muted-foreground">
                  Đang tải...
                </TableCell>
              </TableRow>
            ) : pagedOrders.length === 0 ? (
              <TableRow>
                <TableCell colSpan={8} className="h-24 text-center text-muted-foreground">
                  Không có đơn hàng nào
                </TableCell>
              </TableRow>
            ) : (
              pagedOrders.map((order) => {
                const orderTotal = order.totalPrice
                return (
                  <TableRow key={order.orderId}>
                    <TableCell className="text-left">
                      <div>
                        <p className="font-semibold text-foreground">{order.orderCode || "—"}</p>
                        <p className="text-xs text-muted-foreground">{formatCurrency(orderTotal)}</p>
                      </div>
                    </TableCell>
                    <TableCell className="text-left">
                      <div>
                        <p className="font-medium text-foreground">{order.customerName || "—"}</p>
                        <p className="text-xs text-muted-foreground">{order.phone || "—"}</p>
                      </div>
                    </TableCell>
                    <TableCell className="text-left text-muted-foreground">
                      {order.itemCount != null ? `${order.itemCount} sản phẩm` : "—"}
                    </TableCell>
                    <TableCell className="text-left">
                      <Badge variant={getPaymentBadge(order.paymentStatus)}>
                        {paymentLabels[order.paymentStatus] || order.paymentStatus}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-left">
                      <Badge variant={order.status === "completed" ? "success" : order.status === "cancelled" ? "destructive" : "info"}>
                        {order.paymentMethod || "—"}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-center">
                      <Badge variant={getOrderBadge(order.status)}>
                        {statusLabels[order.status] || order.status}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-left text-muted-foreground">
                      {formatDate(order.createdOn)}
                    </TableCell>
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
              })
            )}
          </TableBody>
        </Table>
      </div>

      {!isLoading && filteredOrders.length > 0 && (
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
      )}

      <Dialog open={detailDialogOpen} onOpenChange={setDetailDialogOpen}>
        <DialogContent className="max-w-3xl">
          <DialogHeader className="text-left">
            <DialogTitle className="text-xl">
              Chi tiết đơn hàng {selectedOrder?.orderCode}
            </DialogTitle>
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
                    <p>{selectedOrder.customerName || "—"}</p>
                    <p>{selectedOrder.phone || "—"}</p>
                    <p>{selectedOrder.email || "—"}</p>
                    <p className="flex items-start gap-2">
                      <Truck className="mt-0.5 h-4 w-4 flex-shrink-0" />
                      <span>{selectedOrder.shippingAddress || "—"}</span>
                    </p>
                  </div>
                </div>

                <div className="rounded-lg border border-border bg-secondary/20 p-4">
                  <p className="mb-3 text-sm font-semibold text-foreground">Trạng thái xử lý</p>
                  <div className="space-y-3 text-sm">
                    <div className="flex items-center justify-between">
                      <span className="text-muted-foreground">Thanh toán</span>
                      <Badge variant={getPaymentBadge(selectedOrder.paymentStatus)}>
                        {paymentLabels[selectedOrder.paymentStatus] || selectedOrder.paymentStatus}
                      </Badge>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-muted-foreground">Phương thức</span>
                      <span className="font-medium text-foreground">{selectedOrder.paymentMethod || "—"}</span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-muted-foreground">Đơn hàng</span>
                      <Badge variant={getOrderBadge(selectedOrder.status)}>
                        {statusLabels[selectedOrder.status] || selectedOrder.status}
                      </Badge>
                    </div>
                  </div>
                </div>
              </div>

              <div className="rounded-lg border border-border bg-secondary/20 p-4">
                <p className="mb-3 text-sm font-semibold text-foreground">Danh sách sản phẩm</p>
                <div className="space-y-3">
                  {selectedOrder.items?.map((item, index) => (
                    <div
                      key={`${item.productItemId || ""}-${index}`}
                      className="flex items-center justify-between rounded-md border border-border bg-background px-4 py-3"
                    >
                      <div>
                        <p className="font-medium text-foreground">{item.productName || item.name || "—"}</p>
                        <p className="text-xs text-muted-foreground">
                          {item.sku ? `SKU: ${item.sku}` : ""} {item.quantity ? `x ${item.quantity}` : ""}
                        </p>
                      </div>
                      <p className="font-semibold text-foreground">
                        {formatCurrency(item.price ? item.price * (item.quantity || 1) : item.totalPrice)}
                      </p>
                    </div>
                  ))}
                </div>
              </div>

              <div className="flex items-center justify-between rounded-lg border border-border bg-primary/10 px-4 py-3">
                <div>
                  <p className="text-sm text-muted-foreground">Tổng tiền</p>
                  <p className="text-lg font-bold text-foreground">
                    {formatCurrency(selectedOrder.totalPrice)}
                  </p>
                </div>
                <div className="flex items-center gap-2 text-sm text-muted-foreground">
                  <CreditCard className="h-4 w-4" />
                  {selectedOrder.paymentMethod || "—"}
                </div>
              </div>
            </div>
          )}

          <DialogFooter className="gap-3 pt-2">
            <Button variant="outline" onClick={() => setDetailDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Đóng
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
