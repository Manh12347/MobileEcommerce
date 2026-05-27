import { useEffect, useState, useCallback } from "react"
import { X, CheckCircle, AlertCircle } from "lucide-react"

const toastListeners = new Set()
let toastId = 0

export function toast({ title, description, variant = "default", duration = 2000 }) {
  const id = ++toastId
  const toast = { id, title, description, variant }
  toastListeners.forEach(listener => listener(toast))
  return id
}

export function Toaster({ position = "top-4 right-4" }) {
  const [toasts, setToasts] = useState([])

  const addToast = useCallback((newToast) => {
    setToasts(prev => [...prev, newToast])
  }, [])

  const removeToast = useCallback((id) => {
    setToasts(prev => prev.filter(t => t.id !== id))
  }, [])

  useEffect(() => {
    toastListeners.add(addToast)
    return () => {
      toastListeners.delete(addToast)
    }
  }, [addToast])

  return (
    <div className={`fixed ${position} z-[9999] flex flex-col gap-2 pointer-events-none`}>
      {toasts.map((t) => (
        <Toast key={t.id} {...t} onClose={() => removeToast(t.id)} />
      ))}
    </div>
  )
}

function Toast({ title, description, variant, onClose }) {
  const [isVisible, setIsVisible] = useState(false)

  useEffect(() => {
    const showTimer = setTimeout(() => setIsVisible(true), 10)
    const hideTimer = setTimeout(() => {
      setIsVisible(false)
      setTimeout(onClose, 300)
    }, 2000)

    return () => {
      clearTimeout(showTimer)
      clearTimeout(hideTimer)
    }
  }, [onClose])

  const isDestructive = variant === "destructive"
  const bgColor = isDestructive ? "bg-red-500" : "bg-green-600"
  const Icon = isDestructive ? AlertCircle : CheckCircle

  return (
    <div
      className={`
        pointer-events-auto flex items-center gap-3 px-4 py-2.5 rounded-md shadow-lg text-white
        transition-all duration-300 ease-out
        ${bgColor}
        ${isVisible ? "translate-x-0 opacity-100" : "translate-x-full opacity-0"}
      `}
    >
      <Icon className="w-5 h-5 flex-shrink-0" />
      <div className="flex-1 min-w-0">
        {title && <p className="font-medium text-sm">{title}</p>}
        {description && <p className="text-xs opacity-90 truncate">{description}</p>}
      </div>
      <button
        onClick={() => {
          setIsVisible(false)
          setTimeout(onClose, 300)
        }}
        className="p-1 hover:bg-white/20 rounded transition-colors flex-shrink-0"
      >
        <X className="w-4 h-4" />
      </button>
    </div>
  )
}

export function useToast() {
  return { toast }
}
