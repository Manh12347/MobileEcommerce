import { useEffect, useMemo, useState } from "react"
import { Search, Plus, MoreVertical, Edit, Trash2 } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from "../../components/ui/dropdown-menu"
import { PaginationControls } from "../../components/dashboard/PaginationControls"
import { ColumnVisibilitySelect } from "../../components/dashboard/ColumnVisibilitySelect"
import { catalogAPI } from "../../api/client"
import { useToast } from "../../hooks/use-toast"

const DEFAULT_FORM = {
  name: "",
  country: "",
  status: "active",
}

const columnOptions = [
  { value: "name", label: "Tên thương hiệu" },
  { value: "country", label: "Quốc gia" },
  { value: "status", label: "Trạng thái" },
  { value: "actions", label: "Thao tác" },
]

export function BrandsPage() {
  const { toast } = useToast()
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(5)
  const [visibleColumns, setVisibleColumns] = useState(["name", "country", "status"])

  const [brands, setBrands] = useState([])
  const [loading, setLoading] = useState(false)

  const [addDialogOpen, setAddDialogOpen] = useState(false)
  const [editDialogOpen, setEditDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)

  const [selectedBrand, setSelectedBrand] = useState(null)
  const [addForm, setAddForm] = useState(DEFAULT_FORM)
  const [editForm, setEditForm] = useState(DEFAULT_FORM)

  const loadBrands = async () => {
    try {
      setLoading(true)
      const response = await catalogAPI.getBrands()
      const list = response?.data?.data || []
      setBrands(list)
    } catch (error) {
      console.error("Load brands error", error)
      window.alert(error?.response?.data?.message || "Không tải được danh sách thương hiệu")
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadBrands()
  }, [])

  useEffect(() => {
    setCurrentPage(1)
  }, [searchTerm, statusFilter, pageSize])

  const filteredBrands = useMemo(() => {
    return brands
      .filter((brand) => {
        const keyword = searchTerm.trim().toLowerCase()
        const matchesSearch =
          !keyword ||
          (brand.name || "").toLowerCase().includes(keyword) ||
          (brand.country || "").toLowerCase().includes(keyword)
        const matchesStatus = statusFilter === "all" || brand.status === statusFilter
        return matchesSearch && matchesStatus
      })
      .sort((a, b) => {
        if (a.status === "active" && b.status !== "active") return -1
        if (a.status !== "active" && b.status === "active") return 1
        return (a.name || "").localeCompare(b.name || "")
      })
  }, [brands, searchTerm, statusFilter])

  const pagedBrands = filteredBrands.slice((currentPage - 1) * pageSize, currentPage * pageSize)

  const handleCreateBrand = async () => {
    if (!addForm.name.trim()) {
      toast({ title: "Lỗi", description: "Tên thương hiệu không được để trống", variant: "destructive" })
      return
    }

    try {
      await catalogAPI.createBrand({
        name: addForm.name.trim(),
        country: addForm.country.trim() || null,
        status: addForm.status,
      })
      setAddDialogOpen(false)
      setAddForm(DEFAULT_FORM)
      await loadBrands()
      toast({ title: "Thành công", description: "Đã thêm thương hiệu mới" })
    } catch (error) {
      console.error("Create brand error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Tạo thương hiệu thất bại", variant: "destructive" })
    }
  }

  const handleUpdateBrand = async () => {
    if (!selectedBrand) return
    if (!editForm.name.trim()) {
      toast({ title: "Lỗi", description: "Tên thương hiệu không được để trống", variant: "destructive" })
      return
    }

    try {
      await catalogAPI.updateBrand(selectedBrand.brandId, {
        name: editForm.name.trim(),
        country: editForm.country.trim() || null,
        status: editForm.status,
      })
      setEditDialogOpen(false)
      setSelectedBrand(null)
      await loadBrands()
      toast({ title: "Thành công", description: "Đã cập nhật thương hiệu" })
    } catch (error) {
      console.error("Update brand error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Cập nhật thương hiệu thất bại", variant: "destructive" })
    }
  }

  const handleToggleBrandStatus = async () => {
    if (!selectedBrand) return

    try {
      await catalogAPI.toggleBrandStatus(selectedBrand.brandId)
      setDeleteDialogOpen(false)
      setSelectedBrand(null)
      await loadBrands()
      toast({ title: "Thành công", description: selectedBrand.status === "active" ? "Đã vô hiệu thương hiệu" : "Đã kích hoạt thương hiệu" })
    } catch (error) {
      console.error("Toggle brand status error", error)
      toast({ title: "Lỗi", description: error?.response?.data?.message || "Cập nhật trạng thái thất bại", variant: "destructive" })
    }
  }

  return (
    <div className="space-y-6">
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

      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm theo tên hoặc quốc gia..."
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
              {visibleColumns.includes("name") && <TableHead className="text-left">Tên thương hiệu</TableHead>}
              {visibleColumns.includes("country") && <TableHead className="text-left">Quốc gia</TableHead>}
              {visibleColumns.includes("status") && <TableHead className="text-left">Trạng thái</TableHead>}
              <TableHead className="w-12"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {pagedBrands.map((brand) => (
              <TableRow key={brand.brandId}>
                {visibleColumns.includes("name") && (
                  <TableCell className="text-left font-medium text-foreground">{brand.name}</TableCell>
                )}
                {visibleColumns.includes("country") && (
                  <TableCell className="text-left text-muted-foreground">{brand.country || "-"}</TableCell>
                )}
                {visibleColumns.includes("status") && (
                  <TableCell className="text-left">
                    <Badge variant={brand.status === "active" ? "success" : "destructive"}>
                      {brand.status === "active" ? "Hoạt động" : "Đã vô hiệu"}
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
                      <DropdownMenuContent align="end" className="w-48">
                        <DropdownMenuItem
                          className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer"
                          onSelect={() => {
                            setSelectedBrand(brand)
                            setEditForm({
                              name: brand.name || "",
                              country: brand.country || "",
                              status: brand.status || "active",
                            })
                            setEditDialogOpen(true)
                          }}
                        >
                          <Edit className="w-5 h-5 mr-3 text-blue-500" />
                          Sửa thương hiệu
                        </DropdownMenuItem>
                        <DropdownMenuItem
                          className={`flex items-center py-3 px-4 text-base rounded-md cursor-pointer ${brand.status === "active" ? "text-red-500 hover:bg-red-50" : "text-green-500 hover:bg-green-50"}`}
                          onSelect={() => {
                            setSelectedBrand(brand)
                            setDeleteDialogOpen(true)
                          }}
                        >
                          <Trash2 className="w-5 h-5 mr-3" />
                          {brand.status === "active" ? "Vô hiệu" : "Kích hoạt"}
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </TableCell>
                )}
              </TableRow>
            ))}
            {!loading && pagedBrands.length === 0 && (
              <TableRow>
                <TableCell colSpan={visibleColumns.length} className="text-center text-muted-foreground py-8">
                  Không có dữ liệu thương hiệu
                </TableCell>
              </TableRow>
            )}
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

      <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Thêm thương hiệu mới</DialogTitle>
            <DialogDescription>Điền thông tin thương hiệu</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Tên thương hiệu</label>
              <Input
                placeholder="Nhập tên thương hiệu"
                className="h-11"
                value={addForm.name}
                onChange={(e) => setAddForm({ ...addForm, name: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Quốc gia</label>
              <Input
                placeholder="VD: USA"
                className="h-11"
                value={addForm.country}
                onChange={(e) => setAddForm({ ...addForm, country: e.target.value })}
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
            <Button onClick={handleCreateBrand} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              Thêm thương hiệu
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Chỉnh sửa thương hiệu</DialogTitle>
            <DialogDescription>
              Cập nhật thông tin cho <span className="font-medium text-foreground">{selectedBrand?.name}</span>
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Tên thương hiệu</label>
              <Input
                className="h-11"
                value={editForm.name}
                onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Quốc gia</label>
              <Input
                className="h-11"
                value={editForm.country}
                onChange={(e) => setEditForm({ ...editForm, country: e.target.value })}
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
            <Button onClick={handleUpdateBrand} className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
              Lưu thay đổi
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent className="max-w-md max-h-[90vh] overflow-y-auto">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Xác nhận {selectedBrand?.status === "active" ? "vô hiệu" : "kích hoạt"} thương hiệu</DialogTitle>
            <DialogDescription>
              Thương hiệu <span className="font-medium text-foreground">{selectedBrand?.name}</span> sẽ chuyển sang trạng thái {selectedBrand?.status === "active" ? "vô hiệu" : "hoạt động"}.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="gap-3 pt-4">
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              Hủy
            </Button>
            <Button variant="destructive" onClick={handleToggleBrandStatus} className="h-11 px-6 text-base font-medium">
              Xác nhận
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
