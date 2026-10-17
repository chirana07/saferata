import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { toast } from "sonner";
import { Upload, Check, X, AlertTriangle } from "lucide-react";
import { getCompany } from "@/lib/data";
import { apiPostJob, apiAppealFinding } from "@/lib/api";
import { useStore, setState, type AgencyListing } from "@/lib/store";
import { PageHeader, VerifyBadge, SimulatedTag } from "@/components/sr/ui";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/agency")({
  head: () => ({
    meta: [
      { title: "Agency portal — SafeRata" },
      {
        name: "description",
        content:
          "Publish transparent overseas job listings, respond to findings and manage verification.",
      },
      { property: "og:title", content: "Agency portal — SafeRata" },
      {
        property: "og:description",
        content: "Structured, verified listings for licensed recruitment agencies.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Agency,
});

const empty = {
  role: "",
  country: "",
  salary: "",
  currency: "QAR",
  visa: "",
  contract: "",
  accommodation: "",
  deductions: "",
  fee: "0",
};
const input =
  "mt-1 h-10 w-full rounded-md border border-input bg-card px-3 text-sm font-normal outline-none focus:border-primary";

function Agency() {
  const a = getCompany("lanka-horizon")!;
  const listings = useStore((s) => s.listings);
  const [f, setF] = useState(empty);
  const [files, setFiles] = useState<string[]>([]);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [appeal, setAppeal] = useState<string | null>(null);
  const [appealText, setAppealText] = useState("");

  const checks = [
    { label: "Role and destination", ok: !!f.role && !!f.country },
    { label: "Basic salary stated", ok: +f.salary > 0 },
    { label: "Employment visa (not tourist)", ok: !!f.visa && !/tourist|visit/i.test(f.visa) },
    { label: "Contract duration", ok: !!f.contract },
    { label: "Accommodation disclosed", ok: !!f.accommodation },
    { label: "Worker fee disclosed", ok: f.fee !== "" },
    { label: "Supporting document attached", ok: files.length > 0 },
  ];

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    const er: Record<string, string> = {};
    if (!f.role) er["role"] = "Required";
    if (!f.country) er["country"] = "Required";
    if (!(+f.salary > 0)) er["salary"] = "Enter a monthly amount";
    if (!f.visa) er["visa"] = "Required";
    else if (/tourist|visit/i.test(f.visa))
      er["visa"] = "Tourist or visit visas cannot be used for employment";
    if (!f.contract) er["contract"] = "Required";
    setErrors(er);
    if (Object.keys(er).length) {
      toast.error("Fix the highlighted fields");
      return;
    }

    const flagged = +f.fee > 150000;
    const l: AgencyListing = {
      id: `l${Date.now()}`,
      role: f.role,
      country: f.country,
      salary: +f.salary,
      currency: f.currency,
      visa: f.visa,
      contract: f.contract,
      fee: +f.fee,
      status: flagged ? "Correction requested" : "Under review",
      created: new Date().toISOString().slice(0, 10),
    };
    setState((s) => ({ ...s, listings: [l, ...s.listings] }));

    // Send to live Jac backend if accessible
    apiPostJob({
      title: f.role,
      country: f.country,
      salary: `${f.currency} ${f.salary}`,
      description: `Visa: ${f.visa}. Contract: ${f.contract}. Accommodation: ${f.accommodation || "Standard"}.`,
      licence_no: a.licence || "3500",
      contact_phone: "0112818268",
      accommodation: f.accommodation,
      contract_type: f.contract,
      worker_fee_lkr: +f.fee || 0,
    }).then(({ result, error }) => {
      if (result && result.ok) {
        toast.success("Live PostJob: Verified & published", {
          description: `Licence ${a.licence} verified on live SLBFE register.`,
        });
      } else if (result && !result.ok) {
        toast.error("Gatekeeper rejected", {
          description: result.message,
        });
      } else {
        toast.success(
          flagged ? "Saved locally — correction requested" : "Saved locally for review",
          {
            description: "Jac backend offline. Saved in local demo state.",
          },
        );
      }
    });

    setF(empty);
    setFiles([]);
  };

  const field = (
    k: keyof typeof empty,
    label: string,
    props: React.InputHTMLAttributes<HTMLInputElement> = {},
  ) => (
    <label className="block text-xs font-semibold">
      {label}
      <input
        value={f[k]}
        onChange={(e) => setF({ ...f, [k]: e.target.value })}
        aria-invalid={!!errors[k]}
        className={cn(input, errors[k] && "border-risk")}
        {...props}
      />
      {errors[k] && <span className="mt-1 block text-xs font-medium text-risk">{errors[k]}</span>}
    </label>
  );

  return (
    <div>
      <PageHeader eyebrow="Agency portal" title={a.name}>
        <div className="text-right text-sm">
          <p className="font-mono">{a.licence}</p>
          <div className="mt-1 flex items-center justify-end gap-2">
            <VerifyBadge state={a.licenceState} />
            <SimulatedTag>Demo account</SimulatedTag>
          </div>
        </div>
      </PageHeader>

      <div className="grid gap-8 lg:grid-cols-[1.5fr_1fr]">
        <form
          onSubmit={submit}
          className="space-y-6 rounded-xl border border-border bg-card p-6 shadow-card"
        >
          <h2 className="text-xl font-bold">New listing</h2>
          <fieldset className="grid gap-4 sm:grid-cols-2">
            <legend className="eyebrow mb-2">Role</legend>
            {field("role", "Job title")}
            {field("country", "Destination country")}
          </fieldset>
          <fieldset className="grid gap-4 sm:grid-cols-3">
            <legend className="eyebrow mb-2">Pay</legend>
            {field("salary", "Basic monthly salary", { type: "number", min: 0 })}
            <label className="block text-xs font-semibold">
              Currency
              <select
                value={f.currency}
                onChange={(e) => setF({ ...f, currency: e.target.value })}
                className={input}
              >
                {["QAR", "SAR", "AED", "KWD", "MYR", "JPY", "KRW"].map((c) => (
                  <option key={c}>{c}</option>
                ))}
              </select>
            </label>
            {field("fee", "Fee charged to worker (LKR)", { type: "number", min: 0 })}
            <div className="sm:col-span-3">
              {field("deductions", "Deductions (e.g. food 200, transport 0)")}
            </div>
          </fieldset>
          <fieldset className="grid gap-4 sm:grid-cols-2">
            <legend className="eyebrow mb-2">Visa, contract & housing</legend>
            {field("visa", "Visa category")}
            {field("contract", "Contract duration")}
            <div className="sm:col-span-2">{field("accommodation", "Accommodation")}</div>
          </fieldset>
          <div>
            <p className="eyebrow mb-2">Documents</p>
            <label className="flex cursor-pointer flex-col items-center gap-2 rounded-lg border border-dashed border-input bg-muted/50 px-4 py-6 text-center text-sm hover:border-primary">
              <Upload className="h-5 w-5 text-muted-foreground" />
              <span>
                <b>Choose files</b> — demand letter, contract template
              </span>
              <span className="text-xs text-muted-foreground">
                File names only are kept in this demo; nothing is uploaded.
              </span>
              <input
                type="file"
                multiple
                className="sr-only"
                onChange={(e) => setFiles(Array.from(e.target.files ?? []).map((x) => x.name))}
              />
            </label>
            {files.length > 0 && (
              <ul className="mt-2 text-xs">
                {files.map((n) => (
                  <li key={n} className="font-mono">
                    · {n}
                  </li>
                ))}
              </ul>
            )}
          </div>
          <p className="text-xs text-muted-foreground">
            Paid promotion affects placement only. It never changes a listing's safety assessment.
          </p>
          <button className="h-11 rounded-md bg-primary px-5 text-sm font-semibold text-primary-foreground hover:bg-primary-deep">
            Submit for verification
          </button>
        </form>

        <div className="space-y-6">
          <section className="rounded-xl border border-border bg-card p-5">
            <h2 className="font-bold">Pre-publication checklist</h2>
            <ul className="mt-3 space-y-2 text-sm">
              {checks.map((c) => (
                <li key={c.label} className="flex items-center gap-2">
                  {c.ok ? (
                    <Check className="h-4 w-4 text-safe" />
                  ) : (
                    <X className="h-4 w-4 text-muted-foreground" />
                  )}
                  <span className={c.ok ? "" : "text-muted-foreground"}>{c.label}</span>
                </li>
              ))}
            </ul>
          </section>

          <section className="rounded-xl border border-border bg-card p-5">
            <h2 className="font-bold">Your listings</h2>
            {listings.length === 0 ? (
              <p className="mt-2 text-sm text-muted-foreground">
                No listings submitted in this session.
              </p>
            ) : (
              <ul className="mt-3 divide-y divide-border">
                {listings.map((l) => (
                  <li key={l.id} className="py-3 text-sm">
                    <div className="flex items-start justify-between gap-2">
                      <span className="font-semibold">
                        {l.role} · {l.country}
                      </span>
                      <span
                        className={cn(
                          "rounded px-1.5 py-0.5 text-[11px] font-semibold",
                          l.status === "Correction requested"
                            ? "bg-caution-soft"
                            : "bg-secondary text-primary-deep",
                        )}
                      >
                        {l.status}
                      </span>
                    </div>
                    <p className="font-mono text-xs text-muted-foreground">
                      {l.currency} {l.salary.toLocaleString("en-US")} · fee LKR{" "}
                      {l.fee.toLocaleString("en-US")} · {l.created}
                    </p>
                    {l.status === "Correction requested" && (
                      <div className="mt-2 rounded-md bg-caution-soft p-3 text-xs">
                        <p className="flex items-center gap-1 font-semibold">
                          <AlertTriangle className="h-3.5 w-3.5" /> Finding: worker fee exceeds
                          typical range
                        </p>
                        {appeal === l.id ? (
                          <div className="mt-2 space-y-2">
                            <textarea
                              value={appealText}
                              onChange={(e) => setAppealText(e.target.value)}
                              rows={2}
                              placeholder="Explain and reference evidence…"
                              className="w-full rounded border border-input bg-card p-2"
                            />
                            <button
                              onClick={() => {
                                if (appealText.trim().length < 10) {
                                  toast.error("Add a short explanation");
                                  return;
                                }
                                apiAppealFinding(
                                  l.id,
                                  "worker fee exceeds typical range",
                                  appealText.trim(),
                                ).then(({ job, error }) => {
                                  if (job) {
                                    toast.success("Live Appeal submitted to Review Board", {
                                      description: `Updated status on backend: ${job.band}`,
                                    });
                                  } else {
                                    toast.success("Appeal submitted for independent review", {
                                      description: "Saved locally (backend offline).",
                                    });
                                  }
                                });
                                setState((s) => ({
                                  ...s,
                                  listings: s.listings.map((x) =>
                                    x.id === l.id ? { ...x, status: "Appeal submitted" } : x,
                                  ),
                                }));
                                setAppeal(null);
                                setAppealText("");
                              }}
                              className="rounded bg-ink px-3 py-1.5 font-semibold text-ink-foreground"
                            >
                              Send appeal
                            </button>
                          </div>
                        ) : (
                          <button
                            onClick={() => setAppeal(l.id)}
                            className="mt-1 font-semibold text-primary-deep underline"
                          >
                            Dispute this finding
                          </button>
                        )}
                      </div>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </section>

          <section className="rounded-xl border border-border bg-card p-5 text-sm">
            <h2 className="font-bold">Status legend</h2>
            <div className="mt-3 flex flex-wrap gap-2">
              {(["verified", "pending", "expired", "rejected", "unverified"] as const).map((s) => (
                <VerifyBadge key={s} state={s} />
              ))}
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}
