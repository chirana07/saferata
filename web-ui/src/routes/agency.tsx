import { createFileRoute, Link } from "@tanstack/react-router";
import { useState } from "react";
import { toast } from "sonner";
import { Upload, Check, X, AlertTriangle, Loader2 } from "lucide-react";
import { getCompany, backendJobToUiJob, registerLiveJobs } from "@/lib/data";
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
  const [selectedLicence, setSelectedLicence] = useState("3500");
  const a = getCompany("lanka-horizon")!;
  const [agencyName, setAgencyName] = useState("A T C GLOBAL HOLDINGS (PVT) LTD");
  const listings = useStore((s) => s.listings);
  const [f, setF] = useState(empty);
  const [files, setFiles] = useState<string[]>([]);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [appeal, setAppeal] = useState<string | null>(null);
  const [appealText, setAppealText] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const checks = [
    { label: "Role and destination", ok: !!f.role && !!f.country },
    { label: "Basic salary stated", ok: +f.salary > 0 },
    { label: "Employment visa (not tourist)", ok: !!f.visa && !/tourist|visit/i.test(f.visa) },
    { label: "Contract duration", ok: !!f.contract },
    { label: "Accommodation disclosed", ok: !!f.accommodation },
    { label: "Worker fee disclosed", ok: f.fee !== "" },
    { label: "Supporting document attached", ok: files.length > 0 },
  ];

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (isSubmitting) return;

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

    setIsSubmitting(true);
    const flagged = +f.fee > 150000;
    const activeLicence = selectedLicence.trim() || a.licence || "3500";

    try {
      const { result, error } = await apiPostJob({
        title: f.role,
        country: f.country,
        salary: `${f.currency} ${f.salary}`,
        description: `Visa: ${f.visa}. Contract: ${f.contract}. Accommodation: ${f.accommodation || "Standard"}.`,
        licence_no: activeLicence,
        contact_phone: "0112818268",
        accommodation: f.accommodation,
        contract_type: f.contract,
        worker_fee_lkr: +f.fee || 0,
      });

      if (result && result.ok && result.job) {
        // Successfully published and verified against live SLBFE register!
        const uiJob = backendJobToUiJob(result.job);
        registerLiveJobs([uiJob]);

        // Add to agency portal listings
        const l: AgencyListing = {
          id: result.job.id,
          role: result.job.title,
          country: result.job.country,
          salary: +f.salary,
          currency: f.currency,
          visa: f.visa,
          contract: f.contract,
          fee: +f.fee,
          status: result.job.band === "DANGER" ? "Correction requested" : "Under review",
          created: new Date().toISOString().slice(0, 10),
        };
        setState((s) => ({ ...s, listings: [l, ...s.listings] }));

        toast.success("Live PostJob: Verified & published", {
          description: `Licence ${activeLicence} verified on live SLBFE register (${result.job.agency_name}).`,
        });

        setF(empty);
        setFiles([]);
      } else if (result && !result.ok) {
        toast.error("Gatekeeper rejected", {
          description: result.message || "Job could not be verified by SLBFE gatekeeper.",
        });
      } else {
        // Fallback / offline mode
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

        toast.success(
          flagged ? "Saved locally — correction requested" : "Saved locally for review",
          {
            description: error?.message || "Jac backend offline. Saved in local demo state.",
          },
        );

        setF(empty);
        setFiles([]);
      }
    } catch (err: unknown) {
      toast.error("Submission failed", {
        description: err instanceof Error ? err.message : "An unexpected error occurred.",
      });
    } finally {
      setIsSubmitting(false);
    }
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
      <PageHeader eyebrow="Agency portal" title={selectedLicence === "3500" ? "A T C GLOBAL HOLDINGS (PVT) LTD" : a.name}>
        <div className="text-right text-sm">
          <div className="flex items-center justify-end gap-2">
            <span className="text-xs text-muted-foreground font-medium">Agency Licence:</span>
            <select
              value={selectedLicence}
              onChange={(e) => {
                setSelectedLicence(e.target.value);
                if (e.target.value === "3500") {
                  setAgencyName("A T C GLOBAL HOLDINGS (PVT) LTD");
                } else if (e.target.value === "2241") {
                  setAgencyName("NEW TRANS ARABIAN (PVT) LTD");
                }
              }}
              className="rounded border border-input bg-card px-2 py-1 font-mono text-xs font-semibold focus:border-primary outline-none"
            >
              <option value="3500">Licence 3500 (A T C GLOBAL HOLDINGS)</option>
              <option value="2241">Licence 2241 (NEW TRANS ARABIAN)</option>
            </select>
          </div>
          <div className="mt-1 flex items-center justify-end gap-2">
            <VerifyBadge state="verified" />
            <span className="rounded bg-safe-soft px-1.5 py-0.5 text-[10px] font-semibold text-safe">Live SLBFE Verified</span>
          </div>
        </div>
      </PageHeader>

      <div className="grid gap-8 lg:grid-cols-[1.5fr_1fr]">
        <form
          onSubmit={submit}
          className="space-y-6 rounded-xl border border-border bg-card p-6 shadow-card"
        >
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-bold">New listing</h2>
            <span className="text-xs font-mono text-muted-foreground bg-secondary px-2 py-0.5 rounded">
              SLBFE #{selectedLicence}
            </span>
          </div>
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
          <button
            type="submit"
            disabled={isSubmitting}
            className="flex items-center justify-center gap-2 h-11 rounded-md bg-primary px-5 text-sm font-semibold text-primary-foreground hover:bg-primary-deep disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isSubmitting ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" />
                <span>Verifying licence with SLBFE & publishing…</span>
              </>
            ) : (
              "Submit for verification"
            )}
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
                      {l.id.startsWith("l") ? (
                        <span className="font-semibold">
                          {l.role} · {l.country}
                        </span>
                      ) : (
                        <Link
                          to="/jobs/$id"
                          params={{ id: l.id }}
                          className="font-semibold text-primary hover:underline"
                        >
                          {l.role} · {l.country} →
                        </Link>
                      )}
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
