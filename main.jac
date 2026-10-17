"""SafeRata - entry point: agent endpoints + client UI."""

import from agents { Investigate, RecentChecks, CaseReport }
import from jobboard { PostJob, ListJobs, AddReview }

import from .frontend { app as ClientApp }

def:pub app -> JsxElement {
    return <ClientApp/>;
}
