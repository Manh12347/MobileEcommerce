import { useEffect, useState } from "react"
import { Search, Plus, FolderTree, MoreVertical, Edit, Trash2, ChevronRight, ChevronDown } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from "../../components/ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"
import { PaginationControls } from "../../components/dashboard/PaginationControls"

const mockCategories = [
  { id: 1, name: "Điện thoại", slug: "dien-thoai", icon: "📱", parent: null, products: 156, children: 3, status: "active" },
  { id: 2, name: "Smartphone", slug: "smartphone", icon: "📱", parent: 1, products: 120, children: 0, status: "active" },
  { id: 3, name: "Điện thoại phổ thông", slug: "dien-thoai-pho-thong", icon: "📞", parent: 1, products: 36, children: 0, status: "active" },
  { id: 4, name: "Máy tính bảng", slug: "may-tinh-bang", icon: "📲", parent: null, products: 89, children: 2, status: "active" },
  { id: 5, name: "iPad", slug: "ipad", icon: "📱", parent: 4, products: 45, children: 0, status: "active" },
  { id: 6, name: "Phụ kiện", slug: "phu-kien", icon: "🎧", parent: null, products: 234, children: 5, status: "active" },
  { id: 7, name: "Tai nghe", slug: "tai-nghe", icon: "🎧", parent: 6, products: 78, children: 0, status: "active" },
  { id: 8, name: "Sạc dự phòng", slug: "sac-du-phong", icon: "🔋", parent: 6, products: 56, children: 0, status: "inactive" },
]

export function CategoriesPage() {
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(5)
  const [categories, setCategories] = useState(mockCategories)
  const [addDialogOpen, setAddDialogOpen] = useState(false)
  const [editDialogOpen, setEditDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [selectedCategory, setSelectedCategory] = useState(null)
  const [expandedRows, setExpandedRows] = useState([1, 4, 6])
  const [editForm, setEditForm] = useState({
    name: "",
    slug: "",
    icon: "",
    parent: ""
  })

  const toggleRow = (id) => {
    setExpandedRows(prev =>
      prev.includes(id) ? prev.filter(i => i !== id) : [...prev, id]
    )
  }

  const filteredCategories = categories
    .filter(cat => {
      const matchesSearch = cat.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                            cat.slug.toLowerCase().includes(searchTerm.toLowerCase())
      const matchesStatus = statusFilter === "all" || cat.status === statusFilter
      return matchesSearch && matchesStatus
    })
    .sort((a, b) => {
      if (a.parent === null && b.parent !== null) return -1
      if (a.parent !== null && b.parent === null) return 1
      if (a.status === "active" && b.status !== "active") return -1
      if (a.status !== "active" && b.status === "active") return 1
      return 0
    })

  useEffect(() => {
    setCurrentPage(1)
  }, [searchTerm, statusFilter, pageSize])

  const rootCategories = filteredCategories.filter((cat) => cat.parent === null)
  const pagedRootCategories = rootCategories.slice(
    (currentPage - 1) * pageSize,
    currentPage * pageSize
  )

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Danh mục</h1>
          <p className="text-muted-foreground">Quản lý danh mục sản phẩm</p>
        </div>
        <Button onClick={() => setAddDialogOpen(true)} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
          <Plus className="w-5 h-5 mr-2" />
          Thêm danh mục
        </Button>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm kiếm danh mục..."
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

      {/* Tree View */}
      <div className="bg-card rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="w-12 text-center"></TableHead>
              <TableHead className="text-left">Danh mục</TableHead>
              <TableHead className="text-left">Slug</TableHead>
              <TableHead className="text-left">Số sản phẩm</TableHead>
              <TableHead className="text-left">Danh mục con</TableHead>
              <TableHead className="text-center">Trạng thái</TableHead>
              <TableHead className="w-12 text-center"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {pagedRootCategories.map((cat) => (
              <>
                <TableRow key={cat.id} className="cursor-pointer hover:bg-secondary/30" onClick={() => toggleRow(cat.id)}>
                  <TableCell className="text-center">
                    {cat.children > 0 && (
                      expandedRows.includes(cat.id) ? (
                        <ChevronDown className="w-4 h-4 text-muted-foreground" />
                      ) : (
                        <ChevronRight className="w-4 h-4 text-muted-foreground" />
                      )
                    )}
                  </TableCell>
                  <TableCell className="text-left">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center text-xl">
                        {cat.icon}
                      </div>
                      <span className="font-medium text-foreground">{cat.name}</span>
                    </div>
                  </TableCell>
                  <TableCell className="text-left">
                    <code className="text-sm text-muted-foreground">{cat.slug}</code>
                  </TableCell>
                  <TableCell className="text-left text-muted-foreground">
                    {cat.products} sản phẩm
                  </TableCell>
                  <TableCell className="text-left">
                    <Badge variant="secondary">{cat.children} danh mục con</Badge>
                  </TableCell>
                  <TableCell className="text-center">
                    <Badge variant={cat.status === "active" ? "success" : "destructive"}>
                      {cat.status === "active" ? "Hoạt động" : "Không hoạt động"}
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
                            setSelectedCategory(cat)
                            setEditForm({
                              name: cat.name,
                              slug: cat.slug,
                              icon: cat.icon,
                              parent: cat.parent || ""
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
                            setSelectedCategory(cat)
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
                {expandedRows.includes(cat.id) &&
                  filteredCategories
                    .filter((child) => child.parent === cat.id)
                    .map((child) => (
                      <TableRow key={child.id} className="bg-secondary/20">
                        <TableCell className="text-center"></TableCell>
                        <TableCell className="text-left">
                          <div className="flex items-center gap-3 ml-6">
                            <span className="text-xl">{child.icon}</span>
                            <span className="text-foreground">{child.name}</span>
                          </div>
                        </TableCell>
                        <TableCell className="text-left">
                          <code className="text-sm text-muted-foreground">{child.slug}</code>
                        </TableCell>
                        <TableCell className="text-left text-muted-foreground">
                          {child.products} sản phẩm
                        </TableCell>
                        <TableCell className="text-left"></TableCell>
                        <TableCell className="text-center">
                          <Badge variant={child.status === "active" ? "success" : "destructive"}>
                            {child.status === "active" ? "Hoạt động" : "Không hoạt động"}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-center">
                          <DropdownMenu>
                            <DropdownMenuTrigger>
                              <Button variant="ghost" size="icon" className="h-10 w-10 hover:bg-primary/10 hover:text-primary transition-colors">
                                <MoreVertical className="w-5 h-5" />
                              </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end" className="w-36">
                              <DropdownMenuItem
                                className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer text-red-500 hover:bg-red-50"
                                onSelect={() => {
                                  setSelectedCategory(child)
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
              </>
            ))}
              ))
          </TableBody>
        </Table>
      </div>

      <PaginationControls
        totalItems={rootCategories.length}
        pageSize={pageSize}
        currentPage={currentPage}
        onPageChange={setCurrentPage}
        onPageSizeChange={(size) => {
          setPageSize(size)
          setCurrentPage(1)
        }}
      />

      {/* Add Category Dialog */}
      <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Thêm danh mục mới</DialogTitle>
            <DialogDescription>
              Điền thông tin để thêm danh mục sản phẩm mới
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Tên danh mục</label>
              <Input placeholder="Nhập tên danh mục" className="h-11" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Slug</label>
              <Input placeholder="VD: dien-thoai" className="font-mono h-11" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Danh mục cha</label>
              <select className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm">
                <option value="">Không có (Danh mục gốc)</option>
                <option value="1">Điện thoại</option>
                <option value="4">Máy tính bảng</option>
                <option value="6">Phụ kiện</option>
              </select>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Biểu tượng (Emoji)</label>
              <Input placeholder="VD: 📱" className="h-11" />
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setAddDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button onClick={() => setAddDialogOpen(false)} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              Thêm danh mục
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Category Dialog */}
      <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Chỉnh sửa danh mục</DialogTitle>
            <DialogDescription>
              Cập nhật thông tin danh mục: <span className="font-medium text-foreground">{selectedCategory?.name}</span>
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Tên danh mục</label>
              <Input
                placeholder="Nhập tên danh mục"
                className="h-11"
                value={editForm.name}
                onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Slug</label>
              <Input
                placeholder="VD: dien-thoai"
                className="font-mono h-11"
                value={editForm.slug}
                onChange={(e) => setEditForm({ ...editForm, slug: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Danh mục cha</label>
              <select
                className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                value={editForm.parent}
                onChange={(e) => setEditForm({ ...editForm, parent: e.target.value })}
              >
                <option value="">Không có (Danh mục gốc)</option>
                <option value="1">Điện thoại</option>
                <option value="4">Máy tính bảng</option>
                <option value="6">Phụ kiện</option>
              </select>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Biểu tượng (Emoji)</label>
              <Input
                placeholder="VD: 📱"
                className="h-11"
                value={editForm.icon}
                onChange={(e) => setEditForm({ ...editForm, icon: e.target.value })}
              />
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setEditDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button
              onClick={() => {
                setCategories(categories.map(c => c.id === selectedCategory?.id ? { ...c, ...editForm } : c))
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
            <DialogTitle className="text-xl">Xác nhận xóa danh mục</DialogTitle>
            <DialogDescription>
              Bạn có chắc chắn muốn xóa danh mục <span className="font-medium text-foreground">{selectedCategory?.name}</span>? Hành động này không thể hoàn tác.
            </DialogDescription>
          </DialogHeader>
          <div className="py-4">
            <div className="flex items-center gap-3 p-4 bg-red-50 rounded-lg border border-red-200">
              <div className="w-12 h-12 rounded-lg bg-red-100 flex items-center justify-center text-2xl">
                {selectedCategory?.icon}
              </div>
              <div>
                <p className="font-medium text-foreground">{selectedCategory?.name}</p>
                <p className="text-sm text-muted-foreground">{selectedCategory?.products} sản phẩm</p>
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
                setCategories(categories.filter(c => c.id !== selectedCategory?.id))
                setDeleteDialogOpen(false)
              }}
              className="h-11 px-6 text-base font-medium"
            >
              Xóa danh mục
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
