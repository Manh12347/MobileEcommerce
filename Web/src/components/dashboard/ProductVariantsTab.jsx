import { useEffect, useMemo, useState } from "react"
import { Search, Plus, MoreVertical, Edit, Trash2, Eye } from "lucide-react"
import { Button } from "../ui/button"
import { Input } from "../ui/input"
import { Badge } from "../ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../ui/table"
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from "../ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../ui/dialog"
import { PaginationControls } from "./PaginationControls"

const formatCurrency = (value) => new Intl.NumberFormat("vi-VN").format(value) + "đ"

const getVariantStatus = (stock) => {
  if (stock === 0) return "outofstock"
  if (stock < 10) return "lowstock"
  return "instock"
}

const getVariantStatusLabel = (stock) => {
  const status = getVariantStatus(stock)
  if (status === "outofstock") return "Hết hàng"
  if (status === "lowstock") return "Sắp hết"
  return "Còn hàng"
}

export function ProductVariantsTab({ products, setProducts }) {
  const [searchTerm, setSearchTerm] = useState("")
  const [productFilter, setProductFilter] = useState("all")
  const [statusFilter, setStatusFilter] = useState("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [dialogOpen, setDialogOpen] = useState(false)
  const [dialogMode, setDialogMode] = useState("add")
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [viewDialogOpen, setViewDialogOpen] = useState(false)
  const [selectedVariant, setSelectedVariant] = useState(null)
  const [selectedProductId, setSelectedProductId] = useState("")
  const [form, setForm] = useState({
    productId: "",
    variant: "",
    price: "",
    originalPrice: "",
    stock: "",
    sold: "",
    rating: "",
  })

  const flattenedVariants = useMemo(
    () =>
      products.flatMap((product) =>
        product.variants.map((variant) => ({
          ...variant,
          productId: product.id,
          productName: product.name,
          productSku: product.sku,
          productImage: product.image,
          brand: product.brand,
          category: product.category,
          productStatus: product.status,
        }))
      ),
    [products]
  )

  const filteredVariants = flattenedVariants.filter((variant) => {
    const matchesSearch =
      variant.productName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      variant.productSku.toLowerCase().includes(searchTerm.toLowerCase()) ||
      variant.variant.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesProduct = productFilter === "all" || String(variant.productId) === productFilter
    const matchesStatus = statusFilter === "all" || getVariantStatus(variant.stock) === statusFilter
    return matchesSearch && matchesProduct && matchesStatus
  })

  useEffect(() => {
    setCurrentPage(1)
  }, [searchTerm, productFilter, statusFilter, pageSize])

  const pagedVariants = filteredVariants.slice(
    (currentPage - 1) * pageSize,
    currentPage * pageSize
  )

  const openAddDialog = () => {
    setDialogMode("add")
    setSelectedVariant(null)
    setSelectedProductId("")
    setForm({
      productId: "",
      variant: "",
      price: "",
      originalPrice: "",
      stock: "",
      sold: "",
      rating: "",
    })
    setDialogOpen(true)
  }

  const openEditDialog = (variant) => {
    setDialogMode("edit")
    setSelectedVariant(variant)
    setSelectedProductId(String(variant.productId))
    setForm({
      productId: String(variant.productId),
      variant: variant.variant,
      price: String(variant.price),
      originalPrice: String(variant.originalPrice ?? variant.price),
      stock: String(variant.stock),
      sold: String(variant.sold),
      rating: String(variant.rating),
    })
    setDialogOpen(true)
  }

  const openViewDialog = (variant) => {
    setSelectedVariant(variant)
    setViewDialogOpen(true)
  }

  const saveVariant = () => {
    const productId = Number(form.productId || selectedProductId)
    const nextVariant = {
      id: selectedVariant?.id ?? Date.now(),
      variant: form.variant,
      price: Number(form.price),
      originalPrice: Number(form.originalPrice),
      stock: Number(form.stock),
      sold: Number(form.sold),
      rating: Number(form.rating),
    }

    setProducts((currentProducts) => {
      if (dialogMode === "add") {
        return currentProducts.map((product) =>
          product.id === productId
            ? { ...product, variants: [...product.variants, nextVariant] }
            : product
        )
      }

      return currentProducts.map((product) => {
        if (product.id !== productId) return product
        return {
          ...product,
          variants: product.variants.map((variant) =>
            variant.id === selectedVariant?.id ? { ...variant, ...nextVariant } : variant
          ),
        }
      })
    })

    setDialogOpen(false)
    setSelectedVariant(null)
  }

  const confirmDelete = () => {
    if (!selectedVariant) return

    setProducts((currentProducts) =>
      currentProducts.map((product) => {
        if (product.id !== selectedVariant.productId) return product
        return {
          ...product,
          variants: product.variants.filter((variant) => variant.id !== selectedVariant.id),
        }
      })
    )

    setDeleteDialogOpen(false)
    setSelectedVariant(null)
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Biến thể</h1>
          <p className="text-muted-foreground">Quản lý CRUD cho các biến thể sản phẩm</p>
        </div>
        <Button onClick={openAddDialog} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
          <Plus className="w-5 h-5 mr-2" />
          Thêm biến thể
        </Button>
      </div>

      <div className="flex flex-col lg:flex-row gap-4">
        <div className="relative flex-1 lg:max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm kiếm biến thể hoặc sản phẩm..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-9"
          />
        </div>
        <select
          value={productFilter}
          onChange={(e) => setProductFilter(e.target.value)}
          className="h-11 px-3 rounded-md border border-input bg-background text-sm"
        >
          <option value="all">Tất cả sản phẩm</option>
          {products.map((product) => (
            <option key={product.id} value={product.id}>
              {product.name}
            </option>
          ))}
        </select>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="h-11 px-3 rounded-md border border-input bg-background text-sm"
        >
          <option value="all">Tất cả trạng thái</option>
          <option value="instock">Còn hàng</option>
          <option value="lowstock">Sắp hết</option>
          <option value="outofstock">Hết hàng</option>
        </select>
      </div>

      <div className="bg-card rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="text-left">Sản phẩm</TableHead>
              <TableHead className="text-left">Biến thể</TableHead>
              <TableHead className="text-left">Giá</TableHead>
              <TableHead className="text-center">Tồn kho</TableHead>
              <TableHead className="text-left">Đã bán</TableHead>
              <TableHead className="text-center">Đánh giá</TableHead>
              <TableHead className="text-center">Trạng thái</TableHead>
              <TableHead className="w-12 text-center"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {pagedVariants.map((variant) => (
              <TableRow key={variant.id}>
                <TableCell className="text-left">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center text-xl">
                      {variant.productImage}
                    </div>
                    <div>
                      <p className="font-medium text-foreground">{variant.productName}</p>
                      <p className="text-xs text-muted-foreground">
                        {variant.brand} • {variant.category}
                      </p>
                    </div>
                  </div>
                </TableCell>
                <TableCell className="text-left">
                  <div className="flex flex-col">
                    <span className="font-medium text-foreground">{variant.variant}</span>
                    <code className="text-xs text-muted-foreground">{variant.productSku}-{variant.id}</code>
                  </div>
                </TableCell>
                <TableCell className="text-left">
                  <div className="flex flex-col">
                    <span className="font-medium text-foreground">{formatCurrency(variant.price)}</span>
                    {variant.originalPrice > variant.price && (
                      <span className="text-xs text-muted-foreground line-through">
                        {formatCurrency(variant.originalPrice)}
                      </span>
                    )}
                  </div>
                </TableCell>
                <TableCell className="text-center">
                  <Badge variant={variant.stock === 0 ? "destructive" : variant.stock < 10 ? "warning" : "success"}>
                    {variant.stock === 0 ? "Hết hàng" : `${variant.stock} cái`}
                  </Badge>
                </TableCell>
                <TableCell className="text-left text-muted-foreground">
                  {variant.sold} đã bán
                </TableCell>
                <TableCell className="text-center text-muted-foreground">
                  {variant.rating}
                </TableCell>
                <TableCell className="text-center">
                  <Badge variant={variant.stock === 0 ? "destructive" : variant.stock < 10 ? "warning" : "success"}>
                    {getVariantStatusLabel(variant.stock)}
                  </Badge>
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
                        onSelect={() => openViewDialog(variant)}
                      >
                        <Eye className="w-5 h-5 mr-3 text-emerald-500" />
                        Xem thông tin
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer"
                        onSelect={() => openEditDialog(variant)}
                      >
                        <Edit className="w-5 h-5 mr-3 text-blue-500" />
                        Chỉnh sửa
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer text-red-500 hover:bg-red-50"
                        onSelect={() => {
                          setSelectedVariant(variant)
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

      <PaginationControls
        totalItems={filteredVariants.length}
        pageSize={pageSize}
        currentPage={currentPage}
        onPageChange={setCurrentPage}
        onPageSizeChange={(size) => {
          setPageSize(size)
          setCurrentPage(1)
        }}
      />

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-2xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">
              {dialogMode === "add" ? "Thêm biến thể mới" : "Chỉnh sửa biến thể"}
            </DialogTitle>
            <DialogDescription>
              {dialogMode === "add"
                ? "Tạo một biến thể mới cho sản phẩm"
                : `Cập nhật biến thể: ${selectedVariant?.variant}`}
            </DialogDescription>
          </DialogHeader>
          <div className="grid grid-cols-2 gap-4 py-4">
            <div className="col-span-2">
              <label className="text-sm font-medium mb-1 block text-left">Sản phẩm</label>
              <select
                className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                value={form.productId}
                disabled={dialogMode === "edit"}
                onChange={(e) => setForm({ ...form, productId: e.target.value })}
              >
                <option value="">Chọn sản phẩm</option>
                {products.map((product) => (
                  <option key={product.id} value={product.id}>
                    {product.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Biến thể</label>
              <Input
                placeholder="VD: 256GB"
                className="h-11"
                value={form.variant}
                onChange={(e) => setForm({ ...form, variant: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Giá bán</label>
              <Input
                type="number"
                placeholder="0"
                className="h-11"
                value={form.price}
                onChange={(e) => setForm({ ...form, price: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Giá gốc</label>
              <Input
                type="number"
                placeholder="0"
                className="h-11"
                value={form.originalPrice}
                onChange={(e) => setForm({ ...form, originalPrice: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Tồn kho</label>
              <Input
                type="number"
                placeholder="0"
                className="h-11"
                value={form.stock}
                onChange={(e) => setForm({ ...form, stock: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Đã bán</label>
              <Input
                type="number"
                placeholder="0"
                className="h-11"
                value={form.sold}
                onChange={(e) => setForm({ ...form, sold: e.target.value })}
              />
            </div>
            <div className="col-span-2">
              <label className="text-sm font-medium mb-1 block text-left">Đánh giá</label>
              <Input
                type="number"
                step="0.1"
                min="0"
                max="5"
                placeholder="4.8"
                className="h-11"
                value={form.rating}
                onChange={(e) => setForm({ ...form, rating: e.target.value })}
              />
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button onClick={saveVariant} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              {dialogMode === "add" ? "Thêm biến thể" : "Lưu thay đổi"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Xác nhận xóa biến thể</DialogTitle>
            <DialogDescription>
              Bạn có chắc chắn muốn xóa biến thể này? Hành động này không thể hoàn tác.
            </DialogDescription>
          </DialogHeader>
          <div className="py-4">
            <div className="flex items-center gap-3 p-4 bg-red-50 rounded-lg border border-red-200">
              <div className="w-12 h-12 rounded-lg bg-red-100 flex items-center justify-center text-2xl">
                {selectedVariant?.productImage}
              </div>
              <div>
                <p className="font-medium text-foreground">{selectedVariant?.productName}</p>
                <p className="text-sm text-muted-foreground">{selectedVariant?.variant}</p>
              </div>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button variant="destructive" onClick={confirmDelete} className="h-11 px-6 text-base font-medium">
              Xóa biến thể
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={viewDialogOpen} onOpenChange={setViewDialogOpen}>
        <DialogContent className="max-w-2xl text-left">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Thông tin biến thể</DialogTitle>
            <DialogDescription>
              Xem chi tiết biến thể đang được chọn
            </DialogDescription>
          </DialogHeader>
          <div className="grid grid-cols-2 gap-4 py-4">
            <div className="col-span-2 flex items-center gap-3 p-4 rounded-lg border border-border bg-secondary/20 text-left">
              <div className="w-12 h-12 rounded-lg bg-secondary flex items-center justify-center text-2xl">
                {selectedVariant?.productImage}
              </div>
              <div>
                <p className="font-semibold text-foreground">{selectedVariant?.productName}</p>
                <p className="text-sm text-muted-foreground">
                  {selectedVariant?.brand} • {selectedVariant?.category}
                </p>
              </div>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Biến thể</label>
              <p className="text-foreground font-medium">{selectedVariant?.variant}</p>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">SKU</label>
              <p className="text-foreground font-medium">{selectedVariant?.productSku}-{selectedVariant?.id}</p>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Giá bán</label>
              <p className="text-foreground font-medium">{selectedVariant ? formatCurrency(selectedVariant.price) : "-"}</p>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Giá gốc</label>
              <p className="text-foreground font-medium">{selectedVariant ? formatCurrency(selectedVariant.originalPrice) : "-"}</p>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Tồn kho</label>
              <p className="text-foreground font-medium">{selectedVariant?.stock ?? "-"}</p>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Đã bán</label>
              <p className="text-foreground font-medium">{selectedVariant?.sold ?? "-"}</p>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Đánh giá</label>
              <p className="text-foreground font-medium">{selectedVariant?.rating ?? "-"}</p>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left text-muted-foreground">Trạng thái</label>
              <Badge variant={selectedVariant ? (selectedVariant.stock === 0 ? "destructive" : selectedVariant.stock < 10 ? "warning" : "success") : "secondary"}>
                {selectedVariant ? getVariantStatusLabel(selectedVariant.stock) : "-"}
              </Badge>
            </div>
          </div>
          <DialogFooter className="pt-4 justify-start">
            <Button onClick={() => setViewDialogOpen(false)} className="h-11 px-6 text-base font-semibold">
              Đóng
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
