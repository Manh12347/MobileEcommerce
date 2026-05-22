import { useState } from "react"
import { Search, Plus, Package, MoreVertical, Edit, Trash2, Star, ChevronRight, ChevronDown } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from "../../components/ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"
import { Tabs, TabsList, TabsTrigger } from "../../components/ui/tabs"

const mockProducts = [
  {
    id: 1, name: "iPhone 15 Pro Max", sku: "IPH15PM", image: "📱", brand: "Apple", category: "Smartphone", status: "active",
    variants: [
      { id: 101, variant: "256GB", price: 32990000, originalPrice: 34990000, stock: 25, sold: 120, rating: 4.8 },
      { id: 102, variant: "512GB", price: 36990000, originalPrice: 38990000, stock: 15, sold: 80, rating: 4.8 },
      { id: 103, variant: "1TB", price: 42990000, originalPrice: 44990000, stock: 5, sold: 34, rating: 4.9 },
    ]
  },
  {
    id: 2, name: "Samsung Galaxy S24 Ultra", sku: "SG24U", image: "📱", brand: "Samsung", category: "Smartphone", status: "active",
    variants: [
      { id: 201, variant: "256GB", price: 28990000, originalPrice: 30990000, stock: 20, sold: 95, rating: 4.7 },
      { id: 202, variant: "512GB", price: 31990000, originalPrice: 33990000, stock: 12, sold: 60, rating: 4.7 },
      { id: 203, variant: "1TB", price: 36990000, originalPrice: 38990000, stock: 6, sold: 34, rating: 4.8 },
    ]
  },
  {
    id: 3, name: "Xiaomi Redmi Note 13 Pro", sku: "XMN13P", image: "📱", brand: "Xiaomi", category: "Smartphone", status: "active",
    variants: [
      { id: 301, variant: "128GB", price: 8990000, originalPrice: 9990000, stock: 60, sold: 300, rating: 4.5 },
      { id: 302, variant: "256GB", price: 10990000, originalPrice: 11990000, stock: 60, sold: 267, rating: 4.5 },
    ]
  },
  {
    id: 4, name: "OPPO Find X7 Pro", sku: "OPFX7P", image: "📱", brand: "OPPO", category: "Smartphone", status: "inactive",
    variants: [
      { id: 401, variant: "256GB", price: 19990000, originalPrice: 21990000, stock: 0, sold: 45, rating: 4.6 },
      { id: 402, variant: "512GB", price: 22990000, originalPrice: 24990000, stock: 0, sold: 44, rating: 4.6 },
    ]
  },
  {
    id: 5, name: "iPad Pro M4 11 inch", sku: "IPDP11M4", image: "📲", brand: "Apple", category: "iPad", status: "active",
    variants: [
      { id: 501, variant: "256GB WiFi", price: 26990000, originalPrice: 27990000, stock: 15, sold: 80, rating: 4.9 },
      { id: 502, variant: "512GB WiFi", price: 30990000, originalPrice: 31990000, stock: 8, sold: 50, rating: 4.9 },
      { id: 503, variant: "256GB 5G", price: 31990000, originalPrice: 32990000, stock: 2, sold: 26, rating: 4.8 },
    ]
  },
  {
    id: 6, name: "AirPods Pro 2", sku: "APP2", image: "🎧", brand: "Apple", category: "Tai nghe", status: "active",
    variants: [
      { id: 601, variant: "USB-C", price: 5490000, originalPrice: 5990000, stock: 50, sold: 250, rating: 4.8 },
      { id: 602, variant: "MagSafe", price: 5790000, originalPrice: 6290000, stock: 39, sold: 182, rating: 4.7 },
    ]
  },
]

const formatCurrency = (value) => {
  return new Intl.NumberFormat('vi-VN').format(value) + 'đ'
}

export function ProductsPage() {
  const [searchTerm, setSearchTerm] = useState("")
  const [statusTab, setStatusTab] = useState("all")
  const [products, setProducts] = useState(mockProducts)
  const [addDialogOpen, setAddDialogOpen] = useState(false)
  const [editDialogOpen, setEditDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [selectedProduct, setSelectedProduct] = useState(null)
  const [selectedVariant, setSelectedVariant] = useState(null)
  const [expandedRows, setExpandedRows] = useState([1, 2, 5])
  const [editForm, setEditForm] = useState({
    name: "",
    sku: "",
    brand: "",
    category: "",
    status: "active"
  })

  const toggleRow = (id) => {
    setExpandedRows(prev =>
      prev.includes(id) ? prev.filter(i => i !== id) : [...prev, id]
    )
  }

  const filteredProducts = products
    .filter(product => {
      const matchesSearch = product.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                            product.sku.toLowerCase().includes(searchTerm.toLowerCase())
      const matchesStatus = statusTab === "all" ||
                            (statusTab === "active" && product.status === "active") ||
                            (statusTab === "inactive" && product.status === "inactive")
      return matchesSearch && matchesStatus
    })
    .sort((a, b) => {
      if (a.status === "active" && b.status !== "active") return -1
      if (a.status !== "active" && b.status === "active") return 1
      return 0
    })

  const renderStars = (rating) => {
    return (
      <div className="flex items-center gap-0.5">
        {[1, 2, 3, 4, 5].map((star) => (
          <Star
            key={star}
            className={`w-3 h-3 ${star <= rating ? "fill-yellow-400 text-yellow-400" : "text-muted-foreground/30"}`}
          />
        ))}
        <span className="ml-1 text-xs text-muted-foreground">{rating}</span>
      </div>
    )
  }

  const totalStock = (product) => product.variants.reduce((sum, v) => sum + v.stock, 0)
  const totalSold = (product) => product.variants.reduce((sum, v) => sum + v.sold, 0)
  const avgRating = (product) => {
    const sum = product.variants.reduce((s, v) => s + v.rating, 0)
    return (sum / product.variants.length).toFixed(1)
  }

  const handleDeleteVariant = (product, variant) => {
    setSelectedProduct(product)
    setSelectedVariant(variant)
    setDeleteDialogOpen(true)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Sản phẩm</h1>
          <p className="text-muted-foreground">Quản lý danh sách sản phẩm</p>
        </div>
        <Button onClick={() => setAddDialogOpen(true)} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
          <Plus className="w-5 h-5 mr-2" />
          Thêm sản phẩm
        </Button>
      </div>

      {/* Tabs & Search */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <Tabs value={statusTab} onValueChange={setStatusTab}>
          <TabsList>
            <TabsTrigger value="all">Tất cả</TabsTrigger>
            <TabsTrigger value="active">Đang bán</TabsTrigger>
            <TabsTrigger value="inactive">Ngừng bán</TabsTrigger>
          </TabsList>
        </Tabs>
        <div className="relative w-full sm:w-72">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm kiếm sản phẩm..."
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
              <TableHead className="w-12 text-center"></TableHead>
              <TableHead className="text-left">Sản phẩm</TableHead>
              <TableHead className="text-left">SKU</TableHead>
              <TableHead className="text-left">Giá</TableHead>
              <TableHead className="text-center">Tồn kho</TableHead>
              <TableHead className="text-left">Đã bán</TableHead>
              <TableHead className="text-center">Trạng thái</TableHead>
              <TableHead className="w-12 text-center"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredProducts.map((product) => (
              <>
                {/* Product Row (Parent) */}
                <TableRow
                  key={product.id}
                  className="cursor-pointer hover:bg-secondary/30"
                  onClick={() => toggleRow(product.id)}
                >
                  <TableCell className="text-center">
                    <button className="p-1 hover:bg-secondary rounded">
                      {expandedRows.includes(product.id) ? (
                        <ChevronDown className="w-4 h-4 text-muted-foreground" />
                      ) : (
                        <ChevronRight className="w-4 h-4 text-muted-foreground" />
                      )}
                    </button>
                  </TableCell>
                  <TableCell className="text-left">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center text-xl">
                        {product.image}
                      </div>
                      <div>
                        <div className="flex items-center gap-2">
                          <span className="font-semibold text-foreground">{product.name}</span>
                          {renderStars(parseFloat(avgRating(product)))}
                        </div>
                        <span className="text-xs text-muted-foreground">
                          {product.brand} • {product.category}
                        </span>
                      </div>
                    </div>
                  </TableCell>
                  <TableCell className="text-left">
                    <code className="text-sm text-muted-foreground">{product.sku}</code>
                  </TableCell>
                  <TableCell className="text-left">
                    <span className="text-muted-foreground">-</span>
                  </TableCell>
                  <TableCell className="text-center">
                    <Badge variant={totalStock(product) === 0 ? "destructive" : totalStock(product) < 20 ? "warning" : "success"}>
                      {totalStock(product)} cái
                    </Badge>
                  </TableCell>
                  <TableCell className="text-left text-muted-foreground">
                    {totalSold(product)} đã bán
                  </TableCell>
                  <TableCell className="text-center">
                    <Badge variant={product.status === "active" ? "success" : "destructive"}>
                      {product.status === "active" ? "Đang bán" : "Ngừng bán"}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-center" onClick={(e) => e.stopPropagation()}>
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
                            setSelectedProduct(product)
                            setEditForm({
                              name: product.name,
                              sku: product.sku,
                              brand: product.brand,
                              category: product.category,
                              status: product.status
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
                            setSelectedProduct(product)
                            setSelectedVariant(null)
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

                {/* Variant Rows */}
                {expandedRows.includes(product.id) &&
                  product.variants.map((variant) => {
                    const variantStatus = variant.stock === 0 ? "outofstock" : variant.stock < 10 ? "lowstock" : "instock";
                    return (
                      <TableRow key={variant.id} className="bg-secondary/10">
                        <TableCell className="text-center">
                          <span className="w-6"></span>
                        </TableCell>
                        <TableCell className="text-left">
                          <div className="flex items-center gap-3 ml-6">
                            <div className="w-8 h-8 rounded bg-secondary/50 flex items-center justify-center text-sm font-medium">
                              {product.sku.split('-')[0].slice(0, 6)}
                            </div>
                            <span className="text-foreground">{product.name} {variant.variant}</span>
                          </div>
                        </TableCell>
                        <TableCell className="text-left">
                          <code className="text-sm text-muted-foreground">{product.sku}-{variant.id}</code>
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
                        <TableCell className="text-center">
                          <Badge variant={variantStatus === "outofstock" ? "destructive" : variantStatus === "lowstock" ? "warning" : "success"}>
                            {variantStatus === "outofstock" ? "Hết hàng" : variantStatus === "lowstock" ? "Sắp hết" : "Còn hàng"}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-center">
                          <DropdownMenu>
                            <DropdownMenuTrigger>
                              <Button variant="ghost" size="icon" className="h-8 w-8 hover:bg-primary/10 hover:text-primary transition-colors">
                                <MoreVertical className="w-4 h-4" />
                              </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end" className="w-36">
                              <DropdownMenuItem
                                className="flex items-center py-2 px-3 text-sm rounded-md cursor-pointer text-red-500 hover:bg-red-50"
                                onSelect={() => handleDeleteVariant(product, variant)}
                              >
                                <Trash2 className="w-4 h-4 mr-2" />
                                Xóa
                              </DropdownMenuItem>
                            </DropdownMenuContent>
                          </DropdownMenu>
                        </TableCell>
                      </TableRow>
                    );
                  })
                }
              </>
            ))}
          </TableBody>
        </Table>
      </div>

      {/* Add Product Dialog */}
      <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
        <DialogContent className="max-w-2xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Thêm sản phẩm mới</DialogTitle>
            <DialogDescription>
              Điền thông tin để thêm sản phẩm mới vào cửa hàng
            </DialogDescription>
          </DialogHeader>
          <div className="grid grid-cols-2 gap-4 py-4">
            <div className="col-span-2">
              <label className="text-sm font-medium mb-1 block text-left">Tên sản phẩm</label>
              <Input placeholder="Nhập tên sản phẩm" className="h-11" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">SKU</label>
              <Input placeholder="Mã sản phẩm" className="font-mono h-11" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Thương hiệu</label>
              <select className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm">
                <option value="">Chọn thương hiệu</option>
                <option value="apple">Apple</option>
                <option value="samsung">Samsung</option>
                <option value="xiaomi">Xiaomi</option>
                <option value="oppo">OPPO</option>
              </select>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Danh mục</label>
              <select className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm">
                <option value="">Chọn danh mục</option>
                <option value="smartphone">Smartphone</option>
                <option value="ipad">iPad</option>
                <option value="accessory">Phụ kiện</option>
              </select>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setAddDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button onClick={() => setAddDialogOpen(false)} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              Thêm sản phẩm
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Product Dialog */}
      <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
        <DialogContent className="max-w-2xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Chỉnh sửa sản phẩm</DialogTitle>
            <DialogDescription>
              Cập nhật thông tin sản phẩm: <span className="font-medium text-foreground">{selectedProduct?.name}</span>
            </DialogDescription>
          </DialogHeader>
          <div className="grid grid-cols-2 gap-4 py-4">
            <div className="col-span-2">
              <label className="text-sm font-medium mb-1 block text-left">Tên sản phẩm</label>
              <Input
                placeholder="Nhập tên sản phẩm"
                className="h-11"
                value={editForm.name}
                onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">SKU</label>
              <Input
                placeholder="Mã sản phẩm"
                className="font-mono h-11"
                value={editForm.sku}
                onChange={(e) => setEditForm({ ...editForm, sku: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Thương hiệu</label>
              <select
                className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                value={editForm.brand}
                onChange={(e) => setEditForm({ ...editForm, brand: e.target.value })}
              >
                <option value="">Chọn thương hiệu</option>
                <option value="Apple">Apple</option>
                <option value="Samsung">Samsung</option>
                <option value="Xiaomi">Xiaomi</option>
                <option value="OPPO">OPPO</option>
              </select>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Danh mục</label>
              <select
                className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                value={editForm.category}
                onChange={(e) => setEditForm({ ...editForm, category: e.target.value })}
              >
                <option value="">Chọn danh mục</option>
                <option value="Smartphone">Smartphone</option>
                <option value="iPad">iPad</option>
                <option value="Tai nghe">Tai nghe</option>
              </select>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setEditDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button
              onClick={() => {
                setProducts(products.map(p => p.id === selectedProduct?.id ? { ...p, ...editForm } : p))
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
            <DialogTitle className="text-xl">Xác nhận xóa</DialogTitle>
            <DialogDescription>
              Bạn có chắc chắn muốn xóa {selectedVariant ? "biến thể" : "sản phẩm"} này? Hành động này không thể hoàn tác.
            </DialogDescription>
          </DialogHeader>
          <div className="py-4">
            <div className="flex items-center gap-3 p-4 bg-red-50 rounded-lg border border-red-200">
              <div className="w-12 h-12 rounded-lg bg-red-100 flex items-center justify-center text-2xl">
                {selectedProduct?.image}
              </div>
              <div>
                <p className="font-medium text-foreground">{selectedProduct?.name}</p>
                {selectedVariant && (
                  <p className="text-sm text-muted-foreground">{selectedVariant.variant}</p>
                )}
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
                if (selectedVariant) {
                  setProducts(products.map(p => {
                    if (p.id === selectedProduct?.id) {
                      return { ...p, variants: p.variants.filter(v => v.id !== selectedVariant.id) }
                    }
                    return p
                  }))
                } else {
                  setProducts(products.filter(p => p.id !== selectedProduct?.id))
                }
                setDeleteDialogOpen(false)
                setSelectedVariant(null)
              }}
              className="h-11 px-6 text-base font-medium"
            >
              Xóa {selectedVariant ? "biến thể" : "sản phẩm"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
