import React from "react";

type Variant = "default" | "success" | "warning" | "danger" | "info";
const variants: Record<Variant, string> = {
  default: "bg-slate-100 text-slate-700",
  success: "bg-emerald-100 text-emerald-800",
  warning: "bg-amber-100 text-amber-800",
  danger: "bg-red-100 text-red-800",
  info: "bg-indigo-100 text-indigo-800",
};

export default function Badge({ variant = "default", className = "", ...props }: React.HTMLAttributes<HTMLSpanElement> & { variant?: Variant }) {
  return <span className={["inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-semibold", variants[variant], className].join(" ").trim()} {...props} />;
}
