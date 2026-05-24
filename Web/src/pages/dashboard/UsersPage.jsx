import { useEffect, useMemo, useState } from "react"
import { Search, Plus, MoreVertical, Edit, Trash2, Eye, Users, UserCheck, UserX, Shield, Check, X, EyeOff, Lock } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from "../../components/ui/dropdown-menu"
import { PaginationControls } from "../../components/dashboard/PaginationControls"
import { ColumnVisibilitySelect } from "../../components/dashboard/ColumnVisibilitySelect"
import { usersAPI } from "../../api/client"
import { useToast } from "../../hooks/use-toast"

const DEFAULT_CREATE_FORM = {
  email: "",
  password: "",
  role: "customer",
  fullName: "",
  phone: "",
  address: "",
}

const DEFAULT_UPDATE_FORM = {
  email: "",
  role: "",
  status: "",
  fullName: "",
  phone: "",
  address: "",
  avatarUrl: "",
  newPassword: "",
}

const passwordRequirements = [
  { id: "length", label: "Tối thiểu 8 ký tự", test: (p) => p.length >= 8 },
  { id: "uppercase", label: "Ít nhất 1 chữ hoa (A-Z)", test: (p) => /[A-Z]/.test(p) },
  { id: "lowercase", label: "Ít nhất 1 chữ thường (a-z)", test: (p) => /[a-z]/.test(p) },
  { id: "digit", label: "Ít nhất 1 số (0-9)", test: (p) => /[0-9]/.test(p) },
  { id: "special", label: "Ít nhất 1 ký tự đặc biệt (!@#$%^&*...)", test: (p) => /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(p) },
]

const validatePassword = (password) => {
  return passwordRequirements.map((req) => ({
    ...req,
    passed: req.test(password),
  }))
}

const isPasswordValid = (password) => {
  return passwordRequirements.every((req) => req.test(password))
}

const columnOptions = [
  { value: "email", label: "Email" },
  { value: "fullName", label: "Họ tên" },
  { value: "phone", label: "Số điện thoại" },
  { value: "role", label: "Vai trò" },
  { value: "status", label: "Trạng thái" },
  { value: "createdOn", label: "Ngày tạo" },
  { value: "actions", label: "Thao tác" },
]

const roleLabels = {
  admin: "Quản trị",
  customer: "Khách hàng",
  staff: "Nhân viên",
}

const statusLabels = {
  active: "Hoạt động",
  pending: "Chờ xác nhận",
  locked: "Bị khóa",
  disabled: "Vô hiệu hóa",
}

export function UsersPage() {
  const { toast } = useToast()
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [roleFilter, setRoleFilter] = useState("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [visibleColumns, setVisibleColumns] = useState(["email", "fullName", "phone", "role", "status"])

  const [users, setUsers] = useState([])
  const [totalUsers, setTotalUsers] = useState(0)
  const [loading, setLoading] = useState(false)

  const [createDialogOpen, setCreateDialogOpen] = useState(false)
  const [editDialogOpen, setEditDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [detailDialogOpen, setDetailDialogOpen] = useState(false)

  const [selectedUser, setSelectedUser] = useState(null)
  const [createForm, setCreateForm] = useState(DEFAULT_CREATE_FORM)
  const [editForm, setEditForm] = useState(DEFAULT_UPDATE_FORM)

  const loadUsers = async () => {
    try {
      setLoading(true)
      const response = await usersAPI.getAll({ page: currentPage - 1, size: pageSize })
      const data = response?.data?.data
      if (data) {
        setUsers(data.users || [])
        setTotalUsers(data.total || 0)
      }
    } catch (error) {
      console.error("Load users error", error)
      toast({
        title: "Lỗi",
        description: error?.response?.data?.message || "Không tải được danh sách người dùng",
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadUsers()
  }, [currentPage, pageSize])

  useEffect(() => {
    setCurrentPage(1)
  }, [searchTerm, statusFilter, roleFilter, pageSize])

  const filteredUsers = useMemo(() => {
    return users.filter((user) => {
      const keyword = searchTerm.trim().toLowerCase()
      const matchesSearch =
        !keyword ||
        (user.email || "").toLowerCase().includes(keyword) ||
        (user.fullName || "").toLowerCase().includes(keyword) ||
        (user.phone || "").includes(keyword)
      const matchesStatus = statusFilter === "all" || user.status === statusFilter
      const matchesRole = roleFilter === "all" || user.role === roleFilter
      return matchesSearch && matchesStatus && matchesRole
    })
  }, [users, searchTerm, statusFilter, roleFilter])

  const stats = useMemo(() => {
    const total = totalUsers
    const active = users.filter((u) => u.status === "active").length
    const inactive = users.filter((u) => u.status === "inactive").length
    const admin = users.filter((u) => u.role === "admin").length
    return { total, active, inactive, admin }
  }, [users, totalUsers])

  const handleCreateUser = async () => {
    if (!createForm.email.trim()) {
      toast({ title: "Lỗi", description: "Email không được để trống", variant: "destructive" })
      return
    }
    if (!createForm.password.trim()) {
      toast({ title: "Lỗi", description: "Mật khẩu không được để trống", variant: "destructive" })
      return
    }

    try {
      await usersAPI.create({
        email: createForm.email.trim(),
        password: createForm.password,
        role: createForm.role,
        fullName: createForm.fullName.trim() || null,
        phone: createForm.phone.trim() || null,
        address: createForm.address.trim() || null,
      })
      setCreateDialogOpen(false)
      setCreateForm(DEFAULT_CREATE_FORM)
      await loadUsers()
      toast({ title: "Thành công", description: "Đã tạo người dùng mới" })
    } catch (error) {
      console.error("Create user error", error)
      toast({
        title: "Lỗi",
        description: error?.response?.data?.message || "Tạo người dùng thất bại",
        variant: "destructive",
      })
    }
  }

  const handleUpdateUser = async () => {
    if (!selectedUser) return
    if (!editForm.email.trim()) {
      toast({ title: "Lỗi", description: "Email không được để trống", variant: "destructive" })
      return
    }

    try {
      const updateData = {
        email: editForm.email.trim(),
        role: editForm.role,
        status: editForm.status,
        fullName: editForm.fullName.trim() || null,
        phone: editForm.phone.trim() || null,
        address: editForm.address.trim() || null,
        avatarUrl: editForm.avatarUrl.trim() || null,
      }

      if (editForm.newPassword && isPasswordValid(editForm.newPassword)) {
        updateData.password = editForm.newPassword
      }

      await usersAPI.update(selectedUser.accountId, updateData)
      setEditDialogOpen(false)
      setEditForm(DEFAULT_UPDATE_FORM)
      setSelectedUser(null)
      await loadUsers()
      toast({ title: "Thành công", description: "Đã cập nhật người dùng" })
    } catch (error) {
      console.error("Update user error", error)
      toast({
        title: "Lỗi",
        description: error?.response?.data?.message || "Cập nhật người dùng thất bại",
        variant: "destructive",
      })
    }
  }

  const handleDeleteUser = async () => {
    if (!selectedUser) return

    try {
      await usersAPI.delete(selectedUser.accountId)
      setDeleteDialogOpen(false)
      setSelectedUser(null)
      await loadUsers()
      toast({ title: "Thành công", description: "Đã xóa người dùng" })
    } catch (error) {
      console.error("Delete user error", error)
      toast({
        title: "Lỗi",
        description: error?.response?.data?.message || "Xóa người dùng thất bại",
        variant: "destructive",
      })
    }
  }

  const openEditDialog = (user) => {
    setSelectedUser(user)
    setEditForm({
      email: user.email || "",
      role: user.role || "customer",
      status: user.status || "active",
      fullName: user.fullName || "",
      phone: user.phone || "",
      address: user.address || "",
      avatarUrl: user.avatarUrl || "",
      newPassword: "",
    })
    setEditDialogOpen(true)
  }

  const openDetailDialog = (user) => {
    setSelectedUser(user)
    setDetailDialogOpen(true)
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Người dùng</h1>
          <p className="text-muted-foreground">Quản lý tài khoản và phân quyền người dùng</p>
        </div>
        <Button
          onClick={() => setCreateDialogOpen(true)}
          className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20"
        >
          <Plus className="w-5 h-5 mr-2" />
          Thêm người dùng
        </Button>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Tổng người dùng</p>
              <p className="mt-2 text-2xl font-bold text-foreground">{stats.total}</p>
            </div>
            <div className="rounded-full bg-primary/10 p-3 text-primary">
              <Users className="h-5 w-5" />
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Hoạt động</p>
              <p className="mt-2 text-2xl font-bold text-emerald-500">{stats.active}</p>
            </div>
            <div className="rounded-full bg-emerald-500/10 p-3 text-emerald-500">
              <UserCheck className="h-5 w-5" />
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Không hoạt động</p>
              <p className="mt-2 text-2xl font-bold text-amber-500">{stats.inactive}</p>
            </div>
            <div className="rounded-full bg-amber-500/10 p-3 text-amber-500">
              <UserX className="h-5 w-5" />
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Quản trị viên</p>
              <p className="mt-2 text-2xl font-bold text-violet-500">{stats.admin}</p>
            </div>
            <div className="rounded-full bg-violet-500/10 p-3 text-violet-500">
              <Shield className="h-5 w-5" />
            </div>
          </div>
        </div>
      </div>

      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm theo email, tên hoặc số điện thoại..."
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
          <option value="pending">Chờ xác nhận</option>
          <option value="locked">Bị khóa</option>
          <option value="disabled">Vô hiệu hóa</option>
        </select>
        <select
          value={roleFilter}
          onChange={(e) => setRoleFilter(e.target.value)}
          className="h-11 px-3 rounded-md border border-input bg-background text-sm"
        >
          <option value="all">Tất cả vai trò</option>
          <option value="admin">Quản trị</option>
          <option value="customer">Khách hàng</option>
          <option value="staff">Nhân viên</option>
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
              {visibleColumns.includes("email") && <TableHead className="text-left">Email</TableHead>}
              {visibleColumns.includes("fullName") && <TableHead className="text-left">Họ tên</TableHead>}
              {visibleColumns.includes("phone") && <TableHead className="text-left">Số điện thoại</TableHead>}
              {visibleColumns.includes("role") && <TableHead className="text-left">Vai trò</TableHead>}
              {visibleColumns.includes("status") && <TableHead className="text-left">Trạng thái</TableHead>}
              {visibleColumns.includes("createdOn") && <TableHead className="text-left">Ngày tạo</TableHead>}
              {visibleColumns.includes("actions") && <TableHead className="w-12"></TableHead>}
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={visibleColumns.length} className="text-center text-muted-foreground py-8">
                  Đang tải...
                </TableCell>
              </TableRow>
            ) : filteredUsers.length === 0 ? (
              <TableRow>
                <TableCell colSpan={visibleColumns.length} className="text-center text-muted-foreground py-8">
                  Không có dữ liệu người dùng
                </TableCell>
              </TableRow>
            ) : (
              filteredUsers.map((user) => (
                <TableRow key={user.accountId}>
                  {visibleColumns.includes("email") && (
                    <TableCell className="text-left">
                      <div>
                        <div className="flex items-center gap-1.5">
                          <p className="font-medium text-foreground">{user.email}</p>
                          {user.emailConfirm && (
                            <span title="Đã xác thực" className="text-emerald-500">
                              <Check className="w-4 h-4" />
                            </span>
                          )}
                        </div>
                        {user.address && (
                          <p className="text-xs text-muted-foreground mt-0.5">{user.address}</p>
                        )}
                      </div>
                    </TableCell>
                  )}
                  {visibleColumns.includes("fullName") && (
                    <TableCell className="text-left text-muted-foreground">
                      {user.fullName || "-"}
                    </TableCell>
                  )}
                  {visibleColumns.includes("phone") && (
                    <TableCell className="text-left text-muted-foreground">
                      {user.phone || "-"}
                    </TableCell>
                  )}
                  {visibleColumns.includes("role") && (
                    <TableCell className="text-left">
                      <Badge variant={user.role === "admin" ? "default" : "secondary"}>
                        {roleLabels[user.role] || user.role}
                      </Badge>
                    </TableCell>
                  )}
                  {visibleColumns.includes("status") && (
                    <TableCell className="text-left">
                      <Badge
                        variant={
                          user.status === "active"
                            ? "success"
                            : user.status === "locked" || user.status === "disabled"
                            ? "destructive"
                            : user.status === "pending"
                            ? "warning"
                            : "secondary"
                        }
                      >
                        {statusLabels[user.status] || user.status}
                      </Badge>
                    </TableCell>
                  )}
                  {visibleColumns.includes("createdOn") && (
                    <TableCell className="text-left text-muted-foreground">
                      {user.createdOn ? new Date(user.createdOn).toLocaleDateString("vi-VN") : "-"}
                    </TableCell>
                  )}
                  {visibleColumns.includes("actions") && (
                    <TableCell className="text-center">
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-10 w-10 hover:bg-primary/10 hover:text-primary transition-colors"
                          >
                            <MoreVertical className="w-5 h-5" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end" className="w-48">
                          <DropdownMenuItem
                            className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer"
                            onSelect={() => openDetailDialog(user)}
                          >
                            <Eye className="w-5 h-5 mr-3 text-blue-500" />
                            Xem chi tiết
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer"
                            onSelect={() => openEditDialog(user)}
                          >
                            <Edit className="w-5 h-5 mr-3 text-blue-500" />
                            Chỉnh sửa
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            className="flex items-center py-3 px-4 text-base rounded-md cursor-pointer text-red-500 hover:bg-red-50"
                            onSelect={() => {
                              setSelectedUser(user)
                              setDeleteDialogOpen(true)
                            }}
                          >
                            <Trash2 className="w-5 h-5 mr-3" />
                            Xóa
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  )}
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      <PaginationControls
        totalItems={totalUsers}
        pageSize={pageSize}
        currentPage={currentPage}
        onPageChange={setCurrentPage}
        onPageSizeChange={(size) => {
          setPageSize(size)
          setCurrentPage(1)
        }}
      />

      <Dialog open={createDialogOpen} onOpenChange={setCreateDialogOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Thêm người dùng mới</DialogTitle>
            <DialogDescription>Điền thông tin tài khoản người dùng</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Email *</label>
              <Input
                type="email"
                placeholder="email@example.com"
                className="h-11"
                value={createForm.email}
                onChange={(e) => setCreateForm({ ...createForm, email: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Mật khẩu *</label>
              <div className="relative">
                <Input
                  type="password"
                  placeholder="Nhập mật khẩu"
                  className="h-11 pr-10"
                  value={createForm.password}
                  onChange={(e) => setCreateForm({ ...createForm, password: e.target.value })}
                />
              </div>
              {createForm.password && (
                <div className="mt-2 space-y-1.5">
                  {validatePassword(createForm.password).map((req) => (
                    <div key={req.id} className="flex items-center gap-2 text-xs">
                      <div className={`w-4 h-4 rounded-full flex items-center justify-center ${
                        req.passed ? "bg-emerald-500 text-white" : "bg-muted text-muted-foreground"
                      }`}>
                        {req.passed ? <Check className="w-2.5 h-2.5" /> : <X className="w-2.5 h-2.5" />}
                      </div>
                      <span className={req.passed ? "text-emerald-600" : "text-muted-foreground"}>
                        {req.label}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Vai trò</label>
              <select
                className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                value={createForm.role}
                onChange={(e) => setCreateForm({ ...createForm, role: e.target.value })}
              >
                <option value="customer">Khách hàng</option>
                <option value="staff">Nhân viên</option>
                <option value="admin">Quản trị</option>
              </select>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Họ tên</label>
              <Input
                placeholder="Nguyễn Văn A"
                className="h-11"
                value={createForm.fullName}
                onChange={(e) => setCreateForm({ ...createForm, fullName: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Số điện thoại</label>
              <Input
                placeholder="0901 234 567"
                className="h-11"
                value={createForm.phone}
                onChange={(e) => setCreateForm({ ...createForm, phone: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Địa chỉ</label>
              <Input
                placeholder="123 Đường ABC, Quận 1, TP.HCM"
                className="h-11"
                value={createForm.address}
                onChange={(e) => setCreateForm({ ...createForm, address: e.target.value })}
              />
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button
              variant="outline"
              onClick={() => {
                setCreateDialogOpen(false)
                setCreateForm(DEFAULT_CREATE_FORM)
              }}
              className="h-11 px-6 text-base font-medium"
            >
              Hủy
            </Button>
            <Button
              onClick={handleCreateUser}
              disabled={!isPasswordValid(createForm.password)}
              className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20"
            >
              Tạo người dùng
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Chỉnh sửa người dùng</DialogTitle>
            <DialogDescription>
              Cập nhật thông tin cho <span className="font-medium text-foreground">{selectedUser?.email}</span>
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Email *</label>
              <Input
                type="email"
                className="h-11"
                value={editForm.email}
                onChange={(e) => setEditForm({ ...editForm, email: e.target.value })}
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Vai trò</label>
                <select
                  className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                  value={editForm.role}
                  onChange={(e) => setEditForm({ ...editForm, role: e.target.value })}
                >
                  <option value="customer">Khách hàng</option>
                  <option value="staff">Nhân viên</option>
                  <option value="admin">Quản trị</option>
                </select>
              </div>
              <div>
                <label className="text-sm font-medium mb-1 block text-left">Trạng thái</label>
                <select
                  className="w-full h-11 px-3 rounded-md border border-input bg-background text-sm"
                  value={editForm.status}
                  onChange={(e) => setEditForm({ ...editForm, status: e.target.value })}
                >
                  <option value="active">Hoạt động</option>
                  <option value="pending">Chờ xác nhận</option>
                  <option value="locked">Bị khóa</option>
                  <option value="disabled">Vô hiệu hóa</option>
                </select>
              </div>
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Họ tên</label>
              <Input
                className="h-11"
                value={editForm.fullName}
                onChange={(e) => setEditForm({ ...editForm, fullName: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Số điện thoại</label>
              <Input
                className="h-11"
                value={editForm.phone}
                onChange={(e) => setEditForm({ ...editForm, phone: e.target.value })}
              />
            </div>
            <div>
              <label className="text-sm font-medium mb-1 block text-left">Địa chỉ</label>
              <Input
                className="h-11"
                value={editForm.address}
                onChange={(e) => setEditForm({ ...editForm, address: e.target.value })}
              />
            </div>
            <div className="border-t border-border pt-4">
              <label className="text-sm font-medium mb-1 block text-left flex items-center gap-2">
                <Lock className="w-4 h-4" />
                Đổi mật khẩu (để trống nếu không đổi)
              </label>
              <Input
                type="password"
                placeholder="Nhập mật khẩu mới"
                className="h-11"
                value={editForm.newPassword}
                onChange={(e) => setEditForm({ ...editForm, newPassword: e.target.value })}
              />
              {editForm.newPassword && (
                <div className="mt-2 space-y-1.5">
                  {validatePassword(editForm.newPassword).map((req) => (
                    <div key={req.id} className="flex items-center gap-2 text-xs">
                      <div className={`w-4 h-4 rounded-full flex items-center justify-center ${
                        req.passed ? "bg-emerald-500 text-white" : "bg-muted text-muted-foreground"
                      }`}>
                        {req.passed ? <Check className="w-2.5 h-2.5" /> : <X className="w-2.5 h-2.5" />}
                      </div>
                      <span className={req.passed ? "text-emerald-600" : "text-muted-foreground"}>
                        {req.label}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
          <DialogFooter className="gap-3 pt-4">
            <Button
              variant="outline"
              onClick={() => {
                setEditDialogOpen(false)
                setEditForm(DEFAULT_UPDATE_FORM)
              }}
              className="h-11 px-6 text-base font-medium"
            >
              Hủy
            </Button>
            <Button
              onClick={handleUpdateUser}
              disabled={editForm.newPassword && !isPasswordValid(editForm.newPassword)}
              className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20"
            >
              Lưu thay đổi
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent className="max-w-md max-h-[90vh] overflow-y-auto">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Xác nhận xóa người dùng</DialogTitle>
            <DialogDescription>
              Bạn có chắc chắn muốn xóa người dùng{" "}
              <span className="font-medium text-foreground">{selectedUser?.email}</span>? Hành động này không thể hoàn tác.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="gap-3 pt-4">
            <Button
              variant="outline"
              onClick={() => setDeleteDialogOpen(false)}
              className="h-11 px-6 text-base font-medium"
            >
              Hủy
            </Button>
            <Button
              variant="destructive"
              onClick={handleDeleteUser}
              className="h-11 px-6 text-base font-medium"
            >
              Xóa
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={detailDialogOpen} onOpenChange={setDetailDialogOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader className="text-left mb-4">
            <DialogTitle className="text-xl">Chi tiết người dùng</DialogTitle>
            <DialogDescription>Thông tin tài khoản và trạng thái người dùng</DialogDescription>
          </DialogHeader>
          {selectedUser && (
            <div className="space-y-4 py-2">
              <div className="flex items-center gap-4 p-4 rounded-lg border border-border bg-secondary/20">
                <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center">
                  {selectedUser.avatarUrl ? (
                    <img
                      src={selectedUser.avatarUrl}
                      alt={selectedUser.fullName || selectedUser.email}
                      className="w-16 h-16 rounded-full object-cover"
                    />
                  ) : (
                    <Users className="w-8 h-8 text-primary" />
                  )}
                </div>
                <div>
                  <div className="flex items-center gap-1.5">
                    <p className="text-lg font-semibold text-foreground">
                      {selectedUser.fullName || "Chưa cập nhật"}
                    </p>
                    {selectedUser.emailConfirm && (
                      <span title="Đã xác thực" className="text-emerald-500">
                        <Check className="w-4 h-4" />
                      </span>
                    )}
                  </div>
                  <p className="text-sm text-muted-foreground">{selectedUser.email}</p>
                  {selectedUser.address && (
                    <p className="text-xs text-muted-foreground mt-1">{selectedUser.address}</p>
                  )}
                  <div className="flex gap-2 mt-2">
                    <Badge variant={selectedUser.role === "admin" ? "default" : "secondary"}>
                      {roleLabels[selectedUser.role] || selectedUser.role}
                    </Badge>
                    <Badge
                      variant={
                        selectedUser.status === "active"
                          ? "success"
                          : selectedUser.status === "locked" || selectedUser.status === "disabled"
                          ? "destructive"
                          : selectedUser.status === "pending"
                          ? "warning"
                          : "secondary"
                      }
                    >
                      {statusLabels[selectedUser.status] || selectedUser.status}
                    </Badge>
                  </div>
                </div>
              </div>

              <div className="space-y-3">
                <div className="flex items-center justify-between py-2 border-b border-border">
                  <span className="text-muted-foreground">Số điện thoại</span>
                  <span className="font-medium">{selectedUser.phone || "Chưa cập nhật"}</span>
                </div>
                <div className="flex items-center justify-between py-2 border-b border-border">
                  <span className="text-muted-foreground">Địa chỉ</span>
                  <span className="font-medium text-right max-w-[60%]">
                    {selectedUser.address || "Chưa cập nhật"}
                  </span>
                </div>
                <div className="flex items-center justify-between py-2 border-b border-border">
                  <span className="text-muted-foreground">Xác thực email</span>
                  <Badge variant={selectedUser.emailConfirm ? "success" : "warning"}>
                    {selectedUser.emailConfirm ? "Đã xác thực" : "Chưa xác thực"}
                  </Badge>
                </div>
                <div className="flex items-center justify-between py-2 border-b border-border">
                  <span className="text-muted-foreground">Bảo mật 2FA</span>
                  <Badge variant={selectedUser.is2faEnabled ? "success" : "secondary"}>
                    {selectedUser.is2faEnabled ? "Đã bật" : "Chưa bật"}
                  </Badge>
                </div>
                <div className="flex items-center justify-between py-2 border-b border-border">
                  <span className="text-muted-foreground">Ngày tạo</span>
                  <span className="font-medium">
                    {selectedUser.createdOn
                      ? new Date(selectedUser.createdOn).toLocaleDateString("vi-VN", {
                          day: "2-digit",
                          month: "2-digit",
                          year: "numeric",
                          hour: "2-digit",
                          minute: "2-digit",
                        })
                      : "Không rõ"}
                  </span>
                </div>
                <div className="flex items-center justify-between py-2">
                  <span className="text-muted-foreground">Cập nhật lần cuối</span>
                  <span className="font-medium">
                    {selectedUser.modifiedOn
                      ? new Date(selectedUser.modifiedOn).toLocaleDateString("vi-VN", {
                          day: "2-digit",
                          month: "2-digit",
                          year: "numeric",
                          hour: "2-digit",
                          minute: "2-digit",
                        })
                      : "Không rõ"}
                  </span>
                </div>
              </div>
            </div>
          )}
          <DialogFooter className="gap-3 pt-4">
            <Button
              variant="outline"
              onClick={() => setDetailDialogOpen(false)}
              className="h-11 px-6 text-base font-medium"
            >
              Đóng
            </Button>
            <Button
              onClick={() => {
                setDetailDialogOpen(false)
                openEditDialog(selectedUser)
              }}
              className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20"
            >
              <Edit className="w-4 h-4 mr-2" />
              Chỉnh sửa
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
