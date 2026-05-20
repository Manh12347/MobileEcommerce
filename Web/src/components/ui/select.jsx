import React, { useState, useRef, useEffect } from 'react';

export function Select({ children, value, onValueChange, className = '', ...props }) {
  const [open, setOpen] = useState(false);

  return (
    <div className={`relative ${className}`}>
      <SelectContext.Provider value={{ open, setOpen, value, onValueChange }}>
        <div onClick={() => setOpen(!open)} {...props}>
          {React.Children.map(children, child => {
            if (child?.type === SelectTrigger) return React.cloneElement(child, { open });
            return child;
          })}
        </div>
      </SelectContext.Provider>
    </div>
  );
}

const SelectContext = React.createContext();

export function SelectTrigger({ children, open, className = '', ...props }) {
  return (
    <button
      type="button"
      className={`flex h-10 w-full items-center justify-between rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring disabled:cursor-not-allowed disabled:opacity-50 ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}

export function SelectValue({ placeholder }) {
  const { value } = React.useContext(SelectContext);
  return <span>{value || placeholder}</span>;
}

export function SelectContent({ children, className = '', ...props }) {
  const { open, setOpen } = React.useContext(SelectContext);
  const ref = useRef(null);

  useEffect(() => {
    function handleClickOutside(event) {
      if (ref.current && !ref.current.contains(event.target)) {
        setOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [setOpen]);

  if (!open) return null;

  return (
    <div
      ref={ref}
      className={`absolute z-50 mt-1 max-h-60 w-full overflow-auto rounded-md border bg-popover p-1 text-popover-foreground shadow-lg animate-in fade-in-0 zoom-in-95 ${className}`}
      {...props}
    >
      {children}
    </div>
  );
}

export function SelectItem({ children, value, className = '', ...props }) {
  const { value: selectedValue, onValueChange, setOpen } = React.useContext(SelectContext);

  return (
    <div
      className={`relative flex w-full cursor-pointer select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none hover:bg-accent hover:text-accent-foreground ${selectedValue === value ? 'bg-accent' : ''} ${className}`}
      onClick={() => {
        onValueChange(value);
        setOpen(false);
      }}
      {...props}
    >
      <span className="absolute left-2 flex h-3.5 w-3.5 items-center justify-center">
        {selectedValue === value && (
          <svg width="15" height="15" viewBox="0 0 15 15" fill="none">
            <path d="M11.4669 3.72684C11.7558 3.91574 11.8369 4.30308 11.648 4.59198L7.39799 11.092C7.29783 11.2452 7.13556 11.3467 6.95402 11.3699C6.77247 11.3931 6.58989 11.3355 6.45446 11.2124L3.70446 8.71241C3.44905 8.48022 3.43023 8.08494 3.66242 7.82953C3.89461 7.57412 4.28989 7.55529 4.5453 7.78749L6.75292 9.79441L10.6018 3.90792C10.7907 3.61902 11.178 3.53795 11.4669 3.72684Z" fill="currentColor" fillRule="evenodd" clipRule="evenodd"></path>
          </svg>
        )}
      </span>
      {children}
    </div>
  );
}
