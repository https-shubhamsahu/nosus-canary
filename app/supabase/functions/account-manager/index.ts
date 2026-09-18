import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

function isObjectNotFound(err: { message: string }): boolean {
  const m = err.message.toLowerCase();
  return m.includes("not found") || m.includes("does not exist") || m.includes("404");
}

Deno.serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const admin = createClient(supabaseUrl, serviceRoleKey);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const uid = user.id;

  const summary = {
    groups: { processed: 0, deleted: 0, ownership_transferred: 0, admin_promoted: 0 },
    files: { database_records: 0, storage_objects_deleted: 0 },
    memberships_removed: 0,
    notes_deleted: 0,
    account: { profile_deleted: false, user_deleted: false },
  };

  const errors: string[] = [];
  const addError = (msg: string) => { errors.push(msg); };

  const respond = (success: boolean, status: number) =>
    new Response(JSON.stringify({ success, summary, errors }), {
      status,
      headers: { "Content-Type": "application/json" },
    });

  // ── 1. Find all groups where user is admin ──────────────────────────────────
  const { data: adminEntries, error: adminQueryErr } = await admin
    .from("study_group_members")
    .select("group_id")
    .eq("user_id", uid)
    .eq("is_admin", true);

  if (adminQueryErr) {
    addError(`Failed to query admin groups: ${adminQueryErr.message}`);
    return respond(false, 500);
  }

  // ── 2. Process each owned group ────────────────────────────────────────────
  for (const entry of adminEntries || []) {
    const groupId = entry.group_id;
    summary.groups.processed++;

    const { data: members, error: membersErr } = await admin
      .from("study_group_members")
      .select("user_id, joined_at, is_admin")
      .eq("group_id", groupId)
      .neq("user_id", uid);

    if (membersErr) {
      addError(`Group ${groupId}: query members failed — ${membersErr.message}`);
      continue;
    }

    const otherAdmins = members.filter((m) => m.is_admin);
    const otherNonAdmins = members.filter((m) => !m.is_admin);

    if (members.length === 0) {
      // No remaining members → delete group + storage + all data
      const { data: files, error: filesErr } = await admin
        .from("secure_files")
        .select("id, storage_path")
        .eq("group_id", groupId);

      if (filesErr) {
        addError(`Group ${groupId}: query files failed — ${filesErr.message}`);
      } else {
        summary.files.database_records += files.length;

        if (files.length > 0) {
          const paths = files.map((f) => f.storage_path || f.id);
          const { error: storageErr } = await admin.storage.from("secure-files").remove(paths);

          if (storageErr) {
            if (isObjectNotFound(storageErr)) {
              summary.files.storage_objects_deleted += paths.length;
            } else {
              addError(`Group ${groupId}: storage remove error — ${storageErr.message}`);
            }
          } else {
            summary.files.storage_objects_deleted += paths.length;
          }
        }
      }

      const { error: delErr } = await admin.from("study_groups").delete().eq("id", groupId);
      if (delErr) {
        addError(`Group ${groupId}: delete failed — ${delErr.message}`);
      } else {
        summary.groups.deleted++;
      }

    } else if (otherAdmins.length > 0) {
      // Another admin exists → group survives, ownership stays
      summary.groups.ownership_transferred++;

    } else {
      // Members exist but no other admin → promote earliest joined
      const earliest = otherNonAdmins.reduce((a, b) => (a.joined_at < b.joined_at ? a : b));
      const { error: promoteErr } = await admin
        .from("study_group_members")
        .update({ is_admin: true })
        .eq("group_id", groupId)
        .eq("user_id", earliest.user_id);

      if (promoteErr) {
        addError(`Group ${groupId}: promote failed — ${promoteErr.message}`);
      } else {
        summary.groups.admin_promoted++;
      }
    }
  }

  // ── 3. Remove remaining memberships (groups where user was a regular member) ──
  const { count: removedCount, error: rmErr } = await admin
    .from("study_group_members")
    .delete({ count: "exact" })
    .eq("user_id", uid);

  if (rmErr) {
    addError(`Remove memberships: ${rmErr.message}`);
  } else {
    summary.memberships_removed = removedCount ?? 0;
  }

  // ── 4. Delete private notes ────────────────────────────────────────────────
  const { count: deletedCount, error: notesErr } = await admin
    .from("user_notes")
    .delete({ count: "exact" })
    .eq("user_id", uid);

  if (notesErr) {
    addError(`Delete notes: ${notesErr.message}`);
  } else {
    summary.notes_deleted = deletedCount ?? 0;
  }

  // ── 5. Delete profile (cascade removes devices) ────────────────────────────
  const { error: profileErr } = await admin.from("profiles").delete().eq("id", uid);
  if (profileErr) {
    addError(`Delete profile: ${profileErr.message}`);
  } else {
    summary.account.profile_deleted = true;
  }

  // ── 6. Delete the auth user (last — after this, no more operations) ───────
  const { error: deleteUserErr } = await admin.auth.admin.deleteUser(uid);
  if (deleteUserErr) {
    if (isObjectNotFound(deleteUserErr)) {
      summary.account.user_deleted = true;
    } else {
      addError(`Delete auth user: ${deleteUserErr.message}`);
    }
  } else {
    summary.account.user_deleted = true;
  }

  const success = errors.length === 0;
  return respond(success, success ? 200 : 500);
});
