import { useEffect, useState, useRef, Fragment } from "react"
import { Search, Plus, Tag, Calendar, MoreVertical, Trash2, Edit, Percent, DollarSign, X, ChevronDown } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Checkbox } from "../../components/ui/checkbox"
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

/**
 * Parse date từ Spring (ISO string hoặc array [year, month, day, hour, min, sec])
 */
const parseDate = (val) => {
  if (!val) return null
  if (typeof val === "string") {
    const d = new Date(val)
    return isNaN(d.getTime()) ? null : d
  }
  if (Array.isArray(val) && val.length >= 6) {
    return new Date(val[0], val[1] - 1, val[2], val[3] || 0, val[4] || 0, val[5] || 0)
  }
  return null
}

const fmtDateTimeDisplay = (val) => {
  const d = parseDate(val)
  if (!d) return "--"
  return d.toLocaleString("vi-VN", {
    day: "2-digit", month: "2-digit", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  })
}

const fmtDateTimeLocal = (val) => {
  // Backend trả LocalDateTime.toString() format: 2026-05-27T10:45
  // Input datetime-local format: yyyy-MM-ddTHH:mm
  if (!val) return ""
  if (typeof val === "string") {
    // Nếu đã đúng format datetime-local, cắt giây
    if (val.length === 19) return val.substring(0, 16)
    if (val.length === 16) return val
  }
  const d = parseDate(val)
  if (!d) return ""
  const pad = (n) => String(n).padStart(2, "0")
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
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

  // Apply dialog
  const [applyProductId, setApplyProductId] = useState("")
  const [applyVariants, setApplyVariants] = useState([])
  const [applySelected, setApplySelected] = useState([])
  const [loadingVariants, setLoadingVariants] = useState(false)

  // Remove dialog
  const [removeItems, setRemoveItems] = useState([])
  const [removeSelected, setRemoveSelected] = useState([])
  const [loadingRemoveItems, setLoadingRemoveItems] = useState(false)

  // Column visibility
  const [visibleColumns, setVisibleColumns] = useState(["promotionName", "discountType", "discountValue", "startDate", "endDate", "status"])

  // Dropdown items per promotion
  const [promotionItems, setPromotionItems] = useState({})
  const [loadingItems, setLoadingItems] = useState(null)
  const openDropdownRef = useRef(null)
  const [openDropdown, setOpenDropdown] = useState(null)

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
      const matchesSearch = !kw || (p.promotionName || "").toLowerCase().includes(kw)
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

  const loadPromotionItems = async (promotionId) => {
    if (promotionItems[promotionId]) return
    try {
      setLoadingItems(promotionId)
      const res = await promotionsAPI.getItemsByPromotion(promotionId)
      setPromotionItems(prev => ({ ...prev, [promotionId]: res.data?.data || [] }))
    } catch (error) {
      console.error("Load promotion items error", error)
    } finally {
      setLoadingItems(null)
    }
  }

  const toggleItemsDropdown = (promotionId) => {
    if (openDropdownRef.current === promotionId) {
      openDropdownRef.current = null
      setOpenDropdown(null)
    } else {
      openDropdownRef.current = promotionId
      setOpenDropdown(promotionId)
      loadPromotionItems(promotionId)
    }
  }

  // ==================== APPLY DIALOG ====================

  const openApplyDialog = (promotion) => {
    setSelectedPromotion(promotion)
    setApplyProductId("")
    setApplyVariants([])
    setApplySelected([])
    loadProducts()
    setApplyDialogOpen(true)
  }

  const loadVariantsForApply = async (productId) => {
    setApplySelected([])
    setApplyVariants([])
    if (!productId) return
    try {
      setLoadingVariants(true)
      // Dùng endpoint nhẹ, không load serials
      const res = await promotionsAPI.getVariantsByProduct(productId)
      const items = res.data?.data || []
      setApplyVariants(items)
    } catch (error) {
      console.error("Load variants error", error)
      toast({ title: "Lỗi", description: "Không tải được biến thể", variant: "destructive" })
    } finally {
      setLoadingVariants(false)
    }
  }

  const toggleApplyVariant = (itemId) => {
    setApplySelected(prev =>
      prev.includes(itemId) ? prev.filter(id => id !== itemId) : [...prev, itemId]
    )
  }

  const toggleApplyAll = () => {
    if (applySelected.length === applyVariants.length) {
      setApplySelected([])
    } else {
      setApplySelected(applyVariants.map(v => v.productItemId))
    }
  }

  const handleApply = async () => {
    if (applySelected.length === 0) {
      toast({ title: "Lỗi", description: "Vui lòng chọn ít nhất một biến thể", variant: "destructive" })
      return
    }
    try {
      setSaving(true)
      await promotionsAPI.applyToItems({
        productItemIds: applySelected,
        promotionId: selectedPromotion.promotionId,
      })
      setApplyDialogOpen(false)
      setApplySelected([])
      setApplyVariants([])
      setApplyProductId("")
      setSelectedPromotion(null)
      setPromotionItems({})
      toast({ title: "Thành công", description: `Đã áp dụng cho ${applySelected.length} biến thể` })
    } catch (error) {
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Áp dụng thất bại", variant: "destructive" })
    } finally {
      setSaving(false)
    }
  }

  // ==================== REMOVE DIALOG ====================

  const openRemoveDialog = (promotion) => {
    setSelectedPromotion(promotion)
    setRemoveSelected([])
    loadPromotionItemsForRemove(promotion.promotionId)
    setRemoveDialogOpen(true)
  }

  const loadPromotionItemsForRemove = async (promotionId) => {
    try {
      setLoadingRemoveItems(true)
      const res = await promotionsAPI.getItemsByPromotion(promotionId)
      setRemoveItems(res.data?.data || [])
    } catch (error) {
      console.error("Load remove items error", error)
    } finally {
      setLoadingRemoveItems(false)
    }
  }

  const toggleRemoveItem = (itemId) => {
    setRemoveSelected(prev =>
      prev.includes(itemId) ? prev.filter(id => id !== itemId) : [...prev, itemId]
    )
  }

  const toggleRemoveAll = () => {
    if (removeSelected.length === removeItems.length) {
      setRemoveSelected([])
    } else {
      setRemoveSelected(removeItems.map(i => i.productItemId))
    }
  }

  const handleRemoveItems = async () => {
    if (removeSelected.length === 0) {
      toast({ title: "Lỗi", description: "Vui lòng chọn ít nhất một biến thể", variant: "destructive" })
      return
    }
    try {
      setSaving(true)
      await promotionsAPI.removeFromItems(removeSelected)
      setRemoveDialogOpen(false)
      setRemoveSelected([])
      setSelectedPromotion(null)
      setPromotionItems({})
      toast({ title: "Thành công", description: `Đã gỡ khuyến mãi khỏi ${removeSelected.length} biến thể` })
    } catch (error) {
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Gỡ thất bại", variant: "destructive" })
    } finally {
      setSaving(false)
    }
  }

  const toLocalDateTimeString = (val) => {
    // datetime-local format yyyy-MM-ddTHH:mm đã đúng với LocalDateTime.parse()
    // Chỉ thêm :00 giây nếu cần, không dùng new Date() để tránh timezone shift
    if (!val || val.trim() === "") return null
    return val.length === 16 ? val + ":00" : val
  }

  // ==================== CREATE ====================

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
        startDate: toLocalDateTimeString(addForm.startDate),
        endDate: toLocalDateTimeString(addForm.endDate),
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

  // ==================== UPDATE ====================

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
        startDate: toLocalDateTimeString(editForm.startDate),
        endDate: toLocalDateTimeString(editForm.endDate),
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

  // ==================== TOGGLE ACTIVE ====================

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

  // ==================== DELETE ====================

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

  const openEdit = (promotion) => {
    setSelectedPromotion(promotion)
    setEditForm({
      promotionName: promotion.promotionName || "",
      discountPercent: promotion.discountPercent != null ? String(promotion.discountPercent) : "",
      discountCost: promotion.discountCost != null ? String(promotion.discountCost) : "",
      startDate: fmtDateTimeLocal(promotion.startDate),
      endDate: fmtDateTimeLocal(promotion.endDate),
    })
    setEditDialogOpen(true)
  }

  // Mutual disable helpers for discount fields
  const handleAddPercentChange = (val) => {
    setAddForm(prev => ({
      ...prev,
      discountPercent: val,
      discountCost: val ? "" : prev.discountCost,
    }))
  }
  const handleAddCostChange = (val) => {
    setAddForm(prev => ({
      ...prev,
      discountCost: val,
      discountPercent: val ? "" : prev.discountPercent,
    }))
  }
  const handleEditPercentChange = (val) => {
    setEditForm(prev => ({
      ...prev,
      discountPercent: val,
      discountCost: val ? "" : prev.discountCost,
    }))
  }
  const handleEditCostChange = (val) => {
    setEditForm(prev => ({
      ...prev,
      discountCost: val,
      discountPercent: val ? "" : prev.discountPercent,
    }))
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
              {visibleColumns.includes("promotionName") && <TableHead className="text-left">Tên khuyến mãi</TableHead>}
              {visibleColumns.includes("discountType") && <TableHead className="text-center">Loại giảm</TableHead>}
              {visibleColumns.includes("discountValue") && <TableHead className="text-left">Mức giảm</TableHead>}
              {visibleColumns.includes("startDate") && <TableHead className="text-left">Ngày bắt đầu</TableHead>}
              {visibleColumns.includes("endDate") && <TableHead className="text-left">Ngày kết thúc</TableHead>}
              {visibleColumns.includes("status") && <TableHead className="text-center">Trạng thái</TableHead>}
              <TableHead className="w-12 text-center"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={7} className="text-center text-muted-foreground py-12">Đang tải...</TableCell>
              </TableRow>
            ) : pagedPromotions.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="text-center text-muted-foreground py-12">Chưa có khuyến mãi nào</TableCell>
              </TableRow>
            ) : (
              pagedPromotions.map((promotion) => {
                const status = getPromotionStatus(promotion)
                const hasDiscount = promotion.discountPercent != null || promotion.discountCost != null
                const itemsList = promotionItems[promotion.promotionId] || []
                const isExpanded = openDropdown === promotion.promotionId
                const colCount = visibleColumns.length + 1 // +1 for actions column
                return (
                  <Fragment key={promotion.promotionId}>
                    {/* Main row */}
                    <TableRow>
                      {visibleColumns.includes("promotionName") && (
                        <TableCell>
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
                        <TableCell
                          className={`font-medium text-foreground ${hasDiscount ? "cursor-pointer hover:text-primary" : "cursor-default"}`}
                          onClick={() => hasDiscount && toggleItemsDropdown(promotion.promotionId)}
                        >
                          <div className="flex items-center gap-1">
                            {promotion.discountPercent != null ? `${promotion.discountPercent}%` : ""}
                            {promotion.discountCost != null ? formatCurrency(promotion.discountCost) : ""}
                            {hasDiscount && (
                              <ChevronDown className={`w-3 h-3 transition-transform ${isExpanded ? "rotate-180" : ""}`} />
                            )}
                          </div>
                        </TableCell>
                      )}
                      {visibleColumns.includes("startDate") && (
                        <TableCell>
                          <div className="flex items-center gap-1 text-xs text-muted-foreground">
                            <Calendar className="w-3 h-3 flex-shrink-0" />
                            {fmtDateTimeDisplay(promotion.startDate)}
                          </div>
                        </TableCell>
                      )}
                      {visibleColumns.includes("endDate") && (
                        <TableCell>
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
                            <DropdownMenuItem className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer" onSelect={() => openEdit(promotion)}>
                              <Edit className="w-5 h-5 mr-3 text-blue-500" />Chỉnh sửa
                            </DropdownMenuItem>
                            <DropdownMenuItem className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer" onSelect={() => openApplyDialog(promotion)}>
                              <Percent className="w-5 h-5 mr-3 text-emerald-500" />Áp dụng biến thể
                            </DropdownMenuItem>
                            <DropdownMenuItem className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer" onSelect={() => openRemoveDialog(promotion)}>
                              <X className="w-5 h-5 mr-3 text-amber-500" />Gỡ biến thể
                            </DropdownMenuItem>
                            <DropdownMenuItem
                              className={`flex items-center py-3 px-4 text-base rounded-md cursor-pointer ${promotion.isActive ? "text-amber-500 hover:bg-amber-50" : "text-green-500 hover:bg-green-50"}`}
                              onSelect={() => handleToggleActive(promotion)}
                            >
                              {promotion.isActive ? <X className="w-5 h-5 mr-3" /> : <Percent className="w-5 h-5 mr-3" />}
                              {promotion.isActive ? "Tắt khuyến mãi" : "Kích hoạt"}
                            </DropdownMenuItem>
                            <DropdownMenuItem className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer text-red-500 hover:bg-red-50" onSelect={() => { setSelectedPromotion(promotion); setDeleteDialogOpen(true); }}>
                              <Trash2 className="w-5 h-5 mr-3" />Xóa
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </TableCell>
                    </TableRow>

                    {/* Expanded row */}
                    {isExpanded && (
                      <TableRow className="bg-accent/30 hover:bg-accent/40">
                        <TableCell colSpan={colCount} className="p-0">
                          <div className="px-6 py-3">
                            <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide mb-2">Biến thể đang áp dụng</p>
                            {loadingItems === promotion.promotionId ? (
                              <p className="text-sm text-muted-foreground">Đang tải...</p>
                            ) : itemsList.length === 0 ? (
                              <p className="text-sm text-muted-foreground">Chưa có biến thể nào</p>
                            ) : (
                              <div className="space-y-1">
                                {itemsList.map((item) => (
                                  <div key={item.productItemId} className="flex items-center justify-between py-2 px-3 bg-card rounded-md border border-border hover:bg-accent transition-colors group">
                                    <div>
                                      <p className="text-sm font-medium text-foreground">{item.sku || "Mặc định"}</p>
                                      <p className="text-xs text-muted-foreground">{item.productName}</p>
                                    </div>
                                    <div className="flex items-center gap-4">
                                      <div className="text-right">
                                        <p className="text-xs text-muted-foreground line-through">{formatCurrency(item.originalPrice)}</p>
                                        <p className="text-sm font-semibold text-red-500">{formatCurrency(item.salePrice)}</p>
                                      </div>
                                      <button
                                        onClick={() => {
                                          setSelectedPromotion(promotion)
                                          setRemoveItems([item])
                                          setRemoveSelected([item.productItemId])
                                          setRemoveDialogOpen(true)
                                        }}
                                        className="opacity-0 group-hover:opacity-100 transition-opacity text-red-400 hover:text-red-600 p-1"
                                        title="Gỡ khuyến mãi"
                                      >
                                        <X className="w-4 h-4" />
                                      </button>
                                    </div>
                                  </div>
                                ))}
                              </div>
                            )}
                          </div>
                        </TableCell>
                      </TableRow>
                    )}
                  </Fragment>
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

      {/* Backdrop */}
      {openDropdown && (
        <div className="fixed inset-0 z-40" onClick={() => { setOpenDropdown(null); openDropdownRef.current = null; }} />
      )}

      {/* ===================== CREATE DIALOG ===================== */}
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
                  type="number" min="0" max="100" placeholder="VD: 10"
                  className="h-11"
                  value={addForm.discountPercent}
                  onChange={(e) => handleAddPercentChange(e.target.value)}
                />
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Giảm số tiền cố định</label>
                <Input
                  type="number" min="0" placeholder="VD: 50000"
                  className="h-11"
                  value={addForm.discountCost}
                  onChange={(e) => handleAddCostChange(e.target.value)}
                />
              </div>
            </div>
            <p className="text-xs text-muted-foreground -mt-2">Nhập % hoặc số tiền cố định. Nhập một trong hai — khi nhập % thì số tiền sẽ bị xóa và ngược lại.</p>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Ngày bắt đầu</label>
                <Input
                  type="datetime-local" className="h-11"
                  value={addForm.startDate}
                  onChange={(e) => setAddForm({ ...addForm, startDate: e.target.value })}
                />
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Ngày kết thúc</label>
                <Input
                  type="datetime-local" className="h-11"
                  value={addForm.endDate}
                  onChange={(e) => setAddForm({ ...addForm, endDate: e.target.value })}
                />
              </div>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setAddDialogOpen(false)} className="h-11 px-6 text-base font-medium">Hủy</Button>
            <Button onClick={handleCreate} disabled={saving} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              {saving ? "Đang lưu..." : "Tạo khuyến mãi"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ===================== EDIT DIALOG ===================== */}
      <Dialog open={editDialogOpen} onOpenChange={(open) => { setEditDialogOpen(open); if (!open) setSelectedPromotion(null); }}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Chỉnh sửa khuyến mãi</DialogTitle>
            <DialogDescription>
              Cập nhật thông tin: <span className="font-medium text-foreground">{selectedPromotion?.promotionName}</span>
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
                  type="number" min="0" max="100" placeholder="VD: 10"
                  className="h-11"
                  value={editForm.discountPercent}
                  onChange={(e) => handleEditPercentChange(e.target.value)}
                />
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Giảm số tiền cố định</label>
                <Input
                  type="number" min="0" placeholder="VD: 50000"
                  className="h-11"
                  value={editForm.discountCost}
                  onChange={(e) => handleEditCostChange(e.target.value)}
                />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Ngày bắt đầu</label>
                <Input
                  type="datetime-local" className="h-11"
                  value={editForm.startDate}
                  onChange={(e) => setEditForm({ ...editForm, startDate: e.target.value })}
                />
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Ngày kết thúc</label>
                <Input
                  type="datetime-local" className="h-11"
                  value={editForm.endDate}
                  onChange={(e) => setEditForm({ ...editForm, endDate: e.target.value })}
                />
              </div>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setEditDialogOpen(false)} className="h-11 px-6 text-base font-medium">Hủy</Button>
            <Button onClick={handleUpdate} disabled={saving} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              {saving ? "Đang lưu..." : "Lưu thay đổi"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ===================== APPLY DIALOG ===================== */}
      <Dialog open={applyDialogOpen} onOpenChange={(open) => {
        setApplyDialogOpen(open)
        if (!open) {
          setSelectedPromotion(null)
          setApplyProductId("")
          setApplyVariants([])
          setApplySelected([])
        }
      }}>
        <DialogContent className="max-w-lg">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Áp dụng biến thể</DialogTitle>
            <DialogDescription>
              Chọn biến thể để áp dụng khuyến mãi <span className="font-medium text-foreground">{selectedPromotion?.promotionName}</span>. Sale price được tự động tính.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            {/* Step 1 */}
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Bước 1 — Chọn sản phẩm</label>
              <select
                className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                value={applyProductId}
                onChange={(e) => { setApplyProductId(e.target.value); loadVariantsForApply(e.target.value); }}
              >
                <option value="">-- Chọn sản phẩm --</option>
                {products.map((p) => (
                  <option key={p.productId} value={p.productId}>{p.name}</option>
                ))}
              </select>
            </div>

            {/* Step 2 */}
            {applyProductId && (
              <div>
                <div className="flex items-center justify-between mb-2">
                  <label className="text-sm font-medium">Bước 2 — Chọn biến thể</label>
                  {applyVariants.length > 0 && (
                    <button onClick={toggleApplyAll} className="text-xs text-primary hover:underline" type="button">
                      {applySelected.length === applyVariants.length ? "Bỏ chọn tất cả" : "Chọn tất cả"}
                    </button>
                  )}
                </div>

                {loadingVariants ? (
                  <p className="text-sm text-muted-foreground py-4 text-center">Đang tải biến thể...</p>
                ) : applyVariants.length === 0 ? (
                  <p className="text-sm text-muted-foreground py-4 text-center">Sản phẩm này chưa có biến thể nào</p>
                ) : (
                  <div className="border border-border rounded-lg overflow-hidden max-h-64 overflow-y-auto">
                    <table className="w-full text-sm">
                      <thead className="bg-muted/50">
                        <tr>
                          <th className="text-left px-3 py-2 font-medium text-muted-foreground w-8"></th>
                          <th className="text-left px-3 py-2 font-medium text-muted-foreground">SKU</th>
                          <th className="text-right px-3 py-2 font-medium text-muted-foreground">Giá gốc</th>
                        </tr>
                      </thead>
                      <tbody>
                        {applyVariants.map((v) => (
                          <tr key={v.productItemId} className="border-t border-border/50 hover:bg-accent/50 transition-colors">
                            <td className="px-3 py-2">
                              <Checkbox
                                checked={applySelected.includes(v.productItemId)}
                                onChange={() => toggleApplyVariant(v.productItemId)}
                              />
                            </td>
                            <td className="px-3 py-2 font-medium text-foreground">{v.sku || "Mặc định"}</td>
                            <td className="px-3 py-2 text-right text-muted-foreground">{formatCurrency(v.price)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
                {applyVariants.length > 0 && (
                  <p className="text-xs text-muted-foreground mt-1">
                    Đã chọn {applySelected.length} / {applyVariants.length} biến thể
                  </p>
                )}
              </div>
            )}

            {/* Promotion info */}
            {selectedPromotion && (
              <div className="p-3 bg-primary/5 rounded-lg border border-primary/20">
                <p className="text-sm font-medium text-foreground">Khuyến mãi:</p>
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
            <Button variant="outline" onClick={() => setApplyDialogOpen(false)} className="h-11 px-6 text-base font-medium">Hủy</Button>
            <Button
              onClick={handleApply}
              disabled={saving || applySelected.length === 0}
              className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20"
            >
              {saving ? "Đang áp dụng..." : `Áp dụng (${applySelected.length})`}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ===================== REMOVE DIALOG ===================== */}
      <Dialog open={removeDialogOpen} onOpenChange={(open) => {
        setRemoveDialogOpen(open)
        if (!open) { setSelectedPromotion(null); setRemoveItems([]); setRemoveSelected([]); }
      }}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Gỡ biến thể khỏi khuyến mãi</DialogTitle>
            <DialogDescription>
              Chọn biến thể cần gỡ khỏi <span className="font-medium text-foreground">{selectedPromotion?.promotionName}</span>. Sale price sẽ bị xóa.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            {loadingRemoveItems ? (
              <p className="text-sm text-muted-foreground text-center py-4">Đang tải...</p>
            ) : removeItems.length === 0 ? (
              <p className="text-sm text-muted-foreground text-center py-4">Không có biến thể nào đang được áp dụng</p>
            ) : (
              <>
                <div className="flex items-center justify-between mb-2">
                  <label className="text-sm font-medium">Chọn biến thể cần gỡ</label>
                  <button onClick={toggleRemoveAll} className="text-xs text-primary hover:underline" type="button">
                    {removeSelected.length === removeItems.length ? "Bỏ chọn tất cả" : "Chọn tất cả"}
                  </button>
                </div>
                <div className="border border-border rounded-lg overflow-hidden max-h-72 overflow-y-auto">
                  <table className="w-full text-sm">
                    <thead className="bg-muted/50">
                      <tr>
                        <th className="text-left px-3 py-2 font-medium text-muted-foreground w-8"></th>
                        <th className="text-left px-3 py-2 font-medium text-muted-foreground">SKU</th>
                        <th className="text-left px-3 py-2 font-medium text-muted-foreground">Sản phẩm</th>
                        <th className="text-right px-3 py-2 font-medium text-muted-foreground">Giá sale</th>
                      </tr>
                    </thead>
                    <tbody>
                      {removeItems.map((item) => (
                        <tr key={item.productItemId} className="border-t border-border/50 hover:bg-accent/50 transition-colors">
                          <td className="px-3 py-2">
                            <Checkbox
                              checked={removeSelected.includes(item.productItemId)}
                              onChange={() => toggleRemoveItem(item.productItemId)}
                            />
                          </td>
                          <td className="px-3 py-2 font-medium text-foreground">{item.sku || "Mặc định"}</td>
                          <td className="px-3 py-2 text-muted-foreground">{item.productName}</td>
                          <td className="px-3 py-2 text-right text-red-500 font-medium">{formatCurrency(item.salePrice)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <p className="text-xs text-muted-foreground">Đã chọn {removeSelected.length} / {removeItems.length} biến thể</p>
              </>
            )}
            {removeSelected.length > 0 && (
              <div className="p-3 bg-red-50 rounded-lg border border-red-200 text-sm text-red-600">
                Sale price của {removeSelected.length} biến thể sẽ bị xóa.
              </div>
            )}
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setRemoveDialogOpen(false)} className="h-11 px-6 text-base font-medium">Hủy</Button>
            <Button
              variant="destructive"
              onClick={handleRemoveItems}
              disabled={saving || removeSelected.length === 0}
              className="h-11 px-6 text-base font-medium"
            >
              {saving ? "Đang gỡ..." : `Gỡ khuyến mãi (${removeSelected.length})`}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ===================== DELETE CONFIRMATION ===================== */}
      <Dialog open={deleteDialogOpen} onOpenChange={(open) => { setDeleteDialogOpen(open); if (!open) setSelectedPromotion(null); }}>
        <DialogContent className="max-w-md">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Xác nhận xóa khuyến mãi</DialogTitle>
            <DialogDescription>
              Xóa <span className="font-medium text-foreground">{selectedPromotion?.promotionName}</span>? Hành động này không thể hoàn tác.
            </DialogDescription>
          </DialogHeader>
          <div className="py-4">
            <div className="flex items-center gap-3 p-4 bg-red-50 rounded-lg border border-red-200">
              <div className="w-12 h-12 rounded-lg bg-red-100 flex items-center justify-center">
                <Tag className="w-6 h-6 text-red-500" />
              </div>
              <div>
                <p className="font-medium text-foreground">{selectedPromotion?.promotionName}</p>
                <p className="text-sm text-muted-foreground">Khuyến mãi sẽ bị xóa vĩnh viễn</p>
              </div>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)} className="h-11 px-6 text-base font-medium">Hủy</Button>
            <Button variant="destructive" onClick={handleDelete} className="h-11 px-6 text-base font-medium">Xóa khuyến mãi</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
