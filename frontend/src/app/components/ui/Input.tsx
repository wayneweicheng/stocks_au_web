import React from "react";

export default function Input({
  className = "",
  ...props
}: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={[
        "h-10 w-full rounded-md border border-slate-200 bg-white px-3 text-sm text-slate-900 shadow-sm",
        "placeholder:text-slate-400",
        "focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2",
        className,
      ]
        .join(" ")
        .trim()}
      {...props}
    />
  );
}
