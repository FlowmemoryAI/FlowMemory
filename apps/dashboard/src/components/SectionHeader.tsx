import type { ReactNode } from "react";

interface SectionHeaderProps {
  eyebrow: string;
  title: string;
  detail: string;
  action?: ReactNode;
}

export function SectionHeader({ eyebrow, title, detail, action }: SectionHeaderProps) {
  return (
    <header className="section-header">
      <div>
        <span className="eyebrow">{eyebrow}</span>
        <h1>{title}</h1>
        <p>{detail}</p>
      </div>
      {action ? <div className="section-action">{action}</div> : null}
    </header>
  );
}

