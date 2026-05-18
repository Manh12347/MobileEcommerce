import React from 'react';

export const Checkbox = React.forwardRef(
  ({ className = '', ...props }, ref) => (
    <input
      ref={ref}
      type="checkbox"
      className={`h-4 w-4 rounded border border-border bg-background cursor-pointer accent-primary ${className}`}
      {...props}
    />
  )
);

Checkbox.displayName = 'Checkbox';
