import React from 'react';

const TableContext = React.createContext();

export function Table({ children, className = '', ...props }) {
  return (
    <TableContext.Provider value={{}}>
      <div className="w-full overflow-auto">
        <table className={`w-full caption-bottom text-sm ${className}`} {...props}>
          {children}
        </table>
      </div>
    </TableContext.Provider>
  );
}

export function TableHeader({ children, className = '', ...props }) {
  return (
    <thead className={`border-b border-border bg-secondary/50 ${className}`} {...props}>
      {children}
    </thead>
  );
}

export function TableBody({ children, className = '', ...props }) {
  return (
    <tbody className={`[&_tr:last-child]:border-0 ${className}`} {...props}>
      {children}
    </tbody>
  );
}

export function TableRow({ children, className = '', ...props }) {
  return (
    <tr className={`border-b border-border transition-colors hover:bg-secondary/30 ${className}`} {...props}>
      {children}
    </tr>
  );
}

export function TableHead({ children, className = '', ...props }) {
  return (
    <th className={`h-12 px-4 text-left align-middle font-medium text-muted-foreground [&:has([role=checkbox])]:pr-0 ${className}`} {...props}>
      {children}
    </th>
  );
}

export function TableCell({ children, className = '', ...props }) {
  return (
    <td className={`p-4 align-middle [&:has([role=checkbox])]:pr-0 ${className}`} {...props}>
      {children}
    </td>
  );
}
