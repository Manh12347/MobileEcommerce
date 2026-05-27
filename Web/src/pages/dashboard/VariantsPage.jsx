import { useEffect, useMemo, useState, useRef } from "react"
import { Search, Plus, MoreVertical, Eye, Edit, Trash2, Package, Image, Upload, Loader2 } from "lucide-react"
import { AlertTriangle } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from "../../components/ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"
import { PaginationControls } from "../../components/dashboard/PaginationControls"
import { ClampText } from "../../components/dashboard/ClampText"
import { ColumnVisibilitySelect } from "../../components/dashboard/ColumnVisibilitySelect"
import { catalogAPI, productItemAPI, uploadAPI } from "../../api/client"
import { useToast } from "../../hooks/use-toast"

const initialForm = {
  productId: "",
  sku: "",
  description: "",
  price: "",
  stockQuantity: "",
  status: "active",
  specifications: "",
  mainImageUrl: "",
}

const renderSpecificationsView = (specJson) => {
  const specs = parseSpecifications(specJson)
  if (!specs) {
    return <span className="text-muted-foreground text-sm">--</span>
  }

  return (
    <div className="border border-input rounded-md overflow-hidden">
      <table className="w-full text-sm">
        <tbody>
          {Object.entries(specs).map(([key, value], index) => (
            <tr key={key} className={index !== Object.keys(specs).length - 1 ? "border-b border-input" : ""}>
              <td className="px-3 py-2 bg-muted/50 text-muted-foreground font-medium w-1/3 text-left">{key}</td>
              <td className="px-3 py-2 text-left">{value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

const SpecificationsInput = ({ value, onChange }) => {
  const [specs, setSpecs] = useState([])
  const [newKey, setNewKey] = useState("")
  const [newValue, setNewValue] = useState("")

  // Parse initial value
  useEffect(() => {
    if (value) {
      const parsed = parseSpecifications(value)
      if (parsed && typeof parsed === 'object') {
        setSpecs(Object.entries(parsed).map(([key, val]) => ({ key, value: val })))
      } else {
        setSpecs([])
      }
    } else {
      setSpecs([])
    }
  }, [value])

  const updateValue = (newSpecs) => {
    if (newSpecs.length === 0) {
      onChange("")
    } else {
      const obj = {}
      newSpecs.forEach(s => { if (s.key.trim()) obj[s.key.trim()] = s.value })
      onChange(JSON.stringify(obj))
    }
  }

  const addSpec = () => {
    if (newKey.trim() && newValue.trim()) {
      const newSpecs = [...specs, { key: newKey.trim(), value: newValue.trim() }]
      setSpecs(newSpecs)
      updateValue(newSpecs)
      setNewKey("")
      setNewValue("")
    }
  }

  const removeSpec = (index) => {
    const newSpecs = specs.filter((_, i) => i !== index)
    setSpecs(newSpecs)
    updateValue(newSpecs)
  }

  const updateSpec = (index, field, fieldValue) => {
    const newSpecs = specs.map((s, i) => i === index ? { ...s, [field]: fieldValue } : s)
    setSpecs(newSpecs)
    updateValue(newSpecs)
  }

  return (
    <div className="space-y-3">
      <div className="border border-input rounded-md overflow-hidden">
        <table className="w-full text-sm">
          <tbody>
            {specs.map((spec, index) => (
              <tr key={index} className={index !== specs.length - 1 ? "border-b border-input" : ""}>
                <td className="px-2 py-1.5">
                  <input
                    className="w-full px-2 py-1 text-sm bg-transparent border-none outline-none"
                    value={spec.key}
                    onChange={(e) => updateSpec(index, 'key', e.target.value)}
                    placeholder="Key"
                  />
                </td>
                <td className="px-2 py-1.5 border-l border-input">
                  <input
                    className="w-full px-2 py-1 text-sm bg-transparent border-none outline-none"
                    value={spec.value}
                    onChange={(e) => updateSpec(index, 'value', e.target.value)}
                    placeholder="Value"
                  />
                </td>
                <td className="px-2 py-1.5 border-l border-input w-10">
                  <button
                    type="button"
                    onClick={() => removeSpec(index)}
                    className="w-full h-8 flex items-center justify-center text-muted-foreground hover:text-destructive transition-colors"
                  >
                    ×
                  </button>
                </td>
              </tr>
            ))}
            {specs.length === 0 && (
              <tr>
                <td colSpan={3} className="px-3 py-4 text-center text-muted-foreground text-sm">
                  Chưa có cấu hình
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      <div className="flex gap-2">
        <input
          className="flex-1 h-10 px-3 rounded-md border border-input bg-background text-sm"
          value={newKey}
          onChange={(e) => setNewKey(e.target.value)}
          placeholder="Key (VD: Type)"
          onKeyDown={(e) => e.key === 'Enter' && addSpec()}
        />
        <input
          className="flex-1 h-10 px-3 rounded-md border border-input bg-background text-sm"
          value={newValue}
          onChange={(e) => setNewValue(e.target.value)}
          placeholder="Value (VD: DDR5)"
          onKeyDown={(e) => e.key === 'Enter' && addSpec()}
        />
        <Button type="button" variant="outline" size="sm" onClick={addSpec} className="h-10 px-3">
          +
        </Button>
      </div>
    </div>
  )
}

const columnOptions = [
  { value: "image", label: "Ảnh" },
  { value: "product", label: "Sản phẩm" },
  { value: "sku", label: "SKU" },
  { value: "price", label: "Giá" },
  { value: "stock", label: "Tồn kho" },
  { value: "sold", label: "Đã bán" },
  { value: "status", label: "Trạng thái" },
  { value: "actions", label: "Thao tác" },
]

const parseSpecifications = (specJson) => {
  if (!specJson) return null
  
  let specs = null
  try {
    // Try to parse - might be already JSON or escaped string
    let parsed = typeof specJson === 'string' ? JSON.parse(specJson) : specJson
    
    // If result is still a string, try parsing again
    if (typeof parsed === 'string') {
      parsed = JSON.parse(parsed)
    }
    
    // Ensure it's an object
    if (typeof parsed === 'object' && parsed !== null) {
      specs = parsed
    }
  } catch (e) {
    // If still fails, return raw string as single key-value
    console.warn("Parse specifications warning:", e, "raw:", specJson)
    return null
  }
  
  return specs
}

const renderSpecifications = (specJson) => {
  const specs = parseSpecifications(specJson)
  if (!specs) {
    return <span className="text-muted-foreground text-xs">{specJson || '--'}</span>
  }

  return (
    <div className="border border-input rounded-md overflow-hidden">
      <table className="w-full text-xs">
        <tbody>
          {Object.entries(specs).map(([key, value], index) => (
            <tr key={key} className={index !== Object.keys(specs).length - 1 ? "border-b border-input" : ""}>
              <td className="px-2 py-1.5 bg-muted/50 text-muted-foreground font-medium w-1/3 text-left">{key}</td>
              <td className="px-2 py-1.5 text-left">{value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

const renderSpecificationsEdit = (specJson) => {
  const specs = parseSpecifications(specJson)
  if (!specs) {
    return <span className="text-muted-foreground text-xs">{specJson || '--'}</span>
  }

  return (
    <div className="border border-input rounded-md overflow-hidden">
      <table className="w-full text-sm">
        <tbody>
          {Object.entries(specs).map(([key, value], index) => (
            <tr key={key} className={index !== Object.keys(specs).length - 1 ? "border-b border-input" : ""}>
              <td className="px-3 py-2 bg-muted/50 text-muted-foreground font-medium w-1/3 text-left">{key}</td>
              <td className="px-3 py-2 text-left">{value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export function VariantsPage() {
  const { toast } = useToast()
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(5)

  const [items, setItems] = useState([])
  const [products, setProducts] = useState([])
  const [loading, setLoading] = useState(false)
  const [totalItems, setTotalItems] = useState(0)

  const [addDialogOpen, setAddDialogOpen] = useState(false)
  const [viewDialogOpen, setViewDialogOpen] = useState(false)
  const [editDialogOpen, setEditDialogOpen] = useState(false)
  const [stockDialogOpen, setStockDialogOpen] = useState(false)
  const [stockChange, setStockChange] = useState(0)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [discontinueDialogOpen, setDiscontinueDialogOpen] = useState(false)
  const [imagePreview, setImagePreview] = useState("")
  const [isUploadingImage, setIsUploadingImage] = useState(false)

  const [selectedItem, setSelectedItem] = useState(null)
  const [addForm, setAddForm] = useState(initialForm)
  const [editForm, setEditForm] = useState(initialForm)
  const [visibleColumns, setVisibleColumns] = useState(["image", "product", "sku", "price", "stock", "sold", "status"])
  const isLoadingRef = useRef(false)

  const productMap = useMemo(() => new Map(products.map((product) => [product.productId, product.name])), [products])

  const loadData = async (page = 1, size = pageSize) => {
    if (isLoadingRef.current) return
    try {
      isLoadingRef.current = true
      setLoading(true)
      const itemsResponse = await productItemAPI.getAll({ page, size })
      const content = itemsResponse?.data?.data?.content ?? itemsResponse?.data?.data ?? []
      const total = itemsResponse?.data?.data?.totalElements ?? itemsResponse?.data?.total ?? content.length
      
      if (page === 1) {
        setItems(content)
      } else {
        setItems(prev => [...prev, ...content])
      }
      setTotalItems(total)
    } catch (error) {
      console.error("Load items error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Không tải được biến thể", variant: "destructive" })
    } finally {
      setLoading(false)
      isLoadingRef.current = false
    }
  }

  const loadProductsForDialog = async () => {
    try {
      const productsResponse = await catalogAPI.getAllProducts()
      console.log("Products response:", productsResponse)
      console.log("Products data:", productsResponse?.data)
      const productsData = productsResponse?.data?.data ?? productsResponse?.data ?? []
      console.log("Products list:", productsData)
      setProducts(Array.isArray(productsData) ? productsData : [])
    } catch (error) {
      console.error("Load products error", error)
    }
  }

  useEffect(() => {
    // Reset currentPage khi search/fillter thay đổi
    if (currentPage !== 1) {
      setCurrentPage(1)
    } else {
      // Nếu đang ở page 1 thì load lại
      loadData(1, pageSize)
    }
  }, [searchTerm, statusFilter])

  useEffect(() => {
    // Load khi page hoặc pageSize thay đổi
    loadData(currentPage, pageSize)
  }, [currentPage, pageSize])

  useEffect(() => {
    loadProductsForDialog()
  }, [])

  const filteredItems = useMemo(() => {
    return items
      .filter((item) => {
        const keyword = searchTerm.trim().toLowerCase()
        const productName = productMap.get(item.productId) || item.productName || ""
        const matchesSearch = !keyword || [productName, item.sku, item.color, item.size]
          .some((v) => (v || "").toLowerCase().includes(keyword))
        const matchesStatus = statusFilter === "all" || item.status === statusFilter
        return matchesSearch && matchesStatus
      })
      .sort((a, b) => {
        if (a.status === "active" && b.status !== "active") return -1
        if (a.status !== "active" && b.status === "active") return 1
        return (productMap.get(a.productId) || "").localeCompare(productMap.get(b.productId) || "")
      })
  }, [items, searchTerm, statusFilter, productMap])

  const pagedItems = filteredItems.slice((currentPage - 1) * pageSize, currentPage * pageSize)

  const handleImageUploadAdd = async (e) => {
    const file = e.target.files?.[0]
    if (!file) return

    if (!file.type.startsWith("image/")) {
      toast({ title: "Lỗi", description: "Vui lòng chọn file ảnh", variant: "destructive" })
      return
    }
    if (file.size > 5 * 1024 * 1024) {
      toast({ title: "Lỗi", description: "Kích thước file không được vượt quá 5MB", variant: "destructive" })
      return
    }

    const preview = URL.createObjectURL(file)
    setImagePreview(preview)
    setIsUploadingImage(true)

    try {
      const res = await uploadAPI.uploadProductImage(file)
      if (res?.data?.success) {
        setAddForm((prev) => ({ ...prev, mainImageUrl: res.data.url }))
        setImagePreview("")
        toast({ title: "Thành công", description: "Upload ảnh thành công" })
      } else {
        toast({ title: "Lỗi", description: res.data?.message || "Upload thất bại", variant: "destructive" })
      }
    } catch (err) {
      toast({ title: "Lỗi", description: err.response?.data?.message || "Upload ảnh thất bại", variant: "destructive" })
    } finally {
      setIsUploadingImage(false)
    }
  }

  const handleImageUpload = async (e, itemId) => {
    const file = e.target.files?.[0]
    if (!file) return

    if (!file.type.startsWith("image/")) {
      toast({ title: "Lỗi", description: "Vui lòng chọn file ảnh", variant: "destructive" })
      return
    }
    if (file.size > 5 * 1024 * 1024) {
      toast({ title: "Lỗi", description: "Kích thước file không được vượt quá 5MB", variant: "destructive" })
      return
    }

    const preview = URL.createObjectURL(file)
    setImagePreview(preview)
    setIsUploadingImage(true)

    try {
      const res = await uploadAPI.uploadProductImage(file)
      if (res?.data?.success) {
        const newUrl = res.data.url
        await productItemAPI.update(itemId, { mainImageUrl: newUrl })
        setSelectedItem((prev) => ({ ...prev, mainImageUrl: newUrl }))
        setImagePreview("")
        loadData(currentPage, pageSize)
        toast({ title: "Thành công", description: "Upload ảnh thành công" })
      } else {
        toast({ title: "Lỗi", description: res.data?.message || "Upload thất bại", variant: "destructive" })
      }
    } catch (err) {
      toast({ title: "Lỗi", description: err.response?.data?.message || "Upload ảnh thất bại", variant: "destructive" })
    } finally {
      setIsUploadingImage(false)
    }
  }

  const handleImageUploadEdit = async (e) => {
    const file = e.target.files?.[0]
    if (!file) return

    if (!file.type.startsWith("image/")) {
      toast({ title: "Lỗi", description: "Vui lòng chọn file ảnh", variant: "destructive" })
      return
    }
    if (file.size > 5 * 1024 * 1024) {
      toast({ title: "Lỗi", description: "Kích thước file không được vượt quá 5MB", variant: "destructive" })
      return
    }

    const preview = URL.createObjectURL(file)
    setImagePreview(preview)
    setIsUploadingImage(true)

    try {
      const res = await uploadAPI.uploadProductImage(file)
      if (res?.data?.success) {
        const newUrl = res.data.url
        setEditForm((prev) => ({ ...prev, mainImageUrl: newUrl }))
        setImagePreview("")
        toast({ title: "Thành công", description: "Upload ảnh thành công" })
      } else {
        toast({ title: "Lỗi", description: res.data?.message || "Upload thất bại", variant: "destructive" })
      }
    } catch (err) {
      toast({ title: "Lỗi", description: err.response?.data?.message || "Upload ảnh thất bại", variant: "destructive" })
    } finally {
      setIsUploadingImage(false)
    }
  }

  const handleCreateItem = async () => {
    if (!addForm.productId) {
      toast({ title: "Lỗi", description: "Vui lòng chọn sản phẩm", variant: "destructive" })
      return
    }

    try {
      await productItemAPI.create({
        productId: Number(addForm.productId),
        sku: addForm.sku.trim(),
        description: addForm.description,
        price: addForm.price ? Number(addForm.price) : null,
        stockQuantity: addForm.stockQuantity ? Number(addForm.stockQuantity) : 0,
        status: addForm.status,
        specifications: addForm.specifications || null,
        mainImageUrl: addForm.mainImageUrl || null,
      })
      setAddDialogOpen(false)
      setAddForm(initialForm)
      setImagePreview("")
      await loadData()
      toast({ title: "Thành công", description: "Đã thêm biến thể mới" })
    } catch (error) {
      console.error("Create item error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Tạo biến thể thất bại", variant: "destructive" })
    }
  }

  const handleUpdateItem = async () => {
    if (!selectedItem) return
    if (!editForm.productId) {
      toast({ title: "Lỗi", description: "Vui lòng chọn sản phẩm", variant: "destructive" })
      return
    }

    try {
      await productItemAPI.update(selectedItem.productItemId, {
        sku: editForm.sku.trim(),
        description: editForm.description,
        price: editForm.price ? Number(editForm.price) : null,
        status: editForm.status,
        specifications: editForm.specifications || null,
        mainImageUrl: editForm.mainImageUrl || null,
      })
      setEditDialogOpen(false)
      setSelectedItem(null)
      setImagePreview("")
      await loadData()
      toast({ title: "Thành công", description: "Đã cập nhật biến thể" })
    } catch (error) {
      console.error("Update item error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Cập nhật biến thể thất bại", variant: "destructive" })
    }
  }

  const handleToggleItemStatus = async () => {
    if (!selectedItem) return

    try {
      await productItemAPI.toggleStatus(selectedItem.productItemId)
      setDeleteDialogOpen(false)
      setSelectedItem(null)
      await loadData()
      toast({ title: "Thành công", description: selectedItem.status === "active" ? "Đã vô hiệu biến thể" : "Đã kích hoạt biến thể" })
    } catch (error) {
      console.error("Toggle item status error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Cập nhật trạng thái thất bại", variant: "destructive" })
    }
  }

  const handleDiscontinueItem = async () => {
    if (!selectedItem) return

    try {
      await productItemAPI.discontinue(selectedItem.productItemId)
      setDiscontinueDialogOpen(false)
      setSelectedItem(null)
      await loadData()
      toast({ title: "Thành công", description: "Biến thể đã được ngừng bán" })
    } catch (error) {
      console.error("Discontinue item error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Ngừng bán thất bại", variant: "destructive" })
    }
  }

  const handleUpdateStock = async () => {
    if (!selectedItem) return

    try {
      if (stockChange > 0) {
        await productItemAPI.addStock(selectedItem.productItemId, stockChange)
      } else if (stockChange < 0) {
        await productItemAPI.reduceStock(selectedItem.productItemId, Math.abs(stockChange))
      }
      setStockDialogOpen(false)
      setSelectedItem(null)
      setStockChange(0)
      await loadData()
      toast({ title: "Thành công", description: stockChange > 0 ? `Đã tăng tồn kho thêm ${stockChange}` : stockChange < 0 ? `Đã giảm tồn kho ${Math.abs(stockChange)}` : "Không có thay đổi" })
    } catch (error) {
      console.error("Update stock error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Cập nhật tồn kho thất bại", variant: "destructive" })
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Biến thể</h1>
          <p className="text-muted-foreground">Quản lý SKU, giá và tồn kho của từng biến thể sản phẩm.</p>
        </div>
        <Button onClick={() => setAddDialogOpen(true)} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
          <Plus className="w-5 h-5 mr-2" />
          Thêm biến thể
        </Button>
      </div>

      <div className="flex flex-col sm:flex-row flex-wrap gap-4">
        <div className="relative flex-1 min-w-48 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm theo SKU, màu, size..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-9"
          />
        </div>
        <div className="flex items-center gap-3">
          <ColumnVisibilitySelect
            options={columnOptions}
            value={visibleColumns}
            onChange={setVisibleColumns}
          />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="h-11 px-3 rounded-md border border-input bg-background text-sm"
          >
            <option value="all">Tất cả trạng thái</option>
            <option value="active">Hoạt động</option>
            <option value="disable">Đã vô hiệu</option>
            <option value="discontinued">Ngừng bán</option>
          </select>
        </div>
      </div>

      <div className="bg-card rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              {visibleColumns.includes("image") && <TableHead className="text-left w-16">Ảnh</TableHead>}
              {visibleColumns.includes("product") && <TableHead className="text-left">Sản phẩm</TableHead>}
              {visibleColumns.includes("sku") && <TableHead className="text-left">SKU</TableHead>}
              {visibleColumns.includes("price") && <TableHead className="text-left">Giá</TableHead>}
              {visibleColumns.includes("stock") && <TableHead className="text-left">Tồn kho</TableHead>}
              {visibleColumns.includes("sold") && <TableHead className="text-left">Đã bán</TableHead>}
              {visibleColumns.includes("status") && <TableHead className="text-left">Trạng thái</TableHead>}
              <TableHead className="w-12"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {pagedItems.map((item) => (
              <TableRow key={item.productItemId}>
                {visibleColumns.includes("image") && (
                  <TableCell className="text-left">
                    {item.mainImageUrl ? (
                      <img
                        src={item.mainImageUrl}
                        alt={item.sku}
                        className="w-10 h-10 rounded-md object-cover border border-border"
                      />
                    ) : (
                      <div className="w-10 h-10 rounded-md bg-muted flex items-center justify-center border border-border">
                        <Image className="w-4 h-4 text-muted-foreground" />
                      </div>
                    )}
                  </TableCell>
                )}
                {visibleColumns.includes("product") && (
                  <TableCell className="text-left font-medium text-foreground">
                    <ClampText title={productMap.get(item.productId) || item.productName || "Chưa gán"}>
                      {productMap.get(item.productId) || item.productName || "Chưa gán"}
                    </ClampText>
                  </TableCell>
                )}
                {visibleColumns.includes("sku") && (
                  <TableCell className="text-left text-muted-foreground">
                    <ClampText title={item.sku || "--"}>{item.sku || "--"}</ClampText>
                  </TableCell>
                )}
                {visibleColumns.includes("price") && (
                  <TableCell className="text-left">
                    {item.salePrice != null && item.salePrice < item.price ? (
                      <div className="flex flex-col">
                        <span className="text-muted-foreground line-through text-xs">{item.price?.toLocaleString()}</span>
                        <span className="text-red-500 font-medium">{item.salePrice?.toLocaleString()}</span>
                      </div>
                    ) : (
                      <span className="text-muted-foreground">{item.price?.toLocaleString() ?? "--"}</span>
                    )}
                  </TableCell>
                )}
                {visibleColumns.includes("stock") && (
                  <TableCell className="text-left text-muted-foreground">{item.stockQuantity ?? 0}</TableCell>
                )}
                {visibleColumns.includes("sold") && (
                  <TableCell className="text-left text-muted-foreground">{item.soldQuantity ?? 0}</TableCell>
                )}
                {visibleColumns.includes("status") && (
                  <TableCell className="text-left">
                    <Badge variant={item.status === "active" ? "success" : item.status === "discontinued" ? "warning" : "destructive"}>
                      {item.status === "active" ? "Hoạt động" : item.status === "discontinued" ? "Ngừng bán" : "Đã vô hiệu"}
                    </Badge>
                  </TableCell>
                )}
                {visibleColumns.includes("actions") && (
                  <TableCell className="text-center">
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="ghost" size="icon" className="h-10 w-10 hover:bg-primary/10 hover:text-primary transition-colors">
                          <MoreVertical className="w-5 h-5" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end" className="w-44">
                        <DropdownMenuItem
                          className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer"
                          onSelect={() => {
                          setSelectedItem(item)
                          setImagePreview("")
                          setViewDialogOpen(true)
                        }}
                      >
                        <Eye className="w-5 h-5 mr-3 text-gray-500" />
                        Xem thông tin
                        </DropdownMenuItem>
                      <DropdownMenuItem
                        className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer"
                        onSelect={() => {
                          setSelectedItem(item)
                          setImagePreview("")
                          setEditForm({
                            productId: item.productId ? String(item.productId) : "",
                            sku: item.sku || "",
                            description: item.description || "",
                            price: item.price != null ? String(item.price) : "",
                            status: item.status || "active",
                            specifications: item.specifications || "",
                            mainImageUrl: item.mainImageUrl || "",
                          })
                          setEditDialogOpen(true)
                        }}
                      >
                        <Edit className="w-5 h-5 mr-3 text-blue-500" />
                        Chỉnh sửa
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer"
                        onSelect={() => {
                          setSelectedItem(item)
                          setStockChange(0)
                          setStockDialogOpen(true)
                        }}
                      >
                        <Package className="w-5 h-5 mr-3 text-orange-500" />
                        Chỉnh số lượng
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        className={`flex items-center py-3 px-4 text-base rounded-md cursor-pointer ${item.status === "active" ? "text-red-500 hover:bg-red-50" : "text-green-500 hover:bg-green-50"}`}
                        onSelect={() => {
                          setSelectedItem(item)
                          setDeleteDialogOpen(true)
                        }}
                      >
                        <Trash2 className="w-5 h-5 mr-3" />
                        {item.status === "active" ? "Vô hiệu" : "Kích hoạt"}
                      </DropdownMenuItem>
                      {item.status === "active" && (
                        <DropdownMenuItem
                          className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer text-amber-500 hover:bg-amber-50"
                          onSelect={() => {
                            setSelectedItem(item)
                            setDiscontinueDialogOpen(true)
                          }}
                        >
                          <AlertTriangle className="w-5 h-5 mr-3" />
                          Ngừng bán
                        </DropdownMenuItem>
                      )}
                    </DropdownMenuContent>
                  </DropdownMenu>
                </TableCell>
                )}
              </TableRow>
            ))}
            {!loading && pagedItems.length === 0 && (
              <TableRow>
                <TableCell colSpan={visibleColumns.length + 1} className="text-center text-muted-foreground py-8">
                  Không có dữ liệu biến thể
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      <PaginationControls
        totalItems={totalItems}
        pageSize={pageSize}
        currentPage={currentPage}
        onPageChange={setCurrentPage}
        onPageSizeChange={(size) => {
          setPageSize(size)
          setCurrentPage(1)
        }}
      />

      <Dialog open={addDialogOpen} onOpenChange={(open) => { if (!open) { setImagePreview(""); setAddForm(initialForm); } setAddDialogOpen(open); }}>
        <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Thêm biến thể mới</DialogTitle>
            <DialogDescription>Nhập thông tin biến thể sản phẩm.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            {/* Ảnh biến thể */}
            <div className="flex items-start gap-4">
              <div className="flex-shrink-0">
                {addForm.mainImageUrl ? (
                  <img
                    src={imagePreview || addForm.mainImageUrl}
                    alt="preview"
                    className="w-20 h-20 rounded-lg object-cover border border-border"
                  />
                ) : imagePreview ? (
                  <img
                    src={imagePreview}
                    alt="preview"
                    className="w-20 h-20 rounded-lg object-cover border border-border"
                  />
                ) : (
                  <div className="w-20 h-20 rounded-lg bg-muted flex items-center justify-center border border-border">
                    <Image className="w-8 h-8 text-muted-foreground" />
                  </div>
                )}
              </div>
              <div className="flex-1">
                <label
                  htmlFor="add-variant-image-upload"
                  className="inline-flex items-center gap-2 px-3 py-1.5 text-sm font-medium rounded-md border border-border bg-background hover:bg-secondary cursor-pointer transition-colors"
                >
                  {isUploadingImage ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    <Upload className="w-4 h-4" />
                  )}
                  {isUploadingImage ? "Đang upload..." : "Chọn ảnh"}
                </label>
                <input
                  id="add-variant-image-upload"
                  type="file"
                  accept="image/*"
                  className="sr-only"
                  disabled={isUploadingImage}
                  onChange={handleImageUploadAdd}
                />
                <p className="text-xs text-muted-foreground mt-1">JPEG, PNG, WEBP, tối đa 5MB</p>
              </div>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Sản phẩm</label>
              <select
                className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                value={addForm.productId}
                onChange={(e) => setAddForm({ ...addForm, productId: e.target.value })}
              >
                <option value="">-- Chọn sản phẩm --</option>
                {products.map((product) => (
                  <option key={product.productId} value={String(product.productId)}>{product.name}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">SKU</label>
              <Input
                className="h-11"
                value={addForm.sku}
                onChange={(e) => setAddForm({ ...addForm, sku: e.target.value })}
                placeholder="Nhập SKU sản phẩm"
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Giá</label>
              <Input
                type="number"
                className="h-11"
                value={addForm.price}
                onChange={(e) => setAddForm({ ...addForm, price: e.target.value })}
                placeholder="0"
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Số lượng tồn kho</label>
              <Input
                type="number"
                className="h-11"
                value={addForm.stockQuantity}
                onChange={(e) => setAddForm({ ...addForm, stockQuantity: e.target.value })}
                placeholder="0"
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Mô tả</label>
              <textarea
                className="w-full px-3 py-2 border border-input rounded-md bg-background text-sm min-h-[80px] resize-y"
                value={addForm.description}
                onChange={(e) => setAddForm({ ...addForm, description: e.target.value })}
                placeholder="Nhập mô tả sản phẩm"
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Cấu hình</label>
              <SpecificationsInput
                value={addForm.specifications}
                onChange={(val) => setAddForm({ ...addForm, specifications: val })}
              />
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setAddDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button onClick={handleCreateItem} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              Thêm biến thể
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={editDialogOpen} onOpenChange={(open) => { if (!open) { setSelectedItem(null); } setEditDialogOpen(open); }}>
        <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Chỉnh sửa biến thể</DialogTitle>
            <DialogDescription>
              SKU: <span className="font-medium text-foreground">{selectedItem?.sku}</span>
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            {/* Ảnh biến thể */}
            <div className="flex items-start gap-4">
              <div className="flex-shrink-0">
                {editForm.mainImageUrl ? (
                  <img
                    src={imagePreview || editForm.mainImageUrl}
                    alt={editForm.sku}
                    className="w-20 h-20 rounded-lg object-cover border border-border"
                  />
                ) : imagePreview ? (
                  <img
                    src={imagePreview}
                    alt={editForm.sku}
                    className="w-20 h-20 rounded-lg object-cover border border-border"
                  />
                ) : (
                  <div className="w-20 h-20 rounded-lg bg-muted flex items-center justify-center border border-border">
                    <Image className="w-8 h-8 text-muted-foreground" />
                  </div>
                )}
              </div>
              <div className="flex-1">
                <label
                  htmlFor="variant-image-upload"
                  className="inline-flex items-center gap-2 px-3 py-1.5 text-sm font-medium rounded-md border border-border bg-background hover:bg-secondary cursor-pointer transition-colors"
                >
                  {isUploadingImage ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    <Upload className="w-4 h-4" />
                  )}
                  {isUploadingImage ? "Đang upload..." : "Đổi ảnh"}
                </label>
                <input
                  id="variant-image-upload"
                  type="file"
                  accept="image/*"
                  className="sr-only"
                  disabled={isUploadingImage}
                  onChange={(e) => handleImageUploadEdit(e)}
                />
                <p className="text-xs text-muted-foreground mt-1">JPEG, PNG, WEBP, tối đa 5MB</p>
              </div>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Sản phẩm</label>
              <select
                className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                value={editForm.productId}
                onChange={(e) => setEditForm({ ...editForm, productId: e.target.value })}
              >
                <option value="">-- Chọn sản phẩm --</option>
                {products.map((product) => (
                  <option key={product.productId} value={String(product.productId)}>{product.name}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">SKU</label>
              <Input
                className="h-11"
                value={editForm.sku}
                onChange={(e) => setEditForm({ ...editForm, sku: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Giá</label>
              <Input
                type="number"
                className="h-11"
                value={editForm.price}
                onChange={(e) => setEditForm({ ...editForm, price: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Trạng thái</label>
              <select
                className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                value={editForm.status}
                onChange={(e) => setEditForm({ ...editForm, status: e.target.value })}
              >
                <option value="active">Hoạt động</option>
                <option value="disable">Vô hiệu</option>
                <option value="discontinued">Ngừng bán</option>
              </select>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Mô tả</label>
              <textarea
                className="w-full px-3 py-2 border border-input rounded-md bg-background text-sm min-h-[80px] resize-y"
                value={editForm.description}
                onChange={(e) => setEditForm({ ...editForm, description: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Cấu hình</label>
              <SpecificationsInput
                value={editForm.specifications}
                onChange={(val) => setEditForm({ ...editForm, specifications: val })}
              />
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => { setEditDialogOpen(false); setSelectedItem(null); }} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button onClick={handleUpdateItem} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              Lưu thay đổi
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={viewDialogOpen} onOpenChange={(open) => { setViewDialogOpen(open); if (!open) { setSelectedItem(null); setImagePreview(""); } }}>
        <DialogContent className="max-w-lg">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Thông tin biến thể</DialogTitle>
            <DialogDescription>SKU: <span className="font-medium text-foreground">{selectedItem?.sku}</span></DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            {/* Ảnh biến thể */}
            <div className="flex items-center gap-4">
              {selectedItem?.mainImageUrl ? (
                <img
                  src={selectedItem.mainImageUrl}
                  alt={selectedItem?.sku}
                  className="w-20 h-20 rounded-lg object-cover border border-border"
                />
              ) : (
                <div className="w-20 h-20 rounded-lg bg-muted flex items-center justify-center border border-border">
                  <Image className="w-8 h-8 text-muted-foreground" />
                </div>
              )}
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Sản phẩm</label>
                <div className="px-3 py-2 border border-input rounded-md bg-muted text-sm">
                  {productMap.get(selectedItem?.productId) || "Chưa gán"}
                </div>
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Trạng thái</label>
                <div className="px-3 py-2 border border-input rounded-md bg-muted text-sm">
                  <Badge variant={selectedItem?.status === "active" ? "success" : selectedItem?.status === "discontinued" ? "warning" : "destructive"}>
                    {selectedItem?.status === "active" ? "Hoạt động" : selectedItem?.status === "discontinued" ? "Ngừng bán" : "Đã vô hiệu"}
                  </Badge>
                </div>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Giá</label>
                <div className="px-3 py-2 border border-input rounded-md bg-muted text-sm">
                  {selectedItem?.price?.toLocaleString() ?? "--"}
                </div>
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Giá khuyến mãi</label>
                <div className="px-3 py-2 border border-input rounded-md bg-muted text-sm">
                  {selectedItem?.salePrice != null ? selectedItem.salePrice.toLocaleString() : "--"}
                </div>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Tồn kho</label>
                <div className="px-3 py-2 border border-input rounded-md bg-muted text-sm">
                  {selectedItem?.stockQuantity ?? 0}
                </div>
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Đã bán</label>
                <div className="px-3 py-2 border border-input rounded-md bg-muted text-sm">
                  {selectedItem?.soldQuantity ?? 0}
                </div>
              </div>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Mô tả</label>
              <div className="px-3 py-2 border border-input rounded-md bg-muted text-sm min-h-[60px] whitespace-pre-wrap">
                {selectedItem?.description || "--"}
              </div>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Cấu hình</label>
              {selectedItem?.specifications ? (
                renderSpecificationsView(selectedItem.specifications)
              ) : (
                <div className="px-3 py-2 border border-input rounded-md bg-muted text-sm">--</div>
              )}
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setViewDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Đóng
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={stockDialogOpen} onOpenChange={(open) => { setStockDialogOpen(open); if (!open) { setSelectedItem(null); setStockChange(0); } }}>
        <DialogContent className="max-w-md">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Chỉnh số lượng tồn kho</DialogTitle>
            <DialogDescription>
              SKU: <span className="font-medium text-foreground">{selectedItem?.sku}</span>
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Tồn kho hiện tại</label>
                <div className="px-3 py-2 border border-input rounded-md bg-muted text-sm font-medium text-lg text-center">
                  {selectedItem?.stockQuantity ?? 0}
                </div>
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Đã bán</label>
                <div className="px-3 py-2 border border-input rounded-md bg-muted text-sm font-medium text-lg text-center">
                  {selectedItem?.soldQuantity ?? 0}
                </div>
              </div>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Thay đổi số lượng</label>
              <div className="flex items-center gap-3">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setStockChange(stockChange - 1)}
                  className="h-11 w-11 text-lg"
                >
                  -
                </Button>
                <Input
                  type="number"
                  className="h-11 text-center text-lg font-medium"
                  value={stockChange}
                  onChange={(e) => setStockChange(Number(e.target.value))}
                />
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setStockChange(stockChange + 1)}
                  className="h-11 w-11 text-lg"
                >
                  +
                </Button>
              </div>
              <p className="text-xs text-muted-foreground mt-2">
                Nhập số dương để tăng tồn kho, số âm để giảm tồn kho.
              </p>
            </div>
            <div className="px-3 py-2 border border-input rounded-md bg-muted text-sm text-center">
              Tồn kho sau khi thay đổi: <span className="font-medium text-lg">{Math.max(0, (selectedItem?.stockQuantity ?? 0) + stockChange)}</span>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => { setStockDialogOpen(false); setStockChange(0); }} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button
              onClick={handleUpdateStock}
              disabled={stockChange === 0}
              className="h-11 px-6 text-base font-semibold"
            >
              Xác nhận
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Xác nhận {selectedItem?.status === "active" ? "vô hiệu" : "kích hoạt"} biến thể</DialogTitle>
            <DialogDescription>
              Biến thể SKU <span className="font-medium text-foreground">{selectedItem?.sku}</span> sẽ chuyển sang trạng thái {selectedItem?.status === "active" ? "vô hiệu" : "hoạt động"}.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button variant="destructive" onClick={handleToggleItemStatus} className="h-11 px-6 text-base font-medium">
              Xác nhận
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={discontinueDialogOpen} onOpenChange={setDiscontinueDialogOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Xác nhận ngừng bán biến thể</DialogTitle>
            <DialogDescription>
              Biến thể SKU <span className="font-medium text-foreground">{selectedItem?.sku}</span> sẽ được ngừng bán. Hành động này có thể hoàn tác.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setDiscontinueDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button variant="destructive" onClick={handleDiscontinueItem} className="h-11 px-6 text-base font-medium">
              Ngừng bán
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
