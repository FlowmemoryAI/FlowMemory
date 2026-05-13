import { STATUS_LABELS, statusClassName } from "../data/status";
import type { DashboardStatus } from "../data/types";

interface StatusBadgeProps {
  status: DashboardStatus;
  compact?: boolean;
}

export function StatusBadge({ status, compact = false }: StatusBadgeProps) {
  return (
    <span className={statusClassName(status)} title={STATUS_LABELS[status]}>
      <span className="status-dot" aria-hidden="true" />
      {compact ? status : STATUS_LABELS[status]}
    </span>
  );
}
