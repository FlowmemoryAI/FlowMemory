export function formatDateTime(value?: string): string {
  if (!value) {
    return "not recorded";
  }
  return new Date(value).toLocaleString();
}

export function formatMs(value: number): string {
  if (value >= 1000) {
    return `${(value / 1000).toFixed(1)}s`;
  }
  return `${value}ms`;
}

export function formatPercent(value?: number): string {
  if (value === undefined) {
    return "n/a";
  }
  return `${value}%`;
}
