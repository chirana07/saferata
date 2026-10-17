import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import React from "react";
import {
  createRootRoute,
  createRoute,
  createRouter,
  RouterProvider,
  createMemoryHistory,
  Outlet,
} from "@tanstack/react-router";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Route as DiscoverRoute } from "@/routes/index";
import * as api from "@/lib/api";
import * as data from "@/lib/data";

function renderDiscover() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });

  const rootRoute = createRootRoute({
    component: () => <Outlet />,
  });

  const indexRoute = createRoute({
    getParentRoute: () => rootRoute,
    path: "/",
    component: DiscoverRoute.options.component!,
  });

  // Dummy route for Link to="/jobs/$id"
  const jobDetailRoute = createRoute({
    getParentRoute: () => rootRoute,
    path: "/jobs/$id",
    component: () => <div>Job Details Page</div>,
  });

  const profileRoute = createRoute({
    getParentRoute: () => rootRoute,
    path: "/profile",
    component: () => <div>Profile Page</div>,
  });

  const investigateRoute = createRoute({
    getParentRoute: () => rootRoute,
    path: "/investigate",
    component: () => <div>Investigate Page</div>,
  });

  const routeTree = rootRoute.addChildren([
    indexRoute,
    jobDetailRoute,
    profileRoute,
    investigateRoute,
  ]);
  const history = createMemoryHistory({ initialEntries: ["/"] });
  const router = createRouter({
    routeTree,
    history,
  });

  return render(
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>,
  );
}

describe("Discover Route Component", () => {
  const originalFetch = global.fetch;

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    global.fetch = originalFetch;
  });

  it("renders with demo jobs when apiListJobs returns empty", async () => {
    vi.spyOn(api, "apiListJobs").mockResolvedValue({ jobs: [], error: null });

    renderDiscover();

    expect(await screen.findByText(/Your next chapter/i)).toBeInTheDocument();
    expect(screen.getByText(/Trust intelligence/i)).toBeInTheDocument();
    expect(screen.getByText(/Recommended for you/i)).toBeInTheDocument();
  });

  it("renders successfully when no jobs are available without crashing", async () => {
    vi.spyOn(api, "apiListJobs").mockResolvedValue({ jobs: [], error: null });

    const jobsSpy = vi.spyOn(data, "jobs", "get").mockReturnValue([]);

    renderDiscover();

    expect(await screen.findByText(/Your next chapter/i)).toBeInTheDocument();
    expect(screen.getByText(/No featured opportunities right now/i)).toBeInTheDocument();
    expect(screen.getByText(/No roads lead here — yet/i)).toBeInTheDocument();

    jobsSpy.mockRestore();
  });

  it("renders live backend jobs and registers them into the cache", async () => {
    const liveBackendJob: api.BackendJobView = {
      id: "live-job-test-1",
      title: "Senior Electrical Engineer",
      country: "Qatar",
      salary: "QAR 5,500",
      salary_amount: 5500,
      salary_currency: "QAR",
      salary_lkr: 450000,
      take_home_lkr: 420000,
      agency_name: "Apex Manpower",
      licence_no: "3999",
      band: "LOOKS SAFE",
      score: 10,
      summary: "Verified engineering vacancy in Doha.",
      description: "Perform electrical installation and inspection.",
      contact_phone: "+94112345678",
      posted_at: "2026-10-17T12:00:00Z",
      occupation: "Engineer",
      experience_years: 3,
      contract_type: "Fixed term",
      contract_months: 24,
      accommodation: "Provided",
      deductions: "",
      worker_fee_lkr: 0,
      top_flags: [],
      warnings: [],
      reviews: [],
      credible_fraud_reports: 0,
      appeals: [],
      corrections: [],
      appealable: [],
    };

    const registerSpy = vi.spyOn(data, "registerLiveJobs");
    vi.spyOn(api, "apiListJobs").mockResolvedValue({
      jobs: [liveBackendJob],
      error: null,
    });

    renderDiscover();

    await waitFor(() => {
      expect(registerSpy).toHaveBeenCalled();
      expect(screen.getByText("Senior Electrical Engineer")).toBeInTheDocument();
    });
  });

  it("handles backend error gracefully without crashing", async () => {
    vi.spyOn(api, "apiListJobs").mockResolvedValue({
      jobs: null,
      error: {
        isNetworkError: true,
        message: "Backend network error",
      },
    });

    renderDiscover();

    expect(await screen.findByText(/Your next chapter/i)).toBeInTheDocument();
    expect(screen.getByText(/Recommended for you/i)).toBeInTheDocument();
  });
});
