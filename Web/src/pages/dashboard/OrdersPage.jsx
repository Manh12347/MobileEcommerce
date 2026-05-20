import { useState } from "react"
import { Search, Eye, Truck, CheckCircle, XCircle, Clock, Package, MapPin, Phone } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "../../components/ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"
import { Tabs, TabsList, TabsTrigger, TabsContent } from "../../components/ui/tabs"

const mockOrders = [
  { id: "DH001", customer: "Nguyễn Văn A", phone: "0912345678", address: "123 Nguyễn Trãi, Q1, TP.HCM", total: 32990000, items: 1, status: "delivered", payment: "paid", date: "2026-05-18", product: "iPhone 15 Pro Max" },
  { id: "DH002", customer: "Trần Thị B", phone: "0923456789", address: "456 Lê Lợi, Q3, TP.HCM", total: 8990000, items: 2, status: "shipping", payment: "paid", date: "2026-05-19", product: "Xiaomi Redmi Note 13 Pro" },
  { id: "DH003", customer: "Lê Văn C", phone: "0934567890", address: "789 Trần Hưng Đạo, Q5, TP.HCM", total: 5490000, items: 1, status: "processing", payment: "pending", date: "2026-05-19", product: "AirPods Pro 2" },
  { id: "DH004", customer: "Phạm Thị D", phone: "0945678901", address: "321 Võ Văn Tần, Q3, TP.HCM", total: 26990000, items: 1, status: "confirmed", payment: "paid", date: "2026-05-20", product: "iPad Pro M4 11 inch" },
  { id: "DH005", customer: "Hoàng Văn E", phone: "0956789012", address: "654 Phạm Ngũ Lão, Q1, TP.HCM", total: 28990000, items: 1, status: "cancelled", payment: "refunded", date: "2026-05-17", product: "Samsung Galaxy S24 Ultra" },
]

const formatCurrency = (value) => {
  return new Intl.NumberFormat('vi-VN').format(value) + 'đ'
}

const statusConfig = {
  pending: { label: "Chờ xác nhận", variant: "warning", icon: Clock },
  confirmed: { label: "Đã xác nhận", variant: "info", icon: CheckCircle },
  processing: { label: "Đang xử lý", variant: "info", icon: Package },
  shipping: { label: "Đang giao", variant: "primary", icon: Truck },
  delivered: { label: "Đã giao", variant: "success", icon: CheckCircle },
  cancelled: { label: "Đã hủy", variant: "destructive", icon: XCircle },
}

const paymentConfig = {
  paid: { label: "Đã thanh toán", variant: "success" },
  pending: { label: "Chưa thanh toán", variant: "warning" },
  refunded: { label: "Đã hoàn tiền", variant: "secondary" },
}

export function OrdersPage() {
  const [searchTerm, setSearchTerm] = useState("")
  const [statusTab, setStatusTab] = useState("all")
  const [selectedOrder, setSelectedOrder] = useState(null)
  const [detailDialogOpen, setDetailDialogOpen] = useState(false)

  const filteredOrders = mockOrders.filter(order => {
    const matchesSearch = order.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
                          order.customer.toLowerCase().includes(searchTerm.toLowerCase()) ||
                          order.phone.includes(searchTerm)
    const matchesStatus = statusTab === "all" || order.status === statusTab
    return matchesSearch && matchesStatus
  })

  const openOrderDetail = (order) => {
    setSelectedOrder(order)
    setDetailDialogOpen(true)
  }

  const getStatusIcon = (status) => {
    const config = statusConfig[status]
    const Icon = config.icon
    return <Icon className="w-4 h-4" />
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Đơn hàng</h1>
          <p className="text-muted-foreground">Quản lý đơn hàng của khách hàng</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline">
            <Package className="w-4 h-4 mr-2" />
            Xuất Excel
          </Button>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-card rounded-lg border border-border p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-amber-500/20 flex items-center justify-center">
              <Clock className="w-5 h-5 text-amber-500" />
            </div>
            <div>
              <p className="text-2xl font-bold text-foreground">12</p>
              <p className="text-xs text-muted-foreground">Chờ xác nhận</p>
            </div>
          </div>
        </div>
        <div className="bg-card rounded-lg border border-border p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-blue-500/20 flex items-center justify-center">
              <Truck className="w-5 h-5 text-blue-500" />
            </div>
            <div>
              <p className="text-2xl font-bold text-foreground">28</p>
              <p className="text-xs text-muted-foreground">Đang giao</p>
            </div>
          </div>
        </div>
        <div className="bg-card rounded-lg border border-border p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-emerald-500/20 flex items-center justify-center">
              <CheckCircle className="w-5 h-5 text-emerald-500" />
            </div>
            <div>
              <p className="text-2xl font-bold text-foreground">156</p>
              <p className="text-xs text-muted-foreground">Hoàn thành</p>
            </div>
          </div>
        </div>
        <div className="bg-card rounded-lg border border-border p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-red-500/20 flex items-center justify-center">
              <XCircle className="w-5 h-5 text-red-500" />
            </div>
            <div>
              <p className="text-2xl font-bold text-foreground">8</p>
              <p className="text-xs text-muted-foreground">Đã hủy</p>
            </div>
          </div>
        </div>
      </div>

      {/* Tabs & Search */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <Tabs value={statusTab} onValueChange={setStatusTab}>
          <TabsList>
            <TabsTrigger value="all">Tất cả</TabsTrigger>
            <TabsTrigger value="pending">Chờ xác nhận</TabsTrigger>
            <TabsTrigger value="confirmed">Đã xác nhận</TabsTrigger>
            <TabsTrigger value="shipping">Đang giao</TabsTrigger>
            <TabsTrigger value="delivered">Hoàn thành</TabsTrigger>
          </TabsList>
        </Tabs>
        <div className="relative w-full sm:w-72">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm kiếm đơn hàng..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-9"
          />
        </div>
      </div>

      {/* Table */}
      <div className="bg-card rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Mã đơn</TableHead>
              <TableHead>Khách hàng</TableHead>
              <TableHead>Tổng tiền</TableHead>
              <TableHead>Thanh toán</TableHead>
              <TableHead>Trạng thái</TableHead>
              <TableHead>Ngày đặt</TableHead>
              <TableHead className="w-12"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredOrders.map((order) => (
              <TableRow key={order.id}>
                <TableCell>
                  <span className="font-mono font-medium text-primary">{order.id}</span>
                </TableCell>
                <TableCell>
                  <div className="flex flex-col">
                    <span className="font-medium text-foreground">{order.customer}</span>
                    <span className="text-xs text-muted-foreground">{order.phone}</span>
                  </div>
                </TableCell>
                <TableCell className="font-medium">
                  {formatCurrency(order.total)}
                </TableCell>
                <TableCell>
                  <Badge variant={paymentConfig[order.payment].variant}>
                    {paymentConfig[order.payment].label}
                  </Badge>
                </TableCell>
                <TableCell>
                  <Badge variant={statusConfig[order.status].variant}>
                    {getStatusIcon(order.status)}
                    <span className="ml-1">{statusConfig[order.status].label}</span>
                  </Badge>
                </TableCell>
                <TableCell className="text-muted-foreground">
                  {order.date}
                </TableCell>
                <TableCell>
                  <Button variant="ghost" size="icon" onClick={() => openOrderDetail(order)}>
                    <Eye className="w-4 h-4" />
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>

      {/* Order Detail Dialog */}
      <Dialog open={detailDialogOpen} onOpenChange={setDetailDialogOpen}>
        <DialogContent className="max-w-2xl">
          {selectedOrder && (
            <>
              <DialogHeader>
                <DialogTitle>Chi tiết đơn hàng {selectedOrder.id}</DialogTitle>
                <DialogDescription>
                  Ngày đặt: {selectedOrder.date}
                </DialogDescription>
              </DialogHeader>
              <div className="space-y-6 py-4">
                {/* Customer Info */}
                <div className="bg-secondary/50 rounded-lg p-4">
                  <h4 className="font-medium mb-3">Thông tin khách hàng</h4>
                  <div className="space-y-2 text-sm">
                    <p className="flex items-center gap-2">
                      <span className="text-muted-foreground">Khách hàng:</span>
                      <span className="font-medium">{selectedOrder.customer}</span>
                    </p>
                    <p className="flex items-center gap-2">
                      <Phone className="w-4 h-4 text-muted-foreground" />
                      <span>{selectedOrder.phone}</span>
                    </p>
                    <p className="flex items-start gap-2">
                      <MapPin className="w-4 h-4 text-muted-foreground mt-0.5" />
                      <span>{selectedOrder.address}</span>
                    </p>
                  </div>
                </div>

                {/* Product Info */}
                <div className="bg-secondary/50 rounded-lg p-4">
                  <h4 className="font-medium mb-3">Sản phẩm</h4>
                  <div className="flex items-center gap-4">
                    <div className="w-16 h-16 rounded-lg bg-muted flex items-center justify-center text-3xl">
                      📱
                    </div>
                    <div>
                      <p className="font-medium">{selectedOrder.product}</p>
                      <p className="text-sm text-muted-foreground">Số lượng: {selectedOrder.items}</p>
                    </div>
                    <div className="ml-auto text-right">
                      <p className="text-xl font-bold">{formatCurrency(selectedOrder.total)}</p>
                    </div>
                  </div>
                </div>

                {/* Status */}
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-muted-foreground">Trạng thái</p>
                    <Badge variant={statusConfig[selectedOrder.status].variant} className="mt-1">
                      {statusConfig[selectedOrder.status].label}
                    </Badge>
                  </div>
                  <div className="text-right">
                    <p className="text-sm text-muted-foreground">Thanh toán</p>
                    <Badge variant={paymentConfig[selectedOrder.payment].variant} className="mt-1">
                      {paymentConfig[selectedOrder.payment].label}
                    </Badge>
                  </div>
                </div>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setDetailDialogOpen(false)}>
                  Đóng
                </Button>
                {selectedOrder.status === "pending" && (
                  <>
                    <Button variant="destructive">Hủy đơn</Button>
                    <Button>Xác nhận đơn hàng</Button>
                  </>
                )}
                {selectedOrder.status === "confirmed" && (
                  <Button>Bắt đầu giao hàng</Button>
                )}
              </DialogFooter>
            </>
          )}
        </DialogContent>
      </Dialog>
    </div>
  )
}
