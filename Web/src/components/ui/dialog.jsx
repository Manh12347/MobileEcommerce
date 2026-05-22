import React, { useState, useRef, useEffect } from 'react';
import { X } from 'lucide-react';

export function Dialog({ open, onOpenChange, children, ...props }) {
  return (
    <DialogContext.Provider value={{ open, onOpenChange }}>
      {open && <DialogOverlay />}
      {children}
    </DialogContext.Provider>
  );
}

const DialogContext = React.createContext();

export function DialogContent({ children, className = '', ...props }) {
  const { open, onOpenChange } = React.useContext(DialogContext);
  const ref = useRef(null);

  useEffect(() => {
    function handleEscape(event) {
      if (event.key === 'Escape') {
        onOpenChange(false);
      }
    }
    if (open) {
      document.addEventListener('keydown', handleEscape);
      document.body.style.overflow = 'hidden';
    }
    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = '';
    };
  }, [open, onOpenChange]);

  if (!open) return null;

  return (
    <>
      <DialogOverlay />
      <div className="fixed inset-0 z-50 flex items-center justify-center">
        <div
          ref={ref}
          className={`relative z-50 grid w-full max-w-lg gap-4 rounded-lg border bg-popover p-6 shadow-lg animate-in fade-in-0 zoom-in-95 ${className}`}
          onClick={(e) => e.stopPropagation()}
          {...props}
        >
          {children}
        </div>
      </div>
    </>
  );
}

function DialogOverlay() {
  const { onOpenChange } = React.useContext(DialogContext);
  return (
    <div 
      className="fixed inset-0 z-40 bg-black/80 backdrop-blur-sm animate-in fade-in-0"
      onClick={() => onOpenChange(false)}
    />
  );
}

export function DialogHeader({ children, className = '', ...props }) {
  return (
    <div className={`flex flex-col space-y-1.5 text-center sm:text-left ${className}`} {...props}>
      {children}
    </div>
  );
}

export function DialogFooter({ children, className = '', ...props }) {
  return (
    <div className={`flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2 ${className}`} {...props}>
      {children}
    </div>
  );
}

export function DialogTitle({ children, className = '', ...props }) {
  return (
    <h2 className={`text-lg font-semibold leading-none tracking-tight ${className}`} {...props}>
      {children}
    </h2>
  );
}

export function DialogDescription({ children, className = '', ...props }) {
  return (
    <p className={`text-sm text-muted-foreground ${className}`} {...props}>
      {children}
    </p>
  );
}

export function DialogClose({ children, onClick, className = '', ...props }) {
  const { onOpenChange } = React.useContext(DialogContext);
  return (
    <button
      type="button"
      className={`absolute right-4 top-4 rounded-sm opacity-70 ring-offset-background transition-opacity hover:opacity-100 ${className}`}
      onClick={() => onOpenChange(false)}
      {...props}
    >
      <X className="h-4 w-4" />
      <span className="sr-only">Close</span>
    </button>
  );
}
