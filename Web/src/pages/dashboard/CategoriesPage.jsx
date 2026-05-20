import { useState } from "react"
import { Search, Plus, FolderTree, MoreVertical, Edit, Trash2, ChevronRight, ChevronDown } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "../../components/ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"

const mockCategories = [
  { id: 1, name: "Điện thoại", slug: "dien-thoai", icon: "📱", parent: null, products: 156, children: 3, status: "active" },
  { id: 2, name: "  - Smartphone", slug: "smartphone", icon: "📱", parent: 1, products: 120, children: 0, status: "active" },
  { id: 3, name: "  - Điện thoại phổ thông", slug: "dien-thoai-pho-thong", icon: "📞", parent: 1, products: 36, children: 0, status: "active" },
  { id: 4, name: "Máy tính bảng", slug: "may-tinh-bang", icon: "📲", parent: null, products: 89, children: 2, status: "active" },
  { id: 5, name: "  - iPad", slug: "ipad", icon: "📱", parent: 4, products: 45, children: 0, status: "active" },
  { id: 6, name: "Phụ kiện", slug: "phu-kien", icon: "🎧", parent: null, products: 234, children: 5, status: "active" },
  { id: 7, name: "  - Tai nghe", slug: "tai-nghe", icon: "🎧", parent: 6, products: 78, children: 0, status: "active" },
  { id: 8, name: "  - Sạc dự phòng", slug: "sac-du-phong", icon: "🔋", parent: 6, products: 56, children: 0, status: "inactive" },
]

export function CategoriesPage() {
  const [searchTerm, setSearchTerm] = useState("")
  const [addDialogOpen, setAddDialogOpen] = useState(false)
  const [expandedRows, setExpandedRows] = useState([1, 4, 6])

  const toggleRow = (id) => {
    setExpandedRows(prev => 
      prev.includes(id) ? prev.filter(i => i !== id) : [...prev, id]
    )
  }

  const filteredCategories = mockCategories.filter(cat => 
    cat.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    cat.slug.toLowerCase().includes(searchTerm.toLowerCase())
  )

  const getIndentation = (cat) => {
    if (cat.parent === null) return ""
    const parent = mockCategories.find(c => c.id === cat.parent)
    if (parent?.parent === null) return "ml-6"
    return "ml-12"
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Danh mục</h1>
          <p className="text-muted-foreground">Quản lý danh mục sản phẩm</p>
        </div>
        <Button onClick={() => setAddDialogOpen(true)}>
          <Plus className="w-4 h-4 mr-2" />
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
      </div>

      {/* Tree View */}
      <div className="bg-card rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="w-12"></TableHead>
              <TableHead>Danh mục</TableHead>
              <TableHead>Slug</TableHead>
              <TableHead>Số sản phẩm</TableHead>
              <TableHead>Danh mục con</TableHead>
              <TableHead>Trạng thái</TableHead>
              <TableHead className="w-12"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredCategories
              .filter(cat => cat.parent === null)
              .map((cat) => (
                <>
                  <TableRow 
                    key={cat.id} 
                    className="cursor-pointer hover:bg-secondary/30"
                    onClick={() => toggleRow(cat.id)}
                  >
                    <TableCell>
                      {cat.children > 0 && (
                        expandedRows.includes(cat.id) ? (
                          <ChevronDown className="w-4 h-4 text-muted-foreground" />
                        ) : (
                          <ChevronRight className="w-4 h-4 text-muted-foreground" />
                        )
                      )}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-3">
                        <span className="text-xl">{cat.icon}</span>
                        <span className="font-medium text-foreground">{cat.name}</span>
                      </div>
                    </TableCell>
                    <TableCell>
                      <code className="text-sm text-muted-foreground">{cat.slug}</code>
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {cat.products} sản phẩm
                    </TableCell>
                    <TableCell>
                      <Badge variant="secondary">{cat.children} danh mục con</Badge>
                    </TableCell>
                    <TableCell>
                      <Badge variant={cat.status === "active" ? "success" : "destructive"}>
                        {cat.status === "active" ? "Hoạt động" : "Không hoạt động"}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon" onClick={(e) => e.stopPropagation()}>
                            <MoreVertical className="w-4 h-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
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
                  {expandedRows.includes(cat.id) && 
                    filteredCategories
                      .filter(child => child.parent === cat.id)
                      .map((child) => (
                        <TableRow key={child.id} className="bg-secondary/20">
                          <TableCell></TableCell>
                          <TableCell>
                            <div className="flex items-center gap-3 ml-6">
                              <span className="text-xl">{child.icon}</span>
                              <span className="text-foreground">{child.name}</span>
                            </div>
                          </TableCell>
                          <TableCell>
                            <code className="text-sm text-muted-foreground">{child.slug}</code>
                          </TableCell>
                          <TableCell className="text-muted-foreground">
                            {child.products} sản phẩm
                          </TableCell>
                          <TableCell></TableCell>
                          <TableCell>
                            <Badge variant={child.status === "active" ? "success" : "destructive"}>
                              {child.status === "active" ? "Hoạt động" : "Không hoạt động"}
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
                      ))
                  }
                </>
              ))}
          </TableBody>
        </Table>
      </div>

      {/* Add Category Dialog */}
      <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Thêm danh mục mới</DialogTitle>
            <DialogDescription>
              Điền thông tin để thêm danh mục sản phẩm mới
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block">Tên danh mục</label>
              <Input placeholder="Nhập tên danh mục" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block">Slug</label>
              <Input placeholder="VD: dien-thoai" className="font-mono" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block">Danh mục cha</label>
              <select className="w-full h-10 px-3 rounded-md border border-input bg-background text-sm">
                <option value="">Không có (Danh mục gốc)</option>
                <option value="1">Điện thoại</option>
                <option value="4">Máy tính bảng</option>
                <option value="6">Phụ kiện</option>
              </select>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block">Biểu tượng (Emoji)</label>
              <Input placeholder="VD: 📱" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAddDialogOpen(false)}>
              Hủy
            </Button>
            <Button onClick={() => setAddDialogOpen(false)}>
              Thêm danh mục
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
