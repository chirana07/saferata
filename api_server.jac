"""SafeRata Backend API Server.
Hosts all public walkers (Investigate, RecentChecks, PostJob, ListJobs, AddReview, ListAgencies, MatchJobs, AppealFinding).
"""

import from agents { Investigate, RecentChecks, CaseReport }
import from jobboard { PostJob, ListJobs, AddReview, ListAgencies, MatchJobs, AppealFinding, RespondToReview, RequestCorrection }

with entry:__main__ {
    print("SafeRata backend walkers loaded.");
}
