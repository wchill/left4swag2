from flask import Flask, render_template, g
import time
app = Flask(__name__)
counter = 0
reboot = time.strftime('%x %X (GMT %z)')

@app.route("/")
@app.route("/index.html")
def index():
    return render_template("index.html", visitors=counter, reboot=reboot)

@app.route("/banner")
@app.route("/banner.html")
def banner():
    global counter
    counter += 1
    return render_template("banner.html")
