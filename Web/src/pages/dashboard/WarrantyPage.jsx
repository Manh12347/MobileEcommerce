import { useState } from "react"
import { Search, Plus, Shield, Calendar, CheckCircle, Clock, AlertCircle, Eye, RefreshCw } from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "../../components/ui/table"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "../../components/ui/dropdown-menu"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "../../components/ui/dialog"
import { Tabs, TabsList, TabsTrigger, TabsContent } from "../../components/ui/tabs"

const mockWarranties = [
  { id: "BH001", product: "iPhone 15 Pro Max", serial: "SN123456789", customer: "Nguyễn Văn A", phone: "0912345678", purchaseDate: "2026-01-15", warrantyEnd: "2027-01-15", status: "active", type: "official", issue: null },
  { id: "BH002", product: "Samsung Galaxy S24", serial: "SN987654321", customer: "Trần Thị B", phone: "0923456789", purchaseDate: "2026-02-20", warrantyEnd: "2027-02-20", status: "active", type: "official", issue: null },
  { id: "BH003", product: "AirPods Pro 2", serial: "SN456789123", customer: "Lê Văn C", phone: "0934567890", purchaseDate: "2025-06-10", warrantyEnd: "2026-06-10", status: "expired", type: "official", issue: null },
  { id: "BH004", product: "iPad Pro M4", serial: "SN321654987", customer: "Phạm Thị D", phone: "0945678901", purchaseDate: "2026-04-05", warrantyEnd: "2027-04-05", status: "repairing", type: "official", issue: "Lỗi màn hình" },
  { id: "BH005", product: "Xiaomi Redmi Note 13", serial: "SN654321789", customer: "Hoàng Văn E", phone: "0956789012", purchaseDate: "2026-03-12", warrantyEnd: "2027-03-12", status: "active", type: "extended", issue: null },
]

const statusConfig = {
  active: { label: "Còn bảo hành", variant: "success", icon: CheckCircle },
  expired: { label: "Hết hạn", variant: "destructive", icon: Clock },
  repairing: { label: "Đang sửa chữa", variant: "warning", icon: RefreshCw },
  claimed: { label: "Đã claim", variant: "info", icon: AlertCircle },
}

export function WarrantyPage() {
  const [searchTerm, setSearchTerm] = useState("")
  const [statusTab, setStatusTab] = useState("all")
  const [selectedWarranty, setSelectedWarranty] = useState(null)
  const [detailDialogOpen, setDetailDialogOpen] = useState(false)

  const filteredWarranties = mockWarranties.filter(warranty => {
    const matchesSearch = warranty.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
                          warranty.serial.toLowerCase().includes(searchTerm.toLowerCase()) ||
                          warranty.customer.toLowerCase().includes(searchTerm.toLowerCase()) ||
                          warranty.product.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesStatus = statusTab === "all" || warranty.status === statusTab
    return matchesSearch && matchesStatus
  })

  const openWarrantyDetail = (warranty) => {
    setSelectedWarranty(warranty)
    setDetailDialogOpen(true)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Bảo hành</h1>
          <p className="text-muted-foreground">Quản lý bảo hành sản phẩm</p>
        </div>
        <Button onClick={() => setDetailDialogOpen(true)}>
          <Plus className="w-4 h-4 mr-2" />
          Tạo bảo hành mới
        </Button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-card rounded-lg border border-border p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-emerald-500/20 flex items-center justify-center">
              <CheckCircle className="w-5 h-5 text-emerald-500" />
            </div>
            <div>
              <p className="text-2xl font-bold text-foreground">156</p>
              <p className="text-xs text-muted-foreground">Còn bảo hành</p>
            </div>
          </div>
        </div>
        <div className="bg-card rounded-lg border border-border p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-amber-500/20 flex items-center justify-center">
              <RefreshCw className="w-5 h-5 text-amber-500" />
            </div>
            <div>
              <p className="text-2xl font-bold text-foreground">12</p>
              <p className="text-xs text-muted-foreground">Đang sửa chữa</p>
            </div>
          </div>
        </div>
        <div className="bg-card rounded-lg border border-border p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-red-500/20 flex items-center justify-center">
              <Clock className="w-5 h-5 text-red-500" />
            </div>
            <div>
              <p className="text-2xl font-bold text-foreground">28</p>
              <p className="text-xs text-muted-foreground">Hết hạn</p>
            </div>
          </div>
        </div>
        <div className="bg-card rounded-lg border border-border p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-blue-500/20 flex items-center justify-center">
              <Shield className="w-5 h-5 text-blue-500" />
            </div>
            <div>
              <p className="text-2xl font-bold text-foreground">8</p>
              <p className="text-xs text-muted-foreground">Bảo hành mở rộng</p>
            </div>
          </div>
        </div>
      </div>

      {/* Tabs & Search */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <Tabs value={statusTab} onValueChange={setStatusTab}>
          <TabsList>
            <TabsTrigger value="all">Tất cả</TabsTrigger>
            <TabsTrigger value="active">Còn bảo hành</TabsTrigger>
            <TabsTrigger value="repairing">Đang sửa chữa</TabsTrigger>
            <TabsTrigger value="expired">Hết hạn</TabsTrigger>
          </TabsList>
        </Tabs>
        <div className="relative w-full sm:w-72">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Tìm kiếm bảo hành..."
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
              <TableHead>Mã BH</TableHead>
              <TableHead>Sản phẩm</TableHead>
              <TableHead>Serial</TableHead>
              <TableHead>Khách hàng</TableHead>
              <TableHead>Ngày mua</TableHead>
              <TableHead>Hạn BH</TableHead>
              <TableHead>Trạng thái</TableHead>
              <TableHead className="w-12"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredWarranties.map((warranty) => (
              <TableRow key={warranty.id}>
                <TableCell>
                  <span className="font-mono font-medium text-primary">{warranty.id}</span>
                </TableCell>
                <TableCell>
                  <span className="font-medium text-foreground">{warranty.product}</span>
                </TableCell>
                <TableCell>
                  <code className="text-sm text-muted-foreground">{warranty.serial}</code>
                </TableCell>
                <TableCell>
                  <div className="flex flex-col">
                    <span className="font-medium text-foreground">{warranty.customer}</span>
                    <span className="text-xs text-muted-foreground">{warranty.phone}</span>
                  </div>
                </TableCell>
                <TableCell className="text-muted-foreground">
                  {warranty.purchaseDate}
                </TableCell>
                <TableCell className="text-muted-foreground">
                  {warranty.warrantyEnd}
                </TableCell>
                <TableCell>
                  <div className="flex flex-col gap-1">
                    <Badge variant={statusConfig[warranty.status].variant}>
                      {statusConfig[warranty.status].label}
                    </Badge>
                    <Badge variant={warranty.type === "official" ? "secondary" : "info"} className="text-xs">
                      {warranty.type === "official" ? "Chính hãng" : "Mở rộng"}
                    </Badge>
                  </div>
                </TableCell>
                <TableCell>
                  <Button variant="ghost" size="icon" onClick={() => openWarrantyDetail(warranty)}>
                    <Eye className="w-4 h-4" />
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>

      {/* Warranty Detail Dialog */}
      <Dialog open={detailDialogOpen} onOpenChange={setDetailDialogOpen}>
        <DialogContent className="max-w-2xl">
          {selectedWarranty && (
            <>
              <DialogHeader>
                <DialogTitle>Chi tiết bảo hành {selectedWarranty.id}</DialogTitle>
                <DialogDescription>
                  Serial: {selectedWarranty.serial}
                </DialogDescription>
              </DialogHeader>
              <div className="space-y-6 py-4">
                {/* Product & Status */}
                <div className="bg-secondary/50 rounded-lg p-4">
                  <div className="flex items-start justify-between">
                    <div>
                      <h4 className="font-medium text-lg">{selectedWarranty.product}</h4>
                      <p className="text-sm text-muted-foreground mt-1">Serial: {selectedWarranty.serial}</p>
                    </div>
                    <div className="flex flex-col gap-1 items-end">
                      <Badge variant={statusConfig[selectedWarranty.status].variant}>
                        {statusConfig[selectedWarranty.status].label}
                      </Badge>
                      <Badge variant={selectedWarranty.type === "official" ? "secondary" : "info"}>
                        {selectedWarranty.type === "official" ? "Bảo hành chính hãng" : "Bảo hành mở rộng"}
                      </Badge>
                    </div>
                  </div>
                </div>

                {/* Customer Info */}
                <div className="bg-secondary/50 rounded-lg p-4">
                  <h4 className="font-medium mb-3">Thông tin khách hàng</h4>
                  <div className="space-y-2 text-sm">
                    <p className="flex justify-between">
                      <span className="text-muted-foreground">Khách hàng:</span>
                      <span className="font-medium">{selectedWarranty.customer}</span>
                    </p>
                    <p className="flex justify-between">
                      <span className="text-muted-foreground">Số điện thoại:</span>
                      <span>{selectedWarranty.phone}</span>
                    </p>
                  </div>
                </div>

                {/* Warranty Period */}
                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-secondary/50 rounded-lg p-4">
                    <p className="text-sm text-muted-foreground mb-1">Ngày mua</p>
                    <p className="flex items-center gap-2 font-medium">
                      <Calendar className="w-4 h-4 text-primary" />
                      {selectedWarranty.purchaseDate}
                    </p>
                  </div>
                  <div className="bg-secondary/50 rounded-lg p-4">
                    <p className="text-sm text-muted-foreground mb-1">Hạn bảo hành</p>
                    <p className="flex items-center gap-2 font-medium">
                      <Calendar className="w-4 h-4 text-primary" />
                      {selectedWarranty.warrantyEnd}
                    </p>
                  </div>
                </div>

                {/* Issue (if any) */}
                {selectedWarranty.issue && (
                  <div className="bg-amber-500/10 border border-amber-500/30 rounded-lg p-4">
                    <div className="flex items-start gap-3">
                      <AlertCircle className="w-5 h-5 text-amber-500 mt-0.5" />
                      <div>
                        <p className="font-medium text-amber-500">Vấn đề đang xử lý</p>
                        <p className="text-sm mt-1">{selectedWarranty.issue}</p>
                      </div>
                    </div>
                  </div>
                )}
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setDetailDialogOpen(false)}>
                  Đóng
                </Button>
                {selectedWarranty.status === "active" && (
                  <Button>Claim bảo hành</Button>
                )}
                {selectedWarranty.status === "repairing" && (
                  <Button>Hoàn thành sửa chữa</Button>
                )}
              </DialogFooter>
            </>
          )}
        </DialogContent>
      </Dialog>
    </div>
  )
}
