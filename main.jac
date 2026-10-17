"""SafeRata - entry point: agent endpoints + client UI."""

import "./assets/main.css";

import from agents { Investigate, RecentChecks, CaseReport }
import from jobboard { PostJob, ListJobs, AddReview, ListAgencies, MatchJobs, AppealFinding, RespondToReview, RequestCorrection }

import from frontend { app as ClientApp }

def:pub app -> JsxElement {
    return <ClientApp/>;
}
