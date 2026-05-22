import React, { useState, useRef, useEffect } from 'react';

const DropdownMenuContext = React.createContext();

export function DropdownMenu({ children }) {
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
          if (!child) return null;

          if (child.type === DropdownMenuTrigger) {
            return React.cloneElement(child, { open, onToggle: () => setOpen(!open) });
          }

          if (child.type === DropdownMenuContent) {
            return open ? React.cloneElement(child, { open, onClose: () => setOpen(false) }) : null;
          }

          return child;
        })}
      </div>
    </DropdownMenuContext.Provider>
  );
}

export function DropdownMenuTrigger({ children, open, onToggle }) {
  return React.Children.map(children, child => {
    if (!child) return null;
    return React.cloneElement(child, {
      onClick: (e) => {
        child.props.onClick?.(e);
        onToggle();
      }
    });
  });
}

export function DropdownMenuContent({ children, align = 'end', className = '', open, onClose, sideOffset = 4 }) {
  return (
    <>
      <div
        className={`absolute z-50 min-w-[160px] overflow-hidden rounded-lg border bg-popover p-1 text-popover-foreground shadow-xl ${align === 'end' ? 'right-0' : 'left-0'} ${className}`}
        style={{ top: `calc(100% + ${sideOffset}px)` }}
        onClick={onClose}
      >
        {children}
      </div>
      <div
        className={`absolute z-50 w-3 h-3 bg-popover border-r border-b border-border rotate-45 ${align === 'end' ? '-right-[7px]' : '-left-[7px]'}`}
        style={{ top: `calc(100% - 5px)` }}
      />
    </>
  );
}

export function DropdownMenuItem({ children, className = '', onSelect, ...props }) {
  const { setOpen } = React.useContext(DropdownMenuContext);

  return (
    <div
      className={`relative flex cursor-pointer select-none items-center rounded-md px-3 py-2.5 text-sm outline-none transition-colors hover:bg-accent hover:text-accent-foreground ${className}`}
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
    <div className={`px-3 py-2 text-sm font-semibold ${className}`} {...props}>
      {children}
    </div>
  );
}
