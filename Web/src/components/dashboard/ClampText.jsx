export function ClampText({ children, className = "", lines = 2, title }) {
  return (
    <span
      title={title}
      className={className}
      style={{
        display: "-webkit-box",
        WebkitBoxOrient: "vertical",
        WebkitLineClamp: lines,
        overflow: "hidden",
        whiteSpace: "normal",
        wordBreak: "break-word",
      }}
    >
      {children}
    </span>
  )
}
