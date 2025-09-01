"use client";

import { useEffect, useState } from "react";

type Row = Record<string, any>;

export default function MonitorStocksPage() {
  const [list, setList] = useState<Row[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");
  const [info, setInfo] = useState<string>("");

  // Add form
  const [newCode, setNewCode] = useState("");

  // Edit state
  const [editIdx, setEditIdx] = useState<number | null>(null);
  const [editCode, setEditCode] = useState("");
  const [editPriority, setEditPriority] = useState<string>("");
  const [editNotes, setEditNotes] = useState("");

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  useEffect(() => {
    setLoading(true);
    fetch(`${baseUrl}/api/monitor-stocks`)
      .then(r => r.ok ? r.json() : [])
      .then((a) => { setList(a||[]); })
      .catch(e => setError(String(e)))
      .finally(()=>setLoading(false));
  }, [baseUrl]);

  // Helpers to infer legacy column names
  const getCodeKey = (rows: Row[]) => rows?.[0] ? (Object.keys(rows[0]).find(k => /ASX|StockCode|Code/i.test(k)) || Object.keys(rows[0])[0]) : "Code";
  const getPriorityKey = (rows: Row[]) => rows?.[0] ? (Object.keys(rows[0]).find(k => /priority/i.test(k)) || "PriorityLevel") : "PriorityLevel";
  const getNotesKey = (rows: Row[]) => rows?.[0] ? (Object.keys(rows[0]).find(k => /note/i.test(k)) || "Notes") : "Notes";

  const refresh = () => {
    setLoading(true);
    fetch(`${baseUrl}/api/monitor-stocks`)
      .then(r => r.ok ? r.json() : [])
      .then((a) => { setList(a||[]); })
      .catch(e => setError(String(e)))
      .finally(()=>setLoading(false));
  };

  const addCode = async () => {
    setError(""); setInfo("");
    if (!newCode.trim()) return;
    const code = newCode.trim();
    const res = await fetch(`${baseUrl}/api/monitor-stocks`, {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ code })});
    if (!res.ok) {
      const msg = await res.text().catch(()=>"");
      setError(`Add failed: HTTP ${res.status}${msg?` - ${msg}`:""}`);
      return;
    }
    setInfo(`Added ${code.toUpperCase()} to watchlist`); setNewCode(""); refresh();
  };

  const startEdit = (idx: number) => {
    const rows = list; const row = rows[idx];
    const codeKey = getCodeKey(rows), prKey = getPriorityKey(rows), ntKey = getNotesKey(rows);
    setEditIdx(idx);
    setEditCode(String(row[codeKey] ?? ""));
    setEditPriority(String(row[prKey] ?? ""));
    setEditNotes(String(row[ntKey] ?? ""));
  };

  const saveEdit = async () => {
    if (editIdx == null) return;
    const rows = list; const row = rows[editIdx];
    const codeKey = getCodeKey(rows);
    const original = String(row[codeKey]);
    const payload = { codeNew: editCode || null, priorityLevel: editPriority!=="" ? Number(editPriority) : null, notes: editNotes || null };
    const res = await fetch(`${baseUrl}/api/monitor-stocks/${encodeURIComponent(original)}`, {method:'PUT', headers:{'Content-Type':'application/json'}, body: JSON.stringify(payload)});
    if (!res.ok) {
      const msg = await res.text().catch(()=>"");
      setError(`Update failed: HTTP ${res.status}${msg?` - ${msg}`:""}`);
      return;
    }
    const target = editCode || original;
    setInfo(`Updated ${original.toUpperCase()} → ${target.toUpperCase()}`); setEditIdx(null); refresh();
  };

  const cancelEdit = () => { setEditIdx(null); };

  const deleteRow = async (idx: number) => {
    const rows = list; const row = rows[idx];
    const codeKey = getCodeKey(rows);
    const code = String(row[codeKey]);
    if (!window.confirm(`Delete ${code.toUpperCase()} from watchlist?`)) return;
    const res = await fetch(`${baseUrl}/api/monitor-stocks/${encodeURIComponent(code)}`, {method:'DELETE'});
    if (!res.ok) { const msg = await res.text().catch(()=>""); setError(`Delete failed: HTTP ${res.status}${msg?` - ${msg}`:""}`); return; }
    setInfo(`Deleted ${code.toUpperCase()} from watchlist`); refresh();
  };

  const renderTable = (rows: Row[]) => {
    const codeKey = getCodeKey(rows);
    const prKey = getPriorityKey(rows);
    const ntKey = getNotesKey(rows);
    return (
      <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto">
        <table className="min-w-full text-sm">
          <thead className="bg-white text-slate-600 uppercase text-[11px] tracking-wide border-b border-slate-200">
            <tr>
              {(rows?.[0] ? Object.keys(rows[0]) : ["No data"]).map((k) => (
                <th key={k} className="px-3 py-3 text-left font-medium whitespace-nowrap">{k}</th>
              ))}
              {rows.length>0 && <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Actions</th>}
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr><td className="px-3 py-3" colSpan={99}>No data.</td></tr>
            ) : rows.map((r, i) => (
              <tr key={i} className={`${i%2?"bg-slate-50":""}`}>
                {editIdx===i ? (
                  <>
                    {Object.keys(rows[0]).map((k) => {
                      if (k===codeKey) return <td key={k} className="px-3 py-2 border-b border-slate-100"><input className="w-40 rounded-md border border-slate-300 px-2 py-1" value={editCode} onChange={e=>setEditCode(e.target.value)} /></td>;
                      if (k===prKey) return <td key={k} className="px-3 py-2 border-b border-slate-100"><input className="w-24 rounded-md border border-slate-300 px-2 py-1" value={editPriority} onChange={e=>setEditPriority(e.target.value)} /></td>;
                      if (k===ntKey) return <td key={k} className="px-3 py-2 border-b border-slate-100"><input className="w-80 rounded-md border border-slate-300 px-2 py-1" value={editNotes} onChange={e=>setEditNotes(e.target.value)} /></td>;
                      return <td key={k} className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{String(r[k] ?? "")}</td>;
                    })}
                    <td className="px-3 py-2 border-b border-slate-100">
                      <button type="button" onClick={saveEdit} className="mr-2 rounded-md bg-emerald-600 text-white px-3 py-1 text-xs">Save</button>
                      <button type="button" onClick={cancelEdit} className="rounded-md border border-slate-300 px-3 py-1 text-xs">Cancel</button>
                    </td>
                  </>
                ) : (
                  <>
                    {Object.keys(rows[0]).map((k) => (
                      <td key={k} className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{String(r[k] ?? "")}</td>
                    ))}
                    <td className="px-3 py-2 border-b border-slate-100">
                      <button
                        type="button"
                        onClick={()=>startEdit(i)}
                        className="mr-2 inline-flex h-8 w-20 items-center justify-center rounded-md border border-slate-300 text-xs"
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        onClick={()=>deleteRow(i)}
                        className="inline-flex h-8 w-20 items-center justify-center rounded-md bg-red-600 text-xs text-white"
                      >
                        Delete
                      </button>
                    </td>
                  </>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  };

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-emerald-500 to-green-600 bg-clip-text text-transparent">Monitor Stocks</h1>
        {error && (
          <div className="mb-4 flex items-start gap-2 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800" role="alert">
            <svg viewBox="0 0 24 24" className="mt-[2px] h-5 w-5 fill-red-500"><path d="M12 2c5.52 0 10 4.48 10 10s-4.48 10-10 10S2 17.52 2 12 6.48 2 12 2Zm1 14v2h-2v-2h2Zm0-10v8h-2V6h2Z"/></svg>
            <div>{error}</div>
          </div>
        )}
        {info && (
          <div className="mb-4 flex items-start gap-2 rounded-md border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-800" role="status">
            <svg viewBox="0 0 24 24" className="mt-[2px] h-5 w-5 fill-emerald-600"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm-1 14-4-4 1.41-1.41L11 12.17l4.59-4.58L17 9l-6 7Z"/></svg>
            <div>{info}</div>
          </div>
        )}
        {loading && <div className="mb-4 text-sm">Loading…</div>}

        <div className="mb-6 flex items-end gap-3">
          <div>
            <label className="block text-sm mb-1 text-slate-600">Add stock code</label>
            <input value={newCode} onChange={e=>setNewCode(e.target.value)} placeholder="e.g. 14D.AX" className="rounded-md border border-slate-300 bg-white px-3 py-2 text-sm" />
          </div>
          <button type="button" onClick={addCode} className="h-9 rounded-md bg-emerald-600 text-white px-4 text-sm">Add</button>
        </div>

        <h2 className="text-lg font-medium mb-2">Watchlist</h2>
        {renderTable(list)}
      </div>
    </div>
  );
}


