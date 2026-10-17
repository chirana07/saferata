import { useSyncExternalStore } from "react";
import type { Review } from "./data";

export interface Profile {
  name: string;
  occupation: string;
  skills: string[];
  experience: number;
  qualifications: string;
  destinations: string[];
  minSalary: number;
  currency: string;
  languages: string[];
  preferences: string;
  accommodation: boolean;
}

export interface AgencyListing {
  id: string;
  role: string;
  country: string;
  salary: number;
  currency: string;
  visa: string;
  contract: string;
  fee: number;
  status: "Under review" | "Correction requested" | "Appeal submitted";
  created: string;
}

interface State {
  saved: string[];
  compare: string[];
  profile: Profile;
  reviews: Record<string, Review[]>;
  listings: AgencyListing[];
}

const KEY = "saferata.demo.v1";
const defaults: State = {
  saved: ["osaka-care"],
  compare: [],
  profile: {
    name: "Nimal",
    occupation: "Hospitality",
    skills: ["Food preparation", "Food hygiene (Level 2)"],
    experience: 3,
    qualifications: "NVQ Level 4 — Culinary",
    destinations: ["Qatar", "Japan"],
    minSalary: 180000,
    currency: "LKR",
    languages: ["Sinhala", "English"],
    preferences: "",
    accommodation: true,
  },
  reviews: {},
  listings: [],
};

let state: State = defaults;
let loaded = false;
const listeners = new Set<() => void>();

function load() {
  if (loaded || typeof window === "undefined") return;
  loaded = true;
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) state = { ...defaults, ...JSON.parse(raw) };
  } catch {
    /* ignore */
  }
}

export function setState(fn: (s: State) => State) {
  load();
  state = fn(state);
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
  } catch {
    /* ignore */
  }
  listeners.forEach((l) => l());
}

function subscribe(l: () => void) {
  listeners.add(l);
  if (!loaded) {
    load();
    queueMicrotask(() => listeners.forEach((x) => x()));
  }
  return () => listeners.delete(l);
}

export function useStore<T>(sel: (s: State) => T): T {
  return useSyncExternalStore(
    subscribe,
    () => sel(state),
    () => sel(defaults),
  );
}

export const toggleSaved = (id: string) =>
  setState((s) => ({
    ...s,
    saved: s.saved.includes(id) ? s.saved.filter((x) => x !== id) : [...s.saved, id],
  }));

export const toggleCompare = (id: string) =>
  setState((s) => {
    if (s.compare.includes(id)) return { ...s, compare: s.compare.filter((x) => x !== id) };
    if (s.compare.length >= 3) return s;
    return { ...s, compare: [...s.compare, id] };
  });

export const profileCompletion = (p: Profile) => {
  const checks = [
    !!p.occupation,
    p.skills.length > 0,
    p.experience > 0,
    !!p.qualifications,
    p.destinations.length > 0,
    p.minSalary > 0,
    p.languages.length > 0,
    !!p.preferences,
  ];
  return Math.round((checks.filter(Boolean).length / checks.length) * 100);
};
