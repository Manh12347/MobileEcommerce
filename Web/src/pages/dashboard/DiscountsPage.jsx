import { useEffect, useState, useRef } from "react"
import { Search, Plus, Tag, Calendar, MoreVertical, Trash2, Edit, Percent, DollarSign, X, ChevronDown, SlidersHorizontal } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "../../components/ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"
import { PaginationControls } from "../../components/dashboard/PaginationControls"
import { ColumnVisibilitySelect } from "../../components/dashboard/ColumnVisibilitySelect"
import { promotionsAPI, catalogAPI } from "../../api/client"
import { useToast } from "../../hooks/use-toast"

const formatCurrency = (value) => {
  if (!value && value !== 0) return "--"
  return new Intl.NumberFormat("vi-VN").format(value) + "đ"
}

const getPromotionStatus = (promotion) => {
  if (!promotion.isActive) return "inactive"
  const now = new Date()
  const start = promotion.startDate ? new Date(promotion.startDate) : null
  const end = promotion.endDate ? new Date(promotion.endDate) : null
  if (start && now < start) return "scheduled"
  if (end && now > end) return "expired"
  return "active"
}

const getStatusLabel = (status) => {
  const labels = { active: "Hoạt động", expired: "Hết hạn", scheduled: "Sắp diễn ra", inactive: "Không hoạt động" }
  return labels[status] || status
}

const getStatusVariant = (status) => {
  const variants = { active: "success", expired: "destructive", scheduled: "warning", inactive: "secondary" }
  return variants[status] || "secondary"
}

const columnOptions = [
  { value: "promotionName", label: "Tên khuyến mãi" },
  { value: "discountType", label: "Loại giảm" },
  { value: "discountValue", label: "Mức giảm" },
  { value: "startDate", label: "Ngày bắt đầu" },
  { value: "endDate", label: "Ngày kết thúc" },
  { value: "status", label: "Trạng thái" },
]

const emptyForm = {
  promotionName: "",
  discountPercent: "",
  discountCost: "",
  startDate: "",
  endDate: "",
}

export function DiscountsPage() {
  const { toast } = useToast()
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [promotions, setPromotions] = useState([])
  const [loading, setLoading] = useState(false)

  const [addDialogOpen, setAddDialogOpen] = useState(false)
  const [editDialogOpen, setEditDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [applyDialogOpen, setApplyDialogOpen] = useState(false)
  const [removeDialogOpen, setRemoveDialogOpen] = useState(false)
  const [selectedPromotion, setSelectedPromotion] = useState(null)
  const [saving, setSaving] = useState(false)
  const [products, setProducts] = useState([])
  const [addForm, setAddForm] = useState(emptyForm)
  const [editForm, setEditForm] = useState(emptyForm)
  const [applyForm, setApplyForm] = useState({ productId: "" })
  const [removeForm, setRemoveForm] = useState({ productId: "" })

  // Column visibility
  const [visibleColumns, setVisibleColumns] = useState(["promotionName", "discountType", "discountValue", "startDate", "endDate", "status"])

  // Products dropdown per promotion
  const [promotionProducts, setPromotionProducts] = useState({}) // { [promotionId]: [...] }
  const [loadingProducts, setLoadingProducts] = useState(null) // promotionId đang load
  const openDropdownRef = useRef(null) // promotionId đang mở dropdown

  const loadPromotions = async () => {
    try {
      setLoading(true)
      const res = await promotionsAPI.getAll()
      setPromotions(res.data?.data || [])
    } catch (error) {
      console.error("Load promotions error", error)
      toast({ title: "Lỗi", description: "Không tải được danh sách khuyến mãi", variant: "destructive" })
    } finally {
      setLoading(false)
    }
  }

  const loadProducts = async () => {
    try {
      const res = await catalogAPI.getAllProducts()
      setProducts(res.data?.data || [])
    } catch (error) {
      console.error("Load products error", error)
    }
  }

  useEffect(() => {
    loadPromotions()
  }, [])

  useEffect(() => {
    setCurrentPage(1)
  }, [searchTerm, statusFilter, pageSize])

  const filteredPromotions = promotions
    .filter((p) => {
      const kw = searchTerm.trim().toLowerCase()
      const matchesSearch =
        !kw || (p.promotionName || "").toLowerCase().includes(kw)
      const status = getPromotionStatus(p)
      const matchesStatus = statusFilter === "all" || status === statusFilter
      return matchesSearch && matchesStatus
    })
    .sort((a, b) => {
      if (a.isActive && !b.isActive) return -1
      if (!a.isActive && b.isActive) return 1
      return 0
    })

  const pagedPromotions = filteredPromotions.slice((currentPage - 1) * pageSize, currentPage * pageSize)

  const loadPromotionProducts = async (promotionId) => {
    if (promotionProducts[promotionId]) return
    try {
      setLoadingProducts(promotionId)
      const res = await promotionsAPI.getProductsByPromotion(promotionId)
      setPromotionProducts(prev => ({ ...prev, [promotionId]: res.data?.data || [] }))
    } catch (error) {
      console.error("Load promotion products error", error)
    } finally {
      setLoadingProducts(null)
    }
  }

  const toggleProductsDropdown = (promotionId) => {
    if (openDropdownRef.current === promotionId) {
      openDropdownRef.current = null
      setOpenDropdown(null)
    } else {
      openDropdownRef.current = promotionId
      setOpenDropdown(promotionId)
      loadPromotionProducts(promotionId)
    }
  }

  const [openDropdown, setOpenDropdown] = useState(null)

  // Create
  const handleCreate = async () => {
    if (!addForm.promotionName.trim()) {
      toast({ title: "Lỗi", description: "Tên khuyến mãi không được để trống", variant: "destructive" })
      return
    }
    if (!addForm.discountPercent && !addForm.discountCost) {
      toast({ title: "Lỗi", description: "Cần nhập ít nhất một loại giảm giá", variant: "destructive" })
      return
    }
    try {
      setSaving(true)
      await promotionsAPI.create({
        promotionName: addForm.promotionName.trim(),
        discountPercent: addForm.discountPercent ? parseFloat(addForm.discountPercent) : null,
        discountCost: addForm.discountCost ? parseFloat(addForm.discountCost) : null,
        startDate: addForm.startDate || null,
        endDate: addForm.endDate || null,
      })
      setAddDialogOpen(false)
      setAddForm(emptyForm)
      await loadPromotions()
      toast({ title: "Thành công", description: "Đã tạo khuyến mãi" })
    } catch (error) {
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Tạo thất bại", variant: "destructive" })
    } finally {
      setSaving(false)
    }
  }

  // Update
  const handleUpdate = async () => {
    if (!selectedPromotion) return
    if (!editForm.promotionName.trim()) {
      toast({ title: "Lỗi", description: "Tên khuyến mãi không được để trống", variant: "destructive" })
      return
    }
    try {
      setSaving(true)
      await promotionsAPI.update(selectedPromotion.promotionId, {
        promotionName: editForm.promotionName.trim(),
        discountPercent: editForm.discountPercent ? parseFloat(editForm.discountPercent) : null,
        discountCost: editForm.discountCost ? parseFloat(editForm.discountCost) : null,
        startDate: editForm.startDate || null,
        endDate: editForm.endDate || null,
        isActive: selectedPromotion.isActive,
      })
      setEditDialogOpen(false)
      setSelectedPromotion(null)
      await loadPromotions()
      toast({ title: "Thành công", description: "Đã cập nhật khuyến mãi" })
    } catch (error) {
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Cập nhật thất bại", variant: "destructive" })
    } finally {
      setSaving(false)
    }
  }

  // Toggle active/inactive
  const handleToggleActive = async (promotion) => {
    try {
      const newActive = !promotion.isActive
      await promotionsAPI.update(promotion.promotionId, {
        promotionName: promotion.promotionName,
        isActive: newActive,
      })
      await loadPromotions()
      toast({ title: "Thành công", description: newActive ? "Đã kích hoạt khuyến mãi" : "Đã tắt khuyến mãi" })
    } catch (error) {
      toast({ title: "Lỗi", description: "Cập nhật trạng thái thất bại", variant: "destructive" })
    }
  }

  // Delete
  const handleDelete = async () => {
    if (!selectedPromotion) return
    try {
      await promotionsAPI.delete(selectedPromotion.promotionId)
      setDeleteDialogOpen(false)
      setSelectedPromotion(null)
      await loadPromotions()
      toast({ title: "Thành công", description: "Đã xóa khuyến mãi" })
    } catch (error) {
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Xóa thất bại", variant: "destructive" })
    }
  }

  // Apply promotion to product
  const handleApply = async () => {
    if (!applyForm.productId) {
      toast({ title: "Lỗi", description: "Vui lòng chọn sản phẩm", variant: "destructive" })
      return
    }
    try {
      await promotionsAPI.apply({
        productId: parseInt(applyForm.productId),
        promotionId: selectedPromotion.promotionId,
      })
      setApplyDialogOpen(false)
      setApplyForm({ productId: "" })
      setSelectedPromotion(null)
      // Refresh products dropdown if open
      if (openDropdownRef.current === selectedPromotion?.promotionId) {
        setPromotionProducts(prev => ({ ...prev, [selectedPromotion.promotionId]: undefined }))
      }
      toast({ title: "Thành công", description: "Đã áp dụng khuyến mãi cho sản phẩm" })
    } catch (error) {
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Áp dụng thất bại", variant: "destructive" })
    }
  }

  // Remove promotion from product
  const handleRemove = async () => {
    if (!removeForm.productId) {
      toast({ title: "Lỗi", description: "Vui lòng chọn sản phẩm", variant: "destructive" })
      return
    }
    try {
      await promotionsAPI.remove({
        productId: parseInt(removeForm.productId),
        promotionId: selectedPromotion.promotionId,
      })
      setRemoveDialogOpen(false)
      setRemoveForm({ productId: "" })
      setSelectedPromotion(null)
      // Refresh products dropdown
      if (openDropdownRef.current === selectedPromotion?.promotionId) {
        setPromotionProducts(prev => ({ ...prev, [selectedPromotion.promotionId]: undefined }))
        loadPromotionProducts(selectedPromotion.promotionId)
      }
      toast({ title: "Thành công", description: "Đã gỡ khuyến mãi khỏi sản phẩm" })
    } catch (error) {
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Gỡ thất bại", variant: "destructive" })
    }
  }

  const openEdit = (promotion) => {
    setSelectedPromotion(promotion)
    const fmtDate = (d) => {
      if (!d) return ""
      const date = new Date(d)
      return date.toISOString().slice(0, 16)
    }
    setEditForm({
      promotionName: promotion.promotionName || "",
      discountPercent: promotion.discountPercent != null ? String(promotion.discountPercent) : "",
      discountCost: promotion.discountCost != null ? String(promotion.discountCost) : "",
      startDate: fmtDate(promotion.startDate),
      endDate: fmtDate(promotion.endDate),
    })
    setEditDialogOpen(true)
  }

  const openApply = (promotion) => {
    setSelectedPromotion(promotion)
    setApplyForm({ productId: "" })
    loadProducts()
    setApplyDialogOpen(true)
  }

  const openRemove = (promotion) => {
    setSelectedPromotion(promotion)
    setRemoveForm({ productId: "" })
    setApplyForm({ productId: "" })
    loadPromotionProducts(promotion.promotionId)
    setRemoveDialogOpen(true)
  }

  const fmtDateDisplay = (d) => {
    if (!d) return "--"
    return new Date(d).toLocaleDateString("vi-VN", { day: "2-digit", month: "2-digit", year: "numeric" })
  }

  const fmtDateTimeDisplay = (d) => {
    if (!d) return "--"
    return new Date(d).toLocaleString("vi-VN", {
      day: "2-digit", month: "2-digit", year: "numeric",
      hour: "2-digit", minute: "2-digit",
    })
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Khuyến mãi</h1>
          <p className="text-muted-foreground">Quản lý chương trình khuyến mãi & giảm giá</p>
        </div>
        <Button
          onClick={() => { setAddForm(emptyForm); setAddDialogOpen(true); }}
          className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20"
        >
          <Plus className="w-5 h-5 mr-2" />
          Tạo khuyến mãi
        </Button>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-4 items-center">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm kiếm khuyến mãi..."
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
          <option value="inactive">Không hoạt động</option>
        </select>
        <ColumnVisibilitySelect
          options={columnOptions}
          value={visibleColumns}
          onChange={setVisibleColumns}
        />
      </div>

      {/* Table */}
      <div className="bg-card rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              {visibleColumns.includes("promotionName") && (
                <TableHead className="text-left">Tên khuyến mãi</TableHead>
              )}
              {visibleColumns.includes("discountType") && (
                <TableHead className="text-center">Loại giảm</TableHead>
              )}
              {visibleColumns.includes("discountValue") && (
                <TableHead className="text-left">Mức giảm</TableHead>
              )}
              {visibleColumns.includes("startDate") && (
                <TableHead className="text-left">Ngày bắt đầu</TableHead>
              )}
              {visibleColumns.includes("endDate") && (
                <TableHead className="text-left">Ngày kết thúc</TableHead>
              )}
              {visibleColumns.includes("status") && (
                <TableHead className="text-center">Trạng thái</TableHead>
              )}
              <TableHead className="w-12 text-center"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={7} className="text-center text-muted-foreground py-12">
                  Đang tải...
                </TableCell>
              </TableRow>
            ) : pagedPromotions.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="text-center text-muted-foreground py-12">
                  Chưa có khuyến mãi nào
                </TableCell>
              </TableRow>
            ) : (
              pagedPromotions.map((promotion) => {
                const status = getPromotionStatus(promotion)
                const hasDiscount = promotion.discountPercent != null || promotion.discountCost != null
                const productsList = promotionProducts[promotion.promotionId] || []
                const isDropdownOpen = openDropdown === promotion.promotionId
                return (
                  <TableRow key={promotion.promotionId}>
                    {visibleColumns.includes("promotionName") && (
                      <TableCell className="text-left">
                        <div className="flex items-center gap-2">
                          <Tag className="w-4 h-4 text-primary flex-shrink-0" />
                          <span className="font-medium text-foreground">{promotion.promotionName}</span>
                        </div>
                      </TableCell>
                    )}
                    {visibleColumns.includes("discountType") && (
                      <TableCell className="text-center">
                        {promotion.discountPercent != null ? (
                          <Badge variant="info"><Percent className="w-3 h-3 mr-1" />Phần trăm</Badge>
                        ) : promotion.discountCost != null ? (
                          <Badge variant="warning"><DollarSign className="w-3 h-3 mr-1" />Cố định</Badge>
                        ) : (
                          <span className="text-muted-foreground text-sm">--</span>
                        )}
                      </TableCell>
                    )}
                    {visibleColumns.includes("discountValue") && (
                      <TableCell className="text-left">
                        <div className="relative">
                          <button
                            className={`font-medium text-foreground hover:text-primary transition-colors ${
                              hasDiscount ? "cursor-pointer" : "cursor-default"
                            }`}
                            onClick={() => hasDiscount && toggleProductsDropdown(promotion.promotionId)}
                            disabled={!hasDiscount}
                          >
                            {promotion.discountPercent != null ? `${promotion.discountPercent}%` : ""}
                            {promotion.discountCost != null ? formatCurrency(promotion.discountCost) : ""}
                            {hasDiscount && (
                              <ChevronDown className={`w-3 h-3 ml-1 inline transition-transform ${isDropdownOpen ? "rotate-180" : ""}`} />
                            )}
                          </button>

                          {/* Dropdown sản phẩm */}
                          {isDropdownOpen && (
                            <div className="absolute left-0 top-full mt-1 z-50 bg-card border border-border rounded-lg shadow-xl w-72 max-h-64 overflow-y-auto">
                              <div className="px-3 py-2 border-b border-border">
                                <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide">
                                  Sản phẩm đang áp dụng
                                </p>
                              </div>
                              {loadingProducts === promotion.promotionId ? (
                                <div className="px-3 py-4 text-sm text-muted-foreground text-center">
                                  Đang tải...
                                </div>
                              ) : productsList.length === 0 ? (
                                <div className="px-3 py-4 text-sm text-muted-foreground text-center">
                                  Chưa có sản phẩm nào
                                </div>
                              ) : (
                                productsList.map((p) => (
                                  <div key={p.productId} className="px-3 py-2.5 hover:bg-accent transition-colors flex items-center justify-between group">
                                    <span className="text-sm text-foreground">{p.productName}</span>
                                    <button
                                      onClick={(e) => {
                                        e.stopPropagation()
                                        setSelectedPromotion(promotion)
                                        setRemoveForm({ productId: String(p.productId) })
                                        setRemoveDialogOpen(true)
                                      }}
                                      className="opacity-0 group-hover:opacity-100 transition-opacity ml-2 text-red-400 hover:text-red-600"
                                      title="Gỡ khỏi sản phẩm"
                                    >
                                      <X className="w-3.5 h-3.5" />
                                    </button>
                                  </div>
                                ))
                              )}
                            </div>
                          )}
                        </div>
                      </TableCell>
                    )}
                    {visibleColumns.includes("startDate") && (
                      <TableCell className="text-left">
                        <div className="flex items-center gap-1 text-xs text-muted-foreground">
                          <Calendar className="w-3 h-3 flex-shrink-0" />
                          {fmtDateTimeDisplay(promotion.startDate)}
                        </div>
                      </TableCell>
                    )}
                    {visibleColumns.includes("endDate") && (
                      <TableCell className="text-left">
                        <div className="flex items-center gap-1 text-xs text-muted-foreground">
                          <Calendar className="w-3 h-3 flex-shrink-0" />
                          {fmtDateTimeDisplay(promotion.endDate)}
                        </div>
                      </TableCell>
                    )}
                    {visibleColumns.includes("status") && (
                      <TableCell className="text-center">
                        <Badge variant={getStatusVariant(status)}>{getStatusLabel(status)}</Badge>
                      </TableCell>
                    )}
                    <TableCell className="text-center">
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon" className="h-10 w-10 hover:bg-primary/10 hover:text-primary transition-colors">
                            <MoreVertical className="w-5 h-5" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end" className="w-48">
                          <DropdownMenuItem
                            className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer"
                            onSelect={() => openEdit(promotion)}
                          >
                            <Edit className="w-5 h-5 mr-3 text-blue-500" />
                            Chỉnh sửa
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer"
                            onSelect={() => openApply(promotion)}
                          >
                            <Percent className="w-5 h-5 mr-3 text-emerald-500" />
                            Áp dụng cho sản phẩm
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            className={`flex items-center py-3 px-4 text-base rounded-md cursor-pointer ${promotion.isActive ? "text-amber-500 hover:bg-amber-50" : "text-green-500 hover:bg-green-50"}`}
                            onSelect={() => handleToggleActive(promotion)}
                          >
                            {promotion.isActive ? <X className="w-5 h-5 mr-3" /> : <Percent className="w-5 h-5 mr-3" />}
                            {promotion.isActive ? "Tắt khuyến mãi" : "Kích hoạt"}
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer text-red-500 hover:bg-red-50"
                            onSelect={() => { setSelectedPromotion(promotion); setDeleteDialogOpen(true); }}
                          >
                            <Trash2 className="w-5 h-5 mr-3" />
                            Xóa
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

      <PaginationControls
        totalItems={filteredPromotions.length}
        pageSize={pageSize}
        currentPage={currentPage}
        onPageChange={setCurrentPage}
        onPageSizeChange={(size) => { setPageSize(size); setCurrentPage(1); }}
      />

      {/* Backdrop to close dropdown when clicking outside */}
      {openDropdown && (
        <div
          className="fixed inset-0 z-40"
          onClick={() => { setOpenDropdown(null); openDropdownRef.current = null; }}
        />
      )}

      {/* Create Dialog */}
      <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Tạo khuyến mãi mới</DialogTitle>
            <DialogDescription>Nhập thông tin khuyến mãi</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Tên khuyến mãi</label>
              <Input
                placeholder="VD: Khuyến mãi mùa hè 2026"
                className="h-11"
                value={addForm.promotionName}
                onChange={(e) => setAddForm({ ...addForm, promotionName: e.target.value })}
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Giảm theo %</label>
                <Input
                  type="number"
                  min="0"
                  max="100"
                  placeholder="VD: 10"
                  className="h-11"
                  value={addForm.discountPercent}
                  onChange={(e) => setAddForm({ ...addForm, discountPercent: e.target.value })}
                />
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Giảm số tiền cố định</label>
                <Input
                  type="number"
                  min="0"
                  placeholder="VD: 50000"
                  className="h-11"
                  value={addForm.discountCost}
                  onChange={(e) => setAddForm({ ...addForm, discountCost: e.target.value })}
                />
              </div>
            </div>
            <p className="text-xs text-muted-foreground -mt-2">Nhập ít nhất một trong hai. Nếu cả hai đều nhập, ưu tiên số tiền cố định.</p>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Ngày bắt đầu</label>
                <Input
                  type="datetime-local"
                  className="h-11"
                  value={addForm.startDate}
                  onChange={(e) => setAddForm({ ...addForm, startDate: e.target.value })}
                />
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Ngày kết thúc</label>
                <Input
                  type="datetime-local"
                  className="h-11"
                  value={addForm.endDate}
                  onChange={(e) => setAddForm({ ...addForm, endDate: e.target.value })}
                />
              </div>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setAddDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button onClick={handleCreate} disabled={saving} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              {saving ? "Đang lưu..." : "Tạo khuyến mãi"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Dialog */}
      <Dialog open={editDialogOpen} onOpenChange={(open) => { setEditDialogOpen(open); if (!open) setSelectedPromotion(null); }}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Chỉnh sửa khuyến mãi</DialogTitle>
            <DialogDescription>
              Cập nhật thông tin khuyến mãi: <span className="font-medium text-foreground">{selectedPromotion?.promotionName}</span>
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Tên khuyến mãi</label>
              <Input
                placeholder="VD: Khuyến mãi mùa hè 2026"
                className="h-11"
                value={editForm.promotionName}
                onChange={(e) => setEditForm({ ...editForm, promotionName: e.target.value })}
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Giảm theo %</label>
                <Input
                  type="number"
                  min="0"
                  max="100"
                  placeholder="VD: 10"
                  className="h-11"
                  value={editForm.discountPercent}
                  onChange={(e) => setEditForm({ ...editForm, discountPercent: e.target.value })}
                />
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Giảm số tiền cố định</label>
                <Input
                  type="number"
                  min="0"
                  placeholder="VD: 50000"
                  className="h-11"
                  value={editForm.discountCost}
                  onChange={(e) => setEditForm({ ...editForm, discountCost: e.target.value })}
                />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Ngày bắt đầu</label>
                <Input
                  type="datetime-local"
                  className="h-11"
                  value={editForm.startDate}
                  onChange={(e) => setEditForm({ ...editForm, startDate: e.target.value })}
                />
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Ngày kết thúc</label>
                <Input
                  type="datetime-local"
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
            <Button onClick={handleUpdate} disabled={saving} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              {saving ? "Đang lưu..." : "Lưu thay đổi"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Apply Dialog */}
      <Dialog open={applyDialogOpen} onOpenChange={(open) => { setApplyDialogOpen(open); if (!open) { setSelectedPromotion(null); setApplyForm({ productId: "" }); } }}>
        <DialogContent className="max-w-md">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Áp dụng khuyến mãi</DialogTitle>
            <DialogDescription>
              Áp dụng khuyến mãi <span className="font-medium text-foreground">{selectedPromotion?.promotionName}</span> cho sản phẩm. Sale price sẽ được tự động tính và cập nhật.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Chọn sản phẩm</label>
              <select
                className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                value={applyForm.productId}
                onChange={(e) => setApplyForm({ ...applyForm, productId: e.target.value })}
              >
                <option value="">-- Chọn sản phẩm --</option>
                {products.map((p) => (
                  <option key={p.productId} value={p.productId}>
                    {p.name}
                  </option>
                ))}
              </select>
            </div>
            {selectedPromotion && (
              <div className="p-4 bg-primary/5 rounded-lg border border-primary/20">
                <p className="text-sm font-medium text-foreground mb-2">Thông tin khuyến mãi:</p>
                <p className="text-sm text-muted-foreground">
                  {selectedPromotion.discountCost != null
                    ? `Giảm ${formatCurrency(selectedPromotion.discountCost)}`
                    : selectedPromotion.discountPercent != null
                    ? `Giảm ${selectedPromotion.discountPercent}%`
                    : "--"}
                </p>
              </div>
            )}
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setApplyDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button onClick={handleApply} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              Áp dụng
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Remove Promotion from Product Dialog */}
      <Dialog open={removeDialogOpen} onOpenChange={(open) => { setRemoveDialogOpen(open); if (!open) { setSelectedPromotion(null); setRemoveForm({ productId: "" }); } }}>
        <DialogContent className="max-w-md">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Gỡ khuyến mãi khỏi sản phẩm</DialogTitle>
            <DialogDescription>
              Gỡ khuyến mãi <span className="font-medium text-foreground">{selectedPromotion?.promotionName}</span> khỏi sản phẩm. Sale price sẽ bị xóa.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Chọn sản phẩm cần gỡ</label>
              <select
                className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                value={removeForm.productId}
                onChange={(e) => setRemoveForm({ ...removeForm, productId: e.target.value })}
              >
                <option value="">-- Chọn sản phẩm --</option>
                {(promotionProducts[selectedPromotion?.promotionId] || []).map((p) => (
                  <option key={p.productId} value={p.productId}>
                    {p.productName}
                  </option>
                ))}
              </select>
            </div>
            {removeForm.productId && (
              <div className="p-3 bg-red-50 rounded-lg border border-red-200 text-sm text-red-600">
                Sale price của sản phẩm này sẽ bị xóa sau khi gỡ khuyến mãi.
              </div>
            )}
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setRemoveDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button variant="destructive" onClick={handleRemove} className="h-11 px-6 text-base font-medium">
              Gỡ khuyến mãi
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation */}
      <Dialog open={deleteDialogOpen} onOpenChange={(open) => { setDeleteDialogOpen(open); if (!open) setSelectedPromotion(null); }}>
        <DialogContent className="max-w-md">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Xác nhận xóa khuyến mãi</DialogTitle>
            <DialogDescription>
              Bạn có chắc muốn xóa khuyến mãi <span className="font-medium text-foreground">{selectedPromotion?.promotionName}</span>? Hành động này không thể hoàn tác.
            </DialogDescription>
          </DialogHeader>
          <div className="py-4">
            <div className="flex items-center gap-3 p-4 bg-red-50 rounded-lg border border-red-200">
              <div className="w-12 h-12 rounded-lg bg-red-100 flex items-center justify-center">
                <Tag className="w-6 h-6 text-red-500" />
              </div>
              <div>
                <p className="font-medium text-foreground">{selectedPromotion?.promotionName}</p>
                <p className="text-sm text-muted-foreground">Mã khuyến mãi sẽ bị xóa vĩnh viễn</p>
              </div>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button variant="destructive" onClick={handleDelete} className="h-11 px-6 text-base font-medium">
              Xóa khuyến mãi
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
