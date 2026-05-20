import { useState } from "react"
import { Search, Plus, Building2, MoreVertical, Edit, Trash2, Eye } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "../../components/ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"

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
  const [addDialogOpen, setAddDialogOpen] = useState(false)

  const filteredBrands = mockBrands.filter(brand => {
    const matchesSearch = brand.name.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesStatus = statusFilter === "all" || brand.status === statusFilter
    return matchesSearch && matchesStatus
  })

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Thương hiệu</h1>
          <p className="text-muted-foreground">Quản lý thương hiệu sản phẩm</p>
        </div>
        <Button onClick={() => setAddDialogOpen(true)}>
          <Plus className="w-4 h-4 mr-2" />
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
          className="h-10 px-3 rounded-md border border-input bg-background text-sm"
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
              <TableHead>Thương hiệu</TableHead>
              <TableHead>Slug</TableHead>
              <TableHead>Số sản phẩm</TableHead>
              <TableHead>Trạng thái</TableHead>
              <TableHead className="w-12"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredBrands.map((brand) => (
              <TableRow key={brand.id}>
                <TableCell>
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center text-xl">
                      {brand.logo}
                    </div>
                    <span className="font-medium text-foreground">{brand.name}</span>
                  </div>
                </TableCell>
                <TableCell>
                  <code className="text-sm text-muted-foreground">{brand.slug}</code>
                </TableCell>
                <TableCell className="text-muted-foreground">
                  {brand.products} sản phẩm
                </TableCell>
                <TableCell>
                  <Badge variant={brand.status === "active" ? "success" : "destructive"}>
                    {brand.status === "active" ? "Hoạt động" : "Không hoạt động"}
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
                        Xem sản phẩm
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

      {/* Add Brand Dialog */}
      <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Thêm thương hiệu mới</DialogTitle>
            <DialogDescription>
              Điền thông tin để thêm thương hiệu mới
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block">Tên thương hiệu</label>
              <Input placeholder="Nhập tên thương hiệu" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block">Slug</label>
              <Input placeholder="VD: apple" className="font-mono" />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block">Biểu tượng (Emoji)</label>
              <Input placeholder="VD: 🍎" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAddDialogOpen(false)}>
              Hủy
            </Button>
            <Button onClick={() => setAddDialogOpen(false)}>
              Thêm thương hiệu
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
