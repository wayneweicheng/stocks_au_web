"use client";

import { use, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import AuthWrapper from "../../../../components/AuthWrapper";
import { authenticatedFetch } from "../../../../utils/authenticatedFetch";

type SubType = {
  SubscriptionTypeID: number;
  SubscriptionTypeCode: string;
  EventType: string;
  DisplayName: string;
  Description?: string;
  RequiresTriggerValue: boolean;
  TriggerValueType?: string;
  TriggerValueMin?: number;
  TriggerValueMax?: number;
  TriggerValueUnit?: string;
  RequiresTriggerValue2?: boolean;
  TriggerValue2Type?: string;
  SupportsTextFilter: boolean;
};

const EVENT_GROUPS = [
  { key: "announcement", label: "Announcements" },
  { key: "price", label: "Price Alerts" },
  { key: "volume", label: "Volume Alerts" },
  { key: "broker_report", label: "Broker Reports" },
  { key: "technical_indicator", label: "Technical Indicators" },
  { key: "gex_insights_spxw", label: "GEX Insights SPXW" },
];

export default function NewSubscriptionPage({ params }: { params: Promise<{ userId: string }> }) {
  const { userId: userIdParam } = use(params);
  const userId = Number(userIdParam);
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [eventType, setEventType] = useState<string>("announcement");
  const [types, setTypes] = useState<SubType[]>([]);
  const [selectedTypeId, setSelectedTypeId] = useState<number | null>(null);
  const [entityCode, setEntityCode] = useState<string>("");
  const [triggerOperator, setTriggerOperator] = useState<string>("above");
  const [triggerValue, setTriggerValue] = useState<string>("");
  const [triggerValue2, setTriggerValue2] = useState<string>("");
  const [includeKeywords, setIncludeKeywords] = useState<string>("");
  const [excludeKeywords, setExcludeKeywords] = useState<string>("");
  const [priority, setPriority] = useState<number>(0);
  const [channel, setChannel] = useState<string>("");
  const [configJson, setConfigJson] = useState<string>("");
  const [isActive, setIsActive] = useState<boolean>(true);
  const [error, setError] = useState<string>("");
  const [submitting, setSubmitting] = useState<boolean>(false);

  const selectedType = useMemo(() => types.find(t => t.SubscriptionTypeID === selectedTypeId) || null, [selectedTypeId, types]);

  useEffect(() => {
    const loadTypes = async () => {
      try {
        const res = await authenticatedFetch(`${baseUrl}/api/subscription-types?eventType=${encodeURIComponent(eventType)}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const json = await res.json();
        setTypes(json);
        setSelectedTypeId(json.length ? json[0].SubscriptionTypeID : null);
      } catch (e: any) {
        setError(e?.message || "Failed to load types");
      }
    };
    loadTypes();
  }, [baseUrl, eventType]);

  const showTrigger = !!selectedType?.RequiresTriggerValue;
  const showTrigger2 = !!selectedType?.RequiresTriggerValue2;
  const showTextFilters = !!selectedType?.SupportsTextFilter;

  const tvMin = selectedType?.TriggerValueMin;
  const tvMax = selectedType?.TriggerValueMax;
  const unit = selectedType?.TriggerValueUnit || "";

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError("");
    try {
      // validate keywords JSON arrays
      let incArr: string[] | undefined = undefined;
      let excArr: string[] | undefined = undefined;
      if (includeKeywords.trim().length > 0) {
        const parsed = JSON.parse(includeKeywords);
        if (!Array.isArray(parsed)) throw new Error("Include Keywords must be JSON array");
        incArr = parsed;
      }
      if (excludeKeywords.trim().length > 0) {
        const parsed = JSON.parse(excludeKeywords);
        if (!Array.isArray(parsed)) throw new Error("Exclude Keywords must be JSON array");
        excArr = parsed;
      }
      let cfgObj: any = undefined;
      if (configJson.trim().length > 0) {
        cfgObj = JSON.parse(configJson);
      }
      const payload = {
        subscription_type_id: selectedTypeId!,
        entity_code: entityCode.trim().toUpperCase(),
        is_active: isActive,
        trigger_value: triggerValue === "" ? null : Number(triggerValue),
        trigger_value2: triggerValue2 === "" ? null : Number(triggerValue2),
        trigger_operator: triggerOperator,
        include_keywords: incArr,
        exclude_keywords: excArr,
        priority,
        notification_channel: channel || null,
        configuration_json: cfgObj,
      };
      const res = await authenticatedFetch(`${baseUrl}/api/users/${userId}/subscriptions`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      if (!res.ok) {
        const txt = await res.text();
        throw new Error(`HTTP ${res.status}: ${txt}`);
      }
      window.location.href = `/users/${userId}/subscriptions`;
    } catch (e: any) {
      setError(e?.message || "Failed to create subscription");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AuthWrapper>
      <div className="min-h-screen text-slate-800">
        <div className="mx-auto max-w-3xl px-6 py-10">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-3">
              <Link href="/users" className="text-blue-600 hover:underline">Users</Link>
              <span>/</span>
              <Link href={`/users/${userId}/subscriptions`} className="text-blue-600 hover:underline">Subscriptions</Link>
              <span>/</span>
              <span>New</span>
            </div>
            <Link href={`/users/${userId}/subscriptions`} className="text-blue-600 hover:underline">Back</Link>
          </div>
          {error && (
            <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
              Error: {error}
            </div>
          )}
          <form onSubmit={handleSubmit} className="grid gap-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="block text-sm mb-1 text-slate-600">Event Type</label>
                <select
                  value={eventType}
                  onChange={(e) => setEventType(e.target.value)}
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                >
                  {EVENT_GROUPS.map(g => (
                    <option key={g.key} value={g.key}>{g.label}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm mb-1 text-slate-600">Subscription Type</label>
                <select
                  value={selectedTypeId ?? ""}
                  onChange={(e) => setSelectedTypeId(Number(e.target.value))}
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                >
                  {types.map(t => (
                    <option key={t.SubscriptionTypeID} value={t.SubscriptionTypeID}>{t.DisplayName}</option>
                  ))}
                </select>
                {selectedType?.Description && (
                  <p className="text-xs text-slate-500 mt-1">{selectedType.Description}</p>
                )}
              </div>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="block text-sm mb-1 text-slate-600">Stock Code (e.g., KAL.AX or *)</label>
                <input
                  value={entityCode}
                  onChange={(e) => setEntityCode(e.target.value)}
                  placeholder="KAL.AX"
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                  required
                />
              </div>
              <div className="flex items-center gap-2">
                <input id="is_active" type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
                <label htmlFor="is_active" className="text-sm text-slate-700">Is Active</label>
              </div>
            </div>

            {showTrigger && (
              <div className="rounded border border-slate-200 p-3">
                <h3 className="font-medium mb-2">Trigger Configuration</h3>
                <div className="grid gap-3 sm:grid-cols-3">
                  <div>
                    <label className="block text-sm mb-1 text-slate-600">Operator</label>
                    <select
                      value={triggerOperator}
                      onChange={(e) => setTriggerOperator(e.target.value)}
                      className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                    >
                      <option value="above">above</option>
                      <option value="below">below</option>
                      <option value="equals">equals</option>
                      <option value="between">between</option>
                      <option value="change_more_than">change_more_than</option>
                      <option value="change_less_than">change_less_than</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm mb-1 text-slate-600">Trigger Value {unit && `(${unit})`}</label>
                    <input
                      type="number"
                      value={triggerValue}
                      onChange={(e) => setTriggerValue(e.target.value)}
                      min={tvMin != null ? tvMin : undefined}
                      max={tvMax != null ? tvMax : undefined}
                      className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                    />
                  </div>
                  {showTrigger2 && (
                    <div>
                      <label className="block text-sm mb-1 text-slate-600">Trigger Value 2</label>
                      <input
                        type="number"
                        value={triggerValue2}
                        onChange={(e) => setTriggerValue2(e.target.value)}
                        className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                      />
                    </div>
                  )}
                </div>
              </div>
            )}

            {showTextFilters && (
              <div className="rounded border border-slate-200 p-3">
                <h3 className="font-medium mb-2">Content Filters</h3>
                <div className="grid gap-3">
                  <div>
                    <label className="block text-sm mb-1 text-slate-600">Include Keywords (JSON array)</label>
                    <input
                      placeholder='["merger","acquisition"]'
                      value={includeKeywords}
                      onChange={(e) => setIncludeKeywords(e.target.value)}
                      className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                    />
                  </div>
                  <div>
                    <label className="block text-sm mb-1 text-slate-600">Exclude Keywords (JSON array)</label>
                    <input
                      placeholder='["daily","update"]'
                      value={excludeKeywords}
                      onChange={(e) => setExcludeKeywords(e.target.value)}
                      className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                    />
                  </div>
                </div>
              </div>
            )}

            <div className="rounded border border-slate-200 p-3">
              <h3 className="font-medium mb-2">Advanced</h3>
              <div className="grid gap-3 sm:grid-cols-3">
                <div>
                  <label className="block text-sm mb-1 text-slate-600">Priority</label>
                  <select
                    value={priority}
                    onChange={(e) => setPriority(Number(e.target.value))}
                    className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                  >
                    <option value={0}>0 - Normal</option>
                    <option value={1}>1 - High</option>
                    <option value={2}>2 - Urgent</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm mb-1 text-slate-600">Channel Override</label>
                  <select
                    value={channel}
                    onChange={(e) => setChannel(e.target.value)}
                    className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                  >
                    <option value="">(Use Default)</option>
                    <option value="Pushover">Pushover</option>
                    <option value="SMS">SMS</option>
                    <option value="Discord">Discord</option>
                    <option value="Email">Email</option>
                  </select>
                </div>
              </div>
              <div className="mt-3">
                <label className="block text-sm mb-1 text-slate-600">Configuration JSON</label>
                <textarea
                  rows={4}
                  placeholder='{"notify_on":"first_breach_only","cooldown_hours":24}'
                  value={configJson}
                  onChange={(e) => setConfigJson(e.target.value)}
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                />
              </div>
            </div>

            <div className="flex gap-2">
              <Link href={`/users/${userId}/subscriptions`} className="rounded-md bg-gray-200 text-gray-800 px-4 py-2 text-sm">Cancel</Link>
              <button type="submit" disabled={submitting} className="rounded-md bg-blue-600 text-white px-4 py-2 text-sm disabled:opacity-50">
                {submitting ? "Saving..." : "Save Subscription"}
              </button>
            </div>
          </form>
        </div>
      </div>
    </AuthWrapper>
  );
}


