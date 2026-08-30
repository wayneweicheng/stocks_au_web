import React from "react";

type Variant = "primary" | "secondary" | "ghost" | "danger";
type Size = "sm" | "md";

export type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant; size?: Size };

const base = "inline-flex items-center justify-center gap-2 rounded-lg font-semibold transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50";
const variants: Record<Variant, string> = {
  primary: "bg-indigo-600 text-white shadow-sm hover:bg-indigo-700",
  secondary: "border border-slate-200 bg-white text-slate-800 shadow-sm hover:bg-slate-50",
  ghost: "bg-transparent text-slate-700 hover:bg-slate-100",
  danger: "bg-red-600 text-white shadow-sm hover:bg-red-700",
};
const sizes: Record<Size, string> = { sm: "h-9 px-3 text-xs", md: "h-10 px-4 text-sm" };

export default function Button({ variant = "primary", size = "md", className = "", ...props }: ButtonProps) {
  return <button className={[base, variants[variant], sizes[size], className].join(" ").trim()} {...props} />;
}
