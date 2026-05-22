import { useState } from "react"
import { Search, Plus, Tag, Calendar, MoreVertical, Trash2, Edit } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "../../components/ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"

const mockDiscounts = [
  { id: 1, code: "SUMMER2026", name: "Khuyến mãi mùa hè", type: "percent", value: 30, minOrder: 500000, maxDiscount: 200000, startDate: "2026-05-01", endDate: "2026-05-31", status: "active", usage: 1250 },
  { id: 2, code: "NEWUSER", name: "Giảm cho người dùng mới", type: "percent", value: 15, minOrder: 0, maxDiscount: 100000, startDate: "2026-01-01", endDate: "2026-12-31", status: "active", usage: 3420 },
  { id: 3, code: "FLASH50K", name: "Flash sale 50K", type: "fixed", value: 50000, minOrder: 200000, maxDiscount: 50000, startDate: "2026-05-15", endDate: "2026-05-25", status: "expired", usage: 890 },
  { id: 4, code: "VIP20", name: "Khách hàng VIP", type: "percent", value: 20, minOrder: 1000000, maxDiscount: 500000, startDate: "2026-01-01", endDate: "2026-12-31", status: "active", usage: 567 },
]

export function DiscountsPage() {
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [discounts, setDiscounts] = useState(mockDiscounts)
  const [addDialogOpen, setAddDialogOpen] = useState(false)
  const [editDialogOpen, setEditDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [selectedDiscount, setSelectedDiscount] = useState(null)
  const [editForm, setEditForm] = useState({
    code: "",
    name: "",
    type: "percent",
    value: 0,
    minOrder: 0,
    startDate: "",
    endDate: ""
  })

  const filteredDiscounts = discounts
    .filter(discount => {
      const matchesSearch = discount.code.toLowerCase().includes(searchTerm.toLowerCase()) ||
                            discount.name.toLowerCase().includes(searchTerm.toLowerCase())
      const matchesStatus = statusFilter === "all" || discount.status === statusFilter
      return matchesSearch && matchesStatus
    })
    .sort((a, b) => {
      if (a.status === "active" && b.status !== "active") return -1
      if (a.status !== "active" && b.status === "active") return 1
      return 0
    })

  const formatCurrency = (value) => {
    return new Intl.NumberFormat('vi-VN').format(value) + 'đ'
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Mã giảm giá</h1>
          <p className="text-muted-foreground">Quản lý các chương trình khuyến mãi</p>
        </div>
        <Button onClick={() => setAddDialogOpen(true)} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
          <Plus className="w-5 h-5 mr-2" />
          Tạo mã giảm giá
        </Button>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm kiếm mã giảm giá..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-9"
          />
        </div>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="h-10 px-3 rounded-md border border-input bg-background text-sm"
        >
          <option value="all">Tất cả trạng thái</option>
          <option value="active">Đang hoạt động</option>
          <option value="expired">Đã hết hạn</option>
          <option value="scheduled">Sắp diễn ra</option>
        </select>
      </div>

      {/* Table */}
      <div className="bg-card rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="text-left">Mã giảm giá</TableHead>
              <TableHead className="text-center">Loại</TableHead>
              <TableHead className="text-left">Giảm</TableHead>
              <TableHead className="text-left">Đơn hàng tối thiểu</TableHead>
              <TableHead className="text-left">Thời gian</TableHead>
              <TableHead className="text-center">Trạng thái</TableHead>
              <TableHead className="text-left">Đã sử dụng</TableHead>
              <TableHead className="w-12 text-center"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredDiscounts.map((discount) => (
              <TableRow key={discount.id}>
                <TableCell className="text-left">
                  <div className="flex items-center gap-2">
                    <Tag className="w-4 h-4 text-primary" />
                    <span className="font-mono font-medium text-primary">{discount.code}</span>
                  </div>
                  <span className="text-xs text-muted-foreground">{discount.name}</span>
                </TableCell>
                <TableCell className="text-center">
                  <Badge variant={discount.type === "percent" ? "info" : "warning"}>
                    {discount.type === "percent" ? "Phần trăm" : "Cố định"}
                  </Badge>
                </TableCell>
                <TableCell className="text-left font-medium">
                  {discount.type === "percent" ? `${discount.value}%` : formatCurrency(discount.value)}
                  {discount.maxDiscount && (
                    <span className="text-xs text-muted-foreground block">
                      Tối đa {formatCurrency(discount.maxDiscount)}
                    </span>
                  )}
                </TableCell>
                <TableCell className="text-left text-muted-foreground">
                  {discount.minOrder > 0 ? formatCurrency(discount.minOrder) : "Không có"}
                </TableCell>
                <TableCell className="text-left">
                  <div className="flex items-center gap-1 text-xs text-muted-foreground">
                    <Calendar className="w-3 h-3" />
                    {discount.startDate} - {discount.endDate}
                  </div>
                </TableCell>
                <TableCell className="text-center">
                  <Badge
                    variant={discount.status === "active" ? "success" : "destructive"}
                  >
                    {discount.status === "active" ? "Hoạt động" : "Hết hạn"}
                  </Badge>
                </TableCell>
                <TableCell className="text-left text-muted-foreground">
                  {new Intl.NumberFormat('vi-VN').format(discount.usage)} lượt
                </TableCell>
                <TableCell className="text-center">
                  <DropdownMenu>
                    <DropdownMenuTrigger>
                      <Button variant="ghost" size="icon" className="h-10 w-10 hover:bg-primary/10 hover:text-primary transition-colors">
                        <MoreVertical className="w-5 h-5" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" className="w-44">
                      <DropdownMenuItem
                        className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer"
                        onSelect={() => {
                          setSelectedDiscount(discount)
                          setEditForm({
                            code: discount.code,
                            name: discount.name,
                            type: discount.type,
                            value: discount.value,
                            minOrder: discount.minOrder,
                            startDate: discount.startDate,
                            endDate: discount.endDate
                          })
                          setEditDialogOpen(true)
                        }}
                      >
                        <Edit className="w-5 h-5 mr-3 text-blue-500" />
                        Chỉnh sửa
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer text-red-500 hover:bg-red-50"
                        onSelect={() => {
                          setSelectedDiscount(discount)
                          setDeleteDialogOpen(true)
                        }}
                      >
                        <Trash2 className="w-5 h-5 mr-3" />
                        Xóa
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>

      {/* Edit Discount Dialog */}
      <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Chỉnh sửa mã giảm giá</DialogTitle>
            <DialogDescription>
              Cập nhật thông tin mã giảm giá: <span className="font-medium text-foreground">{selectedDiscount?.code}</span>
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Mã giảm giá</label>
                <Input
                  placeholder="VD: SUMMER2026"
                  className="font-mono h-11"
                  value={editForm.code}
                  onChange={(e) => setEditForm({ ...editForm, code: e.target.value })}
                />
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Tên chương trình</label>
                <Input
                  placeholder="Nhập tên chương trình"
                  className="h-11"
                  value={editForm.name}
                  onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Loại</label>
                <select
                  className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                  value={editForm.type}
                  onChange={(e) => setEditForm({ ...editForm, type: e.target.value })}
                >
                  <option value="percent">Phần trăm</option>
                  <option value="fixed">Cố định</option>
                </select>
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Giá trị</label>
                <Input
                  type="number"
                  placeholder="0"
                  className="h-11"
                  value={editForm.value}
                  onChange={(e) => setEditForm({ ...editForm, value: parseInt(e.target.value) })}
                />
              </div>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Đơn hàng tối thiểu</label>
              <Input
                type="number"
                placeholder="0"
                className="h-11"
                value={editForm.minOrder}
                onChange={(e) => setEditForm({ ...editForm, minOrder: parseInt(e.target.value) })}
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Ngày bắt đầu</label>
                <Input
                  type="date"
                  className="h-11"
                  value={editForm.startDate}
                  onChange={(e) => setEditForm({ ...editForm, startDate: e.target.value })}
                />
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Ngày kết thúc</label>
                <Input
                  type="date"
                  className="h-11"
                  value={editForm.endDate}
                  onChange={(e) => setEditForm({ ...editForm, endDate: e.target.value })}
                />
              </div>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setEditDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button
              onClick={() => {
                setDiscounts(discounts.map(d => d.id === selectedDiscount?.id ? { ...d, ...editForm } : d))
                setEditDialogOpen(false)
              }}
              className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20"
            >
              Lưu thay đổi
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Xác nhận xóa mã giảm giá</DialogTitle>
            <DialogDescription>
              Bạn có chắc chắn muốn xóa mã giảm giá <span className="font-medium text-foreground">{selectedDiscount?.code}</span>? Hành động này không thể hoàn tác.
            </DialogDescription>
          </DialogHeader>
          <div className="py-4">
            <div className="flex items-center gap-3 p-4 bg-red-50 rounded-lg border border-red-200">
              <div className="w-12 h-12 rounded-lg bg-red-100 flex items-center justify-center">
                <Tag className="w-6 h-6 text-red-500" />
              </div>
              <div>
                <p className="font-mono font-medium text-foreground">{selectedDiscount?.code}</p>
                <p className="text-sm text-muted-foreground">{selectedDiscount?.name}</p>
              </div>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button
              variant="destructive"
              onClick={() => {
                setDiscounts(discounts.filter(d => d.id !== selectedDiscount?.id))
                setDeleteDialogOpen(false)
              }}
              className="h-11 px-6 text-base font-medium"
            >
              Xóa mã giảm giá
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
