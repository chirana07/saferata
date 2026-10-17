/**
 * SYNTHETIC PROTOTYPE DATA — every job, company, review and statistic here is
 * fictional and exists only to demonstrate SafeRata. No record represents a real
 * organisation, licence, or official verification result.
 */

export type VerifyState = "verified" | "pending" | "expired" | "rejected" | "unverified";
export type RiskLevel = "low" | "moderate" | "high" | "critical";
export type Provenance =
  | "Simulated official registry"
  | "Agency-disclosed"
  | "Worker report (moderated)"
  | "SafeRata analysis"
  | "Not available";

export interface Finding {
  id: string;
  severity: RiskLevel;
  kind: "confirmed" | "suspected" | "allegation" | "unavailable";
  title: string;
  excerpt?: string | undefined;
  why: string;
  source: Provenance;
}

export interface Job {
  id: string;
  role: string;
  occupation: string;
  country: string;
  city: string;
  flag: string; // ISO code
  currency: string;
  salary: number;
  salaryLkr: number;
  employerId: string;
  agencyId: string;
  visa: string;
  visaOk: boolean;
  contract: string;
  contractType: "Fixed term" | "Renewable" | "Seasonal";
  experience: number;
  posted: string; // ISO date
  verification: VerifyState;
  risk: RiskLevel;
  match: number;
  matchReasons: string[];
  fee: number | null; // LKR
  deductions: { label: string; amount: number }[];
  accommodation: string;
  description: string;
  findings: Finding[];
  featured?: boolean;
  promoted?: boolean;
}

import type { BackendJobView } from "./api";

export function backendJobToUiJob(bj: BackendJobView): Job {
  const riskLevel: RiskLevel =
    bj.band === "DANGER" ? "critical" : bj.band === "BE CAREFUL" ? "moderate" : "low";

  const agencyId = bj.licence_no
    ? `agency-${bj.licence_no.replace(/[^a-zA-Z0-9_-]/g, "_")}`
    : "backend-agency";
  const employerId = `employer-${bj.country.toLowerCase().replace(/[^a-zA-Z0-9_-]/g, "_")}`;

  // Ensure fallback company records exist
  if (!companies.find((c) => c.id === agencyId)) {
    companies.push({
      id: agencyId,
      name: bj.agency_name || "SLBFE Registered Agency",
      type: "Recruitment agency",
      location: bj.country ? `Placement partner for ${bj.country}` : "Sri Lanka",
      licence: bj.licence_no || null,
      licenceState: bj.licence_no ? "verified" : "unverified",
      lastChecked: bj.posted_at ? bj.posted_at.slice(0, 10) : new Date().toISOString().slice(0, 10),
      summary: bj.licence_no
        ? `SLBFE Licensed Agency (Licence #${bj.licence_no}). Contact phone: ${bj.contact_phone || "Not specified"}.`
        : `Agency named in listing without a verified licence number. Contact phone: ${bj.contact_phone || "Not specified"}.`,
      related: [employerId],
      reviews: [],
    });
  }

  if (!companies.find((c) => c.id === employerId)) {
    companies.push({
      id: employerId,
      name: `${bj.country} Host Employer`,
      type: "Employer",
      location: bj.country,
      licence: null,
      licenceState: "unverified",
      lastChecked: null,
      summary: `Foreign host employer in ${bj.country}. Direct verification with overseas embassy required.`,
      related: [agencyId],
      reviews: [],
    });
  }

  return {
    id: bj.id,
    role: bj.title,
    occupation: bj.occupation || "Skilled worker",
    country: bj.country,
    city: bj.country,
    flag: bj.country.slice(0, 2).toUpperCase(),
    currency: bj.salary_currency || bj.salary.split(" ")[0] || "LKR",
    salary: bj.salary_amount || 0,
    salaryLkr: bj.salary_lkr || 0,
    employerId,
    agencyId,
    visa: "Employment visa (verified)",
    visaOk: true,
    contract: bj.contract_type
      ? `${bj.contract_type} (${bj.contract_months || 24} mos)`
      : "2 years",
    contractType:
      bj.contract_type === "Renewable" || bj.contract_type === "Seasonal"
        ? bj.contract_type
        : "Fixed term",

    experience: bj.experience_years || 0,
    posted: bj.posted_at ? bj.posted_at.slice(0, 10) : new Date().toISOString().slice(0, 10),
    verification: "verified",
    risk: riskLevel,
    match: Math.max(60, 100 - bj.score),
    matchReasons: [
      `Official licence: ${bj.licence_no}`,
      `Agency: ${bj.agency_name}`,
      `Safety score: ${bj.score}/100 (${bj.band})`,
    ],
    fee: bj.worker_fee_lkr || null,
    deductions: [],
    accommodation: bj.accommodation || "Provided",
    description: bj.description,
    findings: (bj.top_flags || []).map((tf: string, i: number) => ({
      id: `live-job-${i}`,
      severity: riskLevel,
      kind: "confirmed" as const,
      title: tf,
      why: tf,
      source: "SafeRata analysis" as const,
    })),
    featured: false,
    promoted: false,
  };
}

export interface Company {
  id: string;
  name: string;
  type: "Recruitment agency" | "Employer";
  location: string;
  licence: string | null;
  licenceState: VerifyState;
  lastChecked: string | null;
  founded?: string;
  summary: string;
  related: string[];
  reviews: Review[];
  agencyResponse?: string;
}

export interface Review {
  id: string;
  date: string;
  category:
    | "Unpaid salary"
    | "Contract changes"
    | "Excessive fees"
    | "Misleading terms"
    | "Positive experience";
  status: "Moderated" | "Under review" | "Resolved" | "Disputed by agency";
  evidence: "Documented" | "Partial" | "Unsubstantiated";
  text: string;
  role: string;
}

export const companies: Company[] = [
  {
    id: "lanka-horizon",
    name: "Lanka Horizon Placements",
    type: "Recruitment agency",
    location: "Colombo 03",
    licence: "SIM-LIC-2241",
    licenceState: "verified",
    lastChecked: "2026-10-12",
    founded: "2011",
    summary:
      "Mid-sized agency placing hospitality and healthcare workers in the Gulf and Japan. Licence matched against the simulated registry.",
    related: ["al-noor-hotels", "sakura-care"],
    reviews: [
      {
        id: "r1",
        date: "2026-08-04",
        category: "Positive experience",
        status: "Moderated",
        evidence: "Documented",
        role: "Commis chef",
        text: "Fees matched the receipt. Contract on arrival was identical to the one I signed in Colombo.",
      },
      {
        id: "r2",
        date: "2026-05-19",
        category: "Contract changes",
        status: "Resolved",
        evidence: "Partial",
        role: "Housekeeping attendant",
        text: "Shift pattern changed after arrival. Agency mediated and the original roster was restored within three weeks.",
      },
    ],
    agencyResponse: "We contacted the employer within 48 hours and shared the original contract.",
  },
  {
    id: "golden-gate",
    name: "Golden Gate Manpower",
    type: "Recruitment agency",
    location: "Negombo",
    licence: "SIM-LIC-0918",
    licenceState: "expired",
    lastChecked: "2026-10-09",
    founded: "2016",
    summary:
      "Licence record found in the simulated registry but its validity period has lapsed. This does not by itself establish wrongdoing.",
    related: ["desert-build"],
    reviews: [
      {
        id: "r3",
        date: "2026-09-22",
        category: "Excessive fees",
        status: "Under review",
        evidence: "Partial",
        role: "Construction labourer",
        text: "Asked for LKR 650,000 in cash with no receipt. Told it covered 'visa processing'.",
      },
      {
        id: "r4",
        date: "2026-07-02",
        category: "Excessive fees",
        status: "Disputed by agency",
        evidence: "Unsubstantiated",
        role: "Mason",
        text: "Different fee quoted on each visit.",
      },
    ],
    agencyResponse: "We dispute the fee amounts quoted and are renewing our licence.",
  },
  {
    id: "bluewave",
    name: "BlueWave Global Careers",
    type: "Recruitment agency",
    location: "Online only",
    licence: null,
    licenceState: "unverified",
    lastChecked: null,
    summary:
      "No licence number disclosed. Unverified status means we could not confirm the agency — not that it is fraudulent.",
    related: ["kl-retail"],
    reviews: [],
  },
  {
    id: "meridian",
    name: "Meridian Overseas Services",
    type: "Recruitment agency",
    location: "Kandy",
    licence: "SIM-LIC-3307",
    licenceState: "verified",
    lastChecked: "2026-10-14",
    founded: "2019",
    summary:
      "Licence matched. Community feedback is mixed and several allegations remain unresolved.",
    related: ["harbour-logistics", "al-noor-hotels"],
    reviews: [
      {
        id: "r5",
        date: "2026-09-30",
        category: "Unpaid salary",
        status: "Under review",
        evidence: "Partial",
        role: "Warehouse operative",
        text: "Second month's salary paid three weeks late. Employer blamed a payroll system change.",
      },
      {
        id: "r6",
        date: "2026-08-11",
        category: "Positive experience",
        status: "Moderated",
        evidence: "Documented",
        role: "Forklift driver",
        text: "Clear briefing before departure. Airport pickup arrived as promised.",
      },
      {
        id: "r7",
        date: "2026-06-27",
        category: "Misleading terms",
        status: "Disputed by agency",
        evidence: "Unsubstantiated",
        role: "Warehouse operative",
        text: "Overtime was described as optional but was expected every week.",
      },
    ],
    agencyResponse:
      "Overtime is voluntary under the contract. We have asked the employer to reissue guidance.",
  },
  {
    id: "al-noor-hotels",
    name: "Al Noor Hotels Group",
    type: "Employer",
    location: "Doha, Qatar",
    licence: null,
    licenceState: "pending",
    lastChecked: "2026-10-01",
    summary: "Employer identity disclosed by agency. Commercial registration check is pending.",
    related: ["lanka-horizon", "meridian"],
    reviews: [],
  },
  {
    id: "sakura-care",
    name: "Sakura Care Homes",
    type: "Employer",
    location: "Osaka, Japan",
    licence: null,
    licenceState: "verified",
    lastChecked: "2026-09-28",
    summary: "Employer registration matched in a simulated SSW employer list.",
    related: ["lanka-horizon"],
    reviews: [],
  },
  {
    id: "desert-build",
    name: "Desert Build Contracting",
    type: "Employer",
    location: "Riyadh, Saudi Arabia",
    licence: null,
    licenceState: "unverified",
    lastChecked: null,
    summary: "Employer named but no registration details provided.",
    related: ["golden-gate"],
    reviews: [],
  },
  {
    id: "kl-retail",
    name: "Unnamed retail chain",
    type: "Employer",
    location: "Kuala Lumpur, Malaysia",
    licence: null,
    licenceState: "unverified",
    lastChecked: null,
    summary: "Employer not named in the advertisement.",
    related: ["bluewave"],
    reviews: [],
  },
  {
    id: "harbour-logistics",
    name: "Harbour Logistics FZE",
    type: "Employer",
    location: "Dubai, UAE",
    licence: null,
    licenceState: "verified",
    lastChecked: "2026-10-03",
    summary: "Free-zone registration matched in a simulated register.",
    related: ["meridian"],
    reviews: [],
  },
];

export const jobs: Job[] = [
  {
    id: "doha-chef",
    role: "Commis Chef — Hotel Kitchen",
    occupation: "Hospitality",
    country: "Qatar",
    city: "Doha",
    flag: "QA",
    currency: "QAR",
    salary: 2400,
    salaryLkr: 198000,
    employerId: "al-noor-hotels",
    agencyId: "lanka-horizon",
    visa: "Employment visa (work residence permit)",
    visaOk: true,
    contract: "24 months, renewable",
    contractType: "Renewable",
    experience: 2,
    posted: "2026-10-14",
    verification: "verified",
    risk: "low",
    match: 92,
    matchReasons: [
      "3 years commercial kitchen experience",
      "Prefers Gulf region",
      "Salary above your QAR 2,000 minimum",
    ],
    fee: 0,
    deductions: [
      { label: "Food allowance (provided)", amount: 0 },
      { label: "Health insurance", amount: 0 },
    ],
    accommodation: "Shared staff housing, 2 per room, provided by employer",
    description:
      "Prepare mise en place for the banqueting kitchen. 48-hour week, one rest day. Employer pays visa, flight and medical. No recruitment fee is charged to the worker.",
    findings: [
      {
        id: "f1",
        severity: "low",
        kind: "confirmed",
        title: "Agency licence matches registry",
        why: "A matching licence means the agency is accountable to the regulator.",
        source: "Simulated official registry",
      },
      {
        id: "f2",
        severity: "moderate",
        kind: "unavailable",
        title: "Employer registration not yet confirmed",
        why: "We could not yet confirm the employer independently. Ask the agency for the commercial registration number.",
        source: "Not available",
      },
    ],
    featured: true,
  },
  {
    id: "riyadh-mason",
    role: "Mason / Block Layer",
    occupation: "Construction",
    country: "Saudi Arabia",
    city: "Riyadh",
    flag: "SA",
    currency: "SAR",
    salary: 3200,
    salaryLkr: 256000,
    employerId: "desert-build",
    agencyId: "golden-gate",
    visa: "Employment visa",
    visaOk: true,
    contract: "24 months",
    contractType: "Fixed term",
    experience: 3,
    posted: "2026-10-11",
    verification: "expired",
    risk: "high",
    match: 64,
    matchReasons: [
      "Salary well above your expectation",
      "Experience requirement slightly above yours",
    ],
    fee: 650000,
    deductions: [
      { label: "Recruitment fee instalments", amount: 400 },
      { label: "Accommodation", amount: 250 },
    ],
    accommodation: "Labour camp, deducted from salary",
    description:
      "Urgent requirement. Candidates must pay LKR 650,000 processing fee in cash before medical. Passport to be held by agency until departure.",
    findings: [
      {
        id: "f3",
        severity: "critical",
        kind: "confirmed",
        title: "Excessive recruitment fee requested",
        excerpt: "must pay LKR 650,000 processing fee in cash before medical",
        why: "Cash fees without receipts are a common precursor to debt bondage. Fees for this route are typically borne by the employer.",
        source: "SafeRata analysis",
      },
      {
        id: "f4",
        severity: "high",
        kind: "confirmed",
        title: "Passport retention clause",
        excerpt: "Passport to be held by agency until departure",
        why: "Holding a worker's passport limits their ability to withdraw. You have the right to keep your own passport.",
        source: "SafeRata analysis",
      },
      {
        id: "f5",
        severity: "moderate",
        kind: "confirmed",
        title: "Agency licence has lapsed",
        why: "Expired licence was found in the simulated registry. Ask for proof of renewal before paying anything.",
        source: "Simulated official registry",
      },
    ],
  },
  {
    id: "kl-retail",
    role: "Retail Sales Assistant",
    occupation: "Retail",
    country: "Malaysia",
    city: "Kuala Lumpur",
    flag: "MY",
    currency: "MYR",
    salary: 4800,
    salaryLkr: 312000,
    employerId: "kl-retail",
    agencyId: "bluewave",
    visa: "Tourist visa — 'converted on arrival'",
    visaOk: false,
    contract: "Not provided",
    contractType: "Fixed term",
    experience: 0,
    posted: "2026-10-15",
    verification: "unverified",
    risk: "critical",
    match: 71,
    matchReasons: ["No experience required", "Very high salary for the role"],
    fee: 180000,
    deductions: [],
    accommodation: "Not disclosed",
    description:
      "Earn MYR 4,800 monthly! Travel on tourist visa, our partner will convert to work permit on arrival. Pay LKR 180,000 to secure your place. Limited seats.",
    findings: [
      {
        id: "f6",
        severity: "critical",
        kind: "confirmed",
        title: "Tourist visa proposed for employment",
        excerpt: "Travel on tourist visa, our partner will convert to work permit on arrival",
        why: "Working on a tourist visa is illegal in most destinations and leaves you without labour protection. Conversion on arrival is generally not possible.",
        source: "SafeRata analysis",
      },
      {
        id: "f7",
        severity: "high",
        kind: "suspected",
        title: "Salary unusually high for role",
        excerpt: "Earn MYR 4,800 monthly!",
        why: "This is roughly 2–3× typical retail pay in the destination. Unrealistic salaries are used to create urgency.",
        source: "SafeRata analysis",
      },
      {
        id: "f8",
        severity: "moderate",
        kind: "unavailable",
        title: "No licence or employer disclosed",
        why: "We cannot check accountability without a licence number or employer name.",
        source: "Not available",
      },
    ],
    promoted: true,
  },
  {
    id: "osaka-care",
    role: "Care Worker — Specified Skilled Worker",
    occupation: "Healthcare",
    country: "Japan",
    city: "Osaka",
    flag: "JP",
    currency: "JPY",
    salary: 210000,
    salaryLkr: 412000,
    employerId: "sakura-care",
    agencyId: "lanka-horizon",
    visa: "Specified Skilled Worker (i) — Nursing care",
    visaOk: true,
    contract: "12 months, renewable up to 5 years",
    contractType: "Renewable",
    experience: 1,
    posted: "2026-10-09",
    verification: "verified",
    risk: "low",
    match: 84,
    matchReasons: [
      "JLPT N4 matches requirement",
      "Caregiving certificate on profile",
      "Japan in your preferred destinations",
    ],
    fee: 95000,
    deductions: [
      { label: "Income tax & social insurance (est.)", amount: 38000 },
      { label: "Dormitory rent", amount: 25000 },
    ],
    accommodation: "Single room in company dormitory, JPY 25,000/month",
    description:
      "Support residents with daily living in a 60-bed care home. Requires JLPT N4 and SSW nursing care skills test. Language training fee of LKR 95,000 with receipt.",
    findings: [
      {
        id: "f9",
        severity: "low",
        kind: "confirmed",
        title: "Visa category appropriate",
        why: "SSW nursing care is the correct route for this role.",
        source: "SafeRata analysis",
      },
      {
        id: "f10",
        severity: "low",
        kind: "confirmed",
        title: "Fee disclosed with receipt",
        excerpt: "Language training fee of LKR 95,000 with receipt",
        why: "Disclosed, receipted training fees are reasonable. Confirm what the fee includes.",
        source: "Agency-disclosed",
      },
    ],
  },
  {
    id: "dubai-warehouse",
    role: "Warehouse Operative",
    occupation: "Logistics",
    country: "UAE",
    city: "Dubai",
    flag: "AE",
    currency: "AED",
    salary: 2100,
    salaryLkr: 171000,
    employerId: "harbour-logistics",
    agencyId: "meridian",
    visa: "Employment visa",
    visaOk: true,
    contract: "24 months",
    contractType: "Fixed term",
    experience: 1,
    posted: "2026-10-13",
    verification: "verified",
    risk: "moderate",
    match: 78,
    matchReasons: ["Forklift licence on profile", "Salary meets your minimum"],
    fee: 0,
    deductions: [{ label: "Transport", amount: 0 }],
    accommodation: "Shared housing, provided",
    description:
      "Pick, pack and load in a free-zone warehouse. 9-hour shifts. The employer may change job duties and work location at its sole discretion without notice.",
    findings: [
      {
        id: "f11",
        severity: "high",
        kind: "confirmed",
        title: "Broad unilateral change clause",
        excerpt: "may change job duties and work location at its sole discretion without notice",
        why: "This lets the employer move you to a different role or site you did not agree to. Ask for this clause to be limited in writing.",
        source: "SafeRata analysis",
      },
      {
        id: "f12",
        severity: "moderate",
        kind: "allegation",
        title: "Unresolved late-salary reports",
        why: "One worker report of delayed pay is under review. It is not an established fact.",
        source: "Worker report (moderated)",
      },
    ],
  },
  {
    id: "doha-housekeeping",
    role: "Housekeeping Attendant",
    occupation: "Hospitality",
    country: "Qatar",
    city: "Doha",
    flag: "QA",
    currency: "QAR",
    salary: 1600,
    salaryLkr: 132000,
    employerId: "al-noor-hotels",
    agencyId: "meridian",
    visa: "Employment visa",
    visaOk: true,
    contract: "24 months",
    contractType: "Renewable",
    experience: 0,
    posted: "2026-10-06",
    verification: "pending",
    risk: "low",
    match: 69,
    matchReasons: [
      "Entry-level role",
      "Gulf in preferred region",
      "Salary below your stated minimum",
    ],
    fee: 0,
    deductions: [],
    accommodation: "Shared staff housing, provided",
    description:
      "Room attendant for a 300-key business hotel. Uniform, meals and transport provided. No fee to the worker.",
    findings: [
      {
        id: "f13",
        severity: "low",
        kind: "unavailable",
        title: "Verification in progress",
        why: "Employer documents are being checked. Results normally take 2–3 working days.",
        source: "Not available",
      },
    ],
  },
];

export const countries = Array.from(new Set(jobs.map((j) => j.country)));
export const occupations = Array.from(new Set(jobs.map((j) => j.occupation)));

export const trustStats = {
  listingsChecked: jobs.length,
  agencies: companies.filter((c) => c.type === "Recruitment agency").length,
  highRisk: jobs.filter((j) => j.risk === "high" || j.risk === "critical").length,
  activity: [
    {
      t: "2026-10-15 09:12",
      text: "BlueWave Global Careers listing flagged — tourist visa for employment",
    },
    { t: "2026-10-14 16:40", text: "Meridian Overseas Services licence re-checked — match" },
    { t: "2026-10-12 11:05", text: "Lanka Horizon Placements licence re-checked — match" },
    { t: "2026-10-09 14:22", text: "Golden Gate Manpower licence — validity lapsed" },
  ],
};

const liveJobsCache = new Map<string, Job>();

export function registerLiveJobs(newJobs: Job[]) {
  for (const j of newJobs) {
    liveJobsCache.set(j.id, j);
  }
}

export const getJob = (id: string): Job | undefined => {
  return liveJobsCache.get(id) || jobs.find((j) => j.id === id);
};

export const getCompany = (id: string): Company => {
  const found = companies.find((c) => c.id === id);
  if (found) return found;

  // Resilient fallback for dynamically generated agency / employer IDs
  const isAgency = id.startsWith("agency-") || id === "backend-agency";
  const fallback: Company = {
    id,
    name: isAgency ? "Unverified Agency" : "Unverified Overseas Employer",
    type: isAgency ? "Recruitment agency" : "Employer",
    location: "Unconfirmed Location",
    licence: null,
    licenceState: "unverified",
    lastChecked: null,
    summary: isAgency
      ? "Agency record not yet confirmed against the live SLBFE register. Proceed with caution."
      : "Foreign employer details not yet confirmed through official channels.",
    related: [],
    reviews: [],
  };
  companies.push(fallback);
  return fallback;
};

export const formatMoney = (n: number, cur: string) => `${cur} ${n.toLocaleString("en-US")}`;

export const DEMO_AD = `URGENT!! Supermarket helpers needed in Kuala Lumpur. Salary MYR 4,800 + bonus. No experience needed. Travel on tourist visa, our partner will convert to work permit on arrival. Pay LKR 180,000 now to secure your seat, balance after arrival. Passport must be handed over to our office for processing. Contact BlueWave on WhatsApp only.`;

export const SAMPLE_OFFERS = [
  {
    title: "High Risk (Thailand IT)",
    text: "URGENT HIRING!!! IT / Data Entry jobs in THAILAND\nSalary USD 1500 per month + free accommodation + food\nNo experience needed, basic English and typing only.\nAir ticket FREE. Travel on tourist visa, company will change to work visa after arrival.\nOnly 5 seats left - pay Rs. 150,000 processing fee to confirm your seat.\nDeposit to Commercial Bank account 8012345678 (K. Perera). Send slip on WhatsApp +94 76 555 1234",
  },
  {
    title: "Impersonation (Qatar Driver)",
    text: "A T C GLOBAL HOLDINGS (PVT) LTD - Licence No 3500\nQatar - House Driver vacancies. Salary QAR 1800. Employment visa.\nRegistration fee Rs. 75,000 must be paid before interview to reserve your place.\nContact our recruitment officer on WhatsApp 0789 123 456",
  },
  {
    title: "Genuine (Licensed Agency)",
    text: "A T C GLOBAL HOLDINGS (PVT) LTD (SLBFE Licence No 3500)\nVacancy: Light vehicle driver - Qatar. Employment visa sponsored by employer.\nSalary QAR 2000 + accommodation. 2-year contract provided before departure.\nAll payments only at our Nugegoda office with official receipt, after you sign the contract.\nCall 0112818268 or email info@atcs.lk",
  },
];
