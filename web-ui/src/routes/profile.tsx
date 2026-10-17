import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { toast } from "sonner";
import { countries, occupations } from "@/lib/data";
import { useStore, setState, profileCompletion, type Profile } from "@/lib/store";
import { PageHeader } from "@/components/sr/ui";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/profile")({
  head: () => ({
    meta: [
      { title: "Your work profile — SafeRata" },
      {
        name: "description",
        content:
          "Tell SafeRata about your skills and preferences to get better overseas job matches.",
      },
      { property: "og:title", content: "Your work profile — SafeRata" },
      { property: "og:description", content: "Only what's needed for matching — nothing more." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ProfilePage,
});

const STEPS = ["Work", "Experience", "Destinations & pay", "Languages & preferences"];
const LANGS = ["Sinhala", "Tamil", "English", "Arabic", "Japanese", "Korean", "Malay"];
const input =
  "mt-1 h-11 w-full rounded-md border border-input bg-card px-3 text-sm font-normal focus:border-primary outline-none";

function Chips({
  all,
  value,
  onChange,
}: {
  all: string[];
  value: string[];
  onChange: (v: string[]) => void;
}) {
  return (
    <div className="mt-2 flex flex-wrap gap-2">
      {all.map((x) => {
        const on = value.includes(x);
        return (
          <button
            type="button"
            key={x}
            aria-pressed={on}
            onClick={() => onChange(on ? value.filter((y) => y !== x) : [...value, x])}
            className={cn(
              "h-9 rounded-md border px-3 text-sm font-medium",
              on
                ? "border-primary bg-primary text-primary-foreground"
                : "border-border bg-card hover:border-primary",
            )}
          >
            {x}
          </button>
        );
      })}
    </div>
  );
}

function ProfilePage() {
  const stored = useStore((s) => s.profile);
  const [p, setP] = useState<Profile>(stored);
  const [step, setStep] = useState(0);
  const pct = profileCompletion(p);
  const up = (k: Partial<Profile>) => setP({ ...p, ...k });
  const save = () => {
    setState((s) => ({ ...s, profile: p }));
    toast.success("Preferences saved", { description: "Stored in this browser only." });
  };

  return (
    <div>
      <PageHeader
        eyebrow="Work profile"
        title={
          <>
            Tell us what
            <br />
            you're good at.
          </>
        }
      >
        <div className="w-48">
          <div className="flex justify-between text-xs">
            <span className="eyebrow">Complete</span>
            <span className="font-mono font-semibold">{pct}%</span>
          </div>
          <div className="mt-1 h-1.5 rounded-sm bg-secondary">
            <div
              className="h-full rounded-sm bg-primary transition-all"
              style={{ width: `${pct}%` }}
            />
          </div>
        </div>
      </PageHeader>

      <div className="grid gap-10 lg:grid-cols-[200px_1fr_260px]">
        <ol className="flex gap-2 overflow-x-auto lg:flex-col">
          {STEPS.map((s, i) => (
            <li key={s}>
              <button
                onClick={() => setStep(i)}
                className={cn(
                  "flex w-full items-center gap-3 whitespace-nowrap rounded-md px-3 py-2 text-left text-sm font-medium",
                  step === i ? "bg-card text-foreground shadow-card" : "text-muted-foreground",
                )}
              >
                <span className="font-mono text-xs">0{i + 1}</span>
                {s}
              </button>
            </li>
          ))}
        </ol>

        <form
          onSubmit={(e) => {
            e.preventDefault();
            if (step < 3) setStep(step + 1);
            else save();
          }}
          className="space-y-5 rise-in"
          key={step}
        >
          {step === 0 && (
            <>
              <label className="block text-sm font-semibold">
                Preferred name
                <input
                  value={p.name}
                  onChange={(e) => up({ name: e.target.value })}
                  className={input}
                />
              </label>
              <label className="block text-sm font-semibold">
                Occupation
                <select
                  value={p.occupation}
                  onChange={(e) => up({ occupation: e.target.value })}
                  className={input}
                >
                  {occupations.map((o) => (
                    <option key={o}>{o}</option>
                  ))}
                </select>
              </label>
              <label className="block text-sm font-semibold">
                Skills <span className="font-normal text-muted-foreground">(comma separated)</span>
                <input
                  value={p.skills.join(", ")}
                  onChange={(e) =>
                    up({
                      skills: e.target.value
                        .split(",")
                        .map((x) => x.trim())
                        .filter(Boolean),
                    })
                  }
                  className={input}
                />
              </label>
            </>
          )}
          {step === 1 && (
            <>
              <label className="block text-sm font-semibold">
                Years of experience
                <input
                  type="number"
                  min={0}
                  max={40}
                  value={p.experience}
                  onChange={(e) => up({ experience: +e.target.value })}
                  className={input}
                />
              </label>
              <label className="block text-sm font-semibold">
                Qualifications
                <input
                  value={p.qualifications}
                  onChange={(e) => up({ qualifications: e.target.value })}
                  placeholder="e.g. NVQ Level 3, JLPT N4"
                  className={input}
                />
              </label>
            </>
          )}
          {step === 2 && (
            <>
              <div className="text-sm font-semibold">
                Preferred destinations
                <Chips
                  all={countries}
                  value={p.destinations}
                  onChange={(v) => up({ destinations: v })}
                />
              </div>
              <label className="block text-sm font-semibold">
                Minimum monthly salary (LKR)
                <input
                  type="number"
                  step={5000}
                  min={0}
                  value={p.minSalary}
                  onChange={(e) => up({ minSalary: +e.target.value })}
                  className={input}
                />
              </label>
              <label className="flex items-center gap-2 text-sm font-semibold">
                <input
                  type="checkbox"
                  checked={p.accommodation}
                  onChange={(e) => up({ accommodation: e.target.checked })}
                  className="h-4 w-4 accent-[var(--primary)]"
                />{" "}
                I need accommodation provided
              </label>
            </>
          )}
          {step === 3 && (
            <>
              <div className="text-sm font-semibold">
                Languages
                <Chips all={LANGS} value={p.languages} onChange={(v) => up({ languages: v })} />
              </div>
              <label className="block text-sm font-semibold">
                Work preferences or constraints
                <textarea
                  rows={3}
                  value={p.preferences}
                  onChange={(e) => up({ preferences: e.target.value })}
                  placeholder="e.g. Day shifts only, want to return home for Avurudu"
                  className={cn(input, "h-auto py-2")}
                />
              </label>
            </>
          )}
          <div className="flex gap-2 border-t border-border pt-5">
            {step > 0 && (
              <button
                type="button"
                onClick={() => setStep(step - 1)}
                className="h-11 rounded-md border border-border bg-card px-4 text-sm font-semibold"
              >
                Back
              </button>
            )}
            <button className="h-11 rounded-md bg-primary px-5 text-sm font-semibold text-primary-foreground hover:bg-primary-deep">
              {step < 3 ? "Continue" : "Save preferences"}
            </button>
            {step < 3 && (
              <button
                type="button"
                onClick={save}
                className="h-11 px-3 text-sm font-semibold text-muted-foreground"
              >
                Save now
              </button>
            )}
          </div>
        </form>

        <aside className="h-fit rounded-xl bg-ink p-5 text-sm text-ink-foreground">
          <p className="eyebrow text-sky">How this is used</p>
          <ul className="mt-3 space-y-2 text-ink-foreground/80">
            <li>Occupation and skills set your match score.</li>
            <li>Destinations and salary filter what we recommend first.</li>
            <li>Your profile never changes a job's safety assessment.</li>
            <li>We never ask for your NIC, passport, religion or family details.</li>
          </ul>
        </aside>
      </div>
    </div>
  );
}
