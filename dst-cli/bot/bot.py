"""Discord bot for the dst CLI.
Slash commands restricted to a single channel; long-running ops stream output.
Reads config from .bot.env (chmod 600) — token never logged.
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import subprocess
from pathlib import Path
from typing import Optional

import discord
from discord import app_commands

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("dst-bot")

ROOT = Path(__file__).resolve().parents[2]
DST_BIN = "/usr/local/bin/dst"
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
NON_WORLD_BRANCHES = {"main", "master", "HEAD"}

# --- config -------------------------------------------------------------------
def load_env(path: Path) -> dict:
    out = {}
    if not path.exists():
        return out
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out

CFG = load_env(Path(__file__).parent / ".bot.env")
TOKEN      = CFG.get("DISCORD_TOKEN") or os.environ.get("DISCORD_TOKEN", "")
CHANNEL_ID = int(CFG.get("DST_CONTROL_CHANNEL_ID") or os.environ.get("DST_CONTROL_CHANNEL_ID", "0"))
GUILD_ID   = int(CFG.get("DST_GUILD_ID") or os.environ.get("DST_GUILD_ID", "0"))
MAX_CHARS  = 1800

if not TOKEN:
    raise SystemExit("DISCORD_TOKEN missing in .bot.env")
if not CHANNEL_ID:
    raise SystemExit("DST_CONTROL_CHANNEL_ID missing in .bot.env")

# Optional: DISCORD_WEBHOOK_URL used by the dst CLI for event notifications
# (no action needed here — the CLI reads it directly from .bot.env)

GUILD: Optional[discord.Object] = discord.Object(id=GUILD_ID) if GUILD_ID else None

# --- helpers ------------------------------------------------------------------
def in_allowed_channel(interaction: discord.Interaction) -> bool:
    return interaction.channel_id == CHANNEL_ID

async def deny_wrong_channel(interaction: discord.Interaction):
    await interaction.response.send_message(
        f"This bot only responds in <#{CHANNEL_ID}>.", ephemeral=True
    )

def run_dst(args: list[str], json_mode: bool = False) -> tuple[int, str, str]:
    cmd = [DST_BIN] + (["--json"] if json_mode else []) + args
    res = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    return res.returncode, res.stdout, res.stderr

async def stream_dst(args: list[str], on_line):
    proc = await asyncio.create_subprocess_exec(
        DST_BIN, *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
    )
    assert proc.stdout
    async for raw in proc.stdout:
        line = ANSI_RE.sub("", raw.decode("utf-8", errors="replace").rstrip())
        if line:
            await on_line(line)
    return await proc.wait()

async def git_fetch_branches() -> list[str]:
    """Fetch from origin and return all branch names (local + remote, deduplicated)."""
    await asyncio.create_subprocess_exec(
        "git", "-C", str(ROOT), "fetch", "--prune", "origin",
        stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL,
    )
    proc = await asyncio.create_subprocess_exec(
        "git", "-C", str(ROOT),
        "for-each-ref", "--format=%(refname:short)",
        "refs/heads/", "refs/remotes/origin/",
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
    )
    assert proc.stdout
    out, _ = await proc.communicate()
    seen, branches = set(), []
    for line in out.decode().splitlines():
        name = line.strip().removeprefix("origin/")
        if name and name not in NON_WORLD_BRANCHES and name not in seen:
            seen.add(name)
            branches.append(name)
    return branches

def dst_list_data() -> dict:
    rc, out, _ = run_dst(["list"], json_mode=True)
    if rc == 0:
        try:
            return json.loads(out)
        except json.JSONDecodeError:
            pass
    return {}

# --- switch logic (shared by /switch and the worlds select menu) --------------
async def do_switch(interaction: discord.Interaction, branch: str):
    user = interaction.user
    header = f"🔄 **switch → `{branch}`** (by {user.mention})"
    log_lines: list[str] = []
    last_edit = 0.0
    lock = asyncio.Lock()

    async def render():
        body = "\n".join(log_lines[-40:])
        if len(body) > MAX_CHARS:
            body = body[-MAX_CHARS:]
        await interaction.edit_original_response(content=f"{header}\n```\n{body}\n```", view=None)

    async def on_line(line: str):
        nonlocal last_edit
        log_lines.append(line)
        now = asyncio.get_event_loop().time()
        if now - last_edit > 1.5:
            last_edit = now
            async with lock:
                try:
                    await render()
                except discord.HTTPException as e:
                    log.warning("edit failed: %s", e)

    await interaction.edit_original_response(content=f"{header}\n```\nstarting...\n```", view=None)
    rc = await stream_dst(["switch", branch], on_line)
    log_lines += ["", f"[exit {rc}]"]
    await render()

# --- bot ----------------------------------------------------------------------
intents = discord.Intents.default()
client = discord.Client(intents=intents)
tree = app_commands.CommandTree(client)

@client.event
async def on_ready():
    log.info("Logged in as %s (id=%s)", client.user, client.user.id if client.user else "?")
    if GUILD:
        try:
            tree.copy_global_to(guild=GUILD)
            synced = await tree.sync(guild=GUILD)
            log.info("Synced %d guild commands to guild %s", len(synced), GUILD.id)
            return
        except discord.Forbidden:
            log.warning("Guild %s: Missing Access — falling back to global sync.", GUILD.id)
    synced = await tree.sync()
    log.info("Synced %d global commands (may take up to 1h to appear)", len(synced))

# --- /worlds (dropdown select menu) ------------------------------------------
class WorldSelect(discord.ui.Select):
    def __init__(self, branches: list[str], active: str, running: set[str]):
        options = []
        for b in branches[:25]:
            marks = []
            if b == active:    marks.append("active")
            if b in running:   marks.append("🟢")
            label = b if not marks else f"{b}  [{', '.join(marks)}]"
            options.append(discord.SelectOption(label=label, value=b,
                           default=(b == active)))
        super().__init__(placeholder="Pick a world to switch to…",
                         min_values=1, max_values=1, options=options)

    async def callback(self, interaction: discord.Interaction):
        branch = self.values[0]
        await interaction.response.defer()
        await do_switch(interaction, branch)

class WorldView(discord.ui.View):
    def __init__(self, branches: list[str], active: str, running: set[str]):
        super().__init__(timeout=60)
        self.add_item(WorldSelect(branches, active, running))

    async def on_timeout(self):
        pass  # message stays, select just stops responding

@tree.command(description="Show all worlds and pick one to switch to")
async def worlds(interaction: discord.Interaction):
    if not in_allowed_channel(interaction):
        return await deny_wrong_channel(interaction)
    await interaction.response.defer(thinking=True)

    branches = await git_fetch_branches()
    data = dst_list_data()
    active  = data.get("active_world") or ""
    running = {b["name"] for b in data.get("branches", []) if b.get("running")}
    cloud   = data.get("remote", [])

    if not branches:
        return await interaction.edit_original_response(content="No world branches found.")

    status_line = (
        f"**Active world:** `{active or '(none)'}`  "
        f"{'🟢 running' if active in running else '🔴 stopped'}\n"
        f"**Cloud saves:** {', '.join(f'`{r}`' for r in cloud) or '(none)'}\n\n"
        f"Select a world below to switch:"
    )
    view = WorldView(branches, active, running)
    await interaction.edit_original_response(content=status_line, view=view)

# --- /list -------------------------------------------------------------------
@tree.command(description="List all worlds with running/active markers")
async def list(interaction: discord.Interaction):
    if not in_allowed_channel(interaction):
        return await deny_wrong_channel(interaction)
    data = dst_list_data()
    lines = [
        f"**Branch:** `{data.get('current_branch') or '?'}`",
        f"**Active:** `{data.get('active_world') or '(none)'}`",
        "", "**Worlds:**",
    ]
    for b in data.get("branches", []):
        marks = []
        if b["running"]:      marks.append("🟢 running")
        if b["active"]:       marks.append("active")
        if b["checked_out"]:  marks.append("checked-out")
        lines.append(f"• `{b['name']}`" + (f"  — {', '.join(marks)}" if marks else ""))
    if cloud := data.get("remote", []):
        lines += ["", "**Cloud saves:** " + ", ".join(f"`{r}`" for r in cloud)]
    await interaction.response.send_message("\n".join(lines))

# --- /status -----------------------------------------------------------------
@tree.command(description="Show current world status, container health, Drive save size")
async def status(interaction: discord.Interaction):
    if not in_allowed_channel(interaction):
        return await deny_wrong_channel(interaction)
    await interaction.response.defer(thinking=True)

    rc, out, err = run_dst(["status"], json_mode=True)
    if rc != 0:
        return await interaction.edit_original_response(content=f"failed:\n```{err}```")
    d = json.loads(out)

    world = d.get("active_world") or "(none)"
    running = d.get("running", False)

    # Get Drive save size async
    drive_size = "?"
    try:
        proc = await asyncio.create_subprocess_exec(
            "rclone", "size", f"dst-storage:dst-worlds/{world}.tar.gz",
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
        )
        size_out, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
        m = re.search(r"Total size: ([\d.]+ \w+)", size_out.decode())
        drive_size = m.group(1) if m else "?"
    except Exception:
        pass

    lines = [
        f"**world:** `{world}`",
        f"**status:** {'🟢 running' if running else '🔴 stopped'}",
        f"**master:** `{d.get('master_status') or '-'}`",
        f"**caves:**  `{d.get('caves_status') or '-'}`",
        f"**branch:** `{d.get('branch') or '?'}`",
        f"**drive save:** `{drive_size}`",
    ]
    await interaction.edit_original_response(content="\n".join(lines))

# --- /switch -----------------------------------------------------------------
async def branch_autocomplete(interaction: discord.Interaction, current: str):
    data = dst_list_data()
    local  = [b["name"] for b in data.get("branches", [])]
    remote = [r for r in data.get("remote", []) if r not in local]
    names  = local + remote
    cur    = current.lower()
    return [app_commands.Choice(name=n, value=n) for n in names if cur in n.lower()][:25]

@tree.command(description="Switch to a world by name (stop → push → checkout → pull → start)")
@app_commands.describe(branch="Target world / branch name")
@app_commands.autocomplete(branch=branch_autocomplete)
async def switch(interaction: discord.Interaction, branch: str):
    if not in_allowed_channel(interaction):
        return await deny_wrong_channel(interaction)
    await interaction.response.defer(thinking=True)
    await do_switch(interaction, branch)

# --- /destroy ----------------------------------------------------------------
class DestroyConfirmView(discord.ui.View):
    def __init__(self, user: discord.User | discord.Member):
        super().__init__(timeout=30)
        self.user = user

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        if interaction.user.id != self.user.id:
            await interaction.response.send_message("Only the person who ran this can confirm.", ephemeral=True)
            return False
        return True

    @discord.ui.button(label="Yes, destroy", style=discord.ButtonStyle.danger)
    async def confirm(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        self.stop()
        await do_action_stream(interaction, "destroy", "💣 Destroying DST server…")

    @discord.ui.button(label="Cancel", style=discord.ButtonStyle.secondary)
    async def cancel(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.edit_message(content="Cancelled.", view=None)
        self.stop()

    async def on_timeout(self):
        pass

async def do_action_stream(interaction: discord.Interaction, action: str, header: str):
    log_lines: list[str] = []

    async def on_line(line: str):
        log_lines.append(line)
        body = "\n".join(log_lines[-30:])[-MAX_CHARS:]
        try:
            await interaction.edit_original_response(
                content=f"{header}\n```\n{body}\n```", view=None
            )
        except discord.HTTPException:
            pass

    rc = await stream_dst([action], on_line)
    body = "\n".join(log_lines[-30:])[-MAX_CHARS:] or "(no output)"
    await interaction.edit_original_response(
        content=f"{header}\n```\n{body}\n[exit {rc}]\n```", view=None
    )

@tree.command(description="Stop server, push save to Drive, remove all DST containers/image/volumes")
async def destroy(interaction: discord.Interaction):
    if not in_allowed_channel(interaction):
        return await deny_wrong_channel(interaction)
    view = DestroyConfirmView(interaction.user)
    await interaction.response.send_message(
        "⚠️ **This will:**\n"
        "• Stop the running world and push save to Google Drive\n"
        "• Remove all DST containers, the `dst-server` image, and leftover volumes\n"
        "• Clear `./data/` from the VPS\n\n"
        "Drive saves are kept. You can `dst start` again later to rebuild.\n\n"
        "**Are you sure?**",
        view=view,
        ephemeral=False,
    )

# --- /start /stop /push ------------------------------------------------------
async def _simple(interaction: discord.Interaction, action: str, header: str):
    if not in_allowed_channel(interaction):
        return await deny_wrong_channel(interaction)
    await interaction.response.defer(thinking=True)
    await do_action_stream(interaction, action, header)

@tree.command(description="Start the current world (pulls save from Drive first)")
async def start(interaction: discord.Interaction):
    await _simple(interaction, "start", "🟢 Starting server…")

@tree.command(description="Stop the current world (pushes save to Drive, clears VPS)")
async def stop(interaction: discord.Interaction):
    await _simple(interaction, "stop", "🔴 Stopping server…")

@tree.command(description="Restart the current world (applies DST game updates via steamcmd)")
async def restart(interaction: discord.Interaction):
    await _simple(interaction, "restart", "🔄 Restarting server (applying game updates)…")

# --- /reset ------------------------------------------------------------------
class ResetConfirmView(discord.ui.View):
    def __init__(self, user: discord.User | discord.Member, world: str):
        super().__init__(timeout=30)
        self.user = user
        self.world = world

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        if interaction.user.id != self.user.id:
            await interaction.response.send_message("Only the person who ran this can confirm.", ephemeral=True)
            return False
        return True

    @discord.ui.button(label="Yes, reset world", style=discord.ButtonStyle.danger)
    async def confirm(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        self.stop()
        await do_action_stream(interaction, "reset", f"🌍 Resetting world `{self.world}`…")

    @discord.ui.button(label="Cancel", style=discord.ButtonStyle.secondary)
    async def cancel(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.edit_message(content="Cancelled.", view=None)
        self.stop()

    async def on_timeout(self):
        pass

@tree.command(description="Reset the current world to a fresh map (archives old save on Drive)")
async def reset(interaction: discord.Interaction):
    if not in_allowed_channel(interaction):
        return await deny_wrong_channel(interaction)
    await interaction.response.defer(thinking=True)
    rc, out, _ = run_dst(["status"], json_mode=True)
    world = "(unknown)"
    if rc == 0:
        try:
            d = json.loads(out)
            world = d.get("active_world") or d.get("branch") or "(unknown)"
        except json.JSONDecodeError:
            pass
    view = ResetConfirmView(interaction.user, world)
    await interaction.edit_original_response(
        content=(
            f"⚠️ **Reset world `{world}`?**\n\n"
            "This will:\n"
            f"• Archive current save to Drive as `{world}.pre-reset.tar.gz` (recoverable)\n"
            f"• Delete the live Drive save `{world}.tar.gz`\n"
            "• Wipe local `./data/` and start a fresh world (same mods/config)\n\n"
            "Players will lose all in-world progress on this world."
        ),
        view=view,
    )

@tree.command(description="Push current world's save to Google Drive")
async def push(interaction: discord.Interaction):
    await _simple(interaction, "push", "☁️ Pushing save to Drive…")

# --- /help -------------------------------------------------------------------
@tree.command(description="Show all bot commands and what they do")
async def help(interaction: discord.Interaction):
    if not in_allowed_channel(interaction):
        return await deny_wrong_channel(interaction)
    msg = (
        "**🎮 DST control bot — commands**\n\n"
        "**World info**\n"
        "• `/worlds` — dropdown menu to pick & switch worlds\n"
        "• `/list` — list all branches with running/active markers\n"
        "• `/status` — current world, container health, Drive save size\n\n"
        "**Server control**\n"
        "• `/start` — start the current world (pulls save from Drive first)\n"
        "• `/stop` — stop the current world (pushes save to Drive, clears VPS)\n"
        "• `/restart` — restart in place (applies DST game updates via steamcmd)\n"
        "• `/switch <branch>` — stop+push current → checkout → pull → start\n\n"
        "**Saves**\n"
        "• `/push` — manually push current save to Drive\n"
        "• `/reset` — wipe world to a fresh map, archive old save (asks to confirm)\n\n"
        "**Maintenance**\n"
        "• `/destroy` — stop+push, remove containers/image/volumes (asks to confirm)\n\n"
        "**Help**\n"
        "• `/help` — this message"
    )
    await interaction.response.send_message(msg, ephemeral=True)

# --- main --------------------------------------------------------------------
if __name__ == "__main__":
    client.run(TOKEN, log_handler=None)
