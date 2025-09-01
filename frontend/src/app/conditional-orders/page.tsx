"use client";

import { useEffect, useState } from "react";

interface ConditionalOrder {
  id?: number;
  order_type: string;
  stock_code: string;
  trade_account_name: string;
  order_price_type: string;
  order_price?: number;
  price_buffer_ticks?: number;
  volume_gt?: number;
  order_volume?: number;
  order_value?: number;
  valid_until?: string;
  additional_settings?: string;
  created_date?: string;
}

const ORDER_TYPES = [
  "Sell Open Price Advantage",
  "Sell Close Price Advantage", 
  "Sell at bid above",
  "Sell at bid under",
  "Buy Open Price Advantage",
  "Buy Close Price Advantage",
  "Buy at ask above", 
  "Buy at bid under"
];

const ORDER_PRICE_TYPES = ["Price", "SMA"];

export default function ConditionalOrdersPage() {
  const [orders, setOrders] = useState<ConditionalOrder[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");
  const [message, setMessage] = useState<string>("");
  
  const [formData, setFormData] = useState<ConditionalOrder>({
    order_type: "Sell Open Price Advantage",
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
    load();
  }, [baseUrl]);

  useEffect(() => {
    if (formData.order_type === "Sell Close Price Advantage") {
      setFormData(prev => ({
        ...prev, 
        order_volume: 0,
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
    
    try {
      const response = await fetch(`${baseUrl}/api/conditional-orders`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(formData),
      });
      
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      
      const result = await response.json();
      setMessage(result.message);
      const getDefaultValidUntil = () => {
        const date = new Date();
        date.setDate(date.getDate() + 60);
        return date.toISOString().slice(0, 10);
      };
      
      setFormData({
        order_type: "Sell Open Price Advantage",
        stock_code: "",
        trade_account_name: "huanw2114",
        order_price_type: "Price",
        price_buffer_ticks: 0,
        volume_gt: 0,
        valid_until: getDefaultValidUntil(),
      });
      loadOrders();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Unknown error');
    }
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
          <h2 className="text-xl font-semibold mb-4">Create New Conditional Order</h2>
          
          <form onSubmit={handleSubmit} className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div>
              <label className="block text-sm mb-1 text-slate-600">Choose Order Type</label>
              <select
                value={formData.order_type}
                onChange={(e) => setFormData({...formData, order_type: e.target.value})}
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {ORDER_TYPES.map((type) => (
                  <option key={type} value={type}>{type}</option>
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
                value={formData.order_price || ""}
                onChange={(e) => setFormData({...formData, order_price: e.target.value ? parseFloat(e.target.value) : undefined})}
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
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
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
                value={formData.order_value || ""}
                onChange={(e) => setFormData({...formData, order_value: e.target.value ? parseFloat(e.target.value) : undefined})}
                disabled={formData.order_type === "Sell Close Price Advantage"}
                className={`w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40 ${
                  formData.order_type === "Sell Close Price Advantage" 
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

            <div className="sm:col-span-2 lg:col-span-3">
              <button
                type="submit"
                className="rounded-md bg-blue-500 px-4 py-2 text-sm font-medium text-white hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-400/40"
              >
                Save Conditional Order
              </button>
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
                        <button
                          onClick={() => handleDelete(order.id!)}
                          className="text-red-600 hover:text-red-800 text-sm"
                        >
                          Delete
                        </button>
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