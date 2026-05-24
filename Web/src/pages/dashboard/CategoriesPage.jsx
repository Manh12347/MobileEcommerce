import { useEffect, useMemo, useState } from "react"
import { Search, Plus, MoreVertical, Edit, Trash2 } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from "../../components/ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"
import { PaginationControls } from "../../components/dashboard/PaginationControls"
import { ColumnVisibilitySelect } from "../../components/dashboard/ColumnVisibilitySelect"
import { catalogAPI } from "../../api/client"
import { useToast } from "../../hooks/use-toast"

const DEFAULT_FORM = {
  name: "",
  status: "active",
}

const columnOptions = [
  { value: "name", label: "Tên danh mục" },
  { value: "status", label: "Trạng thái" },
  { value: "actions", label: "Thao tác" },
]

export function CategoriesPage() {
  const { toast } = useToast()
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(5)
  const [visibleColumns, setVisibleColumns] = useState(["name", "status"])

  const [categories, setCategories] = useState([])
  const [loading, setLoading] = useState(false)

  const [addDialogOpen, setAddDialogOpen] = useState(false)
  const [editDialogOpen, setEditDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)

  const [selectedCategory, setSelectedCategory] = useState(null)
  const [addForm, setAddForm] = useState(DEFAULT_FORM)
  const [editForm, setEditForm] = useState(DEFAULT_FORM)

  const loadCategories = async () => {
    try {
      setLoading(true)
      const response = await catalogAPI.getCategories()
      const list = response?.data?.data || []
      setCategories(list)
    } catch (error) {
      console.error("Load categories error", error)
      window.alert(error?.response?.data?.message || "Không tải được danh mục")
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadCategories()
  }, [])

  useEffect(() => {
    setCurrentPage(1)
  }, [searchTerm, statusFilter, pageSize])

  const filteredCategories = useMemo(() => {
    return categories
      .filter((category) => {
        const keyword = searchTerm.trim().toLowerCase()
        const matchesSearch = !keyword || (category.name || "").toLowerCase().includes(keyword)
        const matchesStatus = statusFilter === "all" || category.status === statusFilter
        return matchesSearch && matchesStatus
      })
      .sort((a, b) => {
        if (a.status === "active" && b.status !== "active") return -1
        if (a.status !== "active" && b.status === "active") return 1
        return (a.name || "").localeCompare(b.name || "")
      })
  }, [categories, searchTerm, statusFilter])

  const pagedCategories = filteredCategories.slice((currentPage - 1) * pageSize, currentPage * pageSize)

  const handleCreateCategory = async () => {
    if (!addForm.name.trim()) {
      toast({ title: "Lỗi", description: "Tên danh mục không được để trống", variant: "destructive" })
      return
    }

    try {
      await catalogAPI.createCategory({
        name: addForm.name.trim(),
        status: addForm.status,
      })
      setAddDialogOpen(false)
      setAddForm(DEFAULT_FORM)
      await loadCategories()
      toast({ title: "Thành công", description: "Đã thêm danh mục mới" })
    } catch (error) {
      console.error("Create category error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Tạo danh mục thất bại", variant: "destructive" })
    }
  }

  const handleUpdateCategory = async () => {
    if (!selectedCategory) return
    if (!editForm.name.trim()) {
      toast({ title: "Lỗi", description: "Tên danh mục không được để trống", variant: "destructive" })
      return
    }

    try {
      await catalogAPI.updateCategory(selectedCategory.categoryId, {
        name: editForm.name.trim(),
        status: editForm.status,
      })
      setEditDialogOpen(false)
      setSelectedCategory(null)
      await loadCategories()
      toast({ title: "Thành công", description: "Đã cập nhật danh mục" })
    } catch (error) {
      console.error("Update category error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Cập nhật danh mục thất bại", variant: "destructive" })
    }
  }

  const handleToggleCategoryStatus = async () => {
    if (!selectedCategory) return

    try {
      await catalogAPI.toggleCategoryStatus(selectedCategory.categoryId)
      setDeleteDialogOpen(false)
      setSelectedCategory(null)
      await loadCategories()
      toast({ title: "Thành công", description: selectedCategory.status === "active" ? "Đã vô hiệu danh mục" : "Đã kích hoạt danh mục" })
    } catch (error) {
      console.error("Toggle category status error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Cập nhật trạng thái thất bại", variant: "destructive" })
    }
  }

  return (
    <div className="space-y-6">
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

      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm danh mục..."
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
          <option value="disable">Đã vô hiệu</option>
        </select>
        <ColumnVisibilitySelect
          options={columnOptions}
          value={visibleColumns}
          onChange={setVisibleColumns}
        />
      </div>

      <div className="bg-card rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              {visibleColumns.includes("name") && <TableHead className="text-left">Tên danh mục</TableHead>}
              {visibleColumns.includes("status") && <TableHead className="text-left">Trạng thái</TableHead>}
              <TableHead className="w-12"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {pagedCategories.map((category) => (
              <TableRow key={category.categoryId}>
                {visibleColumns.includes("name") && (
                  <TableCell className="text-left font-medium text-foreground">{category.name}</TableCell>
                )}
                {visibleColumns.includes("status") && (
                  <TableCell className="text-left">
                    <Badge variant={category.status === "active" ? "success" : "destructive"}>
                      {category.status === "active" ? "Hoạt động" : "Đã vô hiệu"}
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
                            setSelectedCategory(category)
                            setEditForm({
                              name: category.name || "",
                              status: category.status || "active",
                            })
                            setEditDialogOpen(true)
                          }}
                        >
                          <Edit className="w-5 h-5 mr-3 text-blue-500" />
                          Chỉnh sửa
                        </DropdownMenuItem>
                        <DropdownMenuItem
                          className={`flex items-center py-3 px-4 text-base rounded-md cursor-pointer ${category.status === "active" ? "text-red-500 hover:bg-red-50" : "text-green-500 hover:bg-green-50"}`}
                          onSelect={() => {
                            setSelectedCategory(category)
                            setDeleteDialogOpen(true)
                          }}
                        >
                          <Trash2 className="w-5 h-5 mr-3" />
                          {category.status === "active" ? "Vô hiệu" : "Kích hoạt"}
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </TableCell>
                )}
              </TableRow>
            ))}
            {!loading && pagedCategories.length === 0 && (
              <TableRow>
                <TableCell colSpan={visibleColumns.length} className="text-center text-muted-foreground py-8">
                  Không có dữ liệu danh mục
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      <PaginationControls
        totalItems={filteredCategories.length}
        pageSize={pageSize}
        currentPage={currentPage}
        onPageChange={setCurrentPage}
        onPageSizeChange={(size) => {
          setPageSize(size)
          setCurrentPage(1)
        }}
      />

      <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Thêm danh mục mới</DialogTitle>
            <DialogDescription>Điền thông tin danh mục</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Tên danh mục</label>
              <Input
                placeholder="Nhập tên danh mục"
                className="h-11"
                value={addForm.name}
                onChange={(e) => setAddForm({ ...addForm, name: e.target.value })}
              />
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
            <Button onClick={handleCreateCategory} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              Thêm danh mục
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Chỉnh sửa danh mục</DialogTitle>
            <DialogDescription>
              Cập nhật thông tin cho <span className="font-medium text-foreground">{selectedCategory?.name}</span>
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Tên danh mục</label>
              <Input
                className="h-11"
                value={editForm.name}
                onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
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
              </select>
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setEditDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button onClick={handleUpdateCategory} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              Lưu thay đổi
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent className="max-w-md max-h-[90vh] overflow-y-auto">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Xác nhận {selectedCategory?.status === "active" ? "vô hiệu" : "kích hoạt"} danh mục</DialogTitle>
            <DialogDescription>
              Danh mục <span className="font-medium text-foreground">{selectedCategory?.name}</span> sẽ chuyển sang trạng thái {selectedCategory?.status === "active" ? "vô hiệu" : "hoạt động"}.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button variant="destructive" onClick={handleToggleCategoryStatus} className="h-11 px-6 text-base font-medium">
              Xác nhận
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
