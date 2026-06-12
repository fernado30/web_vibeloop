import { execSync } from "node:child_process";
import fs from "node:fs";

const xml = execSync("adb shell run-as com.vibeloop.vibeloop cat /data/data/com.vibeloop.vibeloop/shared_prefs/FlutterSharedPreferences.xml", { encoding: "utf8" });
const match = xml.match(/<string name="flutter.sb-rkwugxemjrwtfjvtckes-auth-token">([\s\S]*?)<\/string>/);
if (!match) throw new Error("token missing");
const token = JSON.parse(match[1].replace(/&quot;/g, '"'));

const envText = fs.readFileSync("apps/mobile/assets/.env", "utf8");
const env = {};
for (const line of envText.split(/\r?\n/)) {
  const s = line.trim();
  if (!s || s.startsWith("#")) continue;
  const i = s.indexOf("=");
  if (i > 0) env[s.slice(0, i)] = s.slice(i + 1);
}

const params = new URLSearchParams();
params.set("select", "id,name,invite_code,invite_paused,created_at");
params.set("group_members.user_id", `eq.${token.user.id}`);
params.set("order", "created_at.desc");
params.set("limit", "10");

const url = `${env.SUPABASE_URL}/rest/v1/groups?${params.toString()}`;
const resp = await fetch(url, {
  headers: {
    apikey: env.SUPABASE_ANON_KEY,
    Authorization: `Bearer ${token.access_token}`,
    Accept: "application/json",
  },
});

console.log("status", resp.status);
console.log(await resp.text());
