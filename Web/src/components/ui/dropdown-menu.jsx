import React, { useState, useRef, useEffect, useCallback } from 'react';

const DropdownMenuContext = React.createContext();

export function DropdownMenu({ children }) {
  const [open, setOpen] = useState(false);
  const [position, setPosition] = useState({ top: 0, left: 0 });
  const menuRef = useRef(null);
  const triggerRef = useRef(null);

  useEffect(() => {
    function handleClickOutside(event) {
      if (
        menuRef.current &&
        triggerRef.current &&
        !menuRef.current.contains(event.target) &&
        !triggerRef.current.contains(event.target)
      ) {
        setOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleToggle = useCallback(() => {
    if (triggerRef.current) {
      const rect = triggerRef.current.getBoundingClientRect();
      setPosition({
        top: rect.bottom,
        left: rect.left
      });
    }
    setOpen(prev => !prev);
  }, []);

  return (
    <DropdownMenuContext.Provider value={{ open, setOpen }}>
      <div className="relative inline-block">
        {React.Children.map(children, child => {
          if (!child) return null;

          if (child.type === DropdownMenuTrigger) {
            return React.cloneElement(child, {
              open,
              onToggle: handleToggle,
              triggerRef
            });
          }

          if (child.type === DropdownMenuContent) {
            if (!open) return null;
            return React.cloneElement(child, {
              position,
              menuRef,
              onClose: () => setOpen(false)
            });
          }

          return child;
        })}
      </div>
    </DropdownMenuContext.Provider>
  );
}

export function DropdownMenuTrigger({ children, onToggle, triggerRef }) {
  return React.Children.map(children, child => {
    if (!child) return null;
    return React.cloneElement(child, {
      onClick: (e) => {
        e.stopPropagation();
        if (child.props.onClick) {
          child.props.onClick(e);
        }
        onToggle();
      },
      ref: triggerRef
    });
  });
}

export function DropdownMenuContent({ children, align = 'end', className = '', position, menuRef, sideOffset = 4 }) {
  return (
    <div
      ref={menuRef}
      className={`fixed z-50 min-w-[160px] overflow-hidden rounded-lg border bg-popover p-1 text-popover-foreground shadow-xl animate-in fade-in-0 zoom-in-95 ${className}`}
      style={{
        top: position.top + sideOffset,
        left: align === 'end' ? position.left - 160 : position.left,
        zIndex: 9999,
      }}
    >
      {children}
    </div>
  );
}

export function DropdownMenuItem({ children, className = '', onSelect, ...props }) {
  const { setOpen } = React.useContext(DropdownMenuContext);

  return (
    <div
      className={`relative flex cursor-pointer select-none items-center rounded-md px-3 py-2.5 text-sm outline-none transition-colors hover:bg-accent hover:text-accent-foreground ${className}`}
      onClick={(e) => {
        e.stopPropagation();
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
    <div className={`px-3 py-2 text-sm font-semibold ${className}`} {...props}>
      {children}
    </div>
  );
}
