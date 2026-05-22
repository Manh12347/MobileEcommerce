import { useState } from "react"
import { Search, Plus, FolderTree, MoreVertical, Edit, Trash2 } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from "../../components/ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"

const mockCategories = [
  { id: 1, name: "Điện thoại", slug: "dien-thoai", icon: "📱", products: 156, status: "active" },
  { id: 2, name: "Máy tính bảng", slug: "may-tinh-bang", icon: "📲", products: 89, status: "active" },
  { id: 3, name: "Phụ kiện", slug: "phu-kien", icon: "🎧", products: 234, status: "active" },
  { id: 4, name: "Tai nghe", slug: "tai-nghe", icon: "🎧", products: 78, status: "active" },
  { id: 5, name: "Sạc dự phòng", slug: "sac-du-phong", icon: "🔋", products: 56, status: "inactive" },
  { id: 6, name: "Ốp lưng", slug: "op-lung", icon: "📱", products: 120, status: "active" },
]

export function CategoriesPage() {
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [categories, setCategories] = useState(mockCategories)
  const [addDialogOpen, setAddDialogOpen] = useState(false)
  const [editDialogOpen, setEditDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [selectedCategory, setSelectedCategory] = useState(null)
  const [editForm, setEditForm] = useState({
    name: "",
    slug: "",
    icon: ""
  })

  const filteredCategories = categories
    .filter(cat => {
      const matchesSearch = cat.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                            cat.slug.toLowerCase().includes(searchTerm.toLowerCase())
      const matchesStatus = statusFilter === "all" || cat.status === statusFilter
      return matchesSearch && matchesStatus
    })
    .sort((a, b) => {
      if (a.status === "active" && b.status !== "active") return -1
      if (a.status !== "active" && b.status === "active") return 1
      return 0
    })

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

      {/* Table */}
      <div className="bg-card rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="text-left">Danh mục</TableHead>
              <TableHead className="text-left">Slug</TableHead>
              <TableHead className="text-left">Số sản phẩm</TableHead>
              <TableHead className="text-center">Trạng thái</TableHead>
              <TableHead className="w-12 text-center"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredCategories.map((cat) => (
              <TableRow key={cat.id}>
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
                <TableCell className="text-center">
                  <Badge variant={cat.status === "active" ? "success" : "destructive"}>
                    {cat.status === "active" ? "Hoạt động" : "Không hoạt động"}
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
                        onSelect={() => {
                          setSelectedCategory(cat)
                          setEditForm({
                            name: cat.name,
                            slug: cat.slug,
                            icon: cat.icon
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
            ))}
          </TableBody>
        </Table>
      </div>

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
