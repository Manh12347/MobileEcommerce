import React from 'react';

const badgeVariants = {
  default: 'bg-primary text-primary-foreground',
  secondary: 'bg-secondary text-secondary-foreground',
  destructive: 'bg-destructive text-destructive-foreground',
  outline: 'border border-input bg-background text-foreground',
  success: 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30',
  warning: 'bg-amber-500/20 text-amber-400 border border-amber-500/30',
  info: 'bg-blue-500/20 text-blue-400 border border-blue-500/30',
};

export function Badge({ children, variant = 'default', className = '', ...props }) {
  const variantStyles = badgeVariants[variant] || badgeVariants.default;
  
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold transition-colors ${variantStyles} ${className}`}
      {...props}
    >
      {children}
    </span>
  );
}
