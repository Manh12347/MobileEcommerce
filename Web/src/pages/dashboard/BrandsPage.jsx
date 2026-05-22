import { useEffect, useState } from "react"
import { Search, Plus, Building2, MoreVertical, Edit, Ban, Trash2 } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from "../../components/ui/dropdown-menu"
import { PaginationControls } from "../../components/dashboard/PaginationControls"

const mockBrands = [
  { id: 1, name: "Apple", slug: "apple", logo: "🍎", products: 45, status: "active" },
  { id: 2, name: "Samsung", slug: "samsung", logo: "📱", products: 38, status: "active" },
  { id: 3, name: "Xiaomi", slug: "xiaomi", logo: "📲", products: 52, status: "active" },
  { id: 4, name: "OPPO", slug: "oppo", logo: "📱", products: 28, status: "active" },
  { id: 5, name: "Vivo", slug: "vivo", logo: "📱", products: 22, status: "inactive" },
  { id: 6, name: "Realme", slug: "realme", logo: "📱", products: 31, status: "active" },
]

export function BrandsPage() {
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(5)
  const [brands, setBrands] = useState(mockBrands)
  const [addDialogOpen, setAddDialogOpen] = useState(false)
  const [editDialogOpen, setEditDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [selectedBrand, setSelectedBrand] = useState(null)
  const [editForm, setEditForm] = useState({ name: "", slug: "", logo: "" })

  const filteredBrands = brands
    .filter(brand => {
      const matchesSearch = brand.name.toLowerCase().includes(searchTerm.toLowerCase())
      const matchesStatus = statusFilter === "all" || brand.status === statusFilter
      return matchesSearch && matchesStatus
    })
    .sort((a, b) => {
      if (a.status === "active" && b.status !== "active") return -1
      if (a.status !== "active" && b.status === "active") return 1
      return 0
    })

  useEffect(() => {
    setCurrentPage(1)
  }, [searchTerm, statusFilter, pageSize])

  const pagedBrands = filteredBrands.slice(
    (currentPage - 1) * pageSize,
    currentPage * pageSize
  )

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Thương hiệu</h1>
          <p className="text-muted-foreground">Quản lý thương hiệu sản phẩm</p>
        </div>
        <Button onClick={() => setAddDialogOpen(true)} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
          <Plus className="w-5 h-5 mr-2" />
          Thêm thương hiệu
        </Button>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm kiếm thương hiệu..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-9"
          />
        </div>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="h-11 px-3 rounded-md border border-input bg-background text-sm"
        >
          <option value="all">Tất cả trạng thái</option>
          <option value="active">Hoạt động</option>
          <option value="inactive">Không hoạt động</option>
        </select>
      </div>

      {/* Table */}
      <div className="bg-card rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="text-left">Thương hiệu</TableHead>
              <TableHead className="text-left">Slug</TableHead>
              <TableHead className="text-left">Số sản phẩm</TableHead>
              <TableHead className="text-center">Trạng thái</TableHead>
              <TableHead className="w-12 text-center"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {pagedBrands.map((brand) => (
              <TableRow key={brand.id}>
                <TableCell className="text-left">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center text-xl">
                      {brand.logo}
                    </div>
                    <span className="font-medium text-foreground">{brand.name}</span>
                  </div>
                </TableCell>
                <TableCell className="text-left">
                  <code className="text-sm text-muted-foreground">{brand.slug}</code>
                </TableCell>
                <TableCell className="text-left text-muted-foreground">
                  {brand.products} sản phẩm
                </TableCell>
                <TableCell className="text-center">
                  <Badge variant={brand.status === "active" ? "success" : "destructive"}>
                    {brand.status === "active" ? "Hoạt động" : "Không hoạt động"}
                  </Badge>
                </TableCell>
                <TableCell className="text-center">
                  <DropdownMenu>
                    <DropdownMenuTrigger>
                      <Button variant="ghost" size="icon" className="h-10 w-10 hover:bg-primary/10 hover:text-primary transition-colors">
                        <MoreVertical className="w-5 h-5" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" className="w-48">
                      <DropdownMenuItem
                        className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer"
                        onSelect={() => {
                          setSelectedBrand(brand)
                          setEditForm({ name: brand.name, slug: brand.slug, logo: brand.logo })
                          setEditDialogOpen(true)
                        }}
                      >
                        <Edit className="w-5 h-5 mr-3 text-blue-500" />
                        Sửa thương hiệu
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer text-red-500 hover:bg-red-50"
                        onSelect={() => {
                          setSelectedBrand(brand)
                          setDeleteDialogOpen(true)
                        }}
                      >
                        <Trash2 className="w-5 h-5 mr-3" />
                        Xóa thương hiệu
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
        totalItems={filteredBrands.length}
        pageSize={pageSize}
        currentPage={currentPage}
        onPageChange={setCurrentPage}
        onPageSizeChange={(size) => {
          setPageSize(size)
          setCurrentPage(1)
        }}
      />

      {/* Add Brand Dialog */}
      <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Thêm thương hiệu mới</DialogTitle>
            <DialogDescription>
              Điền thông tin để thêm thương hiệu mới
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Tên thương hiệu</label>
              <Input placeholder="Nhập tên thương hiệu" className="h-11" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Slug</label>
              <Input placeholder="VD: apple" className="font-mono h-11" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Biểu tượng (Emoji)</label>
              <Input placeholder="VD: 🍎" className="h-11" />
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setAddDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button onClick={() => setAddDialogOpen(false)} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              Thêm thương hiệu
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Brand Dialog */}
      <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Chỉnh sửa thương hiệu</DialogTitle>
            <DialogDescription>
              Cập nhật thông tin thương hiệu: <span className="font-medium text-foreground">{selectedBrand?.name}</span>
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Tên thương hiệu</label>
              <Input
                placeholder="Nhập tên thương hiệu"
                className="h-11"
                value={editForm.name}
                onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Slug</label>
              <Input
                placeholder="VD: apple"
                className="font-mono h-11"
                value={editForm.slug}
                onChange={(e) => setEditForm({ ...editForm, slug: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Biểu tượng (Emoji)</label>
              <Input
                placeholder="VD: 🍎"
                className="h-11"
                value={editForm.logo}
                onChange={(e) => setEditForm({ ...editForm, logo: e.target.value })}
              />
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setEditDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button
              onClick={() => {
                setBrands(brands.map(b => b.id === selectedBrand?.id ? { ...b, ...editForm } : b))
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
            <DialogTitle className="text-xl">Xác nhận xóa thương hiệu</DialogTitle>
            <DialogDescription>
              Bạn có chắc chắn muốn xóa thương hiệu <span className="font-medium text-foreground">{selectedBrand?.name}</span>? Hành động này không thể hoàn tác.
            </DialogDescription>
          </DialogHeader>
          <div className="py-4">
            <div className="flex items-center gap-3 p-4 bg-red-50 rounded-lg border border-red-200">
              <div className="w-12 h-12 rounded-lg bg-red-100 flex items-center justify-center text-2xl">
                {selectedBrand?.logo}
              </div>
              <div>
                <p className="font-medium text-foreground">{selectedBrand?.name}</p>
                <p className="text-sm text-muted-foreground">{selectedBrand?.products} sản phẩm</p>
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
                setBrands(brands.filter(b => b.id !== selectedBrand?.id))
                setDeleteDialogOpen(false)
              }}
              className="h-11 px-6 text-base font-medium"
            >
              Xóa thương hiệu
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
