"""SafeRata - entry point: agent endpoints + client UI."""

import from agents { Investigate, RecentChecks, CaseReport }
import from jobboard { PostJob, ListJobs, AddReview, ListAgencies }

import from .frontend { app as ClientApp }

def:pub app -> JsxElement {
    return <ClientApp/>;
}
