import { useEffect, useMemo, useState, useRef } from "react"
import { Search, Plus, MoreVertical, Eye, Edit, Trash2, Package, AlertTriangle } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from "../../components/ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"
import { PaginationControls } from "../../components/dashboard/PaginationControls"
import { ClampText } from "../../components/dashboard/ClampText"
import { ColumnVisibilitySelect } from "../../components/dashboard/ColumnVisibilitySelect"
import { catalogAPI, productItemAPI } from "../../api/client"
import { useToast } from "../../hooks/use-toast"

const initialForm = {
  name: "",
  brandId: "",
  categoryId: "",
  status: "active",
}

const columnOptions = [
  { value: "name", label: "Tên sản phẩm" },
  { value: "brand", label: "Thương hiệu" },
  { value: "category", label: "Danh mục" },
  { value: "stock", label: "Tồn kho" },
  { value: "sold", label: "Đã bán" },
  { value: "status", label: "Trạng thái" },
  { value: "actions", label: "Thao tác" },
]

export function ProductsPage() {
  const { toast } = useToast()
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(5)

  const [products, setProducts] = useState([])
  const [brands, setBrands] = useState([])
  const [categories, setCategories] = useState([])
  const [variantItems, setVariantItems] = useState([])
  const [loading, setLoading] = useState(false)

  const [addDialogOpen, setAddDialogOpen] = useState(false)
  const [editDialogOpen, setEditDialogOpen] = useState(false)
  const [isViewMode, setIsViewMode] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [discontinueDialogOpen, setDiscontinueDialogOpen] = useState(false)

  const [selectedProduct, setSelectedProduct] = useState(null)
  const [addForm, setAddForm] = useState(initialForm)
  const [editForm, setEditForm] = useState(initialForm)
  const [totalProducts, setTotalProducts] = useState(0)
  const [visibleColumns, setVisibleColumns] = useState(["name", "brand", "category", "stock", "sold", "status"])
  const isLoadingRef = useRef(false)

  const brandMap = useMemo(() => new Map(brands.map(b => [b.brandId, b.name])), [brands])
  const categoryMap = useMemo(() => new Map(categories.map(c => [c.categoryId, c.name])), [categories])

  const variantInfoMap = useMemo(() => {
    const map = new Map()
    variantItems.forEach((item) => {
      const productId = item?.productId ?? item?.product?.productId
      if (!productId) return
      
      const existing = map.get(productId) || { minPrice: null, maxPrice: null, minSalePrice: null, maxSalePrice: null, totalStock: 0, totalSold: 0 }
      
      const price = item.price ?? null
      const salePrice = item.salePrice ?? null
      const stock = item.stock ?? 0
      const sold = item.sold ?? 0
      
      map.set(productId, {
        minPrice: existing.minPrice === null ? price : (price === null ? existing.minPrice : Math.min(existing.minPrice, price)),
        maxPrice: existing.maxPrice === null ? price : (price === null ? existing.maxPrice : Math.max(existing.maxPrice, price)),
        minSalePrice: existing.minSalePrice === null ? salePrice : (salePrice === null ? existing.minSalePrice : Math.min(existing.minSalePrice, salePrice)),
        maxSalePrice: existing.maxSalePrice === null ? salePrice : (salePrice === null ? existing.maxSalePrice : Math.max(existing.maxSalePrice, salePrice)),
        totalStock: existing.totalStock + stock,
        totalSold: existing.totalSold + sold,
      })
    })
    return map
  }, [variantItems])

  const loadData = async (page = 1, size = pageSize) => {
    if (isLoadingRef.current) return
    try {
      isLoadingRef.current = true
      setLoading(true)
      const [productsResponse, itemsResponse, brandsResponse, categoriesResponse] = await Promise.all([
        catalogAPI.getProducts({ page, size }),
        productItemAPI.getAll({ page: 1, size: 1000 }),
        catalogAPI.getBrands(),
        catalogAPI.getCategories(),
      ])
      
      const productsData = productsResponse?.data?.data?.content ?? productsResponse?.data?.data ?? []
      const total = productsResponse?.data?.data?.totalElements ?? productsResponse?.data?.total ?? productsData.length
      
      if (page === 1) {
        setProducts(productsData)
      } else {
        setProducts(prev => [...prev, ...productsData])
      }
      setTotalProducts(total)
      setVariantItems(itemsResponse.data.data?.content ?? itemsResponse.data.data ?? [])
      setBrands(brandsResponse.data.data || [])
      setCategories(categoriesResponse.data.data || [])
    } catch (error) {
      console.error("Load products error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Không tải được sản phẩm", variant: "destructive" })
    } finally {
      setLoading(false)
      isLoadingRef.current = false
    }
  }

  const loadCatalogForDialog = async () => {
    try {
      const [brandsResponse, categoriesResponse] = await Promise.all([
        catalogAPI.getBrands(),
        catalogAPI.getCategories(),
      ])
      setBrands(brandsResponse.data.data || [])
      setCategories(categoriesResponse.data.data || [])
    } catch (error) {
      console.error("Load catalog error", error)
    }
  }

  useEffect(() => {
    loadData(1, pageSize)
  }, [])

  useEffect(() => {
    // Reset currentPage khi search/fillter thay đổi
    if (currentPage !== 1) {
      setCurrentPage(1)
    } else {
      loadData(1, pageSize)
    }
  }, [searchTerm, statusFilter])

  useEffect(() => {
    // Load khi page hoặc pageSize thay đổi
    loadData(currentPage, pageSize)
  }, [currentPage, pageSize])

  const filteredProducts = useMemo(() => {
    return products
      .filter((product) => {
        const keyword = searchTerm.trim().toLowerCase()
        const matchesSearch = !keyword || (product.name || "").toLowerCase().includes(keyword)
        const matchesStatus = statusFilter === "all" || product.status === statusFilter
        return matchesSearch && matchesStatus
      })
      .sort((a, b) => {
        if (a.status === "active" && b.status !== "active") return -1
        if (a.status !== "active" && b.status === "active") return 1
        return (a.name || "").localeCompare(b.name || "")
      })
  }, [products, searchTerm, statusFilter])

  const pagedProducts = filteredProducts.slice((currentPage - 1) * pageSize, currentPage * pageSize)

  const handleCreateProduct = async () => {
    if (!addForm.name.trim()) {
      toast({ title: "Lỗi", description: "Tên sản phẩm không được để trống", variant: "destructive" })
      return
    }

    try {
      await catalogAPI.createProduct({
        name: addForm.name.trim(),
        brandId: addForm.brandId ? Number(addForm.brandId) : null,
        categoryId: addForm.categoryId ? Number(addForm.categoryId) : null,
        status: addForm.status,
      })
      setAddDialogOpen(false)
      setAddForm(initialForm)
      await loadData()
      toast({ title: "Thành công", description: "Đã thêm sản phẩm mới" })
    } catch (error) {
      console.error("Create product error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Tạo sản phẩm thất bại", variant: "destructive" })
    }
  }

  const handleUpdateProduct = async () => {
    if (!selectedProduct) return
    if (!editForm.name.trim()) {
      toast({ title: "Lỗi", description: "Tên sản phẩm không được để trống", variant: "destructive" })
      return
    }

    try {
      await catalogAPI.updateProduct(selectedProduct.productId, {
        name: editForm.name.trim(),
        brandId: editForm.brandId ? Number(editForm.brandId) : null,
        categoryId: editForm.categoryId ? Number(editForm.categoryId) : null,
        status: editForm.status,
      })
      setEditDialogOpen(false)
      setSelectedProduct(null)
      await loadData()
      toast({ title: "Thành công", description: "Đã cập nhật sản phẩm" })
    } catch (error) {
      console.error("Update product error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Cập nhật sản phẩm thất bại", variant: "destructive" })
    }
  }

  const handleToggleProductStatus = async () => {
    if (!selectedProduct) return

    try {
      await catalogAPI.toggleProductStatus(selectedProduct.productId)
      setDeleteDialogOpen(false)
      setSelectedProduct(null)
      await loadData()
      toast({ title: "Thành công", description: selectedProduct.status === "active" ? "Đã vô hiệu sản phẩm" : "Đã kích hoạt sản phẩm" })
    } catch (error) {
      console.error("Toggle product status error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Cập nhật trạng thái thất bại", variant: "destructive" })
    }
  }

  const handleDiscontinueProduct = async () => {
    if (!selectedProduct) return

    try {
      await catalogAPI.discontinueProduct(selectedProduct.productId)
      setDiscontinueDialogOpen(false)
      setSelectedProduct(null)
      await loadData()
      toast({ title: "Thành công", description: "Sản phẩm và các biến thể đã được ngừng bán" })
    } catch (error) {
      console.error("Discontinue product error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Ngừng bán thất bại", variant: "destructive" })
    }
  }

  const openViewDialog = (product) => {
    setSelectedProduct(product)
    setEditForm({
      name: product.name || "",
      brandId: product.brand?.brandId ? String(product.brand.brandId) : "",
      categoryId: product.category?.categoryId ? String(product.category.categoryId) : "",
      status: product.status || "active",
    })
    setIsViewMode(true)
    setEditDialogOpen(true)
  }

  const openEditDialog = (product) => {
    setSelectedProduct(product)
    setEditForm({
      name: product.name || "",
      brandId: product.brand?.brandId ? String(product.brand.brandId) : "",
      categoryId: product.category?.categoryId ? String(product.category.categoryId) : "",
      status: product.status || "active",
    })
    setIsViewMode(false)
    setEditDialogOpen(true)
  }

  const renderPrice = (info) => {
    if (!info || info.minPrice === null) return <span className="text-muted-foreground">--</span>
    
    const hasSale = info.minSalePrice !== null
    if (hasSale) {
      return (
        <div className="flex flex-col items-end">
          <span className="text-muted-foreground line-through text-xs">{info.minPrice?.toLocaleString()}{info.maxPrice !== info.minPrice ? ` - ${info.maxPrice?.toLocaleString()}` : ""}</span>
          <span className="text-red-500 font-medium">{info.minSalePrice?.toLocaleString()}{info.maxSalePrice !== info.minSalePrice ? ` - ${info.maxSalePrice?.toLocaleString()}` : ""}</span>
        </div>
      )
    }
    return <span>{info.minPrice?.toLocaleString()}{info.maxPrice !== info.minPrice ? ` - ${info.maxPrice?.toLocaleString()}` : ""}</span>
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Sản phẩm</h1>
          <p className="text-muted-foreground">Quản lý danh sách sản phẩm và trạng thái hiển thị.</p>
        </div>
        <Button onClick={() => { loadCatalogForDialog(); setAddDialogOpen(true); }} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
          <Plus className="w-5 h-5 mr-2" />
          Thêm sản phẩm
        </Button>
      </div>

      <div className="flex flex-col sm:flex-row flex-wrap gap-4">
        <div className="relative flex-1 min-w-48 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm theo tên sản phẩm..."
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
              {visibleColumns.includes("name") && <TableHead className="text-left">Tên sản phẩm</TableHead>}
              {visibleColumns.includes("brand") && <TableHead className="text-left">Thương hiệu</TableHead>}
              {visibleColumns.includes("category") && <TableHead className="text-left">Danh mục</TableHead>}
              {visibleColumns.includes("stock") && <TableHead className="text-left">Tồn kho</TableHead>}
              {visibleColumns.includes("sold") && <TableHead className="text-left">Đã bán</TableHead>}
              {visibleColumns.includes("status") && <TableHead className="text-left">Trạng thái</TableHead>}
              <TableHead className="w-12"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {pagedProducts.map((product) => (
              <TableRow key={product.productId}>
                {visibleColumns.includes("name") && (
                  <TableCell className="text-left font-medium text-foreground">
                    <ClampText title={product.name}>{product.name}</ClampText>
                  </TableCell>
                )}
                {visibleColumns.includes("brand") && (
                  <TableCell className="text-left text-muted-foreground">
                    <ClampText title={product.brand?.name || brandMap.get(product.brandId) || "--"}>
                      {product.brand?.name || brandMap.get(product.brandId) || "--"}
                    </ClampText>
                  </TableCell>
                )}
                {visibleColumns.includes("category") && (
                  <TableCell className="text-left text-muted-foreground">
                    <ClampText title={product.category?.name || categoryMap.get(product.categoryId) || "--"}>
                      {product.category?.name || categoryMap.get(product.categoryId) || "--"}
                    </ClampText>
                  </TableCell>
                )}
                {visibleColumns.includes("stock") && (
                  <TableCell className="text-left">{variantInfoMap.get(product.productId)?.totalStock ?? 0}</TableCell>
                )}
                {visibleColumns.includes("sold") && (
                  <TableCell className="text-left">{variantInfoMap.get(product.productId)?.totalSold ?? 0}</TableCell>
                )}
                {visibleColumns.includes("status") && (
                  <TableCell className="text-left">
                    <Badge variant={product.status === "active" ? "success" : product.status === "discontinued" ? "warning" : "destructive"}>
                      {product.status === "active" ? "Hoạt động" : product.status === "discontinued" ? "Ngừng bán" : "Đã vô hiệu"}
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
                          onSelect={() => { loadCatalogForDialog(); openViewDialog(product); }}
                        >
                          <Eye className="w-5 h-5 mr-3 text-gray-500" />
                          Xem thông tin
                        </DropdownMenuItem>
                        <DropdownMenuItem
                          className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer"
                          onSelect={() => { loadCatalogForDialog(); openEditDialog(product); }}
                        >
                          <Edit className="w-5 h-5 mr-3 text-blue-500" />
                          Chỉnh sửa
                        </DropdownMenuItem>
                        <DropdownMenuItem
                          className={`flex items-center py-3 px-4 text-base rounded-md cursor-pointer ${product.status === "active" ? "text-red-500 hover:bg-red-50" : "text-green-500 hover:bg-green-50"}`}
                          onSelect={() => {
                            setSelectedProduct(product)
                            setDeleteDialogOpen(true)
                          }}
                        >
                          <Trash2 className="w-5 h-5 mr-3" />
                          {product.status === "active" ? "Vô hiệu" : "Kích hoạt"}
                        </DropdownMenuItem>
                        {product.status === "active" && (
                          <DropdownMenuItem
                            className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer text-amber-500 hover:bg-amber-50"
                            onSelect={() => {
                              setSelectedProduct(product)
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
            {!loading && pagedProducts.length === 0 && (
              <TableRow>
                <TableCell colSpan={visibleColumns.length + 1} className="text-center text-muted-foreground py-8">
                  Không có dữ liệu sản phẩm
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      <PaginationControls
        totalItems={totalProducts}
        pageSize={pageSize}
        currentPage={currentPage}
        onPageChange={setCurrentPage}
        onPageSizeChange={(size) => {
          setPageSize(size)
          setCurrentPage(1)
        }}
      />

      {/* Add Dialog */}
      <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
        <DialogContent className="max-w-xl max-h-[90vh] overflow-y-auto">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Thêm sản phẩm mới</DialogTitle>
            <DialogDescription>Điền thông tin sản phẩm</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Tên sản phẩm</label>
              <Input
                placeholder="Nhập tên sản phẩm"
                className="h-11"
                value={addForm.name}
                onChange={(e) => setAddForm({ ...addForm, name: e.target.value })}
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Thương hiệu</label>
                <select
                  className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                  value={addForm.brandId}
                  onChange={(e) => setAddForm({ ...addForm, brandId: e.target.value })}
                >
                  <option value="">Chọn thương hiệu</option>
                  {brands.map((brand) => (
                    <option key={brand.brandId} value={String(brand.brandId)}>{brand.name}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Danh mục</label>
                <select
                  className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                  value={addForm.categoryId}
                  onChange={(e) => setAddForm({ ...addForm, categoryId: e.target.value })}
                >
                  <option value="">Chọn danh mục</option>
                  {categories.map((category) => (
                    <option key={category.categoryId} value={String(category.categoryId)}>{category.name}</option>
                  ))}
                </select>
              </div>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Trạng thái</label>
              <select
                className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                value={addForm.status}
                onChange={(e) => setAddForm({ ...addForm, status: e.target.value })}
              >
                <option value="active">Hoạt động</option>
                <option value="disable">Vô hiệu</option>
              </select>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setAddDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button onClick={handleCreateProduct} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              Thêm sản phẩm
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit/View Dialog */}
      <Dialog open={editDialogOpen} onOpenChange={(open) => { setEditDialogOpen(open); if (!open) { setIsViewMode(false); setSelectedProduct(null); } }}>
        <DialogContent className="max-w-xl max-h-[90vh] overflow-y-auto">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">{isViewMode ? "Thông tin sản phẩm" : "Chỉnh sửa sản phẩm"}</DialogTitle>
            <DialogDescription>
              {isViewMode ? "Chi tiết của sản phẩm đang được chọn." : <>Cập nhật thông tin cho <span className="font-medium text-foreground">{selectedProduct?.name}</span></>}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Tên sản phẩm</label>
                <Input
                  className="h-11"
                  value={editForm.name}
                  onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                  disabled={isViewMode}
                />
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Trạng thái</label>
                {isViewMode ? (
                  <div className="h-11 px-3 flex items-center border border-input rounded-md bg-muted text-sm">
                    <Badge variant={editForm.status === "active" ? "success" : "destructive"}>
                      {editForm.status === "active" ? "Hoạt động" : "Đã vô hiệu"}
                    </Badge>
                  </div>
                ) : (
                  <select
                    className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                    value={editForm.status}
                    onChange={(e) => setEditForm({ ...editForm, status: e.target.value })}
                  >
                    <option value="active">Hoạt động</option>
                    <option value="disable">Vô hiệu</option>
                  </select>
                )}
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Thương hiệu</label>
                {isViewMode ? (
                  <div className="h-11 px-3 flex items-center border border-input rounded-md bg-muted text-sm">
                    {brands.find(b => b.brandId === Number(editForm.brandId))?.name || "Chưa gán"}
                  </div>
                ) : (
                  <select
                    className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                    value={editForm.brandId}
                    onChange={(e) => setEditForm({ ...editForm, brandId: e.target.value })}
                  >
                    <option value="">Chưa gán</option>
                    {brands.map((brand) => (
                      <option key={brand.brandId} value={String(brand.brandId)}>{brand.name}</option>
                    ))}
                  </select>
                )}
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Danh mục</label>
                {isViewMode ? (
                  <div className="h-11 px-3 flex items-center border border-input rounded-md bg-muted text-sm">
                    {categories.find(c => c.categoryId === Number(editForm.categoryId))?.name || "Chưa gán"}
                  </div>
                ) : (
                  <select
                    className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                    value={editForm.categoryId}
                    onChange={(e) => setEditForm({ ...editForm, categoryId: e.target.value })}
                  >
                    <option value="">Chưa gán</option>
                    {categories.map((category) => (
                      <option key={category.categoryId} value={String(category.categoryId)}>{category.name}</option>
                    ))}
                  </select>
                )}
              </div>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => { setEditDialogOpen(false); setIsViewMode(false); setSelectedProduct(null); }} className="h-11 px-6 text-base font-medium">
              {isViewMode ? "Đóng" : "Hủy"}
            </Button>
            {!isViewMode && (
              <Button onClick={handleUpdateProduct} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
                Lưu thay đổi
              </Button>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Dialog */}
      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Xác nhận {selectedProduct?.status === "active" ? "vô hiệu" : "kích hoạt"} sản phẩm</DialogTitle>
            <DialogDescription>
              Sản phẩm <span className="font-medium text-foreground">{selectedProduct?.name}</span> sẽ chuyển sang trạng thái {selectedProduct?.status === "active" ? "vô hiệu" : "hoạt động"}.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button variant="destructive" onClick={handleToggleProductStatus} className="h-11 px-6 text-base font-medium">
              Xác nhận
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Discontinue Dialog */}
      <Dialog open={discontinueDialogOpen} onOpenChange={setDiscontinueDialogOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Xác nhận ngừng bán sản phẩm</DialogTitle>
            <DialogDescription>
              Sản phẩm <span className="font-medium text-foreground">{selectedProduct?.name}</span> và tất cả biến thể của sản phẩm này sẽ được ngừng bán. Hành động này có thể hoàn tác.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setDiscontinueDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button variant="destructive" onClick={handleDiscontinueProduct} className="h-11 px-6 text-base font-medium">
              Ngừng bán
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
