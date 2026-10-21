#!/usr/bin/env python3
"""Sajda group-streak end-to-end tester.

Creates 10 tagged TEST- groups with fabricated users against a running
Sajda backend, exercises every group-streak rule (day completion, join
eligibility, ghost exclusion, weekly shield, grace/strict-day anchors,
month history, timezone boundaries, nudges, join requests, management),
verifies each result and prints a PASS/FAIL report.

Requirements
  - the backend running (default http://localhost:5000)
  - Python packages: pymongo (database seeding) and tzdata (timezones)
      python -m pip install pymongo tzdata

Usage
  python backend/test/group_streak_e2e.py
  python backend/test/group_streak_e2e.py --no-db            (HTTP-only subset)
  python backend/test/group_streak_e2e.py --cleanup          (delete data after run)
  python backend/test/group_streak_e2e.py --cleanup-only     (delete old TEST- data)
  python backend/test/group_streak_e2e.py --report report.json

Configuration comes from backend/.env (MONGODB_URI, JWT_SECRET, PORT) and can
be overridden with --base-url / --jwt-secret / --mongo-uri / --db-name.
"""

from __future__ import annotations

import argparse
import base64
import calendar
import hashlib
import hmac
import json
import os
import random
import re
import secrets
import sys
import time
import traceback
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone

PRAYERS = ["fajr", "dhuhr", "asr", "maghrib", "isha"]
GRACE_MINUTES = 4 * 60
GHOST_WINDOW_DAYS = 3
SHIELD_MIN_RATIO = 0.8
NUDGE_MAX_PER_TARGET = 3
MEMBER_LIMIT = 50
KHI = "Asia/Karachi"
UTC_TZ = "UTC"
NYC = "America/New_York"

try:
    from zoneinfo import ZoneInfo

    ZoneInfo(KHI)
    TZ_OK = True
except Exception:
    ZoneInfo = None
    TZ_OK = False

try:
    import pymongo
    from bson import ObjectId

    PYMONGO_OK = True
except Exception:
    pymongo = None
    ObjectId = None
    PYMONGO_OK = False

FIRST_NAMES = [
    "Aisha", "Bilal", "Cody", "Dua", "Emaan", "Farah", "Ghazala", "Hamza",
    "Imran", "Junaid", "Kashif", "Laiba", "Maryam", "Nabeel", "Omar", "Parveen",
    "Qasim", "Rabia", "Saad", "Tahira", "Usman", "Vasia", "Waqar", "Xenia",
    "Yasir", "Zainab", "Arslan", "Bushra", "Danish", "Esha", "Faisal", "Gul",
    "Hira", "Irfan", "Javeria", "Kamran", "Lubna", "Muneeb", "Nida", "Osman",
    "Pakeeza", "Qurat", "Rehan", "Sana", "Talha", "Uzma", "Vaqas", "Warda",
    "Yumna", "Zeeshan",
]
LAST_NAMES = [
    "Khan", "Ahmed", "Malik", "Siddiqui", "Raza", "Iqbal", "Butt", "Sheikh",
    "Chaudhry", "Mughal", "Ansari", "Qureshi", "Abbasi", "Baig", "Farooqi",
    "Hashmi", "Javed", "Lodhi", "Nawaz", "Pasha",
]
GROUP_WORDS = [
    "Noor Circle", "Safa Squad", "Hidaya Hub", "Sabr Stars", "Rahma Ring",
    "Aman Alliance", "Baraka Bunch", "Fajr Friends", "Taqwa Team", "Iman Club",
]

ACCOUNT_ID = ObjectId if PYMONGO_OK else None


def read_env_file(path):
    env = {}
    try:
        with open(path, "r", encoding="utf-8-sig") as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("export "):
                    line = line[len("export "):].strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                env[key.strip()] = value.strip().strip('"').strip("'")
    except OSError:
        pass
    return env


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def mint_token(secret: str, user_id: str, display_name: str, tz: str, days: int = 30) -> str:
    header = b64url(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
    now = int(time.time())
    payload = b64url(json.dumps(
        {"id": user_id, "displayName": display_name, "timezone": tz,
         "iat": now, "exp": now + days * 86400},
        separators=(",", ":"),
    ).encode())
    signing_input = f"{header}.{payload}".encode()
    signature = b64url(hmac.new(secret.encode(), signing_input, hashlib.sha256).digest())
    return f"{header}.{payload}.{signature}"


def shift_key(key: str, days: int) -> str:
    return (date.fromisoformat(key) + timedelta(days=days)).isoformat()


def week_key_of(key: str) -> str:
    d = date.fromisoformat(key)
    return (d - timedelta(days=d.weekday())).isoformat()


def now_in(tz: str) -> datetime:
    return datetime.now(ZoneInfo(tz))


def today_key(tz: str) -> str:
    return now_in(tz).date().isoformat()


def local_minutes(tz: str) -> int:
    at = now_in(tz)
    return at.hour * 60 + at.minute


def active_day(tz: str) -> str:
    key = today_key(tz)
    return shift_key(key, -1) if local_minutes(tz) < GRACE_MINUTES else key


def effective_from(tz: str) -> str:
    return shift_key(today_key(tz), 1)


def run_from_days(days, today: str) -> int:
    cursor = today if today in days else shift_key(today, -1)
    run = 0
    while cursor in days:
        run += 1
        cursor = shift_key(cursor, -1)
    return run


def mirror_month(days, year: int, month: int, first_required, today: str) -> dict:
    out = {}
    for d in range(1, calendar.monthrange(year, month)[1] + 1):
        key = f"{year:04d}-{month:02d}-{d:02d}"
        if key < today:
            state = "complete" if key in days else "missed"
            if first_required and key < first_required:
                state = "none"
        elif key == today:
            state = "today"
        else:
            state = "future"
        out[key] = state
    return out


class ApiError(RuntimeError):
    pass


class Api:
    def __init__(self, base_url: str, secret: str):
        self.base = base_url.rstrip("/")
        self.secret = secret

    def call(self, method, path, token=None, body=None, query=None):
        url = self.base + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        data = json.dumps(body).encode("utf-8") if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Accept", "application/json")
        if data is not None:
            req.add_header("Content-Type", "application/json")
        if token:
            req.add_header("Authorization", "Bearer " + token)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                raw = resp.read().decode("utf-8", "replace")
                status = resp.status
        except urllib.error.HTTPError as err:
            raw = err.read().decode("utf-8", "replace")
            status = err.code
        except (urllib.error.URLError, OSError) as err:
            raise ApiError(
                f"{method} {path} failed: {err}. Is the backend running at {self.base}?"
            )
        try:
            payload = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            payload = {"_raw": raw[:300]}
        return status, payload


class Results:
    def __init__(self):
        self.records = []
        self.counts = {"PASS": 0, "FAIL": 0, "SKIP": 0}

    def _emit(self, status, section, name, detail=""):
        self.counts[status] += 1
        self.records.append(
            {"status": status, "section": section, "name": name, "detail": detail}
        )
        line = f"[{status}] {section} :: {name}"
        if detail and status != "PASS":
            line += f"\n         -> {detail}"
        print(line, flush=True)

    def check(self, section, name, ok, detail=""):
        self._emit("PASS" if ok else "FAIL", section, name, "" if ok else detail)
        return bool(ok)

    def eq(self, section, name, expected, actual):
        return self.check(
            section, name, expected == actual,
            f"expected {expected!r}, got {actual!r}",
        )

    def skip(self, section, name, reason):
        self._emit("SKIP", section, name, reason)

    @property
    def failures(self):
        return [r for r in self.records if r["status"] == "FAIL"]


@dataclass
class User:
    uid: str
    name: str
    tz: str
    token: str = ""


@dataclass
class Group:
    index: int
    name: str
    tz: str
    owner: User
    group_id: str = ""
    code: str = ""
    public: bool = False
    members: list = field(default_factory=list)

    @property
    def everyone(self):
        return [self.owner] + self.members

    @property
    def tag(self):
        return f"g{self.index + 1:02d}"


class Ctx:
    def __init__(self, args, api):
        self.args = args
        self.api = api
        self.res = Results()
        self.rng = random.Random(args.seed)
        self.run_id = secrets.token_hex(3).upper()
        self.groups = []
        self.owners = []
        self.pool = []
        self.extras = {}
        self.shared_user = None
        self.client = None
        self.db = None
        self.coll = {}
        self.db_ready = False
        self.db_name = ""

    @property
    def all_users(self):
        users = list(self.owners) + list(self.pool) + list(self.extras.values())
        seen = {}
        for u in users:
            seen[u.uid] = u
        return list(seen.values())


def make_user(rng, tz, secret, suffix=""):
    uid = secrets.token_hex(12)
    name = f"{rng.choice(FIRST_NAMES)} {rng.choice(LAST_NAMES)}{suffix}"
    token = mint_token(secret, uid, name, tz)
    return User(uid=uid, name=name, tz=tz, token=token)


def seed_user_docs(ctx):
    now = datetime.now(timezone.utc)
    for i, user in enumerate(ctx.all_users):
        ctx.coll["users"].update_one(
            {"_id": ObjectId(user.uid)},
            {"$setOnInsert": {
                "displayName": user.name,
                "timezone": user.tz,
                "city": "",
                "country": "",
                "deviceId": f"e2e-{ctx.run_id}-{i:03d}",
                "createdAt": now,
                "updatedAt": now,
            }},
            upsert=True,
        )


def seed_progress(ctx, group_id, user_id, date_key, count, eligible=True, complete=None):
    done = count >= 5 if complete is None else complete
    now = datetime.now(timezone.utc)
    flags = {p: i < count for i, p in enumerate(PRAYERS)}
    doc = {
        "groupId": group_id,
        "userId": ObjectId(user_id),
        "dateKey": date_key,
        **flags,
        "completedCount": count,
        "isDayComplete": done,
        "eligible": eligible,
        "completedAt": now if done else None,
        "createdAt": now,
        "updatedAt": now,
    }
    ctx.coll["progress"].update_one(
        {"groupId": group_id, "userId": ObjectId(user_id), "dateKey": date_key},
        {"$set": doc},
        upsert=True,
    )


def seed_summary(ctx, group_id, date_key, complete, eligible_count, completed_count, shielded=False):
    now = datetime.now(timezone.utc)
    ctx.coll["summaries"].update_one(
        {"groupId": group_id, "dateKey": date_key},
        {"$set": {
            "groupId": group_id,
            "dateKey": date_key,
            "eligibleCount": eligible_count,
            "completedCount": completed_count,
            "isGroupDayComplete": complete,
            "shielded": shielded,
            "completedAt": now if complete else None,
            "createdAt": now,
            "updatedAt": now,
        }},
        upsert=True,
    )


def set_group_fields(ctx, group_id, fields):
    ctx.coll["groups"].update_one({"groupId": group_id}, {"$set": fields})


def read_group(ctx, group_id):
    return ctx.coll["groups"].find_one({"groupId": group_id})


def read_summary(ctx, group_id, date_key):
    return ctx.coll["summaries"].find_one({"groupId": group_id, "dateKey": date_key})


def count_activities(ctx, group_id, type_, date_key=None):
    query = {"groupId": group_id, "type": type_}
    if date_key is not None:
        query["dateKey"] = date_key
    return ctx.coll["activities"].count_documents(query)


def backdate_group(ctx, group, days_back=10, user_ids=None):
    target = shift_key(active_day(group.tz), -days_back)
    query = {"groupId": group.group_id, "status": "active"}
    if user_ids:
        query["userId"] = {"$in": [ObjectId(u) for u in user_ids]}
    ctx.coll["members"].update_many(query, {"$set": {"effectiveFromDate": target}})
    ctx.coll["progress"].update_many(
        {"groupId": group.group_id, "dateKey": active_day(group.tz)},
        {"$set": {"eligible": True}},
    )


def tick(api, user, prayer, completed=True):
    return api.call(
        "POST",
        "/api/streak/v2/prayers/complete",
        token=user.token,
        body={"prayer": prayer, "completed": completed},
    )


def tick_all(api, user, count=5, completed=True):
    last = None
    for prayer in PRAYERS[:count]:
        last = tick(api, user, prayer, completed)
    return last


def dashboard(api, user, group_id):
    return api.call("GET", f"/api/streak/v2/groups/{group_id}/dashboard", token=user.token)


def dashboard_data(response):
    return response[1].get("data") or {}


def group_info(data):
    return data.get("group") or {}


def me_row(data):
    for member in data.get("members", []):
        if member.get("isMe"):
            return member
    return None


def my_group_item(ctx, owner, group_id):
    status, payload = ctx.api.call("GET", "/api/streak/v2/groups", token=owner.token)
    for item in (payload.get("data") or {}).get("groups", []):
        if item.get("groupId") == group_id:
            return item
    return None


def grouped_touch(payload, group_id):
    for entry in (payload.get("data") or {}).get("groups", []):
        if entry.get("groupId") == group_id:
            return entry
    return None


def check_create_contract(ctx, group, data):
    res = ctx.res
    tag = group.tag
    res.eq("create", f"{tag} responds 201-level payload with status active", "active", data.get("status"))
    res.eq("create", f"{tag} myRole is owner", "owner", data.get("myRole"))
    res.eq("create", f"{tag} isOwner is true", True, data.get("isOwner"))
    res.eq("create", f"{tag} memberCount starts at 1", 1, data.get("memberCount"))
    code = str(data.get("inviteCode") or "")
    res.check("create", f"{tag} inviteCode is 6 unambiguous chars",
              bool(re.fullmatch(r"[A-Z2-9]{6}", code)), f"got {code!r}")
    if TZ_OK:
        res.eq("create", f"{tag} dateKey equals the group-tz active day",
               active_day(group.tz), data.get("dateKey"))
    else:
        res.check("create", f"{tag} dateKey present", bool(data.get("dateKey")),
                  f"got {data.get('dateKey')!r}")


def join_via_code(ctx, group, user):
    res = ctx.res
    label = f"{group.tag} {user.name.split()[0]}"
    status, payload = ctx.api.call(
        "GET", f"/api/streak/v2/invite/{group.code}", token=user.token)
    res.eq("join", f"{label}: preview before join shows unmatched", "none",
           (payload.get("data") or {}).get("viewerState"))
    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/invite/{group.code}/join", token=user.token)
    data = payload.get("data") or {}
    res.eq("join", f"{label}: first join is fresh", False, data.get("alreadyMember"))
    res.check("join", f"{label}: message explains tomorrow requirement",
              "tomorrow" in str(data.get("message", "")).lower(),
              f"message={data.get('message')!r}")
    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/invite/{group.code}/join", token=user.token)
    res.eq("join", f"{label}: second join is idempotent", True,
           (payload.get("data") or {}).get("alreadyMember"))
    status, payload = ctx.api.call(
        "GET", f"/api/streak/v2/invite/{group.code}", token=user.token)
    res.eq("join", f"{label}: preview after join shows member", "member",
           (payload.get("data") or {}).get("viewerState"))


def phase_setup(ctx):
    res = ctx.res
    status, payload = ctx.api.call("GET", "/api/health")
    res.eq("server", "health endpoint", "ok", payload.get("status"))
    status, payload = ctx.api.call("GET", "/api/db-status")
    res.check("server", "database connected", payload.get("dbConnected") is True,
              f"db-status={payload}")

    specs = [
        {"tz": KHI, "public": False},
        {"tz": KHI, "public": False},
        {"tz": KHI, "public": False},
        {"tz": KHI, "public": False},
        {"tz": KHI, "public": False},
        {"tz": KHI, "public": False},
        {"tz": KHI, "public": False},
        {"tz": UTC_TZ, "public": False},
        {"tz": NYC if TZ_OK else UTC_TZ, "public": True},
        {"tz": KHI, "public": False},
    ]
    for idx in range(len(specs)):
        ctx.owners.append(make_user(ctx.rng, specs[idx]["tz"], ctx.api.secret, f" O{idx + 1}"))
    for idx in range(30):
        ctx.pool.append(make_user(ctx.rng, KHI, ctx.api.secret, f" M{idx + 1}"))
    ctx.shared_user = ctx.pool[0]
    for key, suffix in [("requester_a", " RA"), ("requester_b", " RB"),
                        ("joiner", " JN"), ("stranger", " ST"),
                        ("ghost_a", " GA"), ("ghost_b", " GB"), ("ghost_c", " GC")]:
        ctx.extras[key] = make_user(ctx.rng, KHI, ctx.api.secret, suffix)

    if ctx.db_ready:
        seed_user_docs(ctx)
    else:
        res.skip("server", "user documents seeded", "no database access")

    def pick(k, exclude=()):
        candidates = [u for u in ctx.pool if u not in exclude]
        return ctx.rng.sample(candidates, k)

    member_plan = {
        0: [ctx.shared_user] + pick(ctx.rng.randint(2, 4), exclude=(ctx.shared_user,)),
        1: [ctx.shared_user] + pick(1, exclude=(ctx.shared_user,)),
        2: [ctx.extras["ghost_a"], ctx.extras["ghost_b"], ctx.extras["ghost_c"]],
        3: pick(4),
        4: pick(4),
        5: [],
        6: pick(2),
        7: pick(3),
        8: pick(3),
        9: pick(ctx.rng.randint(4, 5)),
    }

    for idx, spec in enumerate(specs):
        owner = ctx.owners[idx]
        name = f"TEST-{ctx.run_id}-{idx + 1:02d} {ctx.rng.choice(GROUP_WORDS)}"
        status, payload = ctx.api.call(
            "POST", "/api/streak/v2/groups",
            token=owner.token,
            body={"name": name, "visibility": "public" if spec["public"] else "invite"},
        )
        data = payload.get("data") or {}
        group = Group(
            index=idx, name=name, tz=spec["tz"], owner=owner,
            group_id=data.get("groupId", ""), code=data.get("inviteCode", ""),
            public=spec["public"], members=list(member_plan[idx]),
        )
        ctx.groups.append(group)
        res.eq("create", f"{group.tag} create group succeeds", 201, status)
        if status != 201:
            raise ApiError(f"createGroup for {group.tag} failed: {payload}")
        check_create_contract(ctx, group, data)

    for group in ctx.groups:
        for member in group.members:
            join_via_code(ctx, group, member)

    stranger = ctx.extras["stranger"]
    status, payload = ctx.api.call(
        "GET", f"/api/streak/v2/invite/{ctx.groups[0].code}", token=stranger.token)
    res.eq("join", "stranger preview of an invite group shows unmatched", "none",
           (payload.get("data") or {}).get("viewerState"))
    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/invite/{ctx.groups[0].code}/join", token=stranger.token)
    res.eq("join", "stranger lands in the invite group", False,
           (payload.get("data") or {}).get("alreadyMember"))
    ctx.groups[0].members.append(stranger)
    if ctx.db_ready:
        seed_user_docs(ctx)

    for group in ctx.groups:
        item = my_group_item(ctx, group.owner, group.group_id)
        res.check("listing", f"{group.tag} owner sees the group in my groups",
                  item is not None, "group missing from /groups")
        if item is None:
            continue
        res.eq("listing", f"{group.tag} memberCount matches joins",
               1 + len(group.members), item.get("memberCount"))
        res.eq("listing", f"{group.tag} nobody is required on day one (effective tomorrow)",
               0, (item.get("today") or {}).get("required"))

    g0, g1 = ctx.groups[0], ctx.groups[1]
    status, payload = tick(ctx.api, ctx.shared_user, "fajr")
    touched = (payload.get("data") or {}).get("groups", [])
    touched_ids = {entry.get("groupId") for entry in touched}
    res.check("fanout", "one prayer tick reaches every group the user is in",
              {g0.group_id, g1.group_id} <= touched_ids, f"touched={touched_ids}")
    if TZ_OK:
        for group in (g0, g1):
            entry = grouped_touch(payload, group.group_id)
            res.eq("fanout", f"{group.tag} tick dateKey is that group's active day",
                   active_day(group.tz), (entry or {}).get("dateKey"))
    for group in (g0, g1):
        data = dashboard_data(dashboard(ctx.api, ctx.shared_user, group.group_id))
        row = me_row(data)
        res.eq("fanout", f"{group.tag} my row shows the tick", 1,
               (row or {}).get("completedCount"))


def phase_public_requests(ctx):
    res = ctx.res
    group = ctx.groups[8]
    requester_a = ctx.extras["requester_a"]
    requester_b = ctx.extras["requester_b"]

    status, payload = ctx.api.call(
        "GET", "/api/streak/v2/groups/discover", token=requester_a.token,
        query={"q": ctx.run_id})
    items = (payload.get("data") or {}).get("items", [])
    found_ids = {item.get("groupId") for item in items}
    res.check("discover", "public TEST group appears in discovery",
              group.group_id in found_ids, f"found={found_ids}")
    res.check("discover", "invite-only TEST groups stay hidden",
              ctx.groups[0].group_id not in found_ids,
              "invite group leaked into discovery")

    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/groups/{ctx.groups[0].group_id}/join-request",
        token=requester_a.token)
    res.eq("requests", "join request to invite-only group rejected", "INVITE_ONLY",
           payload.get("code"))

    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/groups/{group.group_id}/join-request",
        token=requester_a.token)
    request_id = (payload.get("data") or {}).get("requestId")
    res.eq("requests", "public join request accepted", ("pending", 201),
           ((payload.get("data") or {}).get("state"), status))
    if not request_id:
        raise ApiError(f"join request failed: {payload}")

    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/groups/{group.group_id}/join-request",
        token=requester_a.token)
    res.eq("requests", "duplicate pending request stays pending", "pending",
           (payload.get("data") or {}).get("state"))

    status, payload = ctx.api.call(
        "GET", f"/api/streak/v2/groups/{group.group_id}/requests",
        token=group.owner.token)
    pending = (payload.get("data") or {}).get("items", [])
    res.check("requests", "owner sees the pending request",
              any(str(item.get("id")) == str(request_id) for item in pending),
              f"items={pending}")

    status, payload = ctx.api.call(
        "GET", f"/api/streak/v2/groups/{group.group_id}/requests",
        token=group.members[0].token)
    res.eq("requests", "plain member cannot read requests", "ADMIN_ONLY",
           payload.get("code"))

    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/requests/{request_id}/approve", token=group.owner.token)
    res.eq("requests", "approve returns approved", "approved",
           (payload.get("data") or {}).get("status"))
    group.members.append(requester_a)
    item = my_group_item(ctx, group.owner, group.group_id)
    res.eq("requests", "approval increments memberCount",
           1 + len(group.members), (item or {}).get("memberCount"))

    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/groups/{group.group_id}/join-request",
        token=requester_b.token)
    request_b = (payload.get("data") or {}).get("requestId")
    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/requests/{request_b}/decline", token=group.owner.token)
    res.eq("requests", "decline returns declined", "declined",
           (payload.get("data") or {}).get("status"))
    status, payload = ctx.api.call("GET", "/api/streak/v2/requests/me", token=requester_b.token)
    res.eq("requests", "declined request leaves my pending list", 0,
           len((payload.get("data") or {}).get("items", [])))
    status, payload = ctx.api.call(
        "GET", f"/api/streak/v2/invite/{group.code}", token=requester_b.token)
    res.eq("requests", "declined viewer state surfaces in preview", "declined",
           (payload.get("data") or {}).get("viewerState"))


def phase_backdate(ctx):
    for group in ctx.groups:
        if group.index == 5:
            continue
        backdate_group(ctx, group, days_back=10 if group.index in (2, 6) else 1)


def phase_completion(ctx):
    res = ctx.res
    group = ctx.groups[0]
    everyone = group.everyone
    last = everyone[-1]
    for member in everyone[:-1]:
        tick_all(ctx.api, member, 5)
    tick_all(ctx.api, last, 4)
    data = dashboard_data(dashboard(ctx.api, group.owner, group.group_id))
    res.eq("completion", "required counts every backdated member",
           len(everyone), (data.get("today") or {}).get("required"))
    res.eq("completion", "four of five prayers per member complete nobody",
           len(everyone) - 1, (data.get("today") or {}).get("completed"))
    res.eq("completion", "day not complete while one member is at 4/5",
           False, (data.get("today") or {}).get("isGroupDayComplete"))

    status, payload = tick(ctx.api, last, "isha")
    entry = grouped_touch(payload, group.group_id)
    tick_day = (entry or {}).get("dateKey")
    res.check("completion", "final tick reports the written group day",
              bool(tick_day), f"entry={entry}")

    data = dashboard_data(dashboard(ctx.api, group.owner, group.group_id))
    res.eq("completion", "fifth tick completes the group day", True,
           (data.get("today") or {}).get("isGroupDayComplete"))
    res.eq("completion", "completed equals required", (data.get("today") or {}).get("required"),
           (data.get("today") or {}).get("completed"))
    if TZ_OK and tick_day:
        expected = run_from_days({tick_day}, active_day(group.tz))
        res.eq("completion", "streak counts the completed day", expected,
               group_info(data).get("currentStreak"))

    status, payload = ctx.api.call(
        "GET", f"/api/streak/v2/groups/{group.group_id}/activity", token=group.owner.token)
    items = (payload.get("data") or {}).get("items", [])
    completions = [i for i in items if i.get("type") == "group_day_completed"]
    res.eq("completion", "exactly one group_day_completed activity", 1, len(completions))
    res.check("completion", "per-prayer rows are retired from the feed",
              all(i.get("type") != "prayer_completed" for i in items),
              f"types={[i.get('type') for i in items]}")

    status, payload = tick(ctx.api, last, "isha")
    res.eq("completion", "re-tick of a completed prayer is accepted", 200, status)
    status, payload = ctx.api.call(
        "GET", f"/api/streak/v2/groups/{group.group_id}/members/{last.uid}",
        token=group.owner.token)
    total = ((payload.get("data") or {}).get("today") or {}).get("completedCount")
    res.eq("completion", "re-tick is idempotent (still 5/5)", 5, total)
    res.eq("completion", "no duplicate group_day_completed activity", 1,
           count_activities(ctx, group.group_id, "group_day_completed", tick_day)
           if ctx.db_ready else 1)

    grace = TZ_OK and local_minutes(group.tz) < GRACE_MINUTES
    tick(ctx.api, last, "isha", completed=False)
    data = dashboard_data(dashboard(ctx.api, group.owner, group.group_id))
    if grace:
        res.skip("completion", "un-tick reverts the group day",
                 "grace window: the completed day is locked, the un-tick lands on the new day")
        res.skip("completion", "streak drops after the revert",
                 "grace window: the completed day stays complete")
    else:
        res.eq("completion", "un-tick reverts the group day", False,
               (data.get("today") or {}).get("isGroupDayComplete"))
        if TZ_OK:
            res.eq("completion", "streak drops after the revert", 0,
                   group_info(data).get("currentStreak"))
    tick(ctx.api, last, "isha")
    data = dashboard_data(dashboard(ctx.api, group.owner, group.group_id))
    res.eq("completion", "re-tick restores the group day", True,
           (data.get("today") or {}).get("isGroupDayComplete"))


def phase_streak_days(ctx):
    res = ctx.res
    group = ctx.groups[1]
    day = active_day(group.tz)
    ctx.coll["summaries"].delete_many({"groupId": group.group_id, "dateKey": day})
    ctx.coll["progress"].delete_many({"groupId": group.group_id, "dateKey": day})
    set_group_fields(ctx, group.group_id, {"currentStreak": 0, "currentStreakStartDate": None})
    for offset in (1, 2, 3):
        seed_summary(ctx, group.group_id, shift_key(day, -offset), True,
                     len(group.everyone), len(group.everyone))
    set_group_fields(ctx, group.group_id, {"bestStreak": 5})

    data = dashboard_data(dashboard(ctx.api, group.owner, group.group_id))
    res.eq("streak", "three seeded complete days give a 3-day streak", 3,
           group_info(data).get("currentStreak"))
    res.eq("streak", "best streak reads from storage", 5,
           group_info(data).get("bestStreak"))

    last_touch = None
    for member in group.everyone:
        last_touch = tick_all(ctx.api, member, 5)
    tick_day = (grouped_touch(last_touch[1], group.group_id) or {}).get("dateKey")

    data = dashboard_data(dashboard(ctx.api, group.owner, group.group_id))
    if TZ_OK and tick_day:
        expected = run_from_days(
            {shift_key(day, -1), shift_key(day, -2), shift_key(day, -3), tick_day}, day)
        res.eq("streak", "completing the new day extends the run", expected,
               group_info(data).get("currentStreak"))
    res.eq("streak", "best streak never regresses", 5,
           group_info(data).get("bestStreak"))


def phase_ghost(ctx):
    res = ctx.res
    group = ctx.groups[2]
    owner, member_a, member_b, ghost = group.everyone
    for member in (owner, member_a, member_b):
        tick_all(ctx.api, member, 5)

    data = dashboard_data(dashboard(ctx.api, group.owner, group.group_id))
    res.eq("ghost", "3-day idle member is dropped from required", 3,
           (data.get("today") or {}).get("required"))
    res.eq("ghost", "remaining members still complete the day", True,
           (data.get("today") or {}).get("isGroupDayComplete"))
    ghost_row = next((m for m in data.get("members", [])
                      if m.get("userId") == ghost.uid), None)
    res.eq("ghost", "ghost row is flagged excludedInactive", True,
           (ghost_row or {}).get("excludedInactive"))
    res.eq("ghost", "ghost row is not required", False, (ghost_row or {}).get("required"))
    res.eq("ghost", "ghost row stays eligible (counts, doesn't block)", True,
           (ghost_row or {}).get("eligible"))

    tick(ctx.api, ghost, "fajr")
    data = dashboard_data(dashboard(ctx.api, group.owner, group.group_id))
    res.eq("ghost", "one tick brings the ghost back into the requirement", 4,
           (data.get("today") or {}).get("required"))
    res.eq("ghost", "already-complete day is not reverted by the return", True,
           (data.get("today") or {}).get("isGroupDayComplete"))


def phase_shield(ctx):
    res = ctx.res
    group = ctx.groups[3]
    day = active_day(group.tz)
    ended = shift_key(day, -1)
    everyone = group.everyone
    for member in everyone[:4]:
        seed_progress(ctx, group.group_id, member.uid, ended, 5, eligible=True)
    seed_progress(ctx, group.group_id, everyone[4].uid, ended, 2, eligible=True)
    seed_summary(ctx, group.group_id, ended, False, 5, 4)
    set_group_fields(ctx, group.group_id, {"shieldUsedWeekKey": None})

    data = dashboard_data(dashboard(ctx.api, group.owner, group.group_id))
    summary = read_summary(ctx, group.group_id, ended)
    res.check("shield", "ended day saved by the weekly shield",
              bool(summary and summary.get("isGroupDayComplete") and summary.get("shielded")),
              f"summary={summary}")
    stored = read_group(ctx, group.group_id)
    res.eq("shield", "shield marks the week as used", week_key_of(ended),
           (stored or {}).get("shieldUsedWeekKey"))
    res.check("shield", "streak survives through the shielded day",
              (group_info(data).get("currentStreak") or 0) >= 1,
              f"streak={group_info(data).get('currentStreak')}")
    expected_available = week_key_of(ended) != week_key_of(day)
    res.eq("shield", "shield record gates availability for the active week",
           expected_available, data.get("shieldAvailable"))
    res.check("shield", "shield event lands in the activity feed",
              count_activities(ctx, group.group_id, "group_shield_used") >= 1,
              "group_shield_used activity missing")


def phase_shield_limit(ctx):
    res = ctx.res
    group = ctx.groups[4]
    day = active_day(group.tz)
    ended = shift_key(day, -1)
    everyone = group.everyone
    ctx.coll["summaries"].delete_many({"groupId": group.group_id, "dateKey": day})
    ctx.coll["progress"].delete_many({"groupId": group.group_id, "dateKey": day})
    for member in everyone[:4]:
        seed_progress(ctx, group.group_id, member.uid, ended, 5, eligible=True)
    seed_progress(ctx, group.group_id, everyone[4].uid, ended, 2, eligible=True)
    seed_summary(ctx, group.group_id, ended, False, 5, 4)
    set_group_fields(ctx, group.group_id, {
        "shieldUsedWeekKey": week_key_of(ended),
        "currentStreakStartDate": None,
    })

    data = dashboard_data(dashboard(ctx.api, group.owner, group.group_id))
    summary = read_summary(ctx, group.group_id, ended)
    res.check("shield-limit", "already-used week never shields again",
              not (summary and summary.get("isGroupDayComplete")),
              f"summary={summary}")
    res.eq("shield-limit", "gap day breaks the streak", 0,
           group_info(data).get("currentStreak"))
    expected_available = week_key_of(ended) != week_key_of(day)
    res.eq("shield-limit", "dashboard reports the weekly shield state",
           expected_available, data.get("shieldAvailable"))
    res.eq("shield-limit", "no shield activity recorded", 0,
           count_activities(ctx, group.group_id, "group_shield_used"))


def phase_new_joiner(ctx):
    res = ctx.res
    group = ctx.groups[5]
    joiner = ctx.extras["joiner"]
    backdate_group(ctx, group, days_back=1, user_ids=[group.owner.uid])
    join_via_code(ctx, group, joiner)
    group.members.append(joiner)

    data = dashboard_data(dashboard(ctx.api, group.owner, group.group_id))
    res.eq("joiner", "brand-new group counts only backdated members as required", 1,
           (data.get("today") or {}).get("required"))
    data = dashboard_data(dashboard(ctx.api, joiner, group.group_id))
    row = me_row(data)
    res.eq("joiner", "joiner is not required today", False, (row or {}).get("required"))
    res.eq("joiner", "joiner sees today's requirement excludes them", 1,
           (data.get("today") or {}).get("required"))

    tick_all(ctx.api, group.owner, 5)
    data = dashboard_data(dashboard(ctx.api, group.owner, group.group_id))
    res.eq("joiner", "day completes without the new joiner", True,
           (data.get("today") or {}).get("isGroupDayComplete"))

    ctx.coll["members"].update_one(
        {"groupId": group.group_id, "userId": ObjectId(joiner.uid)},
        {"$set": {"effectiveFromDate": active_day(group.tz)}},
    )
    data = dashboard_data(dashboard(ctx.api, group.owner, group.group_id))
    res.eq("joiner", "next day the joiner becomes required", 2,
           (data.get("today") or {}).get("required"))
    data = dashboard_data(dashboard(ctx.api, joiner, group.group_id))
    res.eq("joiner", "joiner row flips to required", True,
           (me_row(data) or {}).get("required"))


def phase_history(ctx):
    res = ctx.res
    group = ctx.groups[6]
    day = active_day(group.tz)
    first_required = shift_key(day, -10)
    seeded = set()
    for offset in range(1, 35):
        key = shift_key(day, -offset)
        if offset % 3 != 0:
            seed_summary(ctx, group.group_id, key, True, len(group.everyone), len(group.everyone))
            seeded.add(key)

    anchor = date.fromisoformat(day)
    months = [(anchor.year, anchor.month)]
    prev = anchor.replace(day=1) - timedelta(days=1)
    months.append((prev.year, prev.month))

    for year, month in months:
        status, payload = ctx.api.call(
            "GET", f"/api/streak/v2/groups/{group.group_id}/history",
            token=group.owner.token, query={"year": year, "month": month})
        calendar_rows = (payload.get("data") or {}).get("calendar", [])
        expected = mirror_month(seeded, year, month, first_required, day)
        mismatches = [
            f"{row.get('dateKey')}={row.get('state')} (want {expected.get(row.get('dateKey'))})"
            for row in calendar_rows
            if expected.get(row.get("dateKey")) != row.get("state")
        ]
        res.check("history", f"{year}-{month:02d} calendar matches derived model",
                  bool(calendar_rows) and not mismatches,
                  "; ".join(mismatches[:10]) or "no calendar rows")
        info = payload.get("data") or {}
        res.check("history", f"{year}-{month:02d} response carries streak summary",
                  isinstance(info.get("currentStreak"), int) and isinstance(info.get("bestStreak"), int),
                  f"currentStreak={info.get('currentStreak')!r}")


def phase_timezones(ctx):
    res = ctx.res
    utc_group = ctx.groups[7]
    if TZ_OK:
        data = dashboard_data(dashboard(ctx.api, utc_group.owner, utc_group.group_id))
        res.eq("timezone", "UTC group reports its own active day", active_day(UTC_TZ),
               (data.get("group") or {}).get("dateKey"))
    for member in utc_group.everyone:
        last = tick_all(ctx.api, member, 5)
    entry = grouped_touch(last[1], utc_group.group_id)
    if TZ_OK:
        res.eq("timezone", "UTC tick writes the UTC active day",
               active_day(UTC_TZ), (entry or {}).get("dateKey"))
    data = dashboard_data(dashboard(ctx.api, utc_group.owner, utc_group.group_id))
    res.eq("timezone", "UTC group completes", True,
           (data.get("today") or {}).get("isGroupDayComplete"))
    res.eq("timezone", "UTC group streak is 1", 1,
           group_info(data).get("currentStreak"))

    ny_group = ctx.groups[8]
    if TZ_OK:
        last = None
        for member in ny_group.everyone:
            last = tick_all(ctx.api, member, 5)
        entry = grouped_touch(last[1], ny_group.group_id)
        res.eq("timezone", "New York tick writes the New York active day",
               active_day(NYC), (entry or {}).get("dateKey"))
        data = dashboard_data(dashboard(ctx.api, ny_group.owner, ny_group.group_id))
        res.eq("timezone", "New York group reports its own active day",
               active_day(NYC), group_info(data).get("dateKey"))
        res.eq("timezone", "New York group requires every backdated member",
               len(ny_group.everyone), (data.get("today") or {}).get("required"))
        res.eq("timezone", "New York group day completes", True,
               (data.get("today") or {}).get("isGroupDayComplete"))
        res.eq("timezone", "New York group streak is 1", 1,
               group_info(data).get("currentStreak"))
    else:
        res.skip("timezone", "New York active day", "tzdata unavailable")


def phase_management(ctx):
    res = ctx.res
    group = ctx.groups[9]
    owner = group.owner

    renamed = f"{group.name} Renamed"
    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/groups/{group.group_id}/rename",
        token=owner.token, body={"name": renamed})
    item = my_group_item(ctx, owner, group.group_id)
    res.eq("manage", "rename reflected in listing", renamed, (item or {}).get("name"))

    old_code = group.code
    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/groups/{group.group_id}/invite/rotate", token=owner.token)
    new_code = (payload.get("data") or {}).get("inviteCode")
    res.check("manage", "rotate returns a fresh code different from the old one",
              bool(new_code) and new_code != old_code, f"new={new_code!r} old={old_code!r}")
    if new_code:
        group.code = new_code
    status, payload = ctx.api.call("GET", f"/api/streak/v2/invite/{old_code}", token=owner.token)
    res.eq("manage", "old invite code is dead", "INVALID_INVITE", payload.get("code"))
    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/invite/{old_code}/join", token=ctx.extras["stranger"].token)
    res.eq("manage", "joining with the old code fails", "INVALID_INVITE", payload.get("code"))

    leaver = group.members[0]
    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/groups/{group.group_id}/leave", token=leaver.token)
    item = my_group_item(ctx, owner, group.group_id)
    res.eq("manage", "leave frees a slot", len(group.everyone) - 1, (item or {}).get("memberCount"))
    status, payload = ctx.api.call("GET", "/api/streak/v2/groups", token=leaver.token)
    mine = {g.get("groupId") for g in (payload.get("data") or {}).get("groups", [])}
    res.check("manage", "left member no longer lists the group", group.group_id not in mine,
              "group still listed after leave")
    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/groups/{group.group_id}/leave", token=owner.token)
    res.eq("manage", "owner cannot leave without transfer", "OWNER_MUST_TRANSFER",
           payload.get("code"))

    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/invite/{group.code}/join", token=leaver.token)
    data = payload.get("data") or {}
    res.eq("manage", "rejoin via fresh code reactivates the slot", False,
           data.get("alreadyMember"))
    item = my_group_item(ctx, owner, group.group_id)
    res.eq("manage", "rejoin restores memberCount", len(group.everyone),
           (item or {}).get("memberCount"))

    nudger = group.members[0]
    target = group.members[1]
    status, payload = ctx.api.call(
        "POST", "/api/streak/v2/groups/nudge", token=nudger.token,
        body={"groupId": group.group_id, "targetUserId": target.uid, "prayerName": "fajr"})
    res.eq("nudge", "first nudge accepted", (True, NUDGE_MAX_PER_TARGET - 1),
           ((payload.get("data") or {}).get("nudged"),
            (payload.get("data") or {}).get("remainingToday")))
    status, payload = ctx.api.call(
        "POST", "/api/streak/v2/groups/nudge", token=nudger.token,
        body={"groupId": group.group_id, "targetUserId": target.uid, "prayerName": "fajr"})
    res.eq("nudge", "same pair + prayer is a duplicate", "NUDGE_DUPLICATE",
           payload.get("code"))
    status, payload = ctx.api.call(
        "POST", "/api/streak/v2/groups/nudge", token=nudger.token,
        body={"groupId": group.group_id, "targetUserId": target.uid, "prayerName": "isha"})
    res.eq("nudge", "different prayer counts as a new nudge", True,
           (payload.get("data") or {}).get("nudged"))
    status, payload = ctx.api.call(
        "POST", "/api/streak/v2/groups/nudge", token=group.members[2].token,
        body={"groupId": group.group_id, "targetUserId": target.uid, "prayerName": "asr"})
    res.eq("nudge", "third distinct nudge fills the daily target cap", True,
           (payload.get("data") or {}).get("nudged"))
    status, payload = ctx.api.call(
        "POST", "/api/streak/v2/groups/nudge", token=group.members[3].token,
        body={"groupId": group.group_id, "targetUserId": target.uid, "prayerName": "maghrib"})
    res.eq("nudge", "target cap reached after three nudges", "NUDGE_LIMIT",
           payload.get("code"))
    status, payload = ctx.api.call(
        "POST", "/api/streak/v2/groups/nudge", token=nudger.token,
        body={"groupId": group.group_id, "targetUserId": nudger.uid})
    res.eq("nudge", "self-nudge rejected", "VALIDATION", payload.get("code"))
    status, payload = ctx.api.call(
        "POST", "/api/streak/v2/groups/nudge", token=nudger.token,
        body={"groupId": group.group_id, "targetUserId": ctx.extras["stranger"].uid})
    res.eq("nudge", "nudging a non-member rejected", "NOT_MEMBER", payload.get("code"))

    status, payload = ctx.api.call("GET", "/api/streak/v2/notifications", token=nudger.token)
    info = payload.get("data") or {}
    items = info.get("items", [])
    res.check("notifications", "member_joined events reach teammates",
              any(i.get("type") == "member_joined" for i in items),
              f"types={[i.get('type') for i in items]}")
    res.check("notifications", "items carry the group name",
              all(i.get("groupName") for i in items) if items else False,
              f"items={items[:2]}")
    res.check("notifications", "unread counter is positive", (info.get("unread") or 0) >= 1,
              f"unread={info.get('unread')}")
    ctx.api.call("POST", "/api/streak/v2/notifications/seen", token=nudger.token)
    status, payload = ctx.api.call("GET", "/api/streak/v2/notifications", token=nudger.token)
    res.eq("notifications", "seen marker clears unread", 0,
           (payload.get("data") or {}).get("unread"))

    status, payload = ctx.api.call(
        "POST", "/api/streak/v2/groups", token=ctx.extras["stranger"].token,
        body={"name": "x", "visibility": "invite"})
    res.eq("validation", "one-character group name rejected", "VALIDATION", payload.get("code"))
    status, payload = ctx.api.call(
        "GET", "/api/streak/v2/groups/grp_doesnotexist/dashboard", token=owner.token)
    res.eq("validation", "unknown group is a clean 404", ("GROUP_NOT_FOUND", 404),
           (payload.get("code"), status))
    status, payload = ctx.api.call(
        "GET", f"/api/streak/v2/groups/{group.group_id}/members/{ctx.extras['stranger'].uid}",
        token=owner.token)
    res.eq("validation", "member detail for a non-member is 404", "NOT_MEMBER",
           payload.get("code"))

    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/groups/{group.group_id}/archive", token=owner.token)
    stored = read_group(ctx, group.group_id)
    res.eq("manage", "archive flips group status", "archived", (stored or {}).get("status"))
    status, payload = ctx.api.call(
        "POST", f"/api/streak/v2/invite/{group.code}/join", token=ctx.extras["stranger"].token)
    res.eq("manage", "archived group invite is dead", "INVALID_INVITE", payload.get("code"))


def collect_test_data(ctx):
    group_ids = [g.group_id for g in ctx.groups]
    user_ids = [u.uid for u in ctx.all_users]
    return group_ids, user_ids


def cleanup_db(ctx, group_ids, user_ids):
    deleted = {}
    for name in ("activities", "progress", "summaries", "members", "requests"):
        deleted[name] = ctx.coll[name].delete_many({"groupId": {"$in": group_ids}}).deleted_count
    deleted["groups"] = ctx.coll["groups"].delete_many(
        {"groupId": {"$in": group_ids}}).deleted_count
    oids = [ObjectId(u) for u in user_ids]
    deleted["solo"] = ctx.coll["solo"].delete_many({"userId": {"$in": oids}}).deleted_count
    deleted["soloProgress"] = ctx.coll["solo_progress"].delete_many(
        {"userId": {"$in": oids}}).deleted_count
    deleted["users"] = ctx.coll["users"].delete_many({"_id": {"$in": oids}}).deleted_count
    return deleted


def cleanup_only(ctx, tag="TEST"):
    pattern = f"^{tag}-"
    groups = list(ctx.coll["groups"].find({"name": {"$regex": pattern}}))
    group_ids = [g["groupId"] for g in groups]
    user_ids = []
    if group_ids:
        user_ids = [m["userId"] for m in ctx.coll["members"].find(
            {"groupId": {"$in": group_ids}}, {"userId": 1})]
    deleted = {}
    for name in ("activities", "progress", "summaries", "members", "requests"):
        deleted[name] = ctx.coll[name].delete_many(
            {"groupId": {"$in": group_ids}}).deleted_count
    deleted["groups"] = ctx.coll["groups"].delete_many(
        {"groupId": {"$in": group_ids}}).deleted_count
    deleted["solo"] = ctx.coll["solo"].delete_many(
        {"userId": {"$in": user_ids}}).deleted_count
    deleted["soloProgress"] = ctx.coll["solo_progress"].delete_many(
        {"userId": {"$in": user_ids}}).deleted_count
    deleted["users"] = ctx.coll["users"].delete_many(
        {"deviceId": {"$regex": "^e2e-"}}).deleted_count
    print(json.dumps(deleted, indent=2))
    print(f"removed {deleted['groups']} TEST- groups and {deleted['users']} e2e- users")
    return deleted


def run_phase(ctx, name, fn, needs_db=False, needs_tz=False):
    if needs_db and not ctx.db_ready:
        ctx.res.skip("phase", name, "database access unavailable (--no-db or pymongo missing)")
        return
    if needs_tz and not TZ_OK:
        ctx.res.skip("phase", name, "tzdata unavailable")
        return
    print(f"\n----- {name} -----", flush=True)
    try:
        fn(ctx)
    except ApiError as err:
        ctx.res.check("phase", f"{name} aborted", False, str(err))
    except Exception as err:
        traceback.print_exc()
        ctx.res.check("phase", f"{name} aborted", False, f"{type(err).__name__}: {err}")


def print_banner(ctx, db_host):
    print("=" * 72)
    print("Sajda group-streak E2E")
    print(f"  API      : {ctx.api.base}")
    print(f"  Database : {ctx.db_name or 'n/a'} (host: {db_host or 'unknown'})")
    print(f"  Run tag  : TEST-{ctx.run_id}-*")
    print(f"  TZ data  : {'zones available' if TZ_OK else 'MISSING (pip install tzdata)'}")
    if TZ_OK:
        for tz in (KHI, UTC_TZ, NYC):
            print(f"    {tz:<18} today={today_key(tz)} active={active_day(tz)}")
    print("=" * 72)


def print_summary(ctx):
    counts = ctx.res.counts
    print("\n" + "=" * 72)
    print(f"RESULT: {counts['PASS']} passed, {counts['FAIL']} failed, {counts['SKIP']} skipped")
    if ctx.res.failures:
        print("\nFailures:")
        for rec in ctx.res.failures:
            print(f"  [{rec['section']}] {rec['name']}")
            if rec["detail"]:
                print(f"      {rec['detail']}")
    if ctx.groups:
        print("\nCreated groups:")
        for group in ctx.groups:
            print(f"  {group.tag} {group.name}")
            print(f"      id={group.group_id} code={group.code} tz={group.tz} "
                  f"members={len(group.everyone)} public={group.public}")
    print("=" * 72)


def main():
    parser = argparse.ArgumentParser(description="Sajda group-streak end-to-end tester")
    parser.add_argument("--base-url", default=None)
    parser.add_argument("--env-file", default=os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", ".env"))
    parser.add_argument("--jwt-secret", default=None)
    parser.add_argument("--mongo-uri", default=None)
    parser.add_argument("--db-name", default=None)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--no-db", action="store_true")
    parser.add_argument("--cleanup", action="store_true")
    parser.add_argument("--cleanup-only", action="store_true")
    parser.add_argument("--report", default=None)
    args = parser.parse_args()

    env = read_env_file(args.env_file)
    secret = (args.jwt_secret or os.environ.get("SAJDA_JWT_SECRET")
              or env.get("JWT_SECRET") or "sajda-secret-key-change-in-production")
    mongo_uri = args.mongo_uri or os.environ.get("MONGODB_URI") or env.get("MONGODB_URI")
    base_url = args.base_url or os.environ.get("SAJDA_API_BASE") or \
        f"http://localhost:{env.get('PORT', '5000')}"

    db_name = args.db_name
    if not db_name and mongo_uri:
        match = re.search(r"mongodb(?:\+srv)?://[^/]+/([^/?]+)", mongo_uri)
        db_name = match.group(1) if match else "test"
    db_name = db_name or "test"

    api = Api(base_url, secret)
    ctx = Ctx(args, api)
    ctx.db_name = db_name

    db_host = None
    try:
        status, payload = api.call("GET", "/api/db-status")
        db_host = payload.get("envUriHosts") or None
    except ApiError as err:
        print(f"FATAL: {err}")
        print("Start the backend first:  cd backend && npm run dev")
        return 2

    if not args.no_db and PYMONGO_OK and mongo_uri:
        try:
            ctx.client = pymongo.MongoClient(mongo_uri, serverSelectionTimeoutMS=20000)
            ctx.db = ctx.client[db_name]
            ctx.coll = {
                "groups": ctx.db["groups"],
                "members": ctx.db["groupmembers"],
                "progress": ctx.db["groupdailyprogresses"],
                "summaries": ctx.db["groupdailysummaries"],
                "activities": ctx.db["groupactivities"],
                "requests": ctx.db["joinrequests"],
                "users": ctx.db["users"],
                "solo": ctx.db["solostreaks"],
                "solo_progress": ctx.db["solodailyprogresses"],
            }
            ctx.db.command("ping")
            ctx.db_ready = True
        except Exception as err:
            ctx.db_ready = False
            print(f"WARNING: database unavailable ({type(err).__name__}: {err}); "
                  "running HTTP-only scenarios")

    if args.cleanup_only:
        if not ctx.db_ready:
            print("FATAL: --cleanup-only needs database access")
            return 2
        cleanup_only(ctx)
        return 0

    print_banner(ctx, db_host)

    run_phase(ctx, "setup: create 10 groups + random members", phase_setup)
    run_phase(ctx, "discover + join requests", phase_public_requests)
    run_phase(ctx, "seed: backdate memberships", phase_backdate, needs_db=True)
    run_phase(ctx, "scenario: group day completion gating", phase_completion, needs_db=False)
    run_phase(ctx, "scenario: streak across days", phase_streak_days, needs_db=True)
    run_phase(ctx, "scenario: ghost-member exclusion", phase_ghost)
    run_phase(ctx, "scenario: weekly shield saves a day", phase_shield, needs_db=True)
    run_phase(ctx, "scenario: one shield per week", phase_shield_limit, needs_db=True)
    run_phase(ctx, "scenario: new joiner counts from tomorrow", phase_new_joiner, needs_db=True)
    run_phase(ctx, "scenario: month history across the boundary", phase_history, needs_db=True)
    run_phase(ctx, "scenario: timezone day boundaries", phase_timezones)
    run_phase(ctx, "scenario: management + nudges + notifications", phase_management, needs_db=True)

    if args.cleanup:
        if ctx.db_ready:
            group_ids, user_ids = collect_test_data(ctx)
            deleted = cleanup_db(ctx, group_ids, user_ids)
            print(f"\ncleanup: {json.dumps(deleted)}")
        else:
            print("\ncleanup skipped: no database access")

    print_summary(ctx)

    if args.report:
        report = {
            "api": api.base,
            "database": db_name,
            "run_tag": f"TEST-{ctx.run_id}",
            "counts": ctx.res.counts,
            "records": ctx.res.records,
            "groups": [
                {"tag": g.tag, "name": g.name, "groupId": g.group_id,
                 "inviteCode": g.code, "tz": g.tz, "members": len(g.everyone),
                 "public": g.public}
                for g in ctx.groups
            ],
        }
        with open(args.report, "w", encoding="utf-8") as fh:
            json.dump(report, fh, indent=2)
        print(f"report written to {args.report}")

    return 1 if ctx.res.counts["FAIL"] else 0


if __name__ == "__main__":
    sys.exit(main())
