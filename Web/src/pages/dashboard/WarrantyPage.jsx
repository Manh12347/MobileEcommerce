import { useEffect, useMemo, useState } from "react"
import {
  Search,
  Plus,
  MoreVertical,
  Eye,
  ShieldCheck,
  Clock3,
  Wrench,
  PackageCheck,
  CalendarDays,
  MapPin,
  Phone,
  CheckCircle2,
  XCircle,
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

const mockWarranties = [
  {
    id: 1,
    code: "WR-24001",
    customer: "Nguyễn Văn A",
    phone: "0901 234 567",
    email: "nva@gmail.com",
    product: "iPhone 15 Pro Max",
    serial: "SN-IPH15PM-001",
    purchaseDate: "2026-03-10",
    warrantyEnd: "2027-03-10",
    issue: "Màn hình chập chờn, cảm ứng lúc được lúc không",
    status: "processing",
    priority: "high",
    technician: "Trần Minh Khoa",
    branch: "Trung tâm bảo hành Q.1",
    createdAt: "2026-05-20 10:25",
  },
  {
    id: 2,
    code: "WR-24002",
    customer: "Trần Thị B",
    phone: "0912 345 678",
    email: "ttb@gmail.com",
    product: "Samsung Galaxy S24 Ultra",
    serial: "SN-S24U-014",
    purchaseDate: "2026-02-18",
    warrantyEnd: "2027-02-18",
    issue: "Loa ngoài rè khi mở âm lượng lớn",
    status: "completed",
    priority: "medium",
    technician: "Lê Hoàng Nam",
    branch: "Chi nhánh Cần Thơ",
    createdAt: "2026-05-19 14:12",
  },
  {
    id: 3,
    code: "WR-24003",
    customer: "Lê Minh C",
    phone: "0933 456 789",
    email: "lmc@gmail.com",
    product: "Xiaomi Redmi Note 13 Pro",
    serial: "SN-XMN13P-002",
    purchaseDate: "2026-04-02",
    warrantyEnd: "2027-04-02",
    issue: "Máy nóng bất thường khi sạc",
    status: "pending",
    priority: "low",
    technician: "",
    branch: "Tiếp nhận online",
    createdAt: "2026-05-18 08:50",
  },
  {
    id: 4,
    code: "WR-24004",
    customer: "Phạm Thu D",
    phone: "0944 567 890",
    email: "ptd@gmail.com",
    product: "iPad Pro M4 11 inch",
    serial: "SN-IPDP11M4-008",
    purchaseDate: "2025-12-21",
    warrantyEnd: "2026-12-21",
    issue: "Máy không nhận Apple Pencil",
    status: "rejected",
    priority: "medium",
    technician: "Đặng Quang Huy",
    branch: "Trung tâm bảo hành Đà Nẵng",
    createdAt: "2026-05-17 16:45",
  },
  {
    id: 5,
    code: "WR-24005",
    customer: "Hoàng Anh E",
    phone: "0977 888 999",
    email: "hae@gmail.com",
    product: "AirPods Pro 2",
    serial: "SN-AIRP2-104",
    purchaseDate: "2026-01-12",
    warrantyEnd: "2027-01-12",
    issue: "Pin tai nghe tụt nhanh, pin hộp sạc yếu",
    status: "processing",
    priority: "high",
    technician: "Nguyễn Minh Tâm",
    branch: "Chi nhánh Nha Trang",
    createdAt: "2026-05-16 11:30",
  },
  {
    id: 6,
    code: "WR-24006",
    customer: "Vũ Quốc F",
    phone: "0988 111 222",
    email: "vqf@gmail.com",
    product: "OPPO Find X7 Pro",
    serial: "SN-OPFX7P-020",
    purchaseDate: "2026-03-28",
    warrantyEnd: "2027-03-28",
    issue: "Camera rung nhẹ khi quay video",
    status: "completed",
    priority: "medium",
    technician: "Lê Hoàng Nam",
    branch: "Trung tâm bảo hành Q.7",
    createdAt: "2026-05-15 09:05",
  },
]

const statusLabels = {
  pending: "Chờ tiếp nhận",
  processing: "Đang xử lý",
  completed: "Hoàn tất",
  rejected: "Từ chối",
}

const priorityLabels = {
  low: "Thấp",
  medium: "Trung bình",
  high: "Cao",
}

const formatDate = (value) => value.split("-").reverse().join("/")

export function WarrantyPage() {
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [priorityFilter, setPriorityFilter] = useState("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(5)
  const [warranties, setWarranties] = useState(mockWarranties)
  const [selectedWarranty, setSelectedWarranty] = useState(null)
  const [detailDialogOpen, setDetailDialogOpen] = useState(false)

  useEffect(() => {
    setCurrentPage(1)
  }, [searchTerm, statusFilter, priorityFilter, pageSize])

  const stats = useMemo(() => {
    const total = warranties.length
    const pending = warranties.filter((item) => item.status === "pending").length
    const processing = warranties.filter((item) => item.status === "processing").length
    const completed = warranties.filter((item) => item.status === "completed").length

    return { total, pending, processing, completed }
  }, [warranties])

  const filteredWarranties = warranties.filter((item) => {
    const search = searchTerm.toLowerCase()
    const matchesSearch =
      item.code.toLowerCase().includes(search) ||
      item.customer.toLowerCase().includes(search) ||
      item.product.toLowerCase().includes(search) ||
      item.serial.toLowerCase().includes(search)
    const matchesStatus = statusFilter === "all" || item.status === statusFilter
    const matchesPriority = priorityFilter === "all" || item.priority === priorityFilter
    return matchesSearch && matchesStatus && matchesPriority
  })

  const pagedWarranties = filteredWarranties.slice((currentPage - 1) * pageSize, currentPage * pageSize)

  const openDetail = (item) => {
    setSelectedWarranty(item)
    setDetailDialogOpen(true)
  }

  const getStatusVariant = (status) => {
    if (status === "completed") return "success"
    if (status === "processing") return "info"
    if (status === "rejected") return "destructive"
    return "warning"
  }

  const getPriorityVariant = (priority) => {
    if (priority === "high") return "destructive"
    if (priority === "medium") return "warning"
    return "secondary"
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Bảo hành</h1>
          <p className="text-muted-foreground">Quản lý phiếu bảo hành, trạng thái tiếp nhận và xử lý</p>
        </div>
        <Button className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
          <Plus className="mr-2 h-5 w-5" />
          Tạo phiếu bảo hành
        </Button>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Tổng phiếu</p>
              <p className="mt-2 text-2xl font-bold text-foreground">{stats.total}</p>
            </div>
            <div className="rounded-full bg-primary/10 p-3 text-primary">
              <ShieldCheck className="h-5 w-5" />
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Chờ tiếp nhận</p>
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
              <p className="text-sm text-muted-foreground">Đang xử lý</p>
              <p className="mt-2 text-2xl font-bold text-foreground">{stats.processing}</p>
            </div>
            <div className="rounded-full bg-blue-500/10 p-3 text-blue-400">
              <Wrench className="h-5 w-5" />
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Đã hoàn tất</p>
              <p className="mt-2 text-2xl font-bold text-foreground">{stats.completed}</p>
            </div>
            <div className="rounded-full bg-emerald-500/10 p-3 text-emerald-400">
              <PackageCheck className="h-5 w-5" />
            </div>
          </div>
        </div>
      </div>

      <div className="grid gap-3 lg:grid-cols-[1.4fr_0.8fr_0.8fr]">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Tìm theo mã phiếu, khách hàng, sản phẩm, serial..."
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
          <option value="pending">Chờ tiếp nhận</option>
          <option value="processing">Đang xử lý</option>
          <option value="completed">Hoàn tất</option>
          <option value="rejected">Từ chối</option>
        </select>
        <select
          value={priorityFilter}
          onChange={(e) => setPriorityFilter(e.target.value)}
          className="h-10 rounded-md border border-input bg-background px-3 text-sm text-foreground"
        >
          <option value="all">Tất cả mức ưu tiên</option>
          <option value="low">Thấp</option>
          <option value="medium">Trung bình</option>
          <option value="high">Cao</option>
        </select>
      </div>

      <div className="overflow-hidden rounded-lg border border-border bg-card">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="text-left">Phiếu</TableHead>
              <TableHead className="text-left">Khách hàng</TableHead>
              <TableHead className="text-left">Sản phẩm</TableHead>
              <TableHead className="text-left">Mức ưu tiên</TableHead>
              <TableHead className="text-left">Trạng thái</TableHead>
              <TableHead className="text-left">Ngày tạo</TableHead>
              <TableHead className="w-12 text-center"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {pagedWarranties.map((item) => (
              <TableRow key={item.id}>
                <TableCell className="text-left">
                  <div>
                    <p className="font-semibold text-foreground">{item.code}</p>
                    <p className="text-xs text-muted-foreground">HSD: {formatDate(item.warrantyEnd)}</p>
                  </div>
                </TableCell>
                <TableCell className="text-left">
                  <div>
                    <p className="font-medium text-foreground">{item.customer}</p>
                    <p className="text-xs text-muted-foreground">{item.phone}</p>
                  </div>
                </TableCell>
                <TableCell className="text-left">
                  <div>
                    <p className="font-medium text-foreground">{item.product}</p>
                    <p className="text-xs text-muted-foreground">{item.serial}</p>
                  </div>
                </TableCell>
                <TableCell className="text-left">
                  <Badge variant={getPriorityVariant(item.priority)}>{priorityLabels[item.priority]}</Badge>
                </TableCell>
                <TableCell className="text-left">
                  <Badge variant={getStatusVariant(item.status)}>{statusLabels[item.status]}</Badge>
                </TableCell>
                <TableCell className="text-left text-muted-foreground">{item.createdAt}</TableCell>
                <TableCell className="text-center">
                  <DropdownMenu>
                    <DropdownMenuTrigger>
                      <Button variant="ghost" size="icon" className="h-10 w-10 hover:bg-primary/10 hover:text-primary transition-colors">
                        <MoreVertical className="h-5 w-5" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" className="w-44">
                      <DropdownMenuItem
                        className="flex cursor-pointer items-center rounded-md px-4 py-3 text-base"
                        onSelect={() => openDetail(item)}
                      >
                        <Eye className="mr-3 h-5 w-5 text-blue-500" />
                        Xem chi tiết
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>

      <PaginationControls
        totalItems={filteredWarranties.length}
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
            <DialogTitle className="text-xl">Chi tiết phiếu {selectedWarranty?.code}</DialogTitle>
            <DialogDescription>
              Thông tin tiếp nhận, tình trạng sản phẩm và xử lý bảo hành.
            </DialogDescription>
          </DialogHeader>

          {selectedWarranty && (
            <div className="space-y-5 py-2">
              <div className="grid gap-4 md:grid-cols-2">
                <div className="rounded-lg border border-border bg-secondary/20 p-4">
                  <p className="mb-3 text-sm font-semibold text-foreground">Thông tin khách hàng</p>
                  <div className="space-y-2 text-sm text-muted-foreground">
                    <p>{selectedWarranty.customer}</p>
                    <p className="flex items-center gap-2"><Phone className="h-4 w-4" />{selectedWarranty.phone}</p>
                    <p>{selectedWarranty.email}</p>
                    <p className="flex items-start gap-2">
                      <MapPin className="mt-0.5 h-4 w-4 flex-shrink-0" />
                      <span>{selectedWarranty.branch}</span>
                    </p>
                  </div>
                </div>

                <div className="rounded-lg border border-border bg-secondary/20 p-4">
                  <p className="mb-3 text-sm font-semibold text-foreground">Trạng thái bảo hành</p>
                  <div className="space-y-3 text-sm">
                    <div className="flex items-center justify-between">
                      <span className="text-muted-foreground">Trạng thái</span>
                      <Badge variant={getStatusVariant(selectedWarranty.status)}>{statusLabels[selectedWarranty.status]}</Badge>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-muted-foreground">Ưu tiên</span>
                      <Badge variant={getPriorityVariant(selectedWarranty.priority)}>{priorityLabels[selectedWarranty.priority]}</Badge>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-muted-foreground">Kỹ thuật viên</span>
                      <span className="font-medium text-foreground">{selectedWarranty.technician || "Chưa phân công"}</span>
                    </div>
                  </div>
                </div>
              </div>

              <div className="rounded-lg border border-border bg-secondary/20 p-4">
                <p className="mb-3 text-sm font-semibold text-foreground">Thông tin sản phẩm</p>
                <div className="grid gap-3 text-sm md:grid-cols-2">
                  <div>
                    <p className="text-muted-foreground">Sản phẩm</p>
                    <p className="font-medium text-foreground">{selectedWarranty.product}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground">Serial</p>
                    <p className="font-medium text-foreground">{selectedWarranty.serial}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground">Ngày mua</p>
                    <p className="font-medium text-foreground">{formatDate(selectedWarranty.purchaseDate)}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground">Ngày hết hạn</p>
                    <p className="font-medium text-foreground">{formatDate(selectedWarranty.warrantyEnd)}</p>
                  </div>
                </div>
              </div>

              <div className="rounded-lg border border-border bg-secondary/20 p-4">
                <p className="mb-3 text-sm font-semibold text-foreground">Mô tả lỗi</p>
                <p className="text-sm leading-6 text-muted-foreground">{selectedWarranty.issue}</p>
              </div>
            </div>
          )}

          <DialogFooter className="gap-3 pt-2">
            <Button variant="outline" onClick={() => setDetailDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Đóng
            </Button>
            <Button className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              <CheckCircle2 className="mr-2 h-4 w-4" />
              Cập nhật xử lý
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}