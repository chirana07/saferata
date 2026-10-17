import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  apiInvestigate,
  apiListJobs,
  apiPostJob,
  apiAddReview,
  apiRecentChecks,
  checkBackendHealth,
} from "../lib/api";

describe("SafeRata API Client", () => {
  const originalFetch = global.fetch;

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    global.fetch = originalFetch;
  });

  it("handles successful Investigate walker response", async () => {
    const mockReport = {
      status: "done",
      band: "DANGER",
      score: 75,
      flags: [
        {
          code: "TOURIST_VISA",
          title: "Tourist visa used for work",
          source: "rules",
          evidence: "Travel on tourist visa",
          points: 40,
        },
      ],
      questions: [],
      removed: [],
      prosecution: "Working on a tourist visa is unlawful.",
      defence: "Salary is reasonable.",
      judge: "Guilty of illegal recruitment methods.",
      steps: [{ agent: "Extractor", action: "extracted", detail: "Salary USD 1500" }],
      confidence: 85,
      offer_id: "off-123",
    };

    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ reports: [mockReport] }),
    } as unknown as Response);

    const { report, error } = await apiInvestigate("Test ad with tourist visa");
    expect(error).toBeNull();
    expect(report).toBeDefined();
    expect(report?.band).toBe("DANGER");
    expect(report?.flags.length).toBe(1);
    expect(report?.flags[0]?.evidence).toBe("Travel on tourist visa");
  });

  it("handles successful ListJobs walker response", async () => {
    const mockJob = {
      id: "j-1",
      title: "Electrician",
      country: "Qatar",
      salary: "QAR 2500",
      description: "Employment visa provided.",
      licence_no: "3500",
      agency_name: "ATC Global Holdings",
      contact_phone: "0112818268",
      posted_at: "2026-10-17 12:00",
      band: "LOOKS SAFE",
      score: 10,
      summary: "Clean verified listing",
      top_flags: [],
      warnings: [],
      reviews: [],
      credible_fraud_reports: 0,
    };

    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ reports: [mockJob] }),
    } as unknown as Response);

    const { jobs, error } = await apiListJobs();
    expect(error).toBeNull();
    expect(jobs).toHaveLength(1);
    expect(jobs?.[0]?.title).toBe("Electrician");
  });

  it("handles network failure gracefully", async () => {
    global.fetch = vi.fn().mockRejectedValue(new Error("Failed to fetch"));

    const { report, error } = await apiInvestigate("Sample offer");
    expect(report).toBeNull();
    expect(error).toBeDefined();
    expect(error?.isNetworkError).toBe(true);
    expect(error?.message).toContain("Cannot reach Jac backend");
  });

  it("handles HTTP 500 server errors", async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 500,
      statusText: "Internal Server Error",
      text: async () => "Walker crashed with division by zero",
    } as unknown as Response);

    const { jobs, error } = await apiListJobs();
    expect(jobs).toBeNull();
    expect(error).toBeDefined();
    expect(error?.status).toBe(500);
    expect(error?.message).toContain("HTTP 500");
  });

  it("handles malformed JSON / unexpected schema envelope", async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ wrong_key: 123 }),
    } as unknown as Response);

    const { checks, error } = await apiRecentChecks();
    expect(checks).toBeNull();
    expect(error).toBeDefined();
    expect(error?.message).toContain("Invalid response format");
  });

  it("checks backend health status", async () => {
    global.fetch = vi.fn().mockResolvedValue({ ok: true } as unknown as Response);
    const healthy = await checkBackendHealth();
    expect(healthy).toBe(true);

    global.fetch = vi.fn().mockRejectedValue(new Error("Down"));
    const down = await checkBackendHealth();
    expect(down).toBe(false);
  });

  it("safely converts backend jobs to UI jobs and resolves live job by ID without crashing", async () => {
    const { backendJobToUiJob, registerLiveJobs, getJob, getCompany } = await import("../lib/data");

    const liveJobData = {
      id: "live-job-99",
      title: "Solar Technician",
      country: "Romania",
      salary: "EUR 1200",
      description: "Work in Brasov with work permit",
      licence_no: "4401",
      agency_name: "Apex Lanka Manpower",
      contact_phone: "+94 11 234 5678",
      posted_at: "2026-10-17 14:00",
      band: "LOOKS SAFE",
      score: 12,
      summary: "Verified listing with work permit",
      top_flags: [],
      warnings: [],
      reviews: [],
      credible_fraud_reports: 0,
      salary_amount: 1200,
      salary_currency: "EUR",
      salary_lkr: 420000,
      take_home_lkr: 380000,
      worker_fee_lkr: 0,
      appeals: [],
      corrections: [],
      appealable: [],
      occupation: "Technician",
      experience_years: 2,
      contract_type: "Fixed term",
      contract_months: 24,
      accommodation: "Provided",
      deductions: "",
    };

    const uiJob = backendJobToUiJob(liveJobData);
    expect(uiJob.id).toBe("live-job-99");
    expect(uiJob.role).toBe("Solar Technician");
    expect(uiJob.salaryLkr).toBe(420000);

    // Register into live cache and retrieve
    registerLiveJobs([uiJob]);
    const retrievedJob = getJob("live-job-99");
    expect(retrievedJob).toBeDefined();
    expect(retrievedJob?.role).toBe("Solar Technician");

    // Look up company and verify safe fallback
    const agency = getCompany(uiJob.agencyId);
    expect(agency).toBeDefined();
    expect(agency.id).toBe("agency-4401");
    expect(agency.name).toBe("Apex Lanka Manpower");
    expect(agency.licenceState).toBe("verified");

    // Look up employer and verify unverified label (no invented official verification)
    const employer = getCompany(uiJob.employerId);
    expect(employer).toBeDefined();
    expect(employer.licenceState).toBe("unverified");

    // Look up completely non-existent company ID
    const randomCompany = getCompany("unknown-random-12345");
    expect(randomCompany).toBeDefined();
    expect(randomCompany.licenceState).toBe("unverified");
    expect(randomCompany.name).toContain("Unverified");
  });
});
