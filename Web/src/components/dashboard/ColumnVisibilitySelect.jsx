import { useMemo, useState, useRef, useEffect } from "react"
import { Button } from "../ui/button"

export function ColumnVisibilitySelect({ label = "Ẩn/hiện cột", options, value, onChange }) {
  const [open, setOpen] = useState(false)
  const dropdownRef = useRef(null)
  const visibleCount = useMemo(() => value.length, [value])

  const toggleColumn = (columnValue) => {
    if (value.includes(columnValue) && value.length === 1) {
      return
    }
    if (value.includes(columnValue)) {
      onChange(value.filter((current) => current !== columnValue))
    } else {
      onChange([...value, columnValue])
    }
  }

  useEffect(() => {
    function handleClickOutside(event) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setOpen(false)
      }
    }
    if (open) {
      document.addEventListener("mousedown", handleClickOutside)
    }
    return () => document.removeEventListener("mousedown", handleClickOutside)
  }, [open])

  return (
    <div className="relative inline-block" ref={dropdownRef}>
      <Button
        type="button"
        variant="outline"
        onClick={() => setOpen(!open)}
        className="h-11 px-4 rounded-md border border-input bg-background text-sm font-normal justify-between gap-2 min-w-[160px]"
      >
        <span>{label}</span>
        <span className="flex items-center gap-2">
          <span className="rounded-full bg-muted px-2 py-0.5 text-xs">{visibleCount}/{options.length}</span>
          <svg className="w-4 h-4 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </span>
      </Button>
      
      {open && (
        <div className="absolute top-full left-0 mt-1 z-50 w-56 bg-popover border rounded-lg shadow-xl p-3">
          <div className="mb-3 text-sm font-medium text-foreground">Chọn cột cần hiển thị</div>
          <div className="space-y-1">
            {options.map((option) => (
              <div
                key={option.value}
                onClick={() => toggleColumn(option.value)}
                className="flex items-center gap-3 rounded-md px-2 py-2 text-sm hover:bg-accent cursor-pointer select-none"
              >
                <div
                  className={`w-4 h-4 border rounded flex items-center justify-center transition-colors ${
                    value.includes(option.value)
                      ? "bg-primary border-primary"
                      : "border-border bg-background"
                  }`}
                >
                  {value.includes(option.value) && (
                    <svg className="w-3 h-3 text-primary-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                    </svg>
                  )}
                </div>
                <span>{option.label}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
