import React from "react";

export function Card({
  className = "",
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={[
        "rounded-xl border border-slate-200 bg-white shadow-sm",
        className,
      ]
        .join(" ")
        .trim()}
      {...props}
    />
  );
}

export function CardHeader({
  className = "",
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={["p-5", className].join(" ").trim()} {...props} />;
}

export function CardTitle({
  className = "",
  ...props
}: React.HTMLAttributes<HTMLHeadingElement>) {
  return (
    <h3
      className={["text-sm font-semibold text-slate-900", className]
        .join(" ")
        .trim()}
      {...props}
    />
  );
}

export function CardContent({
  className = "",
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={["px-5 pb-5", className].join(" ").trim()} {...props} />;
}

export default Card;
