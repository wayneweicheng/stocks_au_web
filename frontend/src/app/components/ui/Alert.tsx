import React from "react";

type Variant = "info" | "success" | "warning" | "danger";

const variants: Record<Variant, string> = {
  info: "border-indigo-200 bg-indigo-50 text-indigo-900",
  success: "border-emerald-200 bg-emerald-50 text-emerald-900",
  warning: "border-amber-200 bg-amber-50 text-amber-900",
  danger: "border-red-200 bg-red-50 text-red-900",
};

export default function Alert({
  variant = "info",
  className = "",
  ...props
}: React.HTMLAttributes<HTMLDivElement> & { variant?: Variant }) {
  return (
    <div
      role="alert"
      className={[
        "rounded-lg border px-4 py-3 text-sm",
        variants[variant],
        className,
      ]
        .join(" ")
        .trim()}
      {...props}
    />
  );
}
