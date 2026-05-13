interface HashValueProps {
  value: string;
  label?: string;
  trim?: "short" | "medium" | "none";
}

function formatHash(value: string, trim: HashValueProps["trim"]): string {
  if (trim === "none" || value.length <= 18) {
    return value;
  }

  const head = trim === "short" ? 8 : 12;
  const tail = trim === "short" ? 6 : 10;
  return `${value.slice(0, head)}...${value.slice(-tail)}`;
}

export function HashValue({ value, label, trim = "medium" }: HashValueProps) {
  return (
    <span className="hash-value" title={label ? `${label}: ${value}` : value}>
      {formatHash(value, trim)}
    </span>
  );
}
