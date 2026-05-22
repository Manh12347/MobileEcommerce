import React, { useState, useRef, useEffect } from 'react';
import { ChevronRight } from 'lucide-react';

export function DropdownMenu({ children, ...props }) {
  const [open, setOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    function handleClickOutside(event) {
      if (ref.current && !ref.current.contains(event.target)) {
        setOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  return (
    <DropdownMenuContext.Provider value={{ open, setOpen }}>
      <div ref={ref} className="relative inline-block">
        {React.Children.map(children, child => {
          if (child?.type === DropdownMenuTrigger) {
            return React.cloneElement(child, { onClick: () => setOpen(!open) });
          }
          if (child?.type === DropdownMenuContent) {
            return open ? React.cloneElement(child) : null;
          }
          return child;
        })}
      </div>
    </DropdownMenuContext.Provider>
  );
}

const DropdownMenuContext = React.createContext();

export function DropdownMenuTrigger({ children, asChild, ...props }) {
  return <>{children}</>;
}

export function DropdownMenuContent({ children, align = 'end', className = '', sideOffset = 4, ...props }) {
  return (
    <div
      className={`z-50 min-w-[8rem] overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground shadow-md animate-in fade-in-0 zoom-in-95 ${align === 'end' ? 'right-0' : 'left-0'} ${className}`}
      style={{ marginTop: `${sideOffset}px` }}
      {...props}
    >
      {children}
    </div>
  );
}

export function DropdownMenuItem({ children, className = '', onSelect, ...props }) {
  const { setOpen } = React.useContext(DropdownMenuContext);
  
  return (
    <div
      className={`relative flex cursor-pointer select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none transition-colors hover:bg-accent hover:text-accent-foreground ${className}`}
      onClick={() => {
        onSelect?.();
        setOpen(false);
      }}
      {...props}
    >
      {children}
    </div>
  );
}

export function DropdownMenuSeparator({ className = '', ...props }) {
  return (
    <div className={`-mx-1 my-1 h-px bg-border ${className}`} {...props} />
  );
}

export function DropdownMenuLabel({ children, className = '', ...props }) {
  return (
    <div className={`px-2 py-1.5 text-sm font-semibold ${className}`} {...props}>
      {children}
    </div>
  );
}
