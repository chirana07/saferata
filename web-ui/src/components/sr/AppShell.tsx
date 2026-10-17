import { Link, useRouterState } from "@tanstack/react-router";
import { Compass, Radar, Building2, UserRound, Briefcase, Scale } from "lucide-react";
import { Logo } from "./ui";
import { useStore } from "@/lib/store";
import { cn } from "@/lib/utils";

const nav = [
  { to: "/", label: "Discover", Icon: Compass },
  { to: "/investigate", label: "Investigate", Icon: Radar },
  { to: "/companies", label: "Companies", Icon: Building2 },
  { to: "/compare", label: "Compare", Icon: Scale },
  { to: "/profile", label: "Profile", Icon: UserRound },
] as const;

export function AppShell({ children }: { children: React.ReactNode }) {
  const path = useRouterState({ select: (s) => s.location.pathname });
  const compareCount = useStore((s) => s.compare.length);
  const isActive = (to: string) =>
    to === "/" ? path === "/" || path.startsWith("/jobs") : path.startsWith(to);

  return (
    <div className="min-h-screen md:grid md:grid-cols-[232px_1fr]">
      <aside className="sticky top-0 hidden h-screen flex-col border-r border-border bg-sidebar px-4 py-6 md:flex">
        <Link to="/" className="px-2">
          <Logo />
        </Link>
        <nav className="mt-10 flex flex-col gap-0.5" aria-label="Primary">
          {nav.map(({ to, label, Icon }) => (
            <Link
              key={to}
              to={to}
              className={cn(
                "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                isActive(to)
                  ? "bg-primary text-primary-foreground"
                  : "text-muted-foreground hover:bg-sidebar-accent hover:text-foreground",
              )}
            >
              <Icon className="h-4 w-4" /> {label}
              {to === "/compare" && compareCount > 0 && (
                <span className="ml-auto font-mono text-[11px]">{compareCount}</span>
              )}
            </Link>
          ))}
        </nav>
        <div className="mt-8 border-t border-border pt-4">
          <p className="eyebrow px-3">For agencies</p>
          <Link
            to="/agency"
            className={cn(
              "mt-2 flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium",
              isActive("/agency")
                ? "bg-ink text-ink-foreground"
                : "text-muted-foreground hover:bg-sidebar-accent hover:text-foreground",
            )}
          >
            <Briefcase className="h-4 w-4" /> Agency portal
          </Link>
        </div>
        <p className="mt-auto px-3 text-[11px] leading-relaxed text-muted-foreground">
          Prototype. All jobs, companies and verifications are simulated. Verification is never a
          guarantee of safety.
        </p>
      </aside>

      <div className="min-w-0">
        <header className="sticky top-0 z-20 flex items-center justify-between border-b border-border bg-card/90 px-4 py-3 backdrop-blur md:hidden">
          <Link to="/">
            <Logo />
          </Link>
          <Link to="/agency" className="text-xs font-semibold text-primary-deep">
            Agency portal
          </Link>
        </header>
        <main className="mx-auto max-w-[1240px] px-4 pb-28 pt-6 md:px-10 md:pb-16 md:pt-10">
          {children}
        </main>
      </div>

      <nav
        className="fixed inset-x-0 bottom-0 z-30 grid grid-cols-5 border-t border-border bg-card/95 backdrop-blur md:hidden"
        aria-label="Primary mobile"
      >
        {nav.map(({ to, label, Icon }) => (
          <Link
            key={to}
            to={to}
            className={cn(
              "flex min-h-14 flex-col items-center justify-center gap-1 text-[11px] font-semibold",
              isActive(to) ? "text-primary" : "text-muted-foreground",
            )}
          >
            <span
              className={cn(
                "grid h-7 w-10 place-items-center rounded-md",
                isActive(to) && "bg-secondary",
              )}
            >
              <Icon className="h-4 w-4" />
            </span>
            {label}
          </Link>
        ))}
      </nav>
    </div>
  );
}
