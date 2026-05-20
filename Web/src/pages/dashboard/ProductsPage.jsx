import { useState } from "react"
import { Search, Plus, Package, MoreVertical, Edit, Trash2, Eye, Star } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "../../components/ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"
import { Tabs, TabsList, TabsTrigger, TabsContent } from "../../components/ui/tabs"

const mockProducts = [
  { id: 1, name: "iPhone 15 Pro Max", sku: "IPH15PM256", price: 32990000, originalPrice: 34990000, stock: 45, brand: "Apple", category: "Smartphone", rating: 4.8, sold: 234, status: "active", image: "📱" },
  { id: 2, name: "Samsung Galaxy S24 Ultra", sku: "SG24U512", price: 28990000, originalPrice: 30990000, stock: 38, brand: "Samsung", category: "Smartphone", rating: 4.7, sold: 189, status: "active", image: "📱" },
  { id: 3, name: "Xiaomi Redmi Note 13 Pro", sku: "XMN13P256", price: 8990000, originalPrice: 9990000, stock: 120, brand: "Xiaomi", category: "Smartphone", rating: 4.5, sold: 567, status: "active", image: "📱" },
  { id: 4, name: "OPPO Find X7 Pro", sku: "OPFX7P512", price: 19990000, originalPrice: 21990000, stock: 0, brand: "OPPO", category: "Smartphone", rating: 4.6, sold: 89, status: "inactive", image: "📱" },
  { id: 5, name: "iPad Pro M4 11 inch", sku: "IPDP11M4256", price: 26990000, originalPrice: 27990000, stock: 25, brand: "Apple", category: "iPad", rating: 4.9, sold: 156, status: "active", image: "📲" },
  { id: 6, name: "AirPods Pro 2", sku: "APP2USB", price: 5490000, originalPrice: 5990000, stock: 89, brand: "Apple", category: "Tai nghe", rating: 4.8, sold: 432, status: "active", image: "🎧" },
]

const formatCurrency = (value) => {
  return new Intl.NumberFormat('vi-VN').format(value) + 'đ'
}

export function ProductsPage() {
  const [searchTerm, setSearchTerm] = useState("")
  const [statusTab, setStatusTab] = useState("all")
  const [addDialogOpen, setAddDialogOpen] = useState(false)

  const filteredProducts = mockProducts.filter(product => {
    const matchesSearch = product.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                          product.sku.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesStatus = statusTab === "all" || 
                          (statusTab === "active" && product.status === "active") ||
                          (statusTab === "inactive" && product.status === "inactive") ||
                          (statusTab === "outofstock" && product.stock === 0)
    return matchesSearch && matchesStatus
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

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Sản phẩm</h1>
          <p className="text-muted-foreground">Quản lý danh sách sản phẩm</p>
        </div>
        <Button onClick={() => setAddDialogOpen(true)}>
          <Plus className="w-4 h-4 mr-2" />
          Thêm sản phẩm
        </Button>
      </div>

      {/* Tabs & Search */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <Tabs value={statusTab} onValueChange={setStatusTab}>
          <TabsList>
            <TabsTrigger value="all">Tất cả</TabsTrigger>
            <TabsTrigger value="active">Đang bán</TabsTrigger>
            <TabsTrigger value="outofstock">Hết hàng</TabsTrigger>
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
              <TableHead>Sản phẩm</TableHead>
              <TableHead>SKU</TableHead>
              <TableHead>Giá</TableHead>
              <TableHead>Tồn kho</TableHead>
              <TableHead>Đã bán</TableHead>
              <TableHead>Trạng thái</TableHead>
              <TableHead className="w-12"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredProducts.map((product) => (
              <TableRow key={product.id}>
                <TableCell>
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-lg bg-secondary flex items-center justify-center text-2xl">
                      {product.image}
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-medium text-foreground">{product.name}</span>
                        {renderStars(product.rating)}
                      </div>
                      <span className="text-xs text-muted-foreground">
                        {product.brand} • {product.category}
                      </span>
                    </div>
                  </div>
                </TableCell>
                <TableCell>
                  <code className="text-sm text-muted-foreground">{product.sku}</code>
                </TableCell>
                <TableCell>
                  <div className="flex flex-col">
                    <span className="font-medium text-foreground">{formatCurrency(product.price)}</span>
                    {product.originalPrice > product.price && (
                      <span className="text-xs text-muted-foreground line-through">
                        {formatCurrency(product.originalPrice)}
                      </span>
                    )}
                  </div>
                </TableCell>
                <TableCell>
                  <Badge variant={product.stock === 0 ? "destructive" : product.stock < 20 ? "warning" : "success"}>
                    {product.stock === 0 ? "Hết hàng" : `${product.stock} cái`}
                  </Badge>
                </TableCell>
                <TableCell className="text-muted-foreground">
                  {product.sold} đã bán
                </TableCell>
                <TableCell>
                  <Badge variant={product.status === "active" ? "success" : "destructive"}>
                    {product.status === "active" ? "Đang bán" : "Ngừng bán"}
                  </Badge>
                </TableCell>
                <TableCell>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="ghost" size="icon">
                        <MoreVertical className="w-4 h-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem>
                        <Eye className="w-4 h-4 mr-2" />
                        Xem chi tiết
                      </DropdownMenuItem>
                      <DropdownMenuItem>
                        <Edit className="w-4 h-4 mr-2" />
                        Chỉnh sửa
                      </DropdownMenuItem>
                      <DropdownMenuItem className="text-destructive">
                        <Trash2 className="w-4 h-4 mr-2" />
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

      {/* Add Product Dialog */}
      <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Thêm sản phẩm mới</DialogTitle>
            <DialogDescription>
              Điền thông tin để thêm sản phẩm mới vào cửa hàng
            </DialogDescription>
          </DialogHeader>
          <div className="grid grid-cols-2 gap-4 py-4">
            <div className="col-span-2">
              <label className="text-sm font-medium mb-1 block">Tên sản phẩm</label>
              <Input placeholder="Nhập tên sản phẩm" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block">SKU</label>
              <Input placeholder="Mã sản phẩm" className="font-mono" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block">Thương hiệu</label>
              <select className="w-full h-10 px-3 rounded-md border border-input bg-background text-sm">
                <option value="">Chọn thương hiệu</option>
                <option value="apple">Apple</option>
                <option value="samsung">Samsung</option>
                <option value="xiaomi">Xiaomi</option>
                <option value="oppo">OPPO</option>
              </select>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block">Danh mục</label>
              <select className="w-full h-10 px-3 rounded-md border border-input bg-background text-sm">
                <option value="">Chọn danh mục</option>
                <option value="smartphone">Smartphone</option>
                <option value="ipad">iPad</option>
                <option value="accessory">Phụ kiện</option>
              </select>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block">Giá bán</label>
              <Input type="number" placeholder="0" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block">Giá gốc</label>
              <Input type="number" placeholder="0" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block">Số lượng</label>
              <Input type="number" placeholder="0" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAddDialogOpen(false)}>
              Hủy
            </Button>
            <Button onClick={() => setAddDialogOpen(false)}>
              Thêm sản phẩm
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
