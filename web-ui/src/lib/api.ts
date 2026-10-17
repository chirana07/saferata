/**
 * SafeRata API Client
 *
 * Typed communication layer with the SafeRata Jac backend (running on Jac 0.34.24).
 * Endpoints:
 *   - POST /walker/Investigate
 *   - POST /walker/ListJobs
 *   - POST /walker/PostJob
 *   - POST /walker/AddReview
 *   - POST /walker/RecentChecks
 */
import { z } from "zod";

// Base URL configured via environment variable with local fallback
export const BACKEND_URL =
  (import.meta.env as Record<string, string | undefined>)["VITE_BACKEND_URL"]?.replace(/\/$/, "") ||
  "http://localhost:8000";

// --- Schema Definitions ---

export const StepSchema = z.object({
  agent: z.string(),
  action: z.string(),
  detail: z.string(),
});
export type BackendStep = z.infer<typeof StepSchema>;

export const RedFlagSchema = z.object({
  code: z.string().optional(),
  title: z.string(),
  source: z.string(),
  points: z.number().optional(),
  evidence: z.string().default(""),
  trust: z.string().optional(),
  severity: z.string().optional(),
});
export type BackendRedFlag = z.infer<typeof RedFlagSchema>;

export const OfferFactsSchema = z.object({
  job_title: z.string().nullable().optional(),
  country: z.string().nullable().optional(),
  city: z.string().nullable().optional(),
  salary_amount: z.number().nullable().optional(),
  salary_currency: z.string().nullable().optional(),
  visa_type: z.string().nullable().optional(),
  contract_duration: z.string().nullable().optional(),
  agency_name: z.string().nullable().optional(),
  licence_no: z.string().nullable().optional(),
  employer_name: z.string().nullable().optional(),
  fee_amount: z.number().nullable().optional(),
  fee_currency: z.string().nullable().optional(),
  phones: z.array(z.string()).default([]),
  emails: z.array(z.string()).default([]),
});
export type BackendOfferFacts = z.infer<typeof OfferFactsSchema>;

export const AgencyRecordSchema = z.object({
  licence_no: z.string(),
  name: z.string(),
  phones: z.array(z.string()).default([]),
  email: z.string().default(""),
  valid_upto: z.string().default(""),
});
export type BackendAgencyRecord = z.infer<typeof AgencyRecordSchema>;

export const AdviceSchema = z.object({
  safe_to_pay: z.boolean().optional(),
  red_flags_summary: z.string().optional(),
  questions_to_ask: z.array(z.string()).default([]),
  next_steps: z.array(z.string()).default([]),
  draft_report: z.string().optional(),
});
export type BackendAdvice = z.infer<typeof AdviceSchema>;

export const CaseReportSchema = z.object({
  status: z.string(), // "done" | "needs_input" | "error"
  questions: z.array(z.string()).default([]),
  band: z.string().default(""), // "LOOKS SAFE" | "BE CAREFUL" | "DANGER"
  score: z.number().default(0),
  hard_points: z.number().optional().default(0),
  soft_points: z.number().optional().default(0),
  flags: z.array(RedFlagSchema).default([]),
  removed: z.array(z.string()).default([]),
  prosecution: z.string().default(""),
  defence: z.string().default(""),
  judge: z.string().default(""),
  advice: AdviceSchema.nullable().optional(),
  agency: AgencyRecordSchema.nullable().optional(),
  register_status: z.string().default(""),
  community: z.array(z.string()).default([]),
  alerts_sent: z.number().default(0),
  facts: OfferFactsSchema.nullable().optional(),
  steps: z.array(StepSchema).default([]),
  confidence: z.number().default(0),
  offer_id: z.string().default(""),
});
export type BackendCaseReport = z.infer<typeof CaseReportSchema>;

export const ReviewViewSchema = z.object({
  id: z.string(),
  author: z.string().default("Anonymous"),
  kind: z.string(),
  text: z.string(),
  evidence: z.string().default(""),
  credibility: z.number().default(0),
  status: z.string().default("unverified"),
  reason: z.string().default(""),
  created_at: z.string().default(""),
  agency_response: z.string().default(""),
});
export type BackendReviewView = z.infer<typeof ReviewViewSchema>;

export const JobViewSchema = z.object({
  id: z.string(),
  title: z.string(),
  country: z.string(),
  salary: z.string(),
  description: z.string(),
  licence_no: z.string(),
  agency_name: z.string(),
  contact_phone: z.string(),
  posted_at: z.string(),
  band: z.string(),
  score: z.number(),
  summary: z.string(),
  top_flags: z.array(z.string()).default([]),
  warnings: z.array(z.string()).default([]),
  reviews: z.array(ReviewViewSchema).default([]),
  credible_fraud_reports: z.number().default(0),
  occupation: z.string().default(""),
  experience_years: z.number().default(0),
  contract_type: z.string().default(""),
  contract_months: z.number().default(0),
  accommodation: z.string().default(""),
  deductions: z.string().default(""),
  salary_amount: z.number().default(0),
  salary_currency: z.string().default(""),
  salary_lkr: z.number().default(0),
  take_home_lkr: z.number().default(0),
  worker_fee_lkr: z.number().default(0),
  appeals: z.array(z.string()).default([]),
  corrections: z.array(z.string()).default([]),
  appealable: z.array(z.string()).default([]),
});
export type BackendJobView = z.infer<typeof JobViewSchema>;

export const PostResultSchema = z.object({
  ok: z.boolean(),
  message: z.string(),
  job: JobViewSchema.nullable().optional(),
  steps: z.array(StepSchema).default([]),
});
export type BackendPostResult = z.infer<typeof PostResultSchema>;

export const CheckViewSchema = z.object({
  id: z.string(),
  job: z.string(),
  country: z.string(),
  agency: z.string(),
  verdict: z.string(),
  score: z.number(),
  created_at: z.string(),
  alerts: z.array(z.string()).default([]),
});
export type BackendCheckView = z.infer<typeof CheckViewSchema>;

export interface ApiError {
  isNetworkError: boolean;
  status?: number;
  message: string;
}

// Generic request helper with timeout and envelope handling
export async function callWalker<T>(
  walkerName: string,
  payload: Record<string, unknown>,
  schema: z.ZodType<T, z.ZodTypeDef, unknown>,
  timeoutMs = 35000,
): Promise<{ data: T | null; error: ApiError | null }> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const res = await fetch(`${BACKEND_URL}/walker/${walkerName}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    clearTimeout(timer);

    if (!res.ok) {
      const errText = await res.text().catch(() => "");
      return {
        data: null,
        error: {
          isNetworkError: false,
          status: res.status,
          message: `Backend returned HTTP ${res.status}: ${errText.slice(0, 160) || res.statusText}`,
        },
      };
    }

    const json = await res.json();
    // Jac walker responses are wrapped in either { reports: [...] } or { data: { reports: [...] } }
    const rawReports = json?.data?.reports ?? json?.reports;

    if (!Array.isArray(rawReports)) {
      return {
        data: null,
        error: {
          isNetworkError: false,
          message: "Invalid response format: 'reports' array expected from walker.",
        },
      };
    }

    const parseResult = schema.safeParse(rawReports);
    if (!parseResult.success) {
      return {
        data: null,
        error: {
          isNetworkError: false,
          message: `Response schema validation failed: ${parseResult.error.issues.map((i) => i.message).join(", ")}`,
        },
      };
    }

    return { data: parseResult.data, error: null };
  } catch (err: unknown) {
    clearTimeout(timer);
    const isAbort = (err as Error)?.name === "AbortError";
    const msg = isAbort
      ? `Request timed out after ${Math.round(timeoutMs / 1000)}s. Please check if the Jac backend is running.`
      : `Cannot reach Jac backend at ${BACKEND_URL}. (Server offline or CORS blocked)`;
    return {
      data: null,
      error: {
        isNetworkError: true,
        message: msg,
      },
    };
  }
}

// --- Specific Walker Calls ---

/**
 * Investigate a job offer with the multi-agent team.
 */
export async function apiInvestigate(text: string, answers: string[] = []) {
  const res = await callWalker<[BackendCaseReport]>(
    "Investigate",
    { text, answers },
    z.tuple([CaseReportSchema]),
    45000,
  );
  if (res.error) return { report: null, error: res.error };
  return { report: res.data ? res.data[0] : null, error: null };
}

/**
 * Fetch all verified jobs posted on the SafeRata board.
 */
export async function apiListJobs() {
  const res = await callWalker<BackendJobView[]>("ListJobs", {}, z.array(JobViewSchema), 10000);
  if (res.error) return { jobs: null, error: res.error };
  return { jobs: res.data ?? [], error: null };
}

/**
 * Post a new job by a licensed agency with live licence verification.
 */
export async function apiPostJob(jobData: {
  title: string;
  country: string;
  salary: string;
  description: string;
  licence_no: string;
  contact_phone: string;
  occupation?: string;
  experience_years?: number;
  contract_type?: string;
  contract_months?: number;
  accommodation?: string;
  deductions?: string;
  monthly_deductions?: number;
  worker_fee_lkr?: number;
}) {
  const res = await callWalker<[BackendPostResult]>(
    "PostJob",
    jobData,
    z.tuple([PostResultSchema]),
    35000,
  );
  if (res.error) return { result: null, error: res.error };
  return { result: res.data ? res.data[0] : null, error: null };
}

/**
 * Add a review or fraud report on a posted job.
 */
export async function apiAddReview(reviewData: {
  job_id: string;
  author: string;
  kind: string; // e.g. "fraud", "unpaid_salary", etc.
  text: string;
  evidence: string;
}) {
  const res = await callWalker<unknown[]>("AddReview", reviewData, z.array(z.unknown()), 25000);
  if (res.error) return { result: null, error: res.error };
  return {
    result: (res.data?.[0] as BackendPostResult | { job: BackendJobView } | null) ?? null,
    error: null,
  };
}

/**
 * Fetch recent community checks and alerts from the shared graph.
 */
export async function apiRecentChecks(limit = 10) {
  const res = await callWalker<BackendCheckView[]>(
    "RecentChecks",
    { limit },
    z.array(CheckViewSchema),
    10000,
  );
  if (res.error) return { checks: null, error: res.error };
  return { checks: res.data ?? [], error: null };
}

export const AgencyViewSchema = z.object({
  id: z.string(),
  licence_no: z.string(),
  name: z.string(),
  phones: z.array(z.string()).default([]),
  email: z.string().default(""),
  valid_upto: z.string().default(""),
  checked_at: z.string().default(""),
  jobs: z.array(JobViewSchema).default([]),
  reports: z.number().default(0),
  credible_fraud: z.number().default(0),
  warnings: z.array(z.string()).default([]),
  related_checks: z.array(z.string()).default([]),
  impersonator_numbers: z.array(z.string()).default([]),
});
export type BackendAgencyView = z.infer<typeof AgencyViewSchema>;

/**
 * Fetch verified agencies from the shared graph.
 */
export async function apiListAgencies() {
  const res = await callWalker<BackendAgencyView[]>(
    "ListAgencies",
    {},
    z.array(AgencyViewSchema),
    10000,
  );
  if (res.error) return { agencies: null, error: res.error };
  return { agencies: res.data ?? [], error: null };
}

export const JobMatchSchema = z.object({
  job_id: z.string(),
  match: z.number(),
  reasons: z.array(z.string()).default([]),
  cautions: z.array(z.string()).default([]),
});
export type BackendJobMatch = z.infer<typeof JobMatchSchema>;

/**
 * Match jobs against candidate profile.
 */
export async function apiMatchJobs(profile: {
  occupation?: string;
  skills?: string[];
  destinations?: string[];
  min_salary_lkr?: number;
  experience_years?: number;
  needs_accommodation?: boolean;
}) {
  const res = await callWalker<BackendJobMatch[]>(
    "MatchJobs",
    profile,
    z.array(JobMatchSchema),
    10000,
  );
  if (res.error) return { matches: null, error: res.error };
  return { matches: res.data ?? [], error: null };
}

/**
 * Appeal a safety finding on a job posting.
 */
export async function apiAppealFinding(jobId: string, finding: string, explanation: string) {
  const res = await callWalker<BackendJobView[]>(
    "AppealFinding",
    { job_id: jobId, finding, explanation },
    z.array(JobViewSchema),
    15000,
  );
  if (res.error) return { job: null, error: res.error };
  return { job: res.data?.[0] ?? null, error: null };
}

/**
 * Check backend health/availability.
 */
export async function checkBackendHealth(): Promise<boolean> {
  try {
    const res = await fetch(`${BACKEND_URL}/walker/RecentChecks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ limit: 1 }),
      signal: AbortSignal.timeout(2500),
    });
    return res.ok;
  } catch {
    return false;
  }
}
