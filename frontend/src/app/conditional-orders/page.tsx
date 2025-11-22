"use client";

import { useEffect, useState } from "react";

interface ConditionalOrder {
  id?: number;
  order_type: string;
  stock_code: string;
  trade_account_name: string;
  order_price_type: string;
  order_price?: number;
  difference_to_current_price?: string | number;
  price_buffer_ticks?: number;
  volume_gt?: number;
  order_volume?: number;
  order_value?: number;
  valid_until?: string;
  additional_settings?: string;
  created_date?: string;
}

type OrderTypeOption = { id: number; name: string };

const ORDER_PRICE_TYPES = ["Price", "SMA"];
const LAST_ORDER_TYPE_KEY = "conditionalOrders.lastOrderType";

function getStoredOrderType(): string | null {
  try {
    if (typeof window === "undefined") return null;
    const v = window.localStorage.getItem(LAST_ORDER_TYPE_KEY);
    return v && v.trim().length > 0 ? v : null;
  } catch {
    return null;
  }
}

function setStoredOrderType(value: string) {
  try {
    if (typeof window === "undefined") return;
    window.localStorage.setItem(LAST_ORDER_TYPE_KEY, value);
  } catch {
    // ignore storage errors
  }
}

export default function ConditionalOrdersPage() {
  const [orders, setOrders] = useState<ConditionalOrder[]>([]);
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string>("");
  const [message, setMessage] = useState<string>("");
  const [editingOrderId, setEditingOrderId] = useState<number | null>(null);
  const [orderTypes, setOrderTypes] = useState<OrderTypeOption[]>([]);

  const getInitialOrderType = () => getStoredOrderType() || "Sell Open Price Advantage";

  const [formData, setFormData] = useState<ConditionalOrder>({
    order_type: getInitialOrderType(),
    stock_code: "",
    trade_account_name: "huanw2114",
    order_price_type: "Price",
    price_buffer_ticks: 0,
    volume_gt: 0,
    valid_until: "",
  });

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  useEffect(() => {
    const getDefaultValidUntil = () => {
      const date = new Date();
      date.setDate(date.getDate() + 60);
      return date.toISOString().slice(0, 10);
    };

    setFormData(prev => ({...prev, valid_until: getDefaultValidUntil(), price_buffer_ticks: 0}));

    const load = async () => {
      try {
        setLoading(true);
        const response = await fetch(`${baseUrl}/api/conditional-orders`);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        setOrders(data);
      } catch (e: unknown) {
        setError(e instanceof Error ? e.message : 'Unknown error');
      } finally {
        setLoading(false);
      }
    };
    const loadOrderTypes = async () => {
      try {
        const res = await fetch(`${baseUrl}/api/conditional-orders/order-types`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        // Filter out any placeholder type like All Orders (id -1)
        const filtered = Array.isArray(data)
          ? data.filter((x: any) => typeof x?.id === 'number' && x.id > 0 && typeof x?.name === 'string')
          : [];
        setOrderTypes(filtered.map((x: any) => ({ id: x.id, name: x.name })));
        // Apply stored selection if valid, else keep current if valid, else fallback to first
        const stored = getStoredOrderType();
        if (stored && filtered.some((x: any) => x.name === stored)) {
          setFormData(prev => ({ ...prev, order_type: stored }));
        } else {
          const current = formData.order_type || "";
          if (!filtered.some((x: any) => x.name === current)) {
            const first = filtered[0];
            if (first) {
              setFormData(prev => ({ ...prev, order_type: first.name }));
            }
          }
        }
      } catch (e: unknown) {
        // Keep UI usable even if SP fails
      }
    };
    load();
    loadOrderTypes();
  }, [baseUrl]);

  useEffect(() => {
    const isBuyOrder = formData.order_type.startsWith("Buy");
    const isSellOrder = formData.order_type.startsWith("Sell");

    if (formData.order_type === "Sell Close Price Advantage") {
      setFormData(prev => ({
        ...prev,
        order_volume: 0,
        order_value: undefined
      }));
    } else if (isBuyOrder) {
      // For buy orders, clear order_volume
      setFormData(prev => ({
        ...prev,
        order_volume: undefined
      }));
    } else if (isSellOrder) {
      // For sell orders, clear order_value
      setFormData(prev => ({
        ...prev,
        order_value: undefined
      }));
    }
  }, [formData.order_type]);

  const loadOrders = async () => {
    try {
      setLoading(true);
      const response = await fetch(`${baseUrl}/api/conditional-orders`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      setOrders(data);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setMessage("");
    setSubmitting(true);

    try {
      let response;

      // Normalize stock code: ensure .AX suffix if missing
      const normalized = (formData.stock_code || "").trim().toUpperCase();
      const stockCode = normalized.endsWith(".AX") ? normalized : `${normalized}.AX`;
      const payload = { ...formData, stock_code: stockCode } as any;

      if (editingOrderId) {
        // Update existing order - call PUT endpoint
        response = await fetch(`${baseUrl}/api/conditional-orders/${editingOrderId}`, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
      } else {
        // Create new order - call POST endpoint
        response = await fetch(`${baseUrl}/api/conditional-orders`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
      }

      if (!response.ok) throw new Error(`HTTP ${response.status}`);

      const result = await response.json();
      setMessage(result.message);

      // Persist the last used order type for next order
      setStoredOrderType(formData.order_type);

      // Reset form and editing state (preserve last used order_type)
      const getDefaultValidUntil = () => {
        const date = new Date();
        date.setDate(date.getDate() + 60);
        return date.toISOString().slice(0, 10);
      };

      const lastType = getStoredOrderType() || formData.order_type;

      setEditingOrderId(null);
      setFormData({
        order_type: lastType,
        stock_code: "",
        trade_account_name: "huanw2114",
        order_price_type: "Price",
        order_price: undefined,
        price_buffer_ticks: 0,
        volume_gt: 0,
        order_volume: undefined,
        order_value: undefined,
        valid_until: getDefaultValidUntil(),
        additional_settings: "",
      });
      loadOrders();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Unknown error');
    } finally {
      setSubmitting(false);
    }
  };

  const handleEdit = (order: ConditionalOrder) => {
    setEditingOrderId(order.id || null);
    setFormData({
      id: order.id,
      order_type: order.order_type,
      stock_code: order.stock_code,
      trade_account_name: order.trade_account_name,
      order_price_type: order.order_price_type,
      order_price: order.order_price,
      price_buffer_ticks: order.price_buffer_ticks,
      volume_gt: order.volume_gt,
      order_volume: order.order_volume,
      order_value: order.order_value,
      valid_until: order.valid_until,
      additional_settings: order.additional_settings,
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleCancelEdit = () => {
    setEditingOrderId(null);
    const getDefaultValidUntil = () => {
      const date = new Date();
      date.setDate(date.getDate() + 60);
      return date.toISOString().slice(0, 10);
    };
    const lastType = getStoredOrderType() || formData.order_type || "Sell Open Price Advantage";
    setFormData({
      order_type: lastType,
      stock_code: "",
      trade_account_name: "huanw2114",
      order_price_type: "Price",
      order_price: undefined,
      price_buffer_ticks: 0,
      volume_gt: 0,
      order_volume: undefined,
      order_value: undefined,
      valid_until: getDefaultValidUntil(),
      additional_settings: "",
    });
  };

  const handleDelete = async (orderId: number) => {
    if (!confirm("Are you sure you want to delete this conditional order?")) return;

    try {
      const response = await fetch(`${baseUrl}/api/conditional-orders/${orderId}`, {
        method: "DELETE",
      });

      if (!response.ok) throw new Error(`HTTP ${response.status}`);

      const result = await response.json();
      setMessage(result.message);
      loadOrders();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Unknown error');
    }
  };

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-blue-500 to-indigo-600 bg-clip-text text-transparent">
          Manage Conditional Orders
        </h1>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
            Error: {error}
          </div>
        )}

        {message && (
          <div className="mb-4 rounded-md border border-green-200 bg-green-50 text-green-700 px-3 py-2 text-sm">
            {message}
          </div>
        )}

        <div className="rounded-lg border border-slate-200 bg-white p-6 mb-6">
          <h2 className="text-xl font-semibold mb-4">
            {editingOrderId ? "Edit Conditional Order" : "Create New Conditional Order"}
          </h2>

          <form onSubmit={handleSubmit} className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div>
              <label className="block text-sm mb-1 text-slate-600">Choose Order Type</label>
              <select
                value={formData.order_type}
                onChange={(e) => {
                  const next = e.target.value;
                  setFormData({...formData, order_type: next});
                  setStoredOrderType(next);
                }}
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {orderTypes.map((t) => (
                  <option key={t.id} value={t.name}>{t.name}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Stock Code</label>
              <input
                type="text"
                value={formData.stock_code}
                onChange={(e) => setFormData({...formData, stock_code: e.target.value})}
                required
                placeholder="e.g., CBA"
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Trade Account</label>
              <input
                type="text"
                value={formData.trade_account_name}
                onChange={(e) => setFormData({...formData, trade_account_name: e.target.value})}
                required
                readOnly
                className="w-full rounded-md border border-slate-300 bg-slate-50 px-3 py-2 text-sm focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Order Price Type</label>
              <select
                value={formData.order_price_type}
                onChange={(e) => setFormData({...formData, order_price_type: e.target.value})}
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {ORDER_PRICE_TYPES.map((type) => (
                  <option key={type} value={type}>{type}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Order Price</label>
              <input
                type="number"
                step="0.01"
                value={formData.order_price ?? ""}
                onChange={(e) => setFormData({...formData, order_price: e.target.value === "" ? undefined : parseFloat(e.target.value)})}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Price Buffer (Ticks)</label>
              <input
                type="number"
                value={formData.price_buffer_ticks || 0}
                onChange={(e) => setFormData({...formData, price_buffer_ticks: e.target.value ? parseInt(e.target.value) : 0})}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Custom Integer Value</label>
              <input
                type="number"
                value={formData.volume_gt ?? 0}
                onChange={(e) => setFormData({...formData, volume_gt: e.target.value ? parseInt(e.target.value) : 0})}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Order Volume</label>
              <input
                type="number"
                value={formData.order_volume ?? ""}
                onChange={(e) => setFormData({...formData, order_volume: e.target.value ? parseInt(e.target.value) : undefined})}
                disabled={formData.order_type.startsWith("Buy")}
                className={`w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40 ${
                  formData.order_type.startsWith("Buy")
                    ? "bg-slate-100 text-slate-500 cursor-not-allowed"
                    : "bg-white"
                }`}
              />
              {formData.order_type === "Sell Close Price Advantage" && (
                <p className="text-xs text-slate-500 mt-1">0 = Sell all volume held for this stock</p>
              )}
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Order Value</label>
              <input
                type="number"
                step="0.01"
                value={formData.order_value ?? ""}
                onChange={(e) => setFormData({...formData, order_value: e.target.value === "" ? undefined : parseFloat(e.target.value)})}
                disabled={formData.order_type.startsWith("Sell")}
                className={`w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40 ${
                  formData.order_type.startsWith("Sell")
                    ? "bg-slate-100 text-slate-500 cursor-not-allowed"
                    : "bg-white"
                }`}
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Valid Until</label>
              <input
                type="date"
                value={formData.valid_until || ""}
                onChange={(e) => setFormData({...formData, valid_until: e.target.value})}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div className="sm:col-span-2 lg:col-span-3">
              <label className="block text-sm mb-1 text-slate-600">Additional Settings</label>
              <textarea
                value={formData.additional_settings || ""}
                onChange={(e) => setFormData({...formData, additional_settings: e.target.value})}
                rows={3}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div className="sm:col-span-2 lg:col-span-3 flex gap-2">
              <button
                type="submit"
                disabled={submitting}
                className="rounded-md bg-blue-500 px-4 py-2 text-sm font-medium text-white hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-400/40 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
              >
                {submitting && (
                  <div className="h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                )}
                {submitting
                  ? (editingOrderId ? "Updating..." : "Creating...")
                  : (editingOrderId ? "Update Order" : "Create Order")
                }
              </button>
              {editingOrderId && (
                <button
                  type="button"
                  onClick={handleCancelEdit}
                  disabled={submitting}
                  className="rounded-md bg-gray-500 px-4 py-2 text-sm font-medium text-white hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-gray-400/40 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Cancel
                </button>
              )}
            </div>
          </form>
        </div>

        <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto relative">
          <h2 className="text-xl font-semibold p-6 pb-0">Existing Conditional Orders</h2>
          
          {loading && (
            <div className="absolute inset-0 bg-white/60 backdrop-blur-sm flex items-center justify-center z-10">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-blue-300/40 border-t-blue-500" />
            </div>
          )}
          
          {orders.length === 0 ? (
            <div className="p-6 text-center text-slate-500">No conditional orders found.</div>
          ) : (
            <table className="min-w-full text-sm">
              <thead className="sticky top-0 z-10 bg-white text-slate-600 uppercase text-[11px] tracking-wide border-b border-slate-200">
                <tr>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Order Type</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Stock Code</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Account</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Price Type</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Price</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Diff to Current</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Buffer Ticks</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Custom Integer</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Order Volume</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Order Value</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Valid Until</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Created</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Actions</th>
                </tr>
              </thead>
              <tbody>
                {orders.map((order, i) => (
                  <tr key={order.id || i} className={`transition-colors ${i % 2 ? "bg-slate-50" : ""} hover:bg-blue-50/40`}>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{order.order_type || "-"}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100 font-medium">{order.stock_code}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{order.trade_account_name}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{order.order_price_type}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{order.order_price || "-"}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{order.difference_to_current_price ?? "-"}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{order.price_buffer_ticks ?? "-"}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{order.volume_gt || "-"}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{order.order_volume || "-"}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{order.order_value || "-"}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{order.valid_until || "-"}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">
                      {order.created_date ? new Date(order.created_date).toLocaleDateString() : "-"}
                    </td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">
                      {order.id && (
                        <div className="flex gap-1">
                          <button
                            onClick={() => handleEdit(order)}
                            title="Edit order"
                            className="p-1.5 rounded hover:bg-blue-50 text-blue-600 hover:text-blue-700 transition-colors"
                          >
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
                              <path strokeLinecap="round" strokeLinejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10" />
                            </svg>
                          </button>
                          <button
                            onClick={() => handleDelete(order.id!)}
                            title="Delete order"
                            className="p-1.5 rounded hover:bg-red-50 text-red-600 hover:text-red-700 transition-colors"
                          >
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
                              <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
                            </svg>
                          </button>
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}