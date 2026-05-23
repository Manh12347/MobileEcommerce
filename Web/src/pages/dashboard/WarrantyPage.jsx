import { useEffect, useMemo, useState } from "react"
import {
  Search,
  Plus,
  MoreVertical,
  Eye,
  ShieldCheck,
  Wrench,
  PackageCheck,
  MapPin,
  Phone,
  CheckCircle2,
  XCircle,
} from "lucide-react"
import { Button } from "../../components/ui/button"
import { Input } from "../../components/ui/input"
import { Badge } from "../../components/ui/badge"
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from "../../components/ui/table"
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
} from "../../components/ui/dropdown-menu"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "../../components/ui/dialog"
import { PaginationControls } from "../../components/dashboard/PaginationControls"
import { warrantyAPI } from "../../api/client"

const statusLabels = {
  processing: "\u0110ang x\u1eed l\u00fd",
  completed: "Ho\u00e0n t\u1ea5t",
  cancelled: "B\u1ecb h\u1ee7y",
}

const uiText = {
  title: "B\u1ea3o h\u00e0nh",
  subtitle: "Qu\u1ea3n l\u00fd phi\u1ebfu b\u1ea3o h\u00e0nh, tr\u1ea1ng th\u00e1i v\u00e0 ti\u1ebfn tr\u00ecnh x\u1eed l\u00fd",
  createTicket: "T\u1ea1o phi\u1ebfu b\u1ea3o h\u00e0nh",
  totalTickets: "T\u1ed5ng phi\u1ebfu",
  completedTickets: "\u0110\u00e3 ho\u00e0n t\u1ea5t",
  searchPlaceholder: "T\u00ecm theo m\u00e3 phi\u1ebfu, kh\u00e1ch h\u00e0ng, s\u1ea3n ph\u1ea9m, serial...",
  allStatuses: "T\u1ea5t c\u1ea3 tr\u1ea1ng th\u00e1i",
  ticket: "Phi\u1ebfu",
  customer: "Kh\u00e1ch h\u00e0ng",
  product: "S\u1ea3n ph\u1ea9m",
  status: "Tr\u1ea1ng th\u00e1i",
  created: "Ng\u00e0y t\u1ea1o",
  loading: "\u0110ang t\u1ea3i nh\u00f3m phi\u1ebfu b\u1ea3o h\u00e0nh...",
  empty: "Kh\u00f4ng c\u00f3 nh\u00f3m phi\u1ebfu b\u1ea3o h\u00e0nh",
  viewDetail: "Xem chi ti\u1ebft",
  updateStatus: "C\u1eadp nh\u1eadt tr\u1ea1ng th\u00e1i",
  lockWarning: "Phi\u1ebfu \u0111\u00e3 ho\u00e0n t\u1ea5t, kh\u00f4ng th\u1ec3 thay \u0111\u1ed5i tr\u1ea1ng th\u00e1i.",
  completeConfirm: "Sau khi chuy\u1ec3n sang Ho\u00e0n t\u1ea5t, tr\u1ea1ng th\u00e1i s\u1ebd kh\u00f4ng th\u1ec3 thay \u0111\u1ed5i. B\u1ea1n c\u00f3 ch\u1eafc mu\u1ed1n ti\u1ebfp t\u1ee5c?",
  loadError: "Kh\u00f4ng th\u1ec3 t\u1ea3i phi\u1ebfu b\u1ea3o h\u00e0nh",
  updateError: "Kh\u00f4ng th\u1ec3 c\u1eadp nh\u1eadt tr\u1ea1ng th\u00e1i",
  detailTitle: "Chi ti\u1ebft phi\u1ebfu",
  detailDescription: "Th\u00f4ng tin ti\u1ebfp nh\u1eadn, t\u00ecnh tr\u1ea1ng s\u1ea3n ph\u1ea9m v\u00e0 x\u1eed l\u00fd b\u1ea3o h\u00e0nh.",
  customerInfo: "Th\u00f4ng tin kh\u00e1ch h\u00e0ng",
  warrantyStatus: "Tr\u1ea1ng th\u00e1i b\u1ea3o h\u00e0nh",
  claimCount: "S\u1ed1 y\u00eau c\u1ea7u",
  productInfo: "Th\u00f4ng tin s\u1ea3n ph\u1ea9m",
  purchaseDate: "Ng\u00e0y mua",
  warrantyEnd: "Ng\u00e0y h\u1ebft h\u1ea1n",
  claimList: "Danh s\u00e1ch y\u00eau c\u1ea7u trong nh\u00f3m",
  close: "\u0110\u00f3ng",
  unknownCustomer: "Ch\u01b0a c\u00f3 kh\u00e1ch h\u00e0ng",
  unknownProduct: "Ch\u01b0a c\u00f3 s\u1ea3n ph\u1ea9m",
  unknownSerial: "Ch\u01b0a c\u00f3 serial",
  noIssue: "Ch\u01b0a c\u00f3 m\u00f4 t\u1ea3 l\u1ed7i",
}

const formatDate = (value) => {
  if (!value) return "-"
  const rawValue = String(value)
  const datePart = rawValue.includes("T") ? rawValue.split("T")[0] : rawValue.split(" ")[0]
  return datePart.includes("-") ? datePart.split("-").reverse().join("/") : value
}

const formatDateTime = (value) => {
  if (!value) return "-"
  const rawValue = String(value)
  const [datePart, timePart = ""] = rawValue.split(/[T ]/)
  const formattedDate = formatDate(datePart)
  const formattedTime = timePart.slice(0, 5)
  return formattedTime ? `${formattedDate} ${formattedTime}` : formattedDate
}

const statusOrder = {
  processing: 0,
  cancelled: 1,
  completed: 2,
}

const uniqueBy = (items, getKey) => {
  const seen = new Set()
  return items.filter((item) => {
    const key = getKey(item)
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
}

const normalizeStatus = (statusCounts = {}) => {
  const processing = (statusCounts.processing || 0) + (statusCounts.pending || 0) + (statusCounts.approved || 0)
  const cancelled = (statusCounts.cancelled || 0) + (statusCounts.canceled || 0) + (statusCounts.rejected || 0)
  const completed = statusCounts.completed || 0

  if (processing > 0) return "processing"
  if (cancelled > 0 && completed === 0) return "cancelled"
  if (completed > 0 && cancelled === 0) return "completed"
  if (cancelled > 0 || completed > 0) return "processing"
  return "processing"
}

const groupToWarrantyRow = (group, index) => {
  const claims = uniqueBy(
    group.claims || [],
    (claim) => claim.claimId || `${claim.serialCode || ""}-${claim.createdAt || ""}-${claim.issueDescription || ""}`
  )
  const latestClaim = claims[0] || {}
  const serialCodes = claims.map((claim) => claim.serialCode).filter(Boolean)
  const customerNames = group.customerNames?.length
    ? group.customerNames
    : claims.map((claim) => claim.customerName || claim.accountEmail).filter(Boolean)
  const uniqueCustomerNames = [...new Set(customerNames)]
  const customerPhones = group.customerPhones?.length
    ? group.customerPhones
    : claims.map((claim) => claim.customerPhone).filter(Boolean)
  const customerEmails = [...new Set(claims.map((claim) => claim.accountEmail).filter(Boolean))]

  return {
    id: `${group.productName || "product"}-${group.serialSeries || "series"}-${index}`,
    code: group.serialSeries || uiText.unknownSerial,
    customer: uniqueCustomerNames.length ? uniqueCustomerNames.join(", ") : uiText.unknownCustomer,
    phone: customerPhones.length ? [...new Set(customerPhones)].join(", ") : "",
    email: customerEmails.join(", "),
    product: group.productName || uiText.unknownProduct,
    serial: group.serialSeries || uiText.unknownSerial,
    productSku: group.productSku || latestClaim.productSku || "",
    serialCodes,
    purchaseDate: group.earliestWarrantyStartDate || latestClaim.warrantyStartDate || "",
    warrantyEnd: group.latestWarrantyEndDate || latestClaim.warrantyEndDate || "",
    issue: latestClaim.issueDescription || "",
    status: normalizeStatus(group.statusCounts),
    createdAt: group.latestCreatedAt || latestClaim.createdAt || "",
    claimCount: group.claimCount || claims.length,
    customerNames: uniqueCustomerNames,
    statusCounts: group.statusCounts || {},
    claims,
  }
}

export function WarrantyPage() {
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(5)
  const [warranties, setWarranties] = useState([])
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState("")
  const [selectedWarranty, setSelectedWarranty] = useState(null)
  const [detailDialogOpen, setDetailDialogOpen] = useState(false)

  const fetchWarrantyGroups = async () => {
    setIsLoading(true)
    setErrorMessage("")

    try {
      const response = await warrantyAPI.getClaimGroups()
      const groups = response.data?.data || []
      const rows = groups.map(groupToWarrantyRow)
      setWarranties(rows)
      return rows
    } catch (error) {
      setWarranties([])
      setErrorMessage(error.response?.data?.message || error.message || uiText.loadError)
      return []
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    fetchWarrantyGroups()
  }, [])

  useEffect(() => {
    setCurrentPage(1)
  }, [searchTerm, statusFilter, pageSize])

  const stats = useMemo(() => {
    const total = warranties.reduce((sum, item) => sum + (item.claimCount || 0), 0)
    const processing = warranties.reduce(
      (sum, item) => sum + (item.statusCounts.processing || 0) + (item.statusCounts.pending || 0) + (item.statusCounts.approved || 0),
      0
    )
    const cancelled = warranties.reduce(
      (sum, item) => sum + (item.statusCounts.cancelled || 0) + (item.statusCounts.canceled || 0) + (item.statusCounts.rejected || 0),
      0
    )
    const completed = warranties.reduce((sum, item) => sum + (item.statusCounts.completed || 0), 0)

    return { total, processing, cancelled, completed }
  }, [warranties])

  const filteredWarranties = warranties
    .filter((item) => {
      const search = searchTerm.toLowerCase()
      const matchesSearch =
        item.code.toLowerCase().includes(search) ||
        item.customer.toLowerCase().includes(search) ||
        item.product.toLowerCase().includes(search) ||
        item.serial.toLowerCase().includes(search)
      const matchesStatus = statusFilter === "all" || item.status === statusFilter
      return matchesSearch && matchesStatus
    })
    .sort((a, b) => {
      const byStatus = (statusOrder[a.status] ?? 99) - (statusOrder[b.status] ?? 99)
      if (byStatus !== 0) return byStatus
      return new Date(b.createdAt || 0) - new Date(a.createdAt || 0)
    })

  const pagedWarranties = filteredWarranties.slice((currentPage - 1) * pageSize, currentPage * pageSize)

  const openDetail = (item) => {
    setSelectedWarranty(item)
    setDetailDialogOpen(true)
  }

  const updateClaimStatus = async (claim, nextStatus) => {
    if (claim.status === "completed") {
      setErrorMessage(uiText.lockWarning)
      return
    }
    if (nextStatus === "completed" && !window.confirm(uiText.completeConfirm)) {
      return
    }

    try {
      await warrantyAPI.updateClaimStatus(claim.claimId, nextStatus)
      const rows = await fetchWarrantyGroups()
      const refreshed = rows.find((row) => row.id === selectedWarranty?.id)
      if (refreshed) {
        setSelectedWarranty(refreshed)
      }
    } catch (error) {
      setErrorMessage(error.response?.data?.message || error.message || uiText.updateError)
    }
  }

  const updateWarrantyGroupStatus = async (item, nextStatus) => {
    const editableClaims = (item.claims || []).filter((claim) => claim.status !== "completed")

    if (editableClaims.length === 0) {
      setErrorMessage(uiText.lockWarning)
      return
    }
    if (nextStatus === "completed" && !window.confirm(uiText.completeConfirm)) {
      return
    }

    try {
      await Promise.all(editableClaims.map((claim) => warrantyAPI.updateClaimStatus(claim.claimId, nextStatus)))
      const rows = await fetchWarrantyGroups()
      const refreshed = rows.find((row) => row.id === selectedWarranty?.id)
      if (refreshed) {
        setSelectedWarranty(refreshed)
      }
    } catch (error) {
      setErrorMessage(error.response?.data?.message || error.message || uiText.updateError)
    }
  }

  const getStatusVariant = (status) => {
    if (status === "completed") return "success"
    if (status === "cancelled") return "destructive"
    return "info"
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">{uiText.title}</h1>
          <p className="text-muted-foreground">{uiText.subtitle}</p>
        </div>
        <Button className="h-11 px-6 text-base font-semibold shadow-lg shadow-primary/20">
          <Plus className="mr-2 h-5 w-5" />
          {uiText.createTicket}
        </Button>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">{uiText.totalTickets}</p>
              <p className="mt-2 text-2xl font-bold text-foreground">{stats.total}</p>
            </div>
            <div className="rounded-full bg-primary/10 p-3 text-primary">
              <ShieldCheck className="h-5 w-5" />
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">{statusLabels.cancelled}</p>
              <p className="mt-2 text-2xl font-bold text-foreground">{stats.cancelled}</p>
            </div>
            <div className="rounded-full bg-amber-500/10 p-3 text-amber-400">
              <XCircle className="h-5 w-5" />
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">{statusLabels.processing}</p>
              <p className="mt-2 text-2xl font-bold text-foreground">{stats.processing}</p>
            </div>
            <div className="rounded-full bg-blue-500/10 p-3 text-blue-400">
              <Wrench className="h-5 w-5" />
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">{uiText.completedTickets}</p>
              <p className="mt-2 text-2xl font-bold text-foreground">{stats.completed}</p>
            </div>
            <div className="rounded-full bg-emerald-500/10 p-3 text-emerald-400">
              <PackageCheck className="h-5 w-5" />
            </div>
          </div>
        </div>
      </div>

      <div className="grid gap-3 lg:grid-cols-[1.4fr_0.8fr]">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder={uiText.searchPlaceholder}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-9"
          />
        </div>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="h-10 rounded-md border border-input bg-background px-3 text-sm text-foreground"
        >
          <option value="all">{uiText.allStatuses}</option>
          <option value="processing">{statusLabels.processing}</option>
          <option value="cancelled">{statusLabels.cancelled}</option>
          <option value="completed">{statusLabels.completed}</option>
        </select>
      </div>

      <div className="overflow-hidden rounded-lg border border-border bg-card">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="text-left">{uiText.ticket}</TableHead>
              <TableHead className="text-left">{uiText.customer}</TableHead>
              <TableHead className="text-left">{uiText.product}</TableHead>
              <TableHead className="text-left">{uiText.status}</TableHead>
              <TableHead className="text-left">{uiText.created}</TableHead>
              <TableHead className="w-12 text-center"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading && (
              <TableRow>
                <TableCell colSpan={6} className="py-8 text-center text-muted-foreground">
                  {uiText.loading}
                </TableCell>
              </TableRow>
            )}
            {!isLoading && errorMessage && (
              <TableRow>
                <TableCell colSpan={6} className="py-8 text-center text-destructive">
                  {errorMessage}
                </TableCell>
              </TableRow>
            )}
            {!isLoading && !errorMessage && pagedWarranties.length === 0 && (
              <TableRow>
                <TableCell colSpan={6} className="py-8 text-center text-muted-foreground">
                  {uiText.empty}
                </TableCell>
              </TableRow>
            )}
            {pagedWarranties.map((item) => (
              <TableRow key={item.id}>
                <TableCell className="text-left">
                  <div>
                    <p className="font-semibold text-foreground">{item.code}</p>
                    <p className="text-xs text-muted-foreground">HSD: {formatDate(item.warrantyEnd)}</p>
                  </div>
                </TableCell>
                <TableCell className="text-left">
                  <div>
                    <p className="font-medium text-foreground">{item.customer}</p>
                    {item.phone && <p className="text-xs text-muted-foreground">{item.phone}</p>}
                  </div>
                </TableCell>
                <TableCell className="text-left">
                  <div>
                    <p className="font-medium text-foreground">{item.product}</p>
                    <p className="text-xs text-muted-foreground">{item.serial}</p>
                  </div>
                </TableCell>
                <TableCell className="text-left">
                  <Badge variant={getStatusVariant(item.status)}>{statusLabels[item.status]}</Badge>
                </TableCell>
                <TableCell className="text-left text-muted-foreground">{formatDateTime(item.createdAt)}</TableCell>
                <TableCell className="text-center">
                  <DropdownMenu>
                    <DropdownMenuTrigger>
                      <Button variant="ghost" size="icon" className="h-10 w-10 hover:bg-primary/10 hover:text-primary transition-colors">
                        <MoreVertical className="h-5 w-5" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" className="w-56">
                      <DropdownMenuItem
                        className="flex cursor-pointer items-center rounded-md px-4 py-3 text-base"
                        onSelect={() => openDetail(item)}
                      >
                        <Eye className="mr-3 h-5 w-5 text-blue-500" />
                        {uiText.viewDetail}
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        className="flex cursor-pointer items-center rounded-md px-4 py-3 text-base"
                        onSelect={() => updateWarrantyGroupStatus(item, "cancelled")}
                      >
                        <XCircle className="mr-3 h-5 w-5 text-amber-500" />
                        {uiText.updateStatus}: {statusLabels.cancelled}
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        className="flex cursor-pointer items-center rounded-md px-4 py-3 text-base"
                        onSelect={() => updateWarrantyGroupStatus(item, "completed")}
                      >
                        <CheckCircle2 className="mr-3 h-5 w-5 text-emerald-500" />
                        {uiText.updateStatus}: {statusLabels.completed}
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
        totalItems={filteredWarranties.length}
        pageSize={pageSize}
        currentPage={currentPage}
        onPageChange={setCurrentPage}
        onPageSizeChange={(size) => {
          setPageSize(size)
          setCurrentPage(1)
        }}
      />

      <Dialog open={detailDialogOpen} onOpenChange={setDetailDialogOpen}>
        <DialogContent className="max-h-[90vh] max-w-4xl overflow-y-auto p-7 text-left">
          <DialogHeader className="text-left">
            <DialogTitle className="text-2xl">{uiText.detailTitle} {selectedWarranty?.code}</DialogTitle>
            <DialogDescription>
              {uiText.detailDescription}
            </DialogDescription>
          </DialogHeader>

          {selectedWarranty && (
            <div className="space-y-4 py-2">
              <div className="grid gap-4 md:grid-cols-2">
                <div className="rounded-lg border border-border bg-secondary/20 p-4 text-left">
                  <p className="mb-3 text-sm font-semibold text-foreground">{uiText.customerInfo}</p>
                  <div className="space-y-2 text-sm text-muted-foreground">
                    <p className="font-medium text-foreground">{selectedWarranty.customer}</p>
                    {selectedWarranty.phone && (
                      <p className="flex items-center gap-2">
                        <Phone className="h-4 w-4" />
                        <span>{selectedWarranty.phone}</span>
                      </p>
                    )}
                    {selectedWarranty.email && selectedWarranty.email !== selectedWarranty.customer && (
                      <p>{selectedWarranty.email}</p>
                    )}
                    {selectedWarranty.claims?.some((claim) => claim.customerAddress) && (
                      <p className="flex items-start gap-2">
                        <MapPin className="mt-0.5 h-4 w-4 flex-shrink-0" />
                        <span>{selectedWarranty.claims.find((claim) => claim.customerAddress)?.customerAddress}</span>
                      </p>
                    )}
                  </div>
                </div>

                <div className="rounded-lg border border-border bg-secondary/20 p-4 text-left">
                  <p className="mb-3 text-sm font-semibold text-foreground">{uiText.warrantyStatus}</p>
                  <div className="space-y-3 text-sm">
                    <div className="flex items-center justify-between">
                      <span className="text-muted-foreground">{uiText.status}</span>
                      <Badge variant={getStatusVariant(selectedWarranty.status)}>{statusLabels[selectedWarranty.status]}</Badge>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-muted-foreground">{uiText.claimCount}</span>
                      <span className="font-medium text-foreground">{selectedWarranty.claimCount}</span>
                    </div>
                  </div>
                </div>
              </div>

              <div className="rounded-lg border border-border bg-secondary/20 p-4 text-left">
                <p className="mb-3 text-sm font-semibold text-foreground">{uiText.productInfo}</p>
                <div className="grid gap-4 text-sm sm:grid-cols-2 lg:grid-cols-3">
                  <div>
                    <p className="text-muted-foreground">{uiText.product}</p>
                    <p className="font-medium text-foreground">{selectedWarranty.product}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground">SKU</p>
                    <p className="font-medium text-foreground">{selectedWarranty.productSku || "-"}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground">Serial</p>
                    <p className="font-medium text-foreground">{selectedWarranty.serial}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground">{uiText.purchaseDate}</p>
                    <p className="font-medium text-foreground">{formatDate(selectedWarranty.purchaseDate)}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground">{uiText.warrantyEnd}</p>
                    <p className="font-medium text-foreground">{formatDate(selectedWarranty.warrantyEnd)}</p>
                  </div>
                </div>
              </div>

              <div className="rounded-lg border border-border bg-secondary/20 p-4 text-left">
                <p className="mb-3 text-sm font-semibold text-foreground">{uiText.claimList}</p>
                <div className="divide-y divide-border overflow-hidden rounded-md border border-border bg-background">
                  {selectedWarranty.claims?.map((claim, index) => (
                    <div key={claim.claimId || `${claim.serialCode}-${index}`} className="p-4 text-sm">
                      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                        <div className="min-w-0 space-y-1">
                          <p className="font-medium text-foreground">{claim.serialCode || uiText.unknownSerial}</p>
                          <p className="text-sm text-muted-foreground">
                            {claim.customerName || claim.accountEmail || uiText.unknownCustomer}
                          </p>
                        </div>
                        <Badge variant={getStatusVariant(claim.status)} className="self-start">
                          {statusLabels[claim.status] || claim.status}
                        </Badge>
                      </div>
                      <p className="mt-3 leading-6 text-muted-foreground">{claim.issueDescription || uiText.noIssue}</p>
                      {claim.status === "completed" ? (
                        <p className="mt-3 rounded-md border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-xs text-amber-300">
                          {uiText.lockWarning}
                        </p>
                      ) : (
                        <div className="mt-3 flex flex-wrap gap-2">
                          <Button
                            type="button"
                            variant="outline"
                            className="h-9 px-3 text-sm"
                            disabled={claim.status === "cancelled"}
                            onClick={() => updateClaimStatus(claim, "cancelled")}
                          >
                            <XCircle className="mr-2 h-4 w-4" />
                            {statusLabels.cancelled}
                          </Button>
                          <Button
                            type="button"
                            className="h-9 px-3 text-sm"
                            onClick={() => updateClaimStatus(claim, "completed")}
                          >
                            <CheckCircle2 className="mr-2 h-4 w-4" />
                            {statusLabels.completed}
                          </Button>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          <DialogFooter className="gap-3 pt-2">
            <Button variant="outline" onClick={() => setDetailDialogOpen(false)} className="h-11 px-6 text-base font-medium">
              {uiText.close}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
