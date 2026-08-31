import os

from flask import Flask, redirect, render_template_string, request, session, url_for

app = Flask(__name__)
app.secret_key = os.environ["WRI_CHAT_SECRET"]
CHAT_USERNAME = os.environ["WRI_CHAT_USERNAME"]
CHAT_PASSWORD = os.environ["WRI_CHAT_PASSWORD"]
STAGING_VHOST = os.environ["WRI_STAGING_VHOST"]

LOGIN_PAGE = """<!doctype html>
<title>Rocket.Chat | WRI Operations</title>
<h1>Rocket.Chat</h1>
<p>WRI Operations workspace</p>
{% if error %}<p><strong>{{ error }}</strong></p>{% endif %}
<form method="post" action="{{ url_for('login') }}">
  <label>Username <input name="username" required></label><br>
  <label>Password <input name="password" type="password" required></label><br>
  <button type="submit">Sign in</button>
</form>
"""

CHANNEL_PAGE = """<!doctype html>
<title>#ops-briefing | Rocket.Chat</title>
<h1>#ops-briefing</h1>
<p><strong>release-manager</strong> · 09:42</p>
<blockquote>
  The migration console has moved to <code>{{ staging_vhost }}.wri.local</code>.
  It is not included in the approved virtual-host wordlist while the migration
  remains in progress. Do not publish this hostname externally.
</blockquote>
<p><a href="{{ url_for('logout') }}">Sign out</a></p>
"""


@app.get("/")
def index():
    if session.get("chat_user"):
        return redirect(url_for("ops_briefing"))
    return render_template_string(LOGIN_PAGE, error=None)


@app.post("/login")
def login():
    if (
        request.form.get("username") == CHAT_USERNAME
        and request.form.get("password") == CHAT_PASSWORD
    ):
        session["chat_user"] = CHAT_USERNAME
        return redirect(url_for("ops_briefing"))
    return render_template_string(LOGIN_PAGE, error="Invalid credentials."), 401


@app.get("/channels/ops-briefing")
def ops_briefing():
    if not session.get("chat_user"):
        return redirect(url_for("index"))
    return render_template_string(CHANNEL_PAGE, staging_vhost=STAGING_VHOST)


@app.get("/health")
def health():
    return {"status": "ok", "service": "week8-rocketchat-lab"}


@app.get("/logout")
def logout():
    session.clear()
    return redirect(url_for("index"))


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=3000)
