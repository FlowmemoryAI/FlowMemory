import { CircleDashed } from "lucide-react";

interface EmptyStateProps {
  title: string;
  detail: string;
}

export function EmptyState({ title, detail }: EmptyStateProps) {
  return (
    <div className="empty-state" role="status">
      <CircleDashed size={22} aria-hidden="true" />
      <div>
        <h3>{title}</h3>
        <p>{detail}</p>
      </div>
    </div>
  );
}

