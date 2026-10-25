"""PrairieLearn, as Mimir uses it: the read-only REST API and dev mode's reload.

Never call the API's course sync (POST /pl/api/v1/course/:id/sync): it runs
pullAndUpdateCourse, i.e. `git clean -fdx` + `git reset --hard` on the course
directory. Dev mode's GET /pl/loadFromDisk only re-reads the files.
"""

import json
import time
import urllib.error
import urllib.request

COURSE_SHORT_NAME = "MIMIR"
INSTANCE_NAME = "Practice"


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class PL:
    def __init__(self, url: str, token: str):
        self.url = url
        self.token = token

    def api(self, path: str):
        req = urllib.request.Request(f"{self.url}/pl/api/v1{path}", headers={"Private-Token": self.token})
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read())

    def ping(self) -> bool:
        try:
            with urllib.request.urlopen(f"{self.url}/pl/webhooks/ping", timeout=10) as r:
                return r.status == 200
        except (urllib.error.URLError, OSError):
            return False

    def course_instance(self, cached: str | None) -> int:
        """The id of the course instance "Practice" in course MIMIR (ids are stable while PL's DB lives)."""
        tried = []
        candidates = ([int(cached)] if cached else []) + list(range(1, 50))
        for ci in candidates:
            if ci in tried:
                continue
            tried.append(ci)
            try:
                info = self.api(f"/course_instances/{ci}")
            except urllib.error.HTTPError:
                continue
            if info.get("course_short_name") == COURSE_SHORT_NAME and \
                    info.get("course_instance_long_name") == INSTANCE_NAME:
                return ci
        raise RuntimeError(f"no course instance {INSTANCE_NAME!r} in course {COURSE_SHORT_NAME!r} "
                           "(has PL loaded the course? try `mimir reload`)")

    def assessments(self, ci: int) -> list[dict]:
        return self.api(f"/course_instances/{ci}/assessments")

    def assessment_instances(self, ci: int, aid: str) -> list[dict]:
        return self.api(f"/course_instances/{ci}/assessments/{aid}/assessment_instances")

    def instance_questions(self, ci: int, aiid: str) -> list[dict]:
        return self.api(f"/course_instances/{ci}/assessment_instances/{aiid}/instance_questions")

    def submissions(self, ci: int, aiid: str) -> list[dict]:
        return self.api(f"/course_instances/{ci}/assessment_instances/{aiid}/submissions")

    def reload(self) -> str:
        """Dev mode's "Load from disk" (all courses). Returns the job sequence URL."""
        op = urllib.request.build_opener(_NoRedirect)
        try:
            op.open(f"{self.url}/pl/loadFromDisk", timeout=60)
        except urllib.error.HTTPError as e:
            if e.code in (301, 302, 303):
                return e.headers.get("Location", "")
            raise
        raise RuntimeError("PL did not answer /pl/loadFromDisk with a redirect (is it in dev mode?)")

    def wait_for(self, ci: int, tid: str, timeout: float = 120) -> bool:
        """After a reload: wait until the assessment `tid` is listed."""
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if any(a["assessment_name"] == tid for a in self.assessments(ci)):
                return True
            time.sleep(1)
        return False
